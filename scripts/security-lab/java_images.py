"""Prepare and inspect explicit verified Java role images; never build or publish."""
import argparse
import ast
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import re
import tarfile
import zipfile

import build_position_security as build
import integrated_deployment as compiler
import runtime_images
import java_runtime

ROLE = 'position-service'
LOCK = compiler.STATE / 'system/java-runtime-images.lock.json'
SOURCE = compiler.ROOT / 'scripts/security-lab'
FILES = {'java_runtime.py', 'private_materializer.py'}
KEYS = ['config.json', 'database-ca.pem', 'entitlements.properties', 'public.pem', 'tls.p12']
STARTUP = b'SELECT 1;\n'


def argv(role=ROLE):
    keys = java_runtime.role_contract(role)['keys']
    command = ['/usr/local/bin/python', '/opt/traderx/private_materializer.py',
               '--source', '/run/projected', '--target', '/run/private/config']
    command += [value for key in keys for value in ('--key', key)]
    return command + ['--', '/usr/local/bin/python', '/opt/traderx/java_runtime.py',
                      '--role', role, '--config', '/run/private/config/config.json']


def jar_bytes(root, role=ROLE):
    spec = build.role_spec(role)
    data = build.regular(Path(root) / spec['jar'], build.LIMIT)
    required = {spec['package'].replace('.', '/') + '/' + name + '.class'
                for name in (spec['application'], *spec['classes'])}
    with zipfile.ZipFile(io.BytesIO(data)) as jar:
        names = jar.namelist()
        if len(names) != len(set(names)) or len(names) > 100000:
            raise ValueError('Duplicate or excessive JAR entries')
        if any(PurePosixPath(name).is_absolute() or '..' in PurePosixPath(name).parts or '\\' in name for name in names):
            raise ValueError('Invalid JAR entry path')
        if not {'BOOT-INF/classes/' + name for name in required}.issubset(names):
            raise ValueError('Java role security classes absent from bootJar')
        manifest = jar.getinfo('META-INF/MANIFEST.MF')
        if manifest.file_size > 16384:
            raise ValueError('Bounded bootJar manifest required')
        text = jar.read(manifest).decode().replace('\r\n', '\n').replace('\n ', '')
        fields = dict(line.split(': ', 1) for line in text.splitlines() if ': ' in line)
        if (fields.get('Main-Class') != 'org.springframework.boot.loader.launch.JarLauncher' or
                fields.get('Start-Class') != spec['package'] + '.' + spec['application']):
            raise ValueError('Explicit Java role bootJar entrypoint required')
    return data


def inputs(root, report, role=ROLE):
    verified = build.verify(root, report, role=role)
    files = {'application.jar': jar_bytes(root, role), 'source/startup-check.sql': STARTUP}
    for name in sorted(FILES):
        files['source/' + name] = build.regular(SOURCE / name)
    for name in FILES:
        for node in ast.walk(ast.parse(files['source/' + name])):
            modules = []
            if isinstance(node, ast.Import):
                modules = [value.name.split('.')[0] for value in node.names]
            elif isinstance(node, ast.ImportFrom) and node.module:
                modules = [node.module.split('.')[0]]
            if any((SOURCE / (module + '.py')).is_file() and module + '.py' not in FILES for module in modules):
                raise ValueError('Java adapter import absent from source allowlist')
    return files, verified


def labels(revision, report, role=ROLE):
    contract = java_runtime.role_contract(role)
    return {'org.opencontainers.image.revision': revision,
            'traderx.security-lab.role': role,
            'traderx.security-lab.source-manifest': report['source_manifest']['sha256'],
            'traderx.security-lab.config-interface': 'private-config-v1',
            'traderx.security-lab.bind-address': '0.0.0.0',
            'traderx.security-lab.transport': 'https', 'traderx.security-lab.port': str(contract['port']),
            'traderx.security-lab.jar-sha256': report['jar']['sha256'],
            'traderx.security-lab.build-report-sha256': compiler.sha(compiler.encoded(report))}


def prepare(root, report, output, revision, role=ROLE):
    contract = java_runtime.role_contract(role)
    if not re.fullmatch(r'[0-9a-f]{40}', revision):
        raise ValueError('Explicit source revision required')
    files, verified = inputs(root, report, role)
    lock = compiler.read_json(LOCK)
    python = compiler.read_json(runtime_images.LOCK)['base']
    if lock['platform'] != 'linux/amd64' or lock['java_major'] != 21:
        raise ValueError('Reviewed Java platform required')
    for reference in (python['reference'], lock['jre']['reference']):
        if not re.fullmatch(r'[a-z0-9][a-z0-9./:_-]+@sha256:[0-9a-f]{64}', reference):
            raise ValueError('Pinned runtime image required')
    dockerfile = [f'FROM {lock["jre"]["reference"]} AS jre', f'FROM {python["reference"]}',
        'COPY --from=jre /opt/java/openjdk/ /opt/java/openjdk/',
        'ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 JAVA_HOME=/opt/java/openjdk',
        'COPY --chmod=0555 source/ /opt/traderx/',
        'COPY --chmod=0444 application.jar /app/application.jar',
        # COPY can create its implicit parent with the file's non-executable
        # mode. The non-root JVM must be able to traverse /app to open the JAR.
        'RUN chmod 0755 /app',
        'RUN /opt/java/openjdk/bin/java -Djava.awt.headless=true --version && /usr/local/bin/python --version',
        'RUN mkdir -p /run/projected /run/private /tmp && chown 10001:10001 /run/private /tmp && chmod 0700 /run/private',
        'WORKDIR /opt/traderx', 'EXPOSE ' + str(contract['port'])]
    dockerfile += ['LABEL ' + key + '=' + json.dumps(value) for key, value in sorted(labels(revision, verified, role).items())]
    dockerfile += ['USER 10001:10001', 'ENTRYPOINT ' + json.dumps(argv(role)), 'CMD []']
    files['Dockerfile'] = ('\n'.join(dockerfile) + '\n').encode()
    files['.dockerignore'] = b'**\n!Dockerfile\n!application.jar\n!source/\n!source/java_runtime.py\n!source/private_materializer.py\n!source/startup-check.sql\n'
    record = {'schema_version': 1, 'role': role, 'platform': lock['platform'], 'source_commit': revision,
              'source_manifest': verified['source_manifest'], 'python_base': python, 'jre': lock['jre'],
              'jar': verified['jar'], 'build_report_sha256': compiler.sha(compiler.encoded(verified)),
              'command': argv(role), 'keys': contract['keys'],
              'context_files': {name: compiler.sha(data) for name, data in sorted(files.items())},
              'status': 'build-context-prepared-not-image-built-or-runtime-accepted'}
    files['image-build.json'] = compiler.encoded(record)
    output = Path(output)
    output.mkdir(parents=True, exist_ok=False)
    for name, data in files.items():
        path = output / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    return record


def filesystem(layout, manifest, expected):
    """Bind actual final OCI files, not only self-declared labels, to build inputs."""
    found = {}
    required_directories = {parent.as_posix() for name in expected
                            for parent in PurePosixPath(name).parents if parent.as_posix() != '.'}
    directories = {}
    for descriptor in manifest['layers']:
        if descriptor['mediaType'] not in ('application/vnd.oci.image.layer.v1.tar', 'application/vnd.oci.image.layer.v1.tar+gzip'):
            raise ValueError('Reviewed tar/gzip Java image export required')
        path = layout / 'blobs/sha256' / descriptor['digest'].split(':')[1]
        expanded = members = 0
        with tarfile.open(path, mode='r|*') as archive:
            for member in archive:
                members += 1
                expanded += member.size
                if members > 200000 or expanded > 8 * 1024**3 or member.size < 0:
                    raise ValueError('OCI filesystem exceeds bound')
                name = PurePosixPath(member.name)
                if name.is_absolute() or '..' in name.parts:
                    raise ValueError('Invalid OCI filesystem path')
                relative = name.as_posix()
                if name.name == '.wh..wh..opq':
                    prefix = name.parent.as_posix().rstrip('.') + '/'
                    found = {key: value for key, value in found.items() if not key.startswith(prefix.lstrip('/'))}
                    directories = {key: value for key, value in directories.items() if not key.startswith(prefix.lstrip('/'))}
                    continue
                if name.name.startswith('.wh.'):
                    erased = (name.parent / name.name[4:]).as_posix()
                    found = {key: value for key, value in found.items() if key != erased and not key.startswith(erased + '/')}
                    directories = {key: value for key, value in directories.items() if key != erased and not key.startswith(erased + '/')}
                    continue
                if relative in required_directories:
                    directories[relative] = (member.isdir(), member.uid, member.gid, member.mode & 0o7777)
                if not member.isdir() and (relative.startswith('opt/traderx/') or relative.startswith('app/')) and relative not in expected:
                    raise ValueError('Unexpected packaged application file')
                for key in expected:
                    if key.startswith(relative + '/') and not member.isdir():
                        raise ValueError('Packaged input ancestor is not a directory')
                if relative not in expected:
                    continue
                digest, mode = expected[relative]
                if not member.isfile() or member.uid != 0 or member.gid != 0 or member.mode & 0o7777 != mode or member.size > build.LIMIT:
                    raise ValueError('Packaged runtime file ownership/type/mode changed')
                stream = archive.extractfile(member)
                actual = hashlib.sha256()
                for part in iter(lambda: stream.read(1024 * 1024), b''):
                    actual.update(part)
                if actual.hexdigest() != digest:
                    raise ValueError('Packaged runtime file bytes changed')
                found[relative] = digest
    if set(found) != set(expected):
        raise ValueError('Verified JAR/runtime file absent from final OCI filesystem')
    if set(directories) != required_directories or any(
            not is_directory or uid != 0 or gid != 0 or mode not in (0o555, 0o755)
            for is_directory, uid, gid, mode in directories.values()):
        raise ValueError('Packaged runtime parent directory ownership or traversal mode changed')


def inspect(layout, name, revision, root, report, role=ROLE):
    contract = java_runtime.role_contract(role)
    if not re.fullmatch(r'[a-z0-9][a-z0-9./:_-]+', name) or not re.fullmatch(r'[0-9a-f]{40}', revision):
        raise ValueError('Explicit local image reference and revision required')
    files, verified = inputs(root, report, role)
    layout = Path(layout).resolve()
    index = compiler.read_json(layout / 'index.json')
    if len(index.get('manifests', [])) != 1:
        raise ValueError('Single-platform unattested local export required')
    entry = {'image': name + '@' + index['manifests'][0]['digest'], 'oci_layout': str(layout),
             'secret': 'private-' + role, 'keys': contract['keys']}
    actual = compiler.image(role, entry, verified['source_manifest'], revision, 'linux/amd64')
    if actual != argv(role):
        raise ValueError('Packaged Java launcher command changed')
    manifest = compiler.blob(layout, index['manifests'][0])
    config = compiler.blob(layout, manifest['config'])
    actual_labels = config['config'].get('Labels', {})
    if any(actual_labels.get(key) != value for key, value in labels(revision, verified, role).items()):
        raise ValueError('Packaged Java build labels differ')
    expected = {'app/application.jar': (verified['jar']['sha256'], 0o444)}
    expected.update({'opt/traderx/' + name.removeprefix('source/'): (compiler.sha(data), 0o555)
                     for name, data in files.items() if name.startswith('source/')})
    filesystem(layout, manifest, expected)
    return entry


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='action', required=True)
    for action in ('prepare', 'inspect'):
        command = commands.add_parser(action)
        command.add_argument('--role', choices=java_runtime.ROLES, default=ROLE)
        command.add_argument('--generated-root', type=Path, required=True)
        command.add_argument('--build-report', type=Path, required=True)
        command.add_argument('--source-commit', required=True)
        if action == 'prepare':
            command.add_argument('--output', type=Path, required=True)
        else:
            command.add_argument('--layout', type=Path, required=True)
            command.add_argument('--image-name', required=True)
    args = parser.parse_args()
    value = (prepare(args.generated_root, args.build_report, args.output, args.source_commit, role=args.role)
             if args.action == 'prepare' else inspect(args.layout, args.image_name, args.source_commit, args.generated_root, args.build_report, role=args.role))
    print(json.dumps(value, sort_keys=True))


if __name__ == '__main__':
    main()
