"""Bounded private launcher for the operator-only .NET people service."""
import base64
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import ssl
import stat
import sys
from urllib.parse import urlsplit

from private_materializer import materialize

PROJECTED = Path('/run/projected')
PRIVATE = Path('/run/private/config')
DOTNET = '/usr/share/dotnet/dotnet'
APPLICATION = '/opt/traderx/PeopleService.WebApi.dll'
DIRECTORY = '/opt/traderx/MockDirectory/people.json'
LISTEN_URL = 'https://0.0.0.0:18089'
FILES = (
    'config.json',
    'identity-public.pem',
    'identity-roles.json',
    'server-cert.pem',
    'server-key.pem',
)
CONFIG_KEYS = {
    'version',
    'issuer',
    'audience',
    'key_not_after',
    'public_key_file',
    'roles_file',
    'server_certificate_file',
    'server_key_file',
}
LIMITS = {
    'config.json': 65536,
    'identity-public.pem': 65536,
    'identity-roles.json': 65536,
    'server-cert.pem': 262144,
    'server-key.pem': 65536,
}
CONFIGURATION_ENV_PREFIXES = ('ASPNETCORE_', 'DOTNET_', 'LAB_')
CONFIGURATION_ENV_KEYS = {
    'URLS',
    'KESTREL',
    'CONTENTROOT',
    'APPLICATIONNAME',
    'ENVIRONMENT',
}
SANITIZED_FAILURE = 'People service private configuration refused; details withheld.\n'


def _json_object(pairs):
    value = {}
    for key, item in pairs:
        if key in value:
            raise ValueError('Duplicate JSON key')
        value[key] = item
    return value


def _reject_json_constant(_):
    raise ValueError('Invalid JSON constant')


def parse_json(raw):
    try:
        return json.loads(
            raw.decode('utf-8'),
            object_pairs_hook=_json_object,
            parse_constant=_reject_json_constant,
        )
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ValueError('Invalid private JSON') from error


def _read_der(data, offset):
    if offset + 2 > len(data):
        raise ValueError('Malformed RSA public key')
    tag = data[offset]
    first_length = data[offset + 1]
    offset += 2
    if first_length < 0x80:
        length = first_length
    else:
        octets = first_length & 0x7f
        if octets == 0 or octets > 4 or offset + octets > len(data) or data[offset] == 0:
            raise ValueError('Malformed RSA public key')
        length = int.from_bytes(data[offset:offset + octets], 'big')
        if length < 0x80:
            raise ValueError('Malformed RSA public key')
        offset += octets
    end = offset + length
    if end > len(data):
        raise ValueError('Malformed RSA public key')
    return tag, data[offset:end], end


def _der_integer(value):
    if not value or value[0] & 0x80 or (len(value) > 1 and value[0] == 0 and not value[1] & 0x80):
        raise ValueError('Malformed RSA public key')
    return int.from_bytes(value, 'big')


def validate_rsa_public_key(raw):
    match = re.fullmatch(
        rb'-----BEGIN PUBLIC KEY-----\r?\n([A-Za-z0-9+/=\r\n]+)\r?\n-----END PUBLIC KEY-----\r?\n?',
        raw,
    )
    if not match:
        raise ValueError('Invalid RSA trust key')
    try:
        der = base64.b64decode(re.sub(rb'\s', b'', match.group(1)), validate=True)
    except ValueError as error:
        raise ValueError('Invalid RSA trust key') from error
    tag, outer, end = _read_der(der, 0)
    if tag != 0x30 or end != len(der):
        raise ValueError('Invalid RSA trust key')
    tag, algorithm, offset = _read_der(outer, 0)
    if tag != 0x30:
        raise ValueError('Invalid RSA trust key')
    tag, oid, algorithm_offset = _read_der(algorithm, 0)
    if tag != 0x06 or oid != bytes.fromhex('2a864886f70d010101'):
        raise ValueError('RSA trust key required')
    if algorithm_offset < len(algorithm):
        tag, null, algorithm_offset = _read_der(algorithm, algorithm_offset)
        if tag != 0x05 or null:
            raise ValueError('Invalid RSA trust key')
    if algorithm_offset != len(algorithm):
        raise ValueError('Invalid RSA trust key')
    tag, bit_string, offset = _read_der(outer, offset)
    if tag != 0x03 or offset != len(outer) or not bit_string or bit_string[0] != 0:
        raise ValueError('Invalid RSA trust key')
    tag, rsa_key, rsa_end = _read_der(bit_string[1:], 0)
    if tag != 0x30 or rsa_end != len(bit_string) - 1:
        raise ValueError('Invalid RSA trust key')
    tag, modulus, offset = _read_der(rsa_key, 0)
    if tag != 0x02:
        raise ValueError('Invalid RSA trust key')
    tag, exponent, offset = _read_der(rsa_key, offset)
    if tag != 0x02 or offset != len(rsa_key):
        raise ValueError('Invalid RSA trust key')
    modulus_value = _der_integer(modulus)
    if modulus_value.bit_length() < 2048 or modulus_value % 2 == 0:
        raise ValueError('Invalid RSA modulus')
    public_exponent = _der_integer(exponent)
    if public_exponent < 3 or public_exponent % 2 == 0 or public_exponent >= modulus_value:
        raise ValueError('Invalid RSA trust key')


def validate_projection(source, names=FILES):
    source = Path(source)
    if not source.is_absolute() or source.is_symlink() or source.resolve(strict=True) != source:
        raise ValueError('Invalid projected configuration directory')
    if not source.is_dir():
        raise ValueError('Invalid projected configuration directory')
    data_link = source / '..data'
    if not data_link.is_symlink():
        raise ValueError('Invalid projected configuration generation')
    generation = data_link.resolve(strict=True)
    if generation.parent != source or not generation.is_dir():
        raise ValueError('Invalid projected configuration generation')
    visible = {item.name for item in source.iterdir() if not item.name.startswith('..')}
    if visible != set(names):
        raise ValueError('Projected configuration inventory mismatch')
    for name in names:
        link = source / name
        if not link.is_symlink() or link.resolve(strict=True) != generation / name:
            raise ValueError('Invalid projected configuration key')
    return source


def _read_private(directory_fd, name, expected_uid, limit):
    descriptor = os.open(
        name,
        os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK,
        dir_fd=directory_fd,
    )
    with os.fdopen(descriptor, 'rb') as stream:
        info = os.fstat(stream.fileno())
        if (not stat.S_ISREG(info.st_mode) or info.st_uid != expected_uid
                or stat.S_IMODE(info.st_mode) != 0o600 or info.st_nlink != 1
                or info.st_size < 1 or info.st_size > limit):
            raise ValueError('Unsafe materialized configuration file')
        value = stream.read(limit + 1)
        if len(value) != info.st_size:
            raise ValueError('Materialized configuration file changed')
        return value


def _timestamp(value, now):
    if not isinstance(value, str) or not re.fullmatch(
        r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,7})?(?:Z|[+-]\d{2}:\d{2})',
        value,
    ):
        raise ValueError('Invalid trust expiry')
    try:
        parsed = datetime.fromisoformat(value[:-1] + '+00:00' if value.endswith('Z') else value)
    except ValueError as error:
        raise ValueError('Invalid trust expiry') from error
    if parsed.tzinfo is None or parsed <= now:
        raise ValueError('Expired trust snapshot')
    return parsed


def _validate_issuer(value):
    if not isinstance(value, str) or len(value) > 2048 or any(ord(char) < 0x21 for char in value):
        raise ValueError('Invalid trusted issuer')
    try:
        uri = urlsplit(value)
        port = uri.port
    except ValueError as error:
        raise ValueError('Invalid trusted issuer') from error
    if (uri.scheme != 'https' or not uri.hostname or uri.username is not None
            or uri.password is not None or uri.query or uri.fragment
            or (port is not None and not 1 <= port <= 65535)):
        raise ValueError('Invalid trusted issuer')


def validate_configuration(private_dir=PRIVATE, expected_uid=10001, now=None):
    private_dir = Path(private_dir)
    directory_fd = os.open(
        private_dir,
        os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW,
    )
    try:
        info = os.fstat(directory_fd)
        if (not stat.S_ISDIR(info.st_mode) or info.st_uid != expected_uid
                or stat.S_IMODE(info.st_mode) != 0o700):
            raise ValueError('Unsafe private configuration directory')
        if set(os.listdir(directory_fd)) != set(FILES):
            raise ValueError('Private configuration inventory mismatch')
        contents = {
            name: _read_private(directory_fd, name, expected_uid, LIMITS[name])
            for name in FILES
        }
    finally:
        os.close(directory_fd)
    config = parse_json(contents['config.json'])
    if not isinstance(config, dict) or set(config) != CONFIG_KEYS:
        raise ValueError('Invalid people runtime schema')
    if type(config['version']) is not int or config['version'] != 1:
        raise ValueError('Unsupported people runtime schema')
    _validate_issuer(config['issuer'])
    audience = config['audience']
    if (not isinstance(audience, str) or not 1 <= len(audience) <= 256
            or any(char.isspace() or ord(char) < 0x21 for char in audience)):
        raise ValueError('Invalid trusted audience')
    _timestamp(config['key_not_after'], now or datetime.now(timezone.utc))
    expected_paths = {
        'public_key_file': private_dir / 'identity-public.pem',
        'roles_file': private_dir / 'identity-roles.json',
        'server_certificate_file': private_dir / 'server-cert.pem',
        'server_key_file': private_dir / 'server-key.pem',
    }
    for key, path in expected_paths.items():
        if config[key] != str(path):
            raise ValueError('Non-fixed private configuration path')
    validate_rsa_public_key(contents['identity-public.pem'])
    roles = parse_json(contents['identity-roles.json'])
    if not isinstance(roles, dict) or not 1 <= len(roles) <= 1024:
        raise ValueError('Invalid private role map')
    for subject, role in roles.items():
        if (not isinstance(subject, str) or not 1 <= len(subject) <= 128
                or subject.strip() != subject or any(ord(char) < 0x21 for char in subject)
                or role not in ('operator', 'trader', 'read-only')):
            raise ValueError('Invalid private role map')
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(
        str(expected_paths['server_certificate_file']),
        str(expected_paths['server_key_file']),
        # No encrypted-key password is part of this interface. Supplying an
        # explicit empty callback prevents OpenSSL's interactive stdin prompt.
        password=lambda: b'',
    )
    return config


def reject_environment_overrides(environ):
    for name in environ:
        upper = name.upper()
        if ('__' in name or ':' in name or upper.startswith(CONFIGURATION_ENV_PREFIXES)
                or upper in CONFIGURATION_ENV_KEYS or upper == 'LAB_PEOPLE_LOOPBACK_PORT'):
            raise ValueError('Inherited application configuration is prohibited')


def application_environment(config):
    return {
        'LAB_IDENTITY_ISSUER': config['issuer'],
        'LAB_IDENTITY_AUDIENCE': config['audience'],
        'LAB_IDENTITY_KEY_NOT_AFTER': config['key_not_after'],
        'LAB_IDENTITY_PUBLIC_KEY_FILE': str(PRIVATE / 'identity-public.pem'),
        'LAB_IDENTITY_DIRECTORY_ROLES_FILE': str(PRIVATE / 'identity-roles.json'),
        'Kestrel__Endpoints__Https__Url': LISTEN_URL,
        'Kestrel__Endpoints__Https__Certificate__Path': str(PRIVATE / 'server-cert.pem'),
        'Kestrel__Endpoints__Https__Certificate__KeyPath': str(PRIVATE / 'server-key.pem'),
        'PeopleJsonFilePath': DIRECTORY,
    }


def exec_application(environment):
    argv = [DOTNET, APPLICATION, '--contentRoot', str(PRIVATE)]
    os.execve(DOTNET, argv, environment)


def main():
    try:
        if (os.getuid(), os.geteuid(), os.getgid(), os.getegid()) != (10001, 10001, 10001, 10001):
            raise ValueError('Fixed non-root identity required')
        reject_environment_overrides(os.environ)
        validate_projection(PROJECTED)
        materialize(PROJECTED, PRIVATE, list(FILES))
        config = validate_configuration()
        exec_application(application_environment(config))
    except Exception:
        sys.stderr.write(SANITIZED_FAILURE)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
