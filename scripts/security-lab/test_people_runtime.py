import base64
from datetime import datetime, timedelta, timezone
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import people_runtime as runtime


def der(tag, value):
    length = len(value)
    if length < 128:
        encoded_length = bytes([length])
    else:
        raw_length = length.to_bytes((length.bit_length() + 7) // 8, 'big')
        encoded_length = bytes([0x80 | len(raw_length)]) + raw_length
    return bytes([tag]) + encoded_length + value


def integer(value):
    raw = value.to_bytes((value.bit_length() + 7) // 8, 'big')
    if raw[0] & 0x80:
        raw = b'\x00' + raw
    return der(0x02, raw)


def rsa_public_pem():
    modulus = (1 << 2047) | (1 << 1024) | 0xD3
    rsa_key = der(0x30, integer(modulus) + integer(65537))
    algorithm = der(0x30, der(0x06, bytes.fromhex('2a864886f70d010101')) + der(0x05, b''))
    public_key = der(0x30, algorithm + der(0x03, b'\x00' + rsa_key))
    encoded = base64.b64encode(public_key)
    lines = b'\n'.join(encoded[index:index + 64] for index in range(0, len(encoded), 64))
    return b'-----BEGIN PUBLIC KEY-----\n' + lines + b'\n-----END PUBLIC KEY-----\n'


class PeopleRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.uid = os.geteuid()
        self.projected = self.root / 'projected'
        self.private = self.root / 'private'
        self.generation = self.projected / '..2026_11_26_21_00_00'
        self.generation.mkdir(parents=True)
        self.private.mkdir(mode=0o700)
        self.private.chmod(0o700)
        self.private_uid = self.uid
        (self.projected / '..data').symlink_to(self.generation.name)
        for name in runtime.FILES:
            (self.projected / name).symlink_to(f'..data/{name}')
        self.config = {
            'version': 1,
            'issuer': 'https://identity.example.test/issuer',
            'audience': 'traderx-people-service',
            'key_not_after': (datetime.now(timezone.utc) + timedelta(hours=1)).isoformat().replace('+00:00', 'Z'),
            'public_key_file': str(self.private / 'identity-public.pem'),
            'roles_file': str(self.private / 'identity-roles.json'),
            'server_certificate_file': str(self.private / 'server-cert.pem'),
            'server_key_file': str(self.private / 'server-key.pem'),
        }
        self.write_files()

    def write_files(self, roles=None):
        values = {
            'config.json': json.dumps(self.config).encode(),
            'identity-public.pem': rsa_public_pem(),
            'identity-roles.json': json.dumps(roles or {'synthetic-operator': 'operator'}).encode(),
            'server-cert.pem': b'certificate fixture',
            'server-key.pem': b'key fixture',
        }
        for name, value in values.items():
            path = self.private / name
            if path.exists():
                path.chmod(0o600)
            path.write_bytes(value)
            path.chmod(0o600)
            projected = self.generation / name
            if projected.exists():
                projected.chmod(0o600)
            projected.write_bytes(value)
            projected.chmod(0o440)

    def validate(self):
        return runtime.validate_configuration(
            self.private, expected_uid=self.private_uid, now=datetime.now(timezone.utc),
        )

    def test_exact_projected_inventory_and_foreign_paths_are_rejected(self):
        self.assertEqual(runtime.validate_projection(self.projected), self.projected)
        unexpected = self.projected / 'foreign.pem'
        unexpected.symlink_to(f'..data/{runtime.FILES[0]}')
        with self.assertRaisesRegex(ValueError, 'inventory'):
            runtime.validate_projection(self.projected)
        unexpected.unlink()
        (self.projected / runtime.FILES[0]).unlink()
        (self.projected / runtime.FILES[0]).symlink_to(self.root / 'outside')
        (self.root / 'outside').write_text('foreign')
        with self.assertRaises(ValueError):
            runtime.validate_projection(self.projected)
        with self.assertRaises(ValueError):
            runtime.validate_projection(self.root)

    def test_materialized_file_type_mode_owner_and_link_count_are_checked(self):
        with patch('people_runtime.ssl.SSLContext.load_cert_chain'):
            self.validate()
        certificate = self.private / 'server-cert.pem'
        certificate.chmod(0o644)
        with patch('people_runtime.ssl.SSLContext.load_cert_chain'):
            with self.assertRaises(ValueError):
                self.validate()
        certificate.chmod(0o600)
        if self.uid == 0:
            os.chown(certificate, 10002, -1)
            with patch('people_runtime.ssl.SSLContext.load_cert_chain'):
                with self.assertRaises(ValueError):
                    self.validate()
            os.chown(certificate, self.uid, -1)
        certificate.unlink()
        certificate.symlink_to(self.generation / 'server-cert.pem')
        with patch('people_runtime.ssl.SSLContext.load_cert_chain'):
            with self.assertRaises(OSError):
                self.validate()

    def test_unknown_and_duplicate_schema_keys_are_rejected(self):
        for raw in (
            json.dumps({**self.config, 'unexpected': True}).encode(),
            b'{"version":1,"version":1}',
        ):
            (self.private / 'config.json').write_bytes(raw)
            (self.private / 'config.json').chmod(0o600)
            with patch('people_runtime.ssl.SSLContext.load_cert_chain'):
                with self.assertRaises(ValueError):
                    self.validate()

    def test_nonfixed_paths_loopback_and_expired_or_malformed_trust_are_rejected(self):
        original = dict(self.config)
        for key, value in (
            ('public_key_file', '/tmp/foreign.pem'),
            ('server_certificate_file', '/run/private/config/other.pem'),
            ('issuer', 'http://identity.example.test'),
            ('key_not_after', 'not-a-time'),
            ('key_not_after', (datetime.now(timezone.utc) - timedelta(seconds=1)).isoformat()),
        ):
            self.config = {**original, key: value}
            self.write_files()
            with patch('people_runtime.ssl.SSLContext.load_cert_chain'):
                with self.assertRaises(ValueError, msg=f'{key}={value}'):
                    self.validate()
        self.config = original
        self.write_files()
        (self.private / 'identity-public.pem').write_text('not a public key')
        with patch('people_runtime.ssl.SSLContext.load_cert_chain'):
            with self.assertRaises(ValueError):
                self.validate()
        with self.assertRaises(ValueError):
            runtime.reject_environment_overrides({'LAB_PEOPLE_LOOPBACK_PORT': '18089'})

    def test_role_file_rejects_duplicate_and_unknown_role_entries(self):
        (self.private / 'identity-roles.json').write_text('{"operator":"operator","operator":"trader"}')
        (self.private / 'identity-roles.json').chmod(0o600)
        with patch('people_runtime.ssl.SSLContext.load_cert_chain'):
            with self.assertRaisesRegex(ValueError, 'Duplicate'):
                self.validate()
        self.write_files({'synthetic-operator': 'admin'})
        with patch('people_runtime.ssl.SSLContext.load_cert_chain'):
            with self.assertRaises(ValueError):
                self.validate()

    def test_environment_overrides_reject_kestrel_dotnet_and_directory_settings(self):
        for name in (
            'ASPNETCORE_URLS',
            'ASPNETCORE_Kestrel__Endpoints__Http__Url',
            'DOTNET_ENVIRONMENT',
            'LAB_IDENTITY_ISSUER',
            'Logging__LogLevel__Default',
            'Kestrel:Endpoints:Http:Url',
        ):
            with self.assertRaises(ValueError, msg=name):
                runtime.reject_environment_overrides({name: 'attacker-controlled'})
        runtime.reject_environment_overrides({'PATH': '/usr/bin', 'KUBERNETES_SERVICE_HOST': '10.0.0.1'})

    def test_exec_uses_fixed_dotnet_dll_and_https_only_environment(self):
        environment = runtime.application_environment(self.config)
        self.assertEqual(environment['Kestrel__Endpoints__Https__Url'], 'https://0.0.0.0:18089')
        self.assertNotIn('Kestrel__Endpoints__Http__Url', environment)
        self.assertEqual(set(environment), {
            'LAB_IDENTITY_ISSUER',
            'LAB_IDENTITY_AUDIENCE',
            'LAB_IDENTITY_KEY_NOT_AFTER',
            'LAB_IDENTITY_PUBLIC_KEY_FILE',
            'LAB_IDENTITY_DIRECTORY_ROLES_FILE',
            'Kestrel__Endpoints__Https__Url',
            'Kestrel__Endpoints__Https__Certificate__Path',
            'Kestrel__Endpoints__Https__Certificate__KeyPath',
            'PeopleJsonFilePath',
        })
        self.assertEqual(environment['PeopleJsonFilePath'], '/opt/traderx/MockDirectory/people.json')
        self.assertTrue(Path(environment['PeopleJsonFilePath']).is_absolute())
        self.assertFalse(Path(environment['PeopleJsonFilePath']).is_relative_to(runtime.PRIVATE))
        self.assertNotIn('private-key-bytes', environment.values())
        with patch('people_runtime.os.execve') as execve:
            runtime.exec_application(environment)
        execve.assert_called_once_with(
            runtime.DOTNET,
            [runtime.DOTNET, runtime.APPLICATION, '--contentRoot', str(runtime.PRIVATE)],
            environment,
        )

    def test_real_tls_material_and_encrypted_key_rejection_never_prompt(self):
        from cryptography import x509
        from cryptography.hazmat.primitives import hashes, serialization
        from cryptography.hazmat.primitives.asymmetric import rsa
        from cryptography.x509.oid import NameOID
        key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, 'synthetic-people-test')])
        now = datetime.now(timezone.utc)
        certificate = (x509.CertificateBuilder().subject_name(name).issuer_name(name)
            .public_key(key.public_key()).serial_number(x509.random_serial_number())
            .not_valid_before(now - timedelta(minutes=1)).not_valid_after(now + timedelta(minutes=5))
            .sign(key, hashes.SHA256()))
        (self.private / 'server-cert.pem').write_bytes(certificate.public_bytes(serialization.Encoding.PEM))
        (self.private / 'server-key.pem').write_bytes(key.private_bytes(serialization.Encoding.PEM,
            serialization.PrivateFormat.PKCS8, serialization.NoEncryption()))
        self.validate()
        (self.private / 'server-key.pem').write_bytes(key.private_bytes(serialization.Encoding.PEM,
            serialization.PrivateFormat.PKCS8, serialization.BestAvailableEncryption(b'synthetic-test-only')))
        # Keep stdin open: omitting the explicit password callback previously
        # blocked here and printed an OpenSSL prompt instead of failing closed.
        code = '''import os,ssl,sys
import people_runtime
try:
    people_runtime.validate_configuration(sys.argv[1],expected_uid=os.geteuid())
except ssl.SSLError:
    sys.exit(0)
sys.exit(1)
'''
        process = subprocess.Popen([sys.executable, '-c', code, str(self.private)],
            cwd=Path(runtime.__file__).parent, stdin=subprocess.PIPE,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.fail('Encrypted TLS key prompted or blocked')
        finally:
            if process.poll() is None:
                process.kill()
            stdout, stderr = process.communicate(timeout=3)
        self.assertEqual(process.returncode, 0)
        self.assertEqual((stdout, stderr), (b'', b''))

    def test_launcher_failure_is_fixed_and_does_not_log_private_details(self):
        output = []
        with patch('people_runtime.os.getuid', return_value=10001), \
                patch('people_runtime.os.geteuid', return_value=10001), \
                patch('people_runtime.os.getgid', return_value=10001), \
                patch('people_runtime.os.getegid', return_value=10001), \
                patch('people_runtime.os.environ', {}), \
                patch('people_runtime.validate_projection'), \
                patch('people_runtime.materialize', side_effect=ValueError('private-token-value')), \
                patch('people_runtime.sys.stderr') as stderr:
            self.assertEqual(runtime.main(), 1)
            output = [call.args[0] for call in stderr.write.call_args_list]
        self.assertEqual(output, [runtime.SANITIZED_FAILURE])
        self.assertNotIn('private-token-value', ''.join(output))


if __name__ == '__main__':
    unittest.main()
