import copy
import datetime
from contextlib import nullcontext, redirect_stdout
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
from types import SimpleNamespace as NS
import unittest
from unittest.mock import Mock, patch

from cryptography import x509
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives.serialization import pkcs12
import jwt

import verify_position_image as campaign


def result(stdout='', returncode=0, stderr=''):
    return subprocess.CompletedProcess([], returncode, stdout, stderr)


class PositionImageTests(unittest.TestCase):
    def test_pkcs12_contains_private_key_leaf_chain_and_exact_service_dns(self):
        ca, bundle, password = campaign.certificate_material()
        key, leaf, chain = pkcs12.load_key_and_certificates(bundle, password.encode())
        self.assertIsNotNone(key)
        leaf.verify_directly_issued_by(x509.load_pem_x509_certificate(ca))
        self.assertEqual(len(chain), 1)
        self.assertEqual(leaf.extensions.get_extension_for_class(x509.SubjectAlternativeName).value.get_values_for_type(x509.DNSName), ['position-service'])
        with self.assertRaises(ValueError): pkcs12.load_key_and_certificates(bundle, b'wrong-password')

    def test_fixture_tokens_exercise_each_distinct_verification_boundary(self):
        key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        other = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        def decode(value):
            return jwt.decode(value, key.public_key(), algorithms=['RS256'], issuer=campaign.ISSUER, audience=campaign.AUDIENCE)
        self.assertEqual(decode(campaign.token(key))['sub'], 'lab-reader')
        cases = [('malformed', key, jwt.DecodeError), ('invalid_signature', other, jwt.InvalidSignatureError), ('foreign_issuer', key, jwt.InvalidIssuerError),
                 ('foreign_audience', key, jwt.InvalidAudienceError), ('expired', key, jwt.ExpiredSignatureError)]
        for name, signing, error in cases:
            with self.assertRaises(error): decode(campaign.token(signing, variant=name))

    def test_row_proof_rejects_empty_crossaccount_missing_or_different_business_data(self):
        expected = [{'accountId': 22214, 'security': 'IBM', 'quantity': 7}]
        self.assertTrue(campaign.rows_match(json.dumps(expected), expected, 'positions', 22214))
        for rows in ([], [dict(expected[0], accountId=62654)], [dict(expected[0], quantity=8)], [{'accountId': 22214}]):
            self.assertFalse(campaign.rows_match(json.dumps(rows), expected, 'positions', 22214))
        trade = [{'id': 'trade', 'accountId': 22214, 'security': 'IBM', 'quantity': 1, 'side': 'Buy'}]
        self.assertTrue(campaign.rows_match(json.dumps(trade), trade, 'trades', 22214))
        self.assertFalse(campaign.rows_match(json.dumps([dict(trade[0], id='other')]), trade, 'trades', 22214))

    def test_runtime_launch_is_restricted_bounded_immutable_and_unpublished(self):
        digest = 'sha256:'+'a'*64
        args = campaign.launch_args('owned', {'owner': 'owner', 'network': 'network'}, Path('/projected'), digest)
        self.assertEqual(args[-1], digest)
        self.assertEqual(args[args.index('--memory')+1], '768m')
        self.assertEqual(args[args.index('--pids-limit')+1], '128')
        self.assertEqual(args[args.index('--user')+1], '10001:10001')
        self.assertIn('--read-only', args)
        self.assertIn('no-new-privileges:true', args)
        self.assertIn('/tmp:rw,noexec,nosuid,nodev,uid=10001,gid=10001,mode=0700,size=64m', args)
        self.assertNotIn('--publish', args)

    def test_projection_rejects_extra_inputs_before_writing(self):
        with tempfile.TemporaryDirectory() as temp, patch.object(campaign.subprocess, 'run', return_value=result()) as run:
            materials = {name: b'private' for name in campaign.KEYS if name != 'config.json'}
            path = campaign.projected(Path(temp), 'owned', {'version': 1}, materials)
            self.assertEqual({p.name for p in path.iterdir()}, set(campaign.KEYS))
            self.assertTrue(all(p.stat().st_mode & 0o777 == 0o440 for p in path.iterdir()))
            self.assertIn('0:10001', run.call_args.args[0])
            with self.assertRaises(campaign.Failure): campaign.projected(Path(temp), 'bad', {}, dict(materials, extra=b'bad'))
            self.assertFalse((Path(temp)/'bad').exists())

    def test_reinspection_binds_single_loaded_image_and_refuses_manifest_drift(self):
        entry = {'image': 'test@sha256:'+'a'*64, 'oci_layout': '/layout', 'secret': 'position-config', 'keys': list(campaign.KEYS)}
        manifest = {'source_commit': 'f'*40, 'image': entry, 'runtime_reference': 'test:built',
                    'generated_root': '/generated', 'build_report': '/report.json'}
        descriptor = {'digest': 'sha256:'+'a'*64, 'size': 10, 'mediaType': 'application/vnd.oci.image.manifest.v1+json'}
        digest = 'sha256:'+'b'*64
        inspector = Mock(return_value=entry)
        docker = Mock(return_value=result(json.dumps({'Id': digest})))
        with patch.dict(sys.modules, {'java_images': NS(inspect=inspector)}), \
                patch.object(campaign.compiler, 'read_json', return_value={'manifests': [descriptor]}), \
                patch.object(campaign.compiler, 'blob', return_value={'config': {'digest': digest}}):
            bound = campaign.verified_image(manifest, docker)
            self.assertEqual(bound['runtime_id'], digest)
            inspector.assert_called_with('/layout', 'test:built', 'f'*40, '/generated', '/report.json')
            inspector.return_value = dict(entry, keys=[])
            with self.assertRaisesRegex(campaign.Failure, '^image_manifest_drift$'): campaign.verified_image(manifest, docker)
            changed = copy.deepcopy(manifest); changed['image']['unexpected'] = 'secret'
            with self.assertRaisesRegex(campaign.Failure, '^image_manifest_invalid$'): campaign.verified_image(changed, docker)

    def test_diagnostics_export_fixed_markers_and_refuse_private_output(self):
        app = object.__new__(campaign.PositionImage)
        app.name, app.secrets = 'owned', ('private-password', 'private-p12-password')
        state = {'Running': False, 'ExitCode': 1, 'OOMKilled': False}
        app.docker = Mock(side_effect=lambda *args, **kw: result(json.dumps([{'State': state}])) if args[0] == 'inspect'
                          else result('PKIX path building failed private-address.example'))
        diagnostic = app.diagnostics()
        self.assertTrue(diagnostic['tls_rejection']); self.assertEqual(diagnostic['exit_code'], 1)
        self.assertNotIn('private-address', json.dumps(diagnostic))
        app.docker = Mock(side_effect=lambda *args, **kw: result(json.dumps([{'State': state}])) if args[0] == 'inspect'
                          else result('private-password'))
        with self.assertRaisesRegex(campaign.Failure, '^private_output_detected$'): app.diagnostics()
        for error in (RuntimeError('private-address'), campaign.Failure('private-address')):
            self.assertNotIn('private-address', json.dumps(campaign.failure(error)))

    def test_wrong_ca_acceptance_must_not_be_confused_with_configuration_refusal(self):
        healthy_failure = {'running': False, 'exit_code': 1, 'oom_killed': False, 'tls_rejection': True, 'markers': []}
        self.assertTrue(campaign.rejected_database_startup(healthy_failure))
        self.assertFalse(campaign.rejected_database_startup(healthy_failure, served_http=True))
        for change in ({'running': True}, {'exit_code': 0}, {'exit_code': 2}, {'exit_code': None},
                       {'oom_killed': True}, {'tls_rejection': False}, {'markers': ['configuration_refused']}):
            self.assertFalse(campaign.rejected_database_startup(dict(healthy_failure, **change)))

    def test_build_failure_exports_bounded_categories_without_raw_private_log(self):
        import build_position_security as build
        with tempfile.TemporaryDirectory() as temp:
            runtime = Path(temp).resolve()
            def refused(*args, **kwargs):
                kwargs['stdout'].write('> Task :compileJava FAILED\nCould not GET https://user:private-secret@private.example/dependency\n')
                raise subprocess.CalledProcessError(1, ['private-command'])
            output = io.StringIO()
            with patch.object(build.portability, 'isolated_linux', return_value=True), \
                    patch.dict(build.os.environ, {'GITHUB_ACTIONS': 'true'}), \
                    patch.object(build, 'operation', return_value=nullcontext()), \
                    patch.object(build, 'render', side_effect=lambda target: target.mkdir()), \
                    patch.object(build, 'generation', return_value={}), \
                    patch.object(build.subprocess, 'run', side_effect=refused), redirect_stdout(output):
                with self.assertRaisesRegex(RuntimeError, '^Position build failed; bounded diagnostics recorded$'):
                    build.build(runtime, Path('/java'))
            value = json.loads((runtime/'evidence/build-failure-position-service.json').read_text())
            self.assertEqual(value['service'], 'position-service')
            self.assertEqual(value['categories'], ['dependency-download'])
            self.assertEqual(value['failed_tasks'], ['compileJava'])
            self.assertEqual(json.loads(output.getvalue()), value)
            for private in ('private-secret', 'private.example', 'private-command'):
                self.assertNotIn(private, output.getvalue())


if __name__ == '__main__': unittest.main()
