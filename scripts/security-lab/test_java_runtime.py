import copy
from datetime import datetime,timezone,timedelta
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import java_runtime as runtime


def matcher_configuration():
    value=configuration();value['role']='order-matcher'
    value['execution']={'endpoint':'https://trade-processor:18091/internal/executions/',
        'token_endpoint':value['identity']['issuer']+'/protocol/openid-connect/token','client_id':'lab-matcher-service'}
    value['broker']={'host':'nats-broker','port':4222,'username':'matcher'}
    return value


def certificate():
    from cryptography import x509
    from cryptography.hazmat.primitives import hashes,serialization
    from cryptography.hazmat.primitives.asymmetric import rsa
    key=rsa.generate_private_key(public_exponent=65537,key_size=2048)
    name=x509.Name([x509.NameAttribute(x509.NameOID.COMMON_NAME,'Synthetic test CA')])
    now=datetime.now(timezone.utc)
    return (x509.CertificateBuilder().subject_name(name).issuer_name(name).public_key(key.public_key())
        .serial_number(x509.random_serial_number()).not_valid_before(now-timedelta(minutes=1))
        .not_valid_after(now+timedelta(hours=1)).add_extension(x509.BasicConstraints(ca=True,path_length=None),critical=True)
        .sign(key,hashes.SHA256()).public_bytes(serialization.Encoding.PEM))


def configuration():
    return {'version':1,'role':'position-service','database':{'host':'database','port':5432,'name':'traderx',
        'username':'lab_position','password':'private-password-123'},'identity':{'issuer':'https://identity:8443/realms/lab',
        'audience':'traderx-api','key_not_after':(datetime.now(timezone.utc)+timedelta(hours=1)).strftime('%Y-%m-%dT%H:%M:%SZ')},
        'tls':{'password':'private-store-pass-123'}}


class JavaRuntimeTests(unittest.TestCase):
    def test_matcher_requires_explicit_scoped_destinations_and_private_credentials(self):
        config=matcher_configuration();value=runtime.properties(config,role='order-matcher').decode()
        for expected in ('server.port=18110','order.matcher.seed-enabled=false','lab.execution.enabled=true',
                         'order.matcher.publisher=nats','order.matcher.pricing-subscriber.enabled=true',
                         'spring.jpa.hibernate.ddl-auto=none','spring.jpa.open-in-view=false',
                         'nats.address=tls://nats-broker:4222','lab.execution.client-id=lab-matcher-service',
                         'order.matcher.price-service-url=disabled','order.matcher.trade-service-url=disabled',
                         'spring.jpa.hibernate.naming.physical-strategy=org.hibernate.boot.model.naming.PhysicalNamingStrategyStandardImpl',
                         'spring.jpa.database-platform=org.hibernate.dialect.PostgreSQLDialect'):
            self.assertIn(expected+'\n',value)
        self.assertIn('lab.execution.secret-file=/run/private/config/client-secret\n',value)
        self.assertIn('lab.broker.secret-file=/run/private/config/broker-secret\n',value)
        self.assertEqual(len(runtime.MATCHER_KEYS),10)
        args=' '.join(runtime.argv('order-matcher'))
        self.assertIn('-Djavax.net.ssl.trustStorePassword=changeit',args)
        for secret in (config['database']['password'],config['tls']['password']):self.assertNotIn(secret,args)
        for section,key,bad in (('execution','endpoint','http://trade-processor:18091/internal/executions/'),
                ('execution','endpoint','https://trade-processor:18091/trade/'),
                ('execution','token_endpoint','https://foreign:8443/token'),
                ('execution','client_id','${OVERRIDE}'),('broker','host','user:pass@nats'),
                ('broker','port',4223),('broker','port',True),('broker','username','bad\nx=1')):
            changed=copy.deepcopy(config);changed[section][key]=bad
            with self.subTest(section=section,key=key),self.assertRaises(ValueError):runtime.validate(changed,role='order-matcher')

    def test_matcher_exact_private_inventory_validates_separate_secrets_and_public_cas(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary).resolve();pem=certificate()
            for name in runtime.MATCHER_KEYS:
                data=pem if name in ('broker-ca.pem','identity-ca.pem','processor-ca.pem') else b'fixture'
                if name in ('broker-secret','client-secret'):data=b'private-credential-1234'
                (root/name).write_bytes(data);(root/name).chmod(0o600)
            (root/'config.json').write_text(json.dumps(matcher_configuration()))
            (root/'entitlements.properties').write_text('trader=trader:62654\n')
            with patch.object(runtime,'PRIVATE',root),patch.object(runtime,'CONFIG',root/'config.json'):
                self.assertEqual(runtime.load_config('order-matcher')['role'],'order-matcher')
                for name,bad in (('client-secret',b'short'),('broker-secret',b'valid-credential-1234\n'),
                        ('identity-ca.pem',pem+pem),('processor-ca.pem',b'-----BEGIN PRIVATE KEY-----\nabc\n-----END PRIVATE KEY-----\n')):
                    old=(root/name).read_bytes();(root/name).write_bytes(bad)
                    with self.subTest(name=name),self.assertRaises(ValueError):runtime.load_config('order-matcher')
                    (root/name).write_bytes(old)
                (root/'extra').write_text('x')
                with self.assertRaisesRegex(ValueError,'inventory'):runtime.load_config('order-matcher')

    def test_outbound_store_contains_only_fixed_public_certificate_imports_and_is_private(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary).resolve();private=root/'config';private.mkdir(mode=0o700)
            output=root/'java/application.properties';store=root/'java/outbound-trust.p12'
            pem=certificate()
            for name in ('identity','processor','broker'):
                path=private/(name+'-ca.pem');path.write_bytes(pem);path.chmod(0o600)
            def imported(args,**kwargs):
                self.assertEqual(args[:3],[runtime.KEYTOOL,'-importcert','-noprompt'])
                self.assertEqual(args[-4:],['-storetype','PKCS12','-storepass','changeit'])
                self.assertEqual(kwargs['umask'],0o077);self.assertEqual(kwargs['timeout'],15)
                self.assertEqual(kwargs['env'],{'PATH':'/usr/bin:/bin','LANG':'C.UTF-8'})
                target=Path(args[args.index('-keystore')+1]);target.write_bytes(b'synthetic-store-not-Java-acceptance');target.chmod(0o600)
            with patch.object(runtime,'PROPERTIES',output),patch.object(runtime,'OUTBOUND',store),patch.object(runtime,'PRIVATE',private),patch.object(runtime.subprocess,'run',side_effect=imported) as run:
                runtime.write_properties(b'private')
                runtime.outbound_truststore()
                self.assertEqual(run.call_count,3)
                self.assertEqual([call.args[0][call.args[0].index('-alias')+1] for call in run.call_args_list],['identity','processor','broker'])
                self.assertEqual(store.stat().st_mode&0o777,0o600)
                self.assertEqual(store.stat().st_nlink,1)
                with self.assertRaisesRegex(ValueError,'Fresh'):runtime.outbound_truststore()
                store.unlink();run.side_effect=runtime.subprocess.TimeoutExpired('keytool',15)
                with self.assertRaises(runtime.subprocess.TimeoutExpired):runtime.outbound_truststore()
                self.assertFalse(store.exists())
                self.assertEqual({p.name for p in output.parent.iterdir()},{'application.properties'})

    def test_role_audiences_ports_matcher_subject_and_entitlements_are_explicit(self):
        for role,port in (('position-service',18090),('account-service',18088),('trade-processor',18091)):
            config=configuration();config['role']=role
            if role=='trade-processor':
                config['identity'].update(audience='traderx-execution',matcher_subject='matcher-123')
            value=runtime.properties(config,role=role).decode()
            self.assertIn('server.port='+str(port)+'\n',value)
            self.assertIn('sslmode=verify-full',value)
            self.assertIn('spring.sql.init.mode=always\n',value)
            self.assertEqual('lab.execution.matcher-subject=matcher-123\n' in value,role=='trade-processor')
            self.assertEqual('lab.identity.entitlements-file=' in value,role!='trade-processor')
            for other in runtime.ROLES:
                if other!=role:
                    with self.assertRaises(ValueError):runtime.validate(config,role=other)
        for matcher in ('','${UNTRUSTED}','valid\ninjected=1','x'*129):
            config=configuration();config['role']='trade-processor'
            config['identity'].update(audience='traderx-execution',matcher_subject=matcher)
            with self.assertRaises(ValueError):runtime.validate(config,role='trade-processor')
        config=configuration();config['role']='trade-processor'
        with self.assertRaises(ValueError):runtime.validate(config,role='trade-processor')
        config['identity']['matcher_subject']='matcher'
        with self.assertRaisesRegex(ValueError,'audience'):runtime.validate(config,role='trade-processor')
        config=configuration();config['identity']['matcher_subject']='matcher'
        with self.assertRaises(ValueError):runtime.validate(config)
        with self.assertRaisesRegex(ValueError,'Reviewed'):runtime.role_contract('unreviewed-java')

    def test_per_role_private_inventory_refuses_borrowed_or_missing_keys(self):
        for role in ('account-service','trade-processor'):
            config=configuration();config['role']=role
            if role=='trade-processor':config['identity'].update(audience='traderx-execution',matcher_subject='matcher')
            with tempfile.TemporaryDirectory() as temporary:
                root=Path(temporary).resolve()
                for name in runtime.role_contract(role)['keys']:
                    (root/name).write_bytes(b'fixture');(root/name).chmod(0o600)
                (root/'config.json').write_text(json.dumps(config))
                if role=='account-service':(root/'entitlements.properties').write_text('reader=read-only:22214\n')
                with patch.object(runtime,'PRIVATE',root),patch.object(runtime,'CONFIG',root/'config.json'):
                    self.assertEqual(runtime.load_config(role)['role'],role)
                    extra=root/('entitlements.properties' if role=='trade-processor' else 'matcher-subject')
                    extra.write_text('unexpected');extra.chmod(0o600)
                    with self.assertRaisesRegex(ValueError,'inventory'):runtime.load_config(role)
                    extra.unlink();(root/'tls.p12').unlink()
                    with self.assertRaisesRegex(ValueError,'inventory'):runtime.load_config(role)

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

    def test_matcher_trust_import_failure_never_executes_java(self):
        import io
        with patch.object(runtime.sys,'argv',['java_runtime.py','--role','order-matcher','--config',str(runtime.CONFIG)]),patch.object(runtime.os,'geteuid',return_value=10001),patch.object(runtime.os,'getegid',return_value=10001),patch.object(runtime,'load_config',return_value=matcher_configuration()),patch.object(runtime,'write_properties'),patch.object(runtime,'outbound_truststore',side_effect=RuntimeError('private-marker')),patch.object(runtime.os,'environ',{}),patch.object(runtime.os,'execve') as execute,patch.object(runtime.sys,'stderr',new_callable=io.StringIO) as error:
            self.assertEqual(runtime.main(),2)
            execute.assert_not_called()
            self.assertEqual(error.getvalue(),'Protected Java configuration refused; private details withheld.\n')

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
