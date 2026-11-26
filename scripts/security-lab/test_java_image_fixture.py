import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import Mock,patch

from cryptography import x509
from cryptography.hazmat.primitives.serialization import pkcs12
import java_image_fixture as fixture
import verify_position_image as position


def result(stdout='',code=0):return subprocess.CompletedProcess([],code,stdout,'')


class JavaImageFixtureTests(unittest.TestCase):
    def test_role_certs_keys_and_probes_do_not_change_position_contract(self):
        original=position.PRIVATE_JAVA_PROBE;issuer=position.ISSUER
        for role,port in fixture.PORTS.items():
            ca,bundle,password=fixture.certificate_material(role)
            key,leaf,chain=pkcs12.load_key_and_certificates(bundle,password.encode())
            self.assertIsNotNone(key);self.assertEqual(len(chain),1)
            leaf.verify_directly_issued_by(x509.load_pem_x509_certificate(ca))
            self.assertEqual(leaf.extensions.get_extension_for_class(x509.SubjectAlternativeName).value.get_values_for_type(x509.DNSName),[role])
            self.assertIn("=='"+str(port)+"'",fixture.private_java_probe(role))
            self.assertEqual('entitlements.properties' in fixture.KEYS[role],role=='account-service')
        self.assertEqual(position.PRIVATE_JAVA_PROBE,original);self.assertEqual(position.ISSUER,issuer)
        with self.assertRaises(ValueError):fixture.certificate_material('unreviewed')

    def test_request_uses_instance_role_port_tls_hostname_and_method(self):
        context=Mock();wrapped=Mock();context.wrap_socket.return_value=wrapped
        connection=Mock();connection.getresponse.return_value.status=403;connection.getresponse.return_value.read.return_value=b'denied'
        raw=Mock()
        with patch.object(fixture.http.client,'HTTPSConnection',return_value=connection) as constructor,patch.object(fixture.socket,'create_connection',return_value=raw) as create:
            self.assertEqual(fixture.request('trade-processor','172.28.240.4',context,'/internal/executions/id',bearer='fixture-token',method='POST',body=b'{}',headers={'X-Service-Subject':'spoof'}),(403,b'denied'))
            constructor.assert_called_once_with('trade-processor',18091,context=context,timeout=4)
            connection.connect();create.assert_called_once_with(('172.28.240.4',18091),timeout=4)
            context.wrap_socket.assert_called_once_with(raw,server_hostname='trade-processor')
            connection.request.assert_called_once_with('POST','/internal/executions/id',body=b'{}',headers={'X-Service-Subject':'spoof','Authorization':'Bearer fixture-token','Content-Type':'application/json'})
            connection.close.assert_called_once()

    def test_projection_refuses_role_mismatch_extra_or_missing_keys(self):
        with tempfile.TemporaryDirectory() as temp,patch.object(fixture.subprocess,'run',return_value=result()):
            materials={key:b'private' for key in fixture.KEYS['trade-processor'] if key!='config.json'}
            path=fixture.projected(Path(temp),'processor',{'role':'trade-processor'},materials)
            self.assertEqual(set(p.name for p in path.iterdir()),set(fixture.KEYS['trade-processor']))
            for role,values in (('account-service',materials),('trade-processor',dict(materials,**{'entitlements.properties':b'extra'}))):
                with self.assertRaises(fixture.Failure):fixture.projected(Path(temp),'bad',{'role':role},values)
                self.assertFalse((Path(temp)/'bad').exists())

    def test_image_inspection_passes_exact_role_and_refuses_drift(self):
        role='account-service';entry={'image':'test@sha256:'+'a'*64,'oci_layout':'/layout','secret':'account-config','keys':list(fixture.KEYS[role])}
        manifest={'source_commit':'f'*40,'image':entry,'runtime_reference':'test:built','generated_root':'/generated','build_report':'/report.json'}
        descriptor={'digest':'sha256:'+'a'*64,'size':10};digest='sha256:'+'b'*64
        inspector=Mock(return_value=entry);docker=Mock(return_value=result(json.dumps({'Id':digest})))
        with patch.dict(sys.modules,{'java_images':SimpleNamespace(inspect=inspector)}),patch.object(fixture.compiler,'read_json',return_value={'manifests':[descriptor]}),patch.object(fixture.compiler,'blob',return_value={'config':{'digest':digest}}):
            self.assertEqual(fixture.verified_image(manifest,docker,role)['runtime_id'],digest)
            inspector.assert_called_once_with('/layout','test:built','f'*40,'/generated','/report.json',role=role)
            inspector.return_value=dict(entry,keys=[])
            with self.assertRaisesRegex(fixture.Failure,'image_manifest_drift'):fixture.verified_image(manifest,docker,role)

    def test_actual_loaded_image_mismatch_still_runs_owned_cleanup(self):
        app=object.__new__(fixture.JavaImage);app.role='account-service';app.name='owned';app.f={'network':'net','owner':'owner'}
        app.target=Path('/private');app.identity={'runtime_id':'sha256:expected','config_digest':'sha256:config'}
        app.docker=Mock();app.inspect=Mock(return_value={'Image':'sha256:wrong','Config':{'Image':'sha256:expected'}})
        app.cleanup=Mock();app.diagnostics=Mock(return_value={'exit_code':1})
        with self.assertRaisesRegex(fixture.Failure,'loaded_image_changed') as failure:
            with app.run():self.fail('Unverified image executed acceptance body')
        app.cleanup.assert_called_once();self.assertEqual(failure.exception.runtime_diagnostic,{'exit_code':1})
        args=app.docker.call_args.args;self.assertEqual(args[-1],'sha256:expected')
        self.assertEqual(args[args.index('--network-alias')+1],'account-service')
        self.assertNotIn('--publish',args)


if __name__=='__main__':unittest.main()
