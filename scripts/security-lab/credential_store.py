"""Private, create-once SQL identities. Checksums detect damage, not a malicious owner."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import stat

import bootstrap_database
import database_permissions
import lab


def encoded(value):
    return (json.dumps(value, sort_keys=True, separators=(',', ':')) + '\n').encode()


def contract():
    return hashlib.sha256(encoded({'version': 1,
        'baseline': lab.read_json(lab.PROFILE / 'baseline.lock.json'),
        'grants': database_permissions.GRANTS})).hexdigest()


def checked(fd, directory=False):
    info = os.fstat(fd)
    expected = 0o700 if directory else 0o600
    if (info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) != expected
            or not (stat.S_ISDIR(info.st_mode) if directory else stat.S_ISREG(info.st_mode))
            or (not directory and info.st_nlink != 1)):
        raise ValueError('Private store ownership, type or permissions invalid')


def directory(path):
    fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        checked(fd, True)
    except BaseException:
        os.close(fd)
        raise
    return fd


def create(path):
    path = Path(path)
    # Parent must already exist and be private. mkdir reserves the name atomically;
    # failures intentionally leave an unusable store rather than permit overwrite.
    parent = directory(path.parent)
    try:
        os.mkdir(path.name, 0o700, dir_fd=parent)
        fd = os.open(path.name, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=parent)
        try:
            checked(fd, True)
            payload = {'version': 1, 'contract': contract(),
                       'bootstrap': {'username': 'traderx', 'password': secrets.token_hex(32)},
                       'runtime': bootstrap_database.credentials()}
            body = encoded({'payload': payload, 'sha256': hashlib.sha256(encoded(payload)).hexdigest()})
            out = os.open('identities.json', os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600, dir_fd=fd)
            with os.fdopen(out, 'wb') as stream:
                stream.write(body)
                stream.flush()
                os.fsync(stream.fileno())
            os.fsync(fd)
            os.fsync(parent)
        finally:
            os.close(fd)
    finally:
        os.close(parent)


def load(path):
    fd = directory(path)
    try:
        if os.listdir(fd) != ['identities.json']:
            raise ValueError('Incomplete or unexpected private store contents')
        source = os.open('identities.json', os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=fd)
        with os.fdopen(source, 'rb') as stream:
            checked(stream.fileno())
            raw = stream.read(16385)
        if len(raw) > 16384:
            raise ValueError('Private store exceeds size limit')
        value = json.loads(raw)
        payload = value['payload']
        if set(value) != {'payload', 'sha256'} or hashlib.sha256(encoded(payload)).hexdigest() != value['sha256']:
            raise ValueError('Private store checksum mismatch')
        if (set(payload) != {'version', 'contract', 'bootstrap', 'runtime'}
                or payload['version'] != 1 or payload['contract'] != contract()
                or set(payload['bootstrap']) != {'username', 'password'}
                or payload['bootstrap']['username'] != 'traderx'
                or not re.fullmatch('[0-9a-f]{64}', payload['bootstrap']['password'])
                or set(payload['runtime']) != set(database_permissions.GRANTS)):
            raise ValueError('Private store contract mismatch')
        for identity in payload['runtime'].values():
            if set(identity) != {'username', 'password'}:
                raise ValueError('Private store identity mismatch')
        database_permissions.grant_sql(payload['runtime'])
        passwords = [payload['bootstrap']['password']] + [i['password'] for i in payload['runtime'].values()]
        if len(set(passwords)) != 5:
            raise ValueError('Private identities must be distinct')
        return payload
    except (ValueError, KeyError, TypeError):
        raise ValueError('Private credential store invalid; preserve it for explicit recovery') from None
    finally:
        os.close(fd)


def bootstrap_sql(path):
    """Return private SQL in memory; callers must never log this value."""
    identities = load(path)
    return bootstrap_database.render(bootstrap_database.pinned_reference(), identities["runtime"])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['create', 'verify'])
    parser.add_argument('--store', required=True, type=Path)
    args = parser.parse_args()
    try:
        if args.action == 'create':
            create(args.store)
        load(args.store)
    except (OSError, ValueError):
        parser.exit(1, 'Credential operation refused; check private ownership, completeness and contract. No replacement attempted.\n')
    print('Private SQL identities verified; no credentials displayed.')


if __name__ == '__main__':
    main()
