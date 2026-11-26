import ipaddress
import io
import json
from pathlib import Path
import socket
import ssl
import subprocess
import tempfile
import threading
import unittest
from unittest.mock import Mock,patch

from cryptography import x509

import worker_image_fixture as peers


class WorkerImageFixtureTests(unittest.TestCase):
    def test_network_verification_checks_actual_boundary_with_additive_metadata(self):
        pool={'Subnet':'172.28.240.0/24','Gateway':'172.28.240.1','IPRange':'','AuxiliaryAddresses':{}}
        info={'Internal':True,'IPAM':{'Config':[pool]}}
        self.assertTrue(peers.verified_network(info,'172.28.240.0/24','172.28.240.1'))
        for bad in (dict(info,Internal=False),dict(info,IPAM={'Config':None}),
                    dict(info,IPAM={'Config':[pool,pool]}),
                    dict(info,IPAM={'Config':[dict(pool,Gateway='172.28.240.9')]}),
                    dict(info,IPAM={'Config':[dict(pool,Subnet='172.29.0.0/16')]}),
                    dict(info,IPAM={'Config':[dict(pool,IPRange='172.28.240.0/25')]})):
            self.assertFalse(peers.verified_network(bad,'172.28.240.0/24','172.28.240.1'))

    @classmethod
    def setUpClass(cls):
        cls.material=peers.tls_material({'database':'172.28.240.2','nats-broker':'172.28.240.3'})

    def handshake(self,name,hostname,trusted=True):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            (root/'ca.pem').write_bytes(self.material['ca.pem'])
            for filename,data in self.material[name].items():(root/filename).write_bytes(data)
            server_context=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            server_context.minimum_version=ssl.TLSVersion.TLSv1_2
            server_context.load_cert_chain(root/'cert.pem',root/'key.pem')
            errors=[]
            with socket.socket() as listener:
                listener.bind(('127.0.0.1',0));listener.listen(1);listener.settimeout(3)
                def serve():
                    try:
                        raw,_=listener.accept()
                        with raw:
                            with server_context.wrap_socket(raw,server_side=True) as connection:connection.sendall(b'ok')
                    except (OSError,ssl.SSLError) as error:errors.append(type(error).__name__)
                thread=threading.Thread(target=serve,daemon=True);thread.start()
                context=ssl.create_default_context(cafile=root/'ca.pem') if trusted else ssl.create_default_context()
                context.verify_flags|=ssl.VERIFY_X509_STRICT
                try:
                    with socket.create_connection(listener.getsockname(),timeout=3) as raw:
                        with context.wrap_socket(raw,server_hostname=hostname) as connection:
                            self.assertEqual(connection.recv(2),b'ok')
                finally:thread.join(timeout=4)
                self.assertFalse(thread.is_alive())

    def test_strict_x509_accepts_alias_and_actual_ip_and_rejects_negative_alias_and_unknown_ca(self):
        for name,address in (('database','172.28.240.2'),('nats-broker','172.28.240.3')):
            self.handshake(name,name);self.handshake(name,address)
            for hostname,trusted in (('wrong-'+('database' if name=='database' else 'broker'),True),(name,False)):
                with self.assertRaises(ssl.SSLCertVerificationError):self.handshake(name,hostname,trusted)
        leaf=x509.load_pem_x509_certificate(self.material['database']['cert.pem'])
        self.assertFalse(leaf.extensions.get_extension_for_class(x509.BasicConstraints).value.ca)

    def test_network_selection_refuses_overlap_with_docker_and_host_routes(self):
        docker=[{'IPAM':{'Config':[{'Subnet':'172.28.0.0/16'}]}}]
        route=[{'dst':'10.248.240.0/24'},{'dst':'default'}]
        self.assertEqual(peers.choose_subnet(docker,route),ipaddress.ip_network('10.248.241.0/24'))
        with self.assertRaisesRegex(ValueError,'unoccupied'):
            peers.choose_subnet(docker,[{'dst':'10.0.0.0/8'}])

    def test_host_none_networks_can_have_null_ipam_but_wrong_types_are_refused(self):
        empty=[{'IPAM':{'Config':None}},{'IPAM':{}},{'IPAM':{'Config':[]}}]
        self.assertEqual(peers.choose_subnet(empty,[]),ipaddress.ip_network('172.28.240.0/24'))
        for config in ('',{},False,[None]):
            with self.assertRaisesRegex(ValueError,'IPAM'):peers.choose_subnet([{'IPAM':{'Config':config}}],[])

    def test_broker_info_handles_fragmented_stream_with_size_and_line_boundary(self):
        class Fragments(io.RawIOBase):
            def __init__(self):self.parts=[b'I',b'N',b'FO ',b'{}',b'\r',b'\n']
            def readable(self):return True
            def readinto(self,buffer):
                if not self.parts:return 0
                part=self.parts.pop(0);buffer[:len(part)]=part;return len(part)
        connection=Mock();connection.makefile.return_value=io.BufferedReader(Fragments())
        peers.broker_info(connection)
        for value in (b'INFO {}',b'OTHER {}\r\n',b'INFO '+b'x'*4096+b'\r\n'):
            connection.makefile.return_value=io.BytesIO(value)
            with self.assertRaisesRegex(ValueError,'INFO'):peers.broker_info(connection)

    def test_peer_commands_have_no_host_publication_or_plaintext_database_transport(self):
        pg=peers.postgres_args('db','net','owner','172.28.240.2','image@sha256:abc',Path('/private/db'),'volume')
        nats=peers.nats_args('broker','net','owner','172.28.240.3','image@sha256:def',Path('/private/broker'),Path('/private/store'),'1001:1001')
        for args in (pg,nats):
            self.assertNotIn('--publish',args);self.assertNotIn('--privileged',args)
            self.assertIn('--read-only',args);self.assertIn('no-new-privileges:true',args);self.assertIn('ALL',args)
            self.assertIn('--memory-swap',args);self.assertIn('--pids-limit',args)
        self.assertIn('ssl=on',pg);self.assertIn('ssl_key_file=/lab/key.pem',pg)
        self.assertIn('hba_file=/lab/pg_hba.conf',pg);self.assertIn('POSTGRES_PASSWORD_FILE=/lab/password',pg)
        self.assertIn('wrong-database',pg);self.assertIn('wrong-broker',nats)

    def test_ack_toggle_changes_only_consumer_ack_permission(self):
        passwords={name:'synthetic-private' for name in peers.permissions()}
        allow=peers.peer_config(passwords);deny=peers.peer_config(passwords,False)
        a={v['user']:v for v in allow['authorization']['users']};b={v['user']:v for v in deny['authorization']['users']}
        for name in a:
            if name!='consumer-a':self.assertEqual(a[name],b[name])
        rules=b['consumer-a']['permissions']
        self.assertEqual(rules['subscribe'],a['consumer-a']['permissions']['subscribe'])
        self.assertEqual(rules['publish']['allow'],[f'$JS.API.CONSUMER.MSG.NEXT.{peers.STREAM}.ACCOUNT_A'])
        self.assertNotIn('http',allow);self.assertTrue(allow['tls']['handshake_first'])
        with self.assertRaises(ValueError):peers.peer_config(passwords,'false')

    def test_ack_reload_reports_fixed_substage_without_secret_errors(self):
        passwords={name:'private-password' for name in peers.permissions()}
        for failstage in ('ack_write','ack_validate','ack_reload','ack_probe',None):
            with self.subTest(stage=failstage),tempfile.TemporaryDirectory() as temp:
                docker=Mock()
                def execute(*args,**kwargs):
                    stage='ack_validate' if args[0]=='exec' else 'ack_reload'
                    if stage==failstage:raise RuntimeError('private-password in command failure')
                docker.side_effect=execute
                probe=Mock(return_value=False)
                if failstage=='ack_probe':probe.side_effect=peers.ProbeFailure('conflicting_decision')
                ownership=Mock()
                if failstage=='ack_write':ownership.side_effect=PermissionError('private-password in filename')
                with patch.object(peers,'owned',ownership),patch.object(peers.subprocess,'run',return_value=subprocess.CompletedProcess([],0)),patch.object(peers,'permission_probe',probe):
                    if failstage:
                        with self.assertRaises(peers.FixtureFailure) as failure:
                            peers.change_ack_permission(docker,'broker','owner',Path(temp),passwords,'172.28.240.3',Path('/ca'),False)
                        self.assertEqual(failure.exception.details['stage'],failstage)
                        self.assertEqual(failure.exception.details['peer'],'broker')
                        self.assertNotIn('private-password',str(failure.exception)+json.dumps(failure.exception.details))
                        if failstage=='ack_probe':self.assertEqual(failure.exception.details['probe_code'],'conflicting_decision')
                    else:
                        peers.change_ack_permission(docker,'broker','owner',Path(temp),passwords,'172.28.240.3',Path('/ca'),False)
                        self.assertEqual([call.args for call in docker.call_args_list],[('exec','broker','nats-server','-t','-c','/lab/nats.json'),('kill','--signal=HUP','broker')])
                        self.assertFalse((Path(temp)/'nats.pending').exists())
                        self.assertEqual((Path(temp)/'nats.json').stat().st_mode&0o777,0o440)

    def test_cleanup_attempts_all_owned_resources_after_one_failure_and_refuses_success(self):
        docker=Mock()
        def execute(*args,**kwargs):
            if args==('rm','-f','worker'):raise RuntimeError('injected removal failure')
            return subprocess.CompletedProcess(args,0,'','')
        docker.side_effect=execute
        def owned(_,kind,name,owner,missing=False):
            if name=='worker':return {'Name':'worker'}
            # First read finds resource; subsequent read confirms absent.
            count=counts.get(name,0);counts[name]=count+1
            return {} if count==0 else None
        counts={}
        with patch.object(peers,'owned',side_effect=owned):
            with self.assertRaisesRegex(RuntimeError,'cleanup incomplete'):peers.cleanup(docker,['worker'],'volume','network','owner')
        self.assertIn(('volume','rm','volume'),[call.args for call in docker.call_args_list])
        self.assertIn(('network','rm','network'),[call.args for call in docker.call_args_list])

    def test_foreign_owner_is_never_removed_and_inspect_failure_is_not_false_absence(self):
        foreign={'Name':'/peer','Config':{'Labels':{peers.LABEL:'other'}}}
        docker=Mock(return_value=subprocess.CompletedProcess([],0,json.dumps([foreign]),''))
        with self.assertRaisesRegex(ValueError,'ownership'):peers.owned(docker,'container','peer','owner',missing=True)
        docker=Mock(side_effect=[subprocess.CompletedProcess([],1,'','unavailable'),subprocess.CompletedProcess([],0,'peer\n','')])
        with self.assertRaisesRegex(RuntimeError,'inspection unavailable'):peers.owned(docker,'container','peer','owner',missing=True)

    def test_guard_refuses_local_execution_before_contacting_docker(self):
        with patch.object(peers.portability,'isolated_linux',return_value=False),patch.object(peers,'Docker') as docker:
            with self.assertRaises(peers.FixtureFailure) as result:
                with peers.fixture(Path('/unused')):pass
            self.assertEqual(result.exception.details['stage'],'guard')
            self.assertEqual(result.exception.details['error_type'],'ValueError')
            docker.assert_not_called()

    def test_setup_stage_diagnostics_never_export_raw_errors_and_preserve_caller_failure(self):
        from contextlib import contextmanager
        @contextmanager
        def setup_failure(_,progress):
            progress['stage']='network_plan'
            raise TypeError('private-password or private endpoint')
            yield
        with patch.object(peers,'_fixture',setup_failure):
            with self.assertRaises(peers.FixtureFailure) as result:
                with peers.fixture(Path('/unused')):pass
        details=result.exception.details
        self.assertEqual(details['stage'],'network_plan');self.assertEqual(details['error_type'],'TypeError')
        self.assertNotIn('private',json.dumps(details));self.assertNotIn('endpoint',str(result.exception))
        @contextmanager
        def active(_,progress):
            progress['stage']='active';yield {}
        with patch.object(peers,'_fixture',active):
            with self.assertRaisesRegex(ValueError,'campaign-owned'):
                with peers.fixture(Path('/unused')):raise ValueError('campaign-owned')

    def test_cleanup_failure_keeps_its_explicit_stage_and_custom_type_is_redacted(self):
        class UntrustedExceptionName(Exception):pass
        value=peers.setup_failure('cleanup',UntrustedExceptionName('never print'))
        self.assertEqual(value.details['stage'],'cleanup');self.assertEqual(value.details['error_type'],'other')
        self.assertNotIn('never print',str(value))
        with patch.object(peers.tempfile,'TemporaryDirectory') as temporary:
            temporary.return_value.name='/fixture'
            temporary.return_value.cleanup.side_effect=PermissionError('secret-path')
            with self.assertRaises(peers.FixtureFailure) as result:
                with peers.private_directory(Path('/unused')):pass
        self.assertEqual(result.exception.details['stage'],'private_cleanup')
        self.assertEqual(result.exception.details['error_type'],'PermissionError')

    def test_readiness_failure_exports_only_fixed_categories_and_state(self):
        docker=Mock(side_effect=[subprocess.CompletedProcess([],0,json.dumps([{'State':{'Running':False,'ExitCode':1,'OOMKilled':False}}]),''),
            subprocess.CompletedProcess([],0,'secret-password and permission denied /private/key','')])
        error=peers.readiness_failure(docker,'owned-name','database')
        self.assertEqual(error.details,{'peer':'database','category':'permissions','running':False,'exit_code':1,'oom_killed':False})
        self.assertNotIn('secret-password',str(error));self.assertNotIn('/private/key',json.dumps(error.details))

    def test_permission_probe_requires_explicit_accept_or_specific_publish_denial(self):
        for outcome,expected in ((b'+OK\r\n',True),(b'-ERR \'Permissions Violation for Publish\'\r\n',False),
                                 (b'-ERR \'Authorization Violation\'\r\n',None),(b'',None)):
            connection=Mock();connection.makefile.return_value=io.BytesIO(b'INFO {}\r\n+OK\r\nPONG\r\n'+outcome+b'PONG\r\n')
            wrapped=Mock();wrapped.__enter__=Mock(return_value=connection);wrapped.__exit__=Mock(return_value=False)
            context=Mock();context.wrap_socket.return_value=wrapped
            raw=Mock();raw.__enter__=Mock(return_value=raw);raw.__exit__=Mock(return_value=False)
            with patch.object(peers.ssl,'create_default_context',return_value=context),patch.object(peers.socket,'create_connection',return_value=raw):
                if expected is None:
                    with self.assertRaises(ValueError):peers.permission_probe('172.28.240.3',Path('/ca.pem'),'never-log-this')
                else:self.assertEqual(peers.permission_probe('172.28.240.3',Path('/ca.pem'),'never-log-this'),expected)
            self.assertTrue(connection.sendall.call_args_list[1].args[0].startswith(b'PUB '+peers.ACK_PROBE.encode()))


if __name__=='__main__':unittest.main()
