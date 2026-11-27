import copy
import json
from pathlib import Path
import subprocess
import http.client
import ssl
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
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
        docker=Mock(side_effect=lambda *args,**kwargs:response(json.dumps({'Id':digests[args[-1]]})))
        actual=smoke.verified_images(manifest,docker)
        self.assertEqual(set(actual),set(smoke.ROLES))
        self.assertTrue(all(call.args[:3]==('image','inspect','--format') for call in docker.call_args_list))
        with self.assertRaises(smoke.SmokeFailure) as failed:
            smoke.verified_images(manifest,Mock(return_value=response(json.dumps({'Id':'sha256:'+'f'*64}))))
        self.assertEqual(failed.exception.check,'image_loaded_identity_mismatch')
        changed=copy.deepcopy(manifest);changed['images']['browser-session']['image']='local/other@sha256:'+'f'*64
        docker.reset_mock()
        with self.assertRaises(smoke.SmokeFailure) as failed:smoke.verified_images(changed,docker)
        self.assertEqual(failed.exception.check,'image_inventory_differs_from_oci')
        docker.assert_not_called()

    def test_classic_and_containerd_ids_bind_to_exact_verified_content(self):
        manifest={'digest':'sha256:'+'a'*64,'size':1234,'mediaType':'application/vnd.oci.image.manifest.v1+json'}
        config='sha256:'+'b'*64
        classic=smoke.bind_loaded_image('browser-session',{'Id':config},manifest,config)
        self.assertEqual(classic['runtime_id'],config);self.assertEqual(classic['identity_kind'],'config')
        modern=smoke.bind_loaded_image('browser-session',{'Id':manifest['digest'],'Descriptor':manifest},manifest,config)
        self.assertEqual(modern['runtime_id'],manifest['digest']);self.assertEqual(modern['identity_kind'],'oci-manifest')
        invalid=[{'Id':manifest['digest']},{'Id':manifest['digest'],'Descriptor':dict(manifest,size=1235)},
            {'Id':manifest['digest'],'Descriptor':dict(manifest,mediaType='application/vnd.oci.image.index.v1+json')},
            {'Id':manifest['digest'],'Descriptor':dict(manifest,digest='sha256:'+'c'*64)},
            {'Id':'sha256:'+'c'*64,'Descriptor':manifest},{'Id':config,'Descriptor':dict(manifest,size=1)}]
        for loaded in invalid:
            with self.assertRaises(smoke.SmokeFailure) as failure:smoke.bind_loaded_image('browser-session',loaded,manifest,config)
            self.assertEqual(failure.exception.check,'image_loaded_identity_mismatch')

    def test_source_reinspection_and_loaded_metadata_have_distinct_safe_errors(self):
        manifest,_=self.inventory()
        with patch.object(smoke.runtime_images,'inspect',side_effect=ValueError('Image source or interface contract mismatch')):
            with self.assertRaises(smoke.SmokeFailure) as failure:smoke.verified_images(manifest,Mock())
            self.assertEqual(failure.exception.check,'image_source_labels_mismatch')
        with self.assertRaises(smoke.SmokeFailure) as failure:smoke.verified_images(manifest,Mock(return_value=response('private invalid output')))
        self.assertEqual(failure.exception.check,'image_loaded_metadata_invalid')
        details=smoke.failure(smoke.SmokeFailure('image_loaded_identity_mismatch',{
            'role':'browser-session','loaded_id':'sha256:'+'f'*64,'descriptor_media_type':{'private':'secret'},
            'descriptor_digest':'private-sentinel','password':'private-sentinel'}))
        self.assertEqual(details['image_identity']['loaded_id'],'sha256:'+'f'*64)
        self.assertNotIn('private-sentinel',json.dumps(details))

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

    def test_internal_direct_probe_preserves_verified_tls_sni_and_host_origin(self):
        smoke.certificates(self.root,'127.0.0.1');hosts=[]
        class Handler(BaseHTTPRequestHandler):
            def log_message(self,*_):pass
            def do_GET(self):
                hosts.append(self.headers['Host']);self.send_response(200)
                self.send_header('Content-Length','2');self.end_headers();self.wfile.write(b'[]')
        server=ThreadingHTTPServer(('127.0.0.1',0),Handler)
        tls=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);tls.load_cert_chain(self.root/'tls.crt',self.root/'tls.key')
        server.socket=tls.wrap_socket(server.socket,server_side=True)
        thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
        try:
            context=ssl.create_default_context(cafile=self.root/'ca.pem');context.verify_flags|=ssl.VERIFY_X509_STRICT
            with patch.object(context,'wrap_socket',wraps=context.wrap_socket) as wrap:
                status,_,_=smoke.request(18447,context,'/health/ready',('127.0.0.1',server.server_port))
                self.assertEqual(status,200);self.assertEqual(wrap.call_args.kwargs['server_hostname'],'localhost')
            self.assertEqual(hosts,['localhost:18447'])
            with self.assertRaises(ssl.SSLCertVerificationError):
                smoke.request(18447,ssl.create_default_context(),'/health/ready',('127.0.0.1',server.server_port))
        finally:server.shutdown();server.server_close();thread.join(2)

    def test_probe_route_uses_effective_mappings_not_just_requested_bindings(self):
        binding=[{'HostIp':'127.0.0.1','HostPort':'18447'}]
        container={'HostConfig':{'PortBindings':{'18447/tcp':binding}},
            'NetworkSettings':{'Ports':{'18447/tcp':None},'Networks':{'owned':{'IPAddress':'172.18.0.2'}}}}
        self.assertEqual(smoke.probe_route(container,'owned','172.18.0.0/16',18447),('internal-direct',('172.18.0.2',18447)))
        container['NetworkSettings']['Ports']['18447/tcp']=binding
        self.assertEqual(smoke.probe_route(container,'owned','172.18.0.0/16',18447),('published-loopback',None))
        container['NetworkSettings']['Ports']['18447/tcp']=[{'HostIp':'0.0.0.0','HostPort':'18447'}]
        with self.assertRaises(ValueError):smoke.probe_route(container,'owned','172.18.0.0/16',18447)
        container['NetworkSettings']['Ports']['18447/tcp']=None
        container['NetworkSettings']['Networks']['owned']['IPAddress']='192.0.2.1'
        with self.assertRaises(ValueError):smoke.probe_route(container,'owned','172.18.0.0/16',18447)

    def test_readiness_failure_contains_only_status_categories_state_and_known_markers(self):
        docker=Mock(side_effect=[response(json.dumps([{'State':{'Running':True,'ExitCode':0,'OOMKilled':False,'Error':'private-sentinel'}}])),
                                response('Browser runtime started with verified identity trust.\nprivate-sentinel\n')])
        details=smoke.readiness_details(docker,'owned',{'last_http_status':None,'last_error':'connection_refused'},'internal-direct')
        self.assertEqual(details['startup_markers'],['started']);self.assertIs(details['running'],True)
        self.assertEqual(details['last_error'],'connection_refused')
        report=smoke.failure(smoke.SmokeFailure('packaged_browser_verified_https_ready',readiness=details))
        self.assertNotIn('private-sentinel',json.dumps(report))
        self.assertEqual(smoke.error_category(TimeoutError('private-sentinel')),'timeout')
        self.assertEqual(smoke.error_category(ssl.SSLCertVerificationError('private-sentinel')),'tls_verification')
        self.assertNotIn('private-sentinel',json.dumps(smoke.public_readiness({'last_error':{'private':'private-sentinel'},'startup_markers':None})))

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
