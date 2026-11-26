import copy
from datetime import datetime,timezone,timedelta
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import java_runtime as runtime


def configuration():
    return {'version':1,'role':'position-service','database':{'host':'database','port':5432,'name':'traderx',
        'username':'lab_position','password':'private-password-123'},'identity':{'issuer':'https://identity:8443/realms/lab',
        'audience':'traderx-api','key_not_after':(datetime.now(timezone.utc)+timedelta(hours=1)).strftime('%Y-%m-%dT%H:%M:%SZ')},
        'tls':{'password':'private-store-pass-123'}}


class JavaRuntimeTests(unittest.TestCase):
    def test_properties_fix_transport_scope_and_keep_credentials_out_of_argv(self):
        config=configuration();value=runtime.properties(config).decode()
        self.assertIn('server.address=0.0.0.0\n',value);self.assertIn('server.port=18090\n',value)
        self.assertIn('sslmode=verify-full&sslrootcert=/run/private/config/database-ca.pem',value)
        self.assertIn('server.ssl.enabled=true\n',value)
        self.assertIn('spring.datasource.hikari.maximum-pool-size=2\n',value)
        self.assertIn('spring.sql.init.mode=always\n',value)
        self.assertIn('spring.sql.init.continue-on-error=false\n',value)
        for phase in ('schema','data'):self.assertIn('spring.sql.init.'+phase+'-locations=file:/opt/traderx/startup-check.sql\n',value)
        self.assertIn('lab.identity.public-key-file=/run/private/config/public.pem\n',value)
        self.assertNotIn(config['database']['password'],' '.join(runtime.argv()))
        self.assertNotIn(config['tls']['password'],' '.join(runtime.argv()))
        self.assertEqual(runtime.argv()[0],'/opt/java/openjdk/bin/java')
        self.assertIn('/app/application.jar',runtime.argv())
        self.assertIn('--spring.config.location=file:/run/private/java/application.properties',runtime.argv())

    def test_unknown_keys_interpolation_control_characters_and_unscoped_identity_fail_closed(self):
        cases=[(('unexpected',),'x'),(('database','sslmode'),'disable'),(('tls','path'),'/tmp/unsafe'),
            (('database','password'),'${OTHER_SECRET}'),(('database','password'),'safe-password\\\nx=bad'),
            (('database','host'),'database?sslmode=disable'),(('database','username'),'traderx'),
            (('database','username'),'postgres'),(('database','port'),True),(('database','port'),5433),
            (('identity','issuer'),'https://identity/${OVERRIDE}'),(('identity','issuer'),'http://identity/'),
            (('identity','issuer'),'https://user:pass@identity/'),(('identity','audience'),'other'),
            (('identity','key_not_after'),'2000-01-01T00:00:00Z'),(('version',),True),
            (('role',),'account-service')]
        for keys,value in cases:
            config=configuration();target=config
            for key in keys[:-1]:target=target[key]
            target[keys[-1]]=value
            with self.subTest(keys=keys,value=value),self.assertRaises(ValueError):runtime.validate(config)
        config=configuration();config['identity']['key_not_after']=(datetime.now(timezone.utc)+timedelta(hours=9)).strftime('%Y-%m-%dT%H:%M:%SZ')
        with self.assertRaises(ValueError):runtime.validate(config)

    def test_private_input_inventory_permissions_duplicate_keys_and_entitlements(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary).resolve()
            for name in runtime.KEYS:
                (root/name).write_bytes(b'fixture');(root/name).chmod(0o600)
            (root/'config.json').write_text(json.dumps(configuration()))
            (root/'entitlements.properties').write_text('subject-1=read-only:22214\noperator=operator:\n')
            with patch.object(runtime,'PRIVATE',root),patch.object(runtime,'CONFIG',root/'config.json'):
                self.assertEqual(runtime.load_config()['role'],'position-service')
                for payload in ('subject-1=read-only:22214\nsubject-1=trader:22214','x=reader:22214','x=trader:01','x=trader:2147483648','x=trader:22,22','x=${PROP}:22'):
                    (root/'entitlements.properties').write_text(payload)
                    with self.assertRaises(ValueError):runtime.load_config()
                (root/'entitlements.properties').write_text('subject-1=read-only:22214\n')
                (root/'public.pem').chmod(0o644)
                with self.assertRaises(ValueError):runtime.load_config()
                (root/'public.pem').chmod(0o600)
                (root/'config.json').write_text('{"version":1,"version":1}')
                with self.assertRaisesRegex(ValueError,'Duplicate'):runtime.load_config()
                (root/'config.json').unlink();(root/'config.json').symlink_to(root/'public.pem')
                with self.assertRaises(OSError):runtime.load_config()

    def test_atomic_output_is_private_and_never_overwrites_or_follows_links(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary).resolve();destination=root/'java/application.properties'
            with patch.object(runtime,'PROPERTIES',destination):
                runtime.write_properties(b'private-data')
                self.assertEqual(destination.read_bytes(),b'private-data')
                self.assertEqual(destination.stat().st_mode&0o777,0o600)
                self.assertEqual(destination.stat().st_uid,os.geteuid())
                self.assertEqual(destination.parent.stat().st_uid,os.geteuid())
                self.assertEqual(destination.parent.stat().st_mode&0o777,0o700)
                with self.assertRaises(FileExistsError):runtime.write_properties(b'replacement')
                self.assertEqual(destination.read_bytes(),b'private-data')
                destination.unlink();outside=root/'other';outside.write_bytes(b'unchanged');destination.symlink_to(outside)
                with self.assertRaises(FileExistsError):runtime.write_properties(b'replacement')
                self.assertEqual(outside.read_bytes(),b'unchanged')
                self.assertFalse(any(path.name.startswith('.java-') for path in destination.parent.iterdir()))

    def test_private_output_directory_refuses_foreign_owner_group_access_and_symlink(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary).resolve();directory=root/'java';directory.mkdir(mode=0o700)
            with patch.object(runtime,'PROPERTIES',directory/'application.properties'):
                for mode in (0o770,0o750,0o755,0o2770):
                    directory.chmod(mode)
                    with self.subTest(mode=mode),self.assertRaisesRegex(ValueError,'ownership and mode'):runtime.write_properties(b'secret')
                    self.assertEqual(list(directory.iterdir()),[])
                directory.chmod(0o700)
                with patch.object(runtime.os,'geteuid',return_value=os.geteuid()+1):
                    with self.assertRaisesRegex(ValueError,'ownership and mode'):runtime.write_properties(b'secret')
                directory.rmdir();directory.symlink_to(root,target_is_directory=True)
                with self.assertRaisesRegex(ValueError,'Direct private'):runtime.write_properties(b'secret')
                self.assertFalse((root/'application.properties').exists())

    def test_environment_overrides_are_refused_before_java_exec(self):
        runtime.check_environment({'PATH':'/usr/local/bin','JAVA_HOME':'/opt/java/openjdk','PYTHON_VERSION':'3.14.0'})
        for name in ('SPRING_APPLICATION_JSON','SPRING_CONFIG_LOCATION','SERVER_PORT','LAB_IDENTITY_ISSUER',
                     'JAVA_TOOL_OPTIONS','JDK_JAVA_OPTIONS','_JAVA_OPTIONS','CLASSPATH','LOGGING_CONFIG'):
            with self.subTest(name=name),self.assertRaises(ValueError):runtime.check_environment({name:'override'})
        with patch.object(runtime.sys,'argv',['java_runtime.py','--role','position-service','--config',str(runtime.CONFIG)]),patch.object(runtime.os,'geteuid',return_value=10001),patch.object(runtime.os,'getegid',return_value=10001),patch.object(runtime,'load_config',return_value=configuration()),patch.object(runtime,'write_properties') as write,patch.object(runtime.os,'environ',{}),patch.object(runtime.os,'execve') as execute:
            runtime.main();write.assert_called_once()
            executable,args,environment=execute.call_args.args
            self.assertEqual(executable,runtime.JAVA);self.assertEqual(args,runtime.argv())
            self.assertEqual(environment,{'PATH':'/usr/bin:/bin','LANG':'C.UTF-8','TZ':'UTC'})


if __name__=='__main__':unittest.main()
