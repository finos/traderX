import copy
import json
from pathlib import Path
import subprocess
import http.client
import ssl
import tempfile
import unittest
from unittest.mock import Mock, patch

import admission_fixture
import integrated_deployment as compiler
import runtime_images
import runtime_launcher
import verify_runtime_images as smoke


def response(stdout='',returncode=0,stderr=''):
    return subprocess.CompletedProcess([],returncode,stdout,stderr)


class RuntimeImageSmokeTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name).resolve()

    def inventory(self):
        entries={};digests={};revision='0'*40;source=compiler.source_manifest()
        for role in smoke.ROLES:
            entry=admission_fixture.image(self.root,role,source,revision,
                lambda config,role=role:config['config'].update(Entrypoint=runtime_images.argv(role),Cmd=[]))
            reference='traderx-local/'+role+':'+revision
            entries[role]=dict(runtime_images.inspect(role,entry['oci_layout'],reference,revision),runtime_reference=reference)
            layout=Path(entry['oci_layout']);descriptor=compiler.read_json(layout/'index.json')['manifests'][0]
            digests[reference]=compiler.blob(layout,descriptor)['config']['digest']
        return {'source_commit':revision,'images':entries},digests

    def test_loaded_config_digest_must_equal_reinspected_oci_before_any_run(self):
        manifest,digests=self.inventory()
        docker=Mock(side_effect=lambda *args,**kwargs:response(digests[args[-1]]+'\n'))
        actual=smoke.verified_images(manifest,docker)
        self.assertEqual(set(actual),set(smoke.ROLES))
        self.assertTrue(all(call.args[:3]==('image','inspect','--format') for call in docker.call_args_list))
        with self.assertRaisesRegex(ValueError,'Loaded Docker'):
            smoke.verified_images(manifest,Mock(return_value=response('sha256:'+'f'*64)))
        changed=copy.deepcopy(manifest);changed['images']['browser-session']['image']='local/other@sha256:'+'f'*64
        docker.reset_mock()
        with self.assertRaisesRegex(ValueError,'differs from inspected'):smoke.verified_images(changed,docker)
        docker.assert_not_called()

    def test_run_uses_immutable_digest_and_hardened_owned_boundaries(self):
        digest='sha256:'+'a'*64
        args=smoke.launch_args('owned','network','owner',self.root/'projected',digest,18447)
        self.assertEqual(args[-1],digest)
        self.assertIn('127.0.0.1:18447:18447',args)
        self.assertIn('10001:10001',args);self.assertIn('--read-only',args)
        self.assertEqual(args[args.index('--memory')+1],'256m')
        self.assertEqual(args[args.index('--cap-drop')+1],'ALL')
        self.assertIn('no-new-privileges:true',args)
        self.assertTrue(any('uid=10001,gid=10001,mode=0700' in value for value in args))
        self.assertTrue(any('dst=/run/projected,readonly' in value for value in args))
        for forbidden in ('--privileged','--network=host','--pid=host','--entrypoint','--env'):
            self.assertNotIn(forbidden,args)

    def test_projected_keys_are_readonly_root_group_readable_even_with_private_umask(self):
        values={'ca.pem':b'public','tls.crt':b'certificate','tls.key':b'private-fixture'}
        with patch.object(smoke.subprocess,'run',return_value=response()) as command:
            root=smoke.projected(self.root,'browser-session',{'sentinel':'private-fixture'},values)
        self.assertEqual(root.stat().st_mode&0o777,0o750)
        self.assertTrue(all(path.stat().st_mode&0o777==0o440 for path in root.iterdir()))
        self.assertEqual(command.call_args_list[0].args[0][:4],['sudo','-n','chgrp','10001'])
        self.assertEqual(command.call_args_list[1].args[0][:4],['sudo','-n','chown','0:10001'])
        self.assertNotIn('private-fixture',str(command.call_args_list))

    def test_workers_deliberately_reject_other_valid_mode_without_claiming_delivery(self):
        for role in ('event-publisher','event-consumer'):
            config=smoke.worker_config(role,'172.18.0.1')
            self.assertEqual(config['database_transport'],'verify-full')
            with self.assertRaisesRegex(ValueError,'role'):runtime_launcher.validate(role,config)
            self.assertNotIn('PGPASSWORD',config)

    def test_container_probe_checks_actual_identity_files_and_privileges(self):
        container={'Config':{'User':'10001:10001'},'HostConfig':{'ReadonlyRootfs':True,'CapDrop':['ALL'],
                   'SecurityOpt':['no-new-privileges:true']},'Mounts':[{'Destination':'/run/projected','RW':False},
                   {'Destination':'/run/private','Type':'tmpfs'}]}
        probe={'uid':10001,'gid':10001,'projected':[0,10001,0o440],'private':[10001,10001,0o600],
               'directory':[10001,10001,0o700],'no_new_privileges':'1','capabilities':'0000000000000000','root_write_denied':True,'private_filesystem':['tmpfs']}
        smoke.check_restrictions(container,probe)
        container['Mounts']=container['Mounts'][:1];container['HostConfig']['Tmpfs']={'/run/private':'mode=0700'}
        smoke.check_restrictions(container,probe)
        for delta in ({'uid':0},{'private':[10001,10001,0o644]},{'root_write_denied':False},{'capabilities':'0000000000000001'},{'private_filesystem':['ext4']}):
            with self.assertRaises(ValueError):smoke.check_restrictions(container,dict(probe,**delta))

    def test_fixture_chain_passes_strict_verified_tls_without_docker(self):
        _,keys=smoke.certificates(self.root,'127.0.0.1')
        context=ssl.create_default_context(cafile=self.root/'ca.pem')
        context.verify_flags|=ssl.VERIFY_X509_STRICT
        with smoke.issuer_peer(self.root,'127.0.0.1',keys) as origin:
            port=int(origin.rsplit(':',1)[1]);connection=http.client.HTTPSConnection('127.0.0.1',port,context=context,timeout=2)
            try:
                connection.request('GET','/realms/image-smoke/protocol/openid-connect/certs')
                reply=connection.getresponse();self.assertEqual(reply.status,200)
                self.assertEqual(json.loads(reply.read()),keys)
            finally:connection.close()

    def test_failure_diagnostics_never_echo_exception_or_private_material(self):
        smoke.stage('browser_ready')
        self.assertEqual(smoke.failure(ValueError('secret-password')),{
            'status':'failed','stage':'browser_ready','check':'runtime_boundary_unavailable'})
        self.assertEqual(smoke.failure(smoke.SmokeFailure('packaged_browser_verified_https_ready'))['check'],'packaged_browser_verified_https_ready')
        self.assertEqual(smoke.failure(smoke.SmokeFailure('secret-password'))['check'],'runtime_boundary_unavailable')
        with self.assertRaises(ValueError):smoke.stage('private-stage-input')

    def test_cleanup_only_removes_owned_resources_and_continues_after_failure(self):
        def command(*args,**kwargs):
            if args[1]=='inspect':
                if args[-1]=='foreign':return response('someone-else')
                if args[-1]=='failed':raise RuntimeError('command unavailable')
                return response('owner')
            return response()
        docker=Mock(side_effect=command)
        with self.assertRaisesRegex(RuntimeError,'cleanup'):
            smoke.cleanup_owned(docker,['own','foreign','failed'],'network','owner')
        removals=[call.args for call in docker.call_args_list if call.args[1]=='rm']
        self.assertEqual(removals,[('container','rm','-f','own'),('network','rm','network')])

    def test_execution_refuses_non_hosted_environment_before_docker(self):
        with patch.object(smoke.portability,'isolated_linux',return_value=False),patch.object(smoke,'Docker') as docker:
            with self.assertRaisesRegex(ValueError,'hosted'):smoke.campaign(self.root,{})
            docker.assert_not_called()


if __name__=='__main__':unittest.main()
