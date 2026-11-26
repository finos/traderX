"""Prepare and inspect a people image without building, loading or publishing it."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import struct
import tarfile

import build_people_image as build
import integrated_deployment as compiler
import people_runtime
import runtime_images

ROLE = 'people-service'
LOCK = compiler.STATE / 'system/people-runtime-images.lock.json'
SOURCE = compiler.ROOT / 'scripts/security-lab'
KEYS = sorted(people_runtime.FILES)
COMMAND = ['/usr/local/bin/python', '/opt/traderx/people_runtime.py']


def inputs(root, publish, report):
    verified = build.verify(root, publish, report)
    files = {'application/' + name: build.regular(Path(publish) / name)
             for name in verified['publish_files']}
    files['application/MockDirectory/people.json'] = build.regular(Path(root) / build.ASSET)
    for name in ('people_runtime.py', 'private_materializer.py'):
        files['source/' + name] = build.regular(SOURCE / name)
    return files, verified


def labels(revision, report):
    return {'org.opencontainers.image.revision': revision,
            'traderx.security-lab.role': ROLE,
            'traderx.security-lab.source-manifest': report['source_manifest']['sha256'],
            'traderx.security-lab.config-interface': 'private-config-v1',
            'traderx.security-lab.bind-address': '0.0.0.0',
            'traderx.security-lab.transport': 'https',
            'traderx.security-lab.port': '18089',
            'traderx.security-lab.assembly-sha256': report['assembly_sha256'],
            'traderx.security-lab.build-report-sha256': compiler.sha(compiler.encoded(report))}


def prepare(root, publish, report, output, revision):
    if not re.fullmatch(r'[0-9a-f]{40}', revision):
        raise ValueError('Explicit source revision required')
    files, verified = inputs(root, publish, report)
    lock, python = compiler.read_json(LOCK), compiler.read_json(runtime_images.LOCK)
    if lock['platform'] != 'linux/amd64' or python['platform'] != 'linux/amd64':
        raise ValueError('Reviewed AMD64 platform required')
    for reference in (lock['runtime']['reference'], python['base']['reference']):
        if not re.fullmatch(r'[a-z0-9][a-z0-9./:_-]+@sha256:[0-9a-f]{64}', reference):
            raise ValueError('Digest-pinned runtime required')
    recipe = [f'FROM {lock["runtime"]["reference"]} AS dotnet',
              f'FROM {python["base"]["reference"]}',
              'COPY --from=dotnet /usr/share/dotnet/ /usr/share/dotnet/',
              'ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1',
              'COPY --chmod=0444 application/ /opt/traderx/',
              'COPY --chmod=0555 source/ /opt/traderx/',
              'RUN chmod 0755 /opt /opt/traderx /opt/traderx/MockDirectory',
              'RUN mkdir -p /run/projected /run/private /tmp && chown 10001:10001 /run/private /tmp && chmod 0700 /run/private',
              'WORKDIR /opt/traderx', 'EXPOSE 18089']
    recipe += ['LABEL ' + k + '=' + json.dumps(v) for k, v in sorted(labels(revision, verified).items())]
    recipe += ['USER 10001:10001', 'ENTRYPOINT ' + json.dumps(COMMAND), 'CMD []']
    files['Dockerfile'] = ('\n'.join(recipe) + '\n').encode()
    files['.dockerignore'] = b'**\n!Dockerfile\n!application/\n!application/**\n!source/\n!source/**\n'
    record = {'schema_version': 1, 'role': ROLE, 'platform': 'linux/amd64',
              'source_commit': revision, 'source_manifest': verified['source_manifest'],
              'runtime': lock['runtime'], 'python_base': python['base'],
              'build_report_sha256': compiler.sha(compiler.encoded(verified)),
              'command': COMMAND, 'keys': KEYS,
              'context_files': {name: compiler.sha(data) for name, data in sorted(files.items())},
              'status': 'context-only-image-and-runtime-acceptance-pending'}
    files['image-build.json'] = compiler.encoded(record)
    output = Path(output)
    output.mkdir(parents=True, exist_ok=False)
    for name, data in files.items():
        path = output / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    return record


def environment(values, version):
    if not isinstance(values, list):
        raise ValueError('Explicit reviewed image environment required')
    env = {}
    for item in values:
        if not isinstance(item, str) or '=' not in item:
            raise ValueError('Invalid image environment')
        key, value = item.split('=', 1)
        if key in env:
            raise ValueError('Duplicate image environment')
        env[key] = value
    expected = {'PATH': r'/usr/local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
                'LANG': r'C\.UTF-8', 'PYTHON_VERSION': re.escape(version),
                'PYTHON_SHA256': 'de414a57119abef52784d8993e341d53aed635fc2b05c2607d9f98a2c5b72032',
                'PYTHONDONTWRITEBYTECODE': '1', 'PYTHONUNBUFFERED': '1'}
    if set(env) != set(expected) or any(not re.fullmatch(pattern, env[key]) for key, pattern in expected.items()):
        raise ValueError('Unreviewed inherited image environment')


def filesystem(layout, manifest, expected):
    """Reconstruct relevant final paths, including whiteouts and all ancestors."""
    state = {}
    directories = {'opt', 'opt/traderx'}
    for name in expected:
        directories.update(p.as_posix() for p in PurePosixPath(name).parents if p.as_posix() != '.')
    runtime_directories = {'usr', 'usr/local', 'usr/local/bin', 'usr/share',
                           'usr/share/dotnet'}
    tracked = directories | runtime_directories | {'usr/share/dotnet/dotnet'}
    for descriptor in manifest['layers']:
        if descriptor['mediaType'] not in ('application/vnd.oci.image.layer.v1.tar',
                                            'application/vnd.oci.image.layer.v1.tar+gzip'):
            raise ValueError('Reviewed tar/gzip layers required')
        path = layout / 'blobs/sha256' / descriptor['digest'].split(':')[1]
        count = size = 0
        whiteouts, additions = [], []
        with tarfile.open(path, 'r|*') as tar:
            for member in tar:
                count += 1
                size += member.size
                if count > 200000 or size > 8 * 1024**3 or member.size < 0:
                    raise ValueError('OCI layer exceeds bound')
                name = PurePosixPath(member.name)
                if name.is_absolute() or '..' in name.parts or '\\' in member.name:
                    raise ValueError('Invalid OCI path')
                rel = name.as_posix()
                if name.name == '.wh..wh..opq':
                    if not member.isfile() or member.size:
                        raise ValueError('Invalid OCI opaque whiteout')
                    whiteouts.append(('opaque', name.parent.as_posix()))
                    continue
                if name.name.startswith('.wh.'):
                    if not member.isfile() or member.size or name.name == '.wh.':
                        raise ValueError('Invalid OCI whiteout')
                    whiteouts.append(('remove', (name.parent / name.name[4:]).as_posix()))
                    continue
                if (rel not in tracked and not rel.startswith('opt/traderx/')
                        and not re.fullmatch(r'usr/local/bin/python(?:3(?:\.\d+)?)?', rel)):
                    continue
                if rel in directories | runtime_directories and not member.isdir():
                    raise ValueError('OCI required ancestor is not a directory: ' + rel)
                digest, header = None, b''
                if member.isfile():
                    if member.size > build.LIMIT:
                        raise ValueError('OCI tracked file exceeds bound')
                    stream = tar.extractfile(member)
                    h = hashlib.sha256()
                    for part in iter(lambda: stream.read(1024 * 1024), b''):
                        if not header and (rel == 'usr/share/dotnet/dotnet'
                                           or rel.startswith('usr/local/bin/python')):
                            header = part[:65536]
                        h.update(part)
                    digest = h.hexdigest()
                additions.append((rel, (member.isdir(), member.isfile(), member.issym(), member.uid,
                                        member.gid, member.mode & 0o7777, digest, member.linkname,
                                        header, member.size)))
        # OCI whiteouts mask lower layers only, irrespective of tar entry order.
        for kind, name in whiteouts:
            if kind == 'opaque':
                prefix = '' if name == '.' else name + '/'
                state = {k: v for k, v in state.items() if not k.startswith(prefix)}
            else:
                state = {k: v for k, v in state.items() if k != name and not k.startswith(name + '/')}
        for rel, item in additions:
            if not item[0]:
                state = {k: v for k, v in state.items() if not k.startswith(rel + '/')}
            state[rel] = item
    app_state = {k: v for k, v in state.items() if k == 'opt' or k == 'opt/traderx'
                 or k.startswith('opt/traderx/')}
    if set(app_state) != directories | set(expected):
        raise ValueError('OCI application inventory differs')
    for name in directories | runtime_directories:
        if name not in state:
            raise ValueError('Required OCI parent directory missing')
        isdir, _, _, uid, gid, mode, _, _, _, _ = state[name]
        if not isdir or uid != 0 or gid != 0 or mode not in (0o555, 0o755):
            raise ValueError('Unsafe OCI parent directory')
    for name, (digest, mode) in expected.items():
        _, isfile, _, uid, gid, actual_mode, actual_digest, _, _, _ = state[name]
        if not isfile or uid != 0 or gid != 0 or actual_mode != mode or actual_digest != digest:
            raise ValueError('OCI application file differs')
    executable(state, 'usr/share/dotnet/dotnet', allow_python_links=False)
    executable(state, 'usr/local/bin/python', allow_python_links=True)


def executable(state, path, *, allow_python_links):
    seen = set()
    while True:
        if path in seen or path not in state:
            raise ValueError('Missing or cyclic OCI executable')
        seen.add(path)
        _, isfile, issym, uid, gid, mode, _, link, header, size = state[path]
        if uid != 0 or gid != 0:
            raise ValueError('Unsafe OCI executable ownership')
        if issym and allow_python_links:
            if not re.fullmatch(r'python3(?:\.\d+)?', link):
                raise ValueError('Unreviewed Python executable link')
            path = 'usr/local/bin/' + link
            continue
        if not isfile or mode not in (0o555, 0o755) or not amd64_elf(header, size):
            raise ValueError('Unsafe or non-amd64 OCI executable')
        return


def amd64_elf(header, size):
    """Check executable structure, not provenance or dynamic-library compatibility."""
    if len(header) < 64 or header[:7] != b'\x7fELF\x02\x01\x01':
        return False
    fields = struct.unpack_from('<HHIQQQIHHHHHH', header, 16)
    kind, machine, version, entry, offset = fields[:5]
    ehsize, phsize, phcount = fields[7:10]
    if (kind not in (2, 3) or machine != 62 or version != 1 or not entry
            or ehsize != 64 or phsize != 56 or not 1 <= phcount <= 128
            or offset < 64 or offset + phsize * phcount > min(size, len(header))):
        return False
    segments = set()
    for index in range(phcount):
        kind, _, pos, _, _, length, memory, _ = struct.unpack_from('<IIQQQQQQ', header, offset + index * phsize)
        if pos + length > size or (kind == 1 and memory < length):
            return False
        segments.add(kind)
    return {1, 3}.issubset(segments)


def inspect(layout, name, revision, root, publish, report):
    if not re.fullmatch(r'[a-z0-9][a-z0-9./:_-]+', name) or not re.fullmatch(r'[0-9a-f]{40}', revision):
        raise ValueError('Explicit image name and source revision required')
    files, verified = inputs(root, publish, report)
    layout = Path(layout)
    if not layout.is_absolute() or layout.resolve() != layout:
        raise ValueError('Absolute non-symlink OCI layout required')
    index = compiler.read_json(layout / 'index.json')
    if len(index.get('manifests', [])) != 1:
        raise ValueError('Single-platform OCI export required')
    descriptor = index['manifests'][0]
    entry = {'image': name + '@' + descriptor['digest'], 'oci_layout': str(layout),
             'secret': 'private-people-service', 'keys': KEYS}
    if compiler.image(ROLE, entry, verified['source_manifest'], revision, 'linux/amd64') != COMMAND:
        raise ValueError('People launcher command changed')
    manifest = compiler.blob(layout, descriptor)
    config = compiler.blob(layout, manifest['config'])['config']
    if config.get('Entrypoint') != COMMAND or config.get('Cmd') not in (None, []) or config.get('WorkingDir') != '/opt/traderx':
        raise ValueError('People image command or working directory changed')
    if any(config.get('Labels', {}).get(k) != v for k, v in labels(revision, verified).items()):
        raise ValueError('People image labels differ')
    environment(config.get('Env'), compiler.read_json(runtime_images.LOCK)['python_version'])
    expected = {'opt/traderx/' + name.removeprefix('application/'): (compiler.sha(data), 0o444)
                for name, data in files.items() if name.startswith('application/')}
    expected.update({'opt/traderx/' + name.removeprefix('source/'): (compiler.sha(data), 0o555)
                     for name, data in files.items() if name.startswith('source/')})
    filesystem(layout, manifest, expected)
    return entry


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='action', required=True)
    for action in ('prepare', 'inspect'):
        command = commands.add_parser(action)
        for flag in ('generated-root', 'publish-dir', 'build-report'):
            command.add_argument('--' + flag, type=Path, required=True)
        command.add_argument('--source-commit', required=True)
        if action == 'prepare':
            command.add_argument('--output', type=Path, required=True)
        else:
            command.add_argument('--layout', type=Path, required=True)
            command.add_argument('--name', required=True)
    args = parser.parse_args()
    if args.action == 'prepare':
        value = prepare(args.generated_root, args.publish_dir, args.build_report, args.output, args.source_commit)
    else:
        value = inspect(args.layout, args.name, args.source_commit, args.generated_root, args.publish_dir, args.build_report)
    print(compiler.encoded(value).decode(), end='')


if __name__ == '__main__':
    main()
