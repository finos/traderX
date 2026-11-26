"""Prepare and inspect a people image without building, loading or publishing it."""
import argparse
import gzip
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


def layer_diff_id(path, media_type):
    opener = gzip.open if media_type.endswith('+gzip') else Path.open
    digest, size = hashlib.sha256(), 0
    with opener(path, 'rb') as stream:
        for part in iter(lambda: stream.read(1024 * 1024), b''):
            size += len(part)
            if size > 8 * 1024**3:
                raise ValueError('Uncompressed OCI layer exceeds bound')
            digest.update(part)
    return 'sha256:' + digest.hexdigest()


def has_symlink_ancestor(name, links):
    return any(parent.as_posix() in links for parent in PurePosixPath(name).parents
               if parent.as_posix() != '.')


def path_bytes(value):
    try:
        return len(value.encode('utf-8', 'surrogateescape'))
    except UnicodeEncodeError:
        raise ValueError('Invalid OCI path encoding') from None


class IndexBudget:
    BYTE_LIMIT = 32 * 1024 * 1024

    def __init__(self):
        self.used = 0

    def charge(self, size):
        if self.used + size > self.BYTE_LIMIT:
            raise ValueError('OCI aggregate path index bytes exceed bound')
        self.used += size


class PathInventory:
    """Index descendants so unrelated paths are never scanned during removal."""
    LIMIT = 200000
    REFERENCE_LIMIT = 1000000

    def __init__(self, budget=None):
        self.items = {}
        self.descendants = {}
        self.references = 0
        self.budget = budget if budget is not None else IndexBudget()
        self.costs = {}
        self.bytes_used = 0

    def __contains__(self, name):
        return name in self.items

    def __len__(self):
        return len(self.items)

    def put(self, name, value):
        if name not in self.items:
            parents = [parent.as_posix() for parent in PurePosixPath(name).parents
                       if parent.as_posix() != '.']
            if len(self.items) >= self.LIMIT or self.references + len(parents) > self.REFERENCE_LIMIT:
                raise ValueError('OCI path index exceeds bound')
            cost = sum(path_bytes(part) for part in (name, *parents))
            self.budget.charge(cost)
            for parent in parents:
                self.descendants.setdefault(parent, set()).add(name)
            self.references += len(parents)
            self.costs[name] = cost
            self.bytes_used += cost
        self.items[name] = value

    def discard(self, name):
        if name not in self.items:
            return
        del self.items[name]
        cost = self.costs.pop(name)
        self.bytes_used -= cost
        self.budget.used -= cost
        for parent in PurePosixPath(name).parents:
            parent = parent.as_posix()
            if parent == '.':
                continue
            children = self.descendants[parent]
            children.remove(name)
            self.references -= 1
            if not children:
                del self.descendants[parent]

    def remove(self, name, *, include_self):
        if name == '.':
            self.budget.used -= self.bytes_used
            self.bytes_used = 0
            self.costs.clear()
            self.items.clear()
            self.descendants.clear()
            self.references = 0
            return
        for child in tuple(self.descendants.get(name, ())):
            self.discard(child)
        if include_self:
            self.discard(name)


def filesystem(layout, manifest, expected, diff_ids):
    """Reconstruct relevant final paths, including whiteouts and all ancestors."""
    budget = IndexBudget()
    state = PathInventory(budget)
    directories = {'opt', 'opt/traderx'}
    for name in expected:
        directories.update(p.as_posix() for p in PurePosixPath(name).parents if p.as_posix() != '.')
    runtime_directories = {'usr', 'usr/local', 'usr/local/bin', 'usr/share',
                           'usr/share/dotnet'}
    tracked = directories | runtime_directories | {'usr/share/dotnet/dotnet'}
    links = PathInventory(budget)
    def protected(name):
        return (name in tracked or name.startswith('opt/traderx/')
                or name.startswith('usr/share/dotnet/')
                or bool(re.fullmatch(r'usr/local/bin/python(?:3(?:\.\d+)?)?', name)))
    if not isinstance(diff_ids, list) or len(diff_ids) != len(manifest['layers']):
        raise ValueError('OCI uncompressed layer inventory mismatch')
    for descriptor, diff_id in zip(manifest['layers'], diff_ids):
        if descriptor['mediaType'] not in ('application/vnd.oci.image.layer.v1.tar',
                                            'application/vnd.oci.image.layer.v1.tar+gzip'):
            raise ValueError('Reviewed tar/gzip layers required')
        path = layout / 'blobs/sha256' / descriptor['digest'].split(':')[1]
        if layer_diff_id(path, descriptor['mediaType']) != diff_id:
            raise ValueError('OCI uncompressed layer digest mismatch')
        count = size = 0
        layer_path_bytes = 0
        whiteouts, additions = [], []
        mode = 'r|gz' if descriptor['mediaType'].endswith('+gzip') else 'r|'
        with tarfile.open(path, mode) as tar:
            for member in tar:
                count += 1
                size += member.size
                if count > 200000 or size > 8 * 1024**3 or member.size < 0:
                    raise ValueError('OCI layer exceeds bound')
                name = PurePosixPath(member.name)
                if (name.is_absolute() or '..' in name.parts or '\\' in member.name
                        or len(member.name) > 4096 or len(member.linkname) > 4096
                        or len(name.parts) > 256):
                    raise ValueError('Invalid OCI path')
                path_cost = path_bytes(member.name) + path_bytes(member.linkname)
                budget.charge(path_cost)
                layer_path_bytes += path_cost
                rel = name.as_posix()
                if rel == '.' and not member.isdir():
                    raise ValueError('Invalid OCI root entry')
                if name.name == '.wh..wh..opq':
                    if not member.isfile() or member.size:
                        raise ValueError('Invalid OCI opaque whiteout')
                    whiteouts.append(('opaque', name.parent.as_posix(), rel))
                    continue
                if name.name.startswith('.wh.'):
                    if not member.isfile() or member.size or name.name == '.wh.':
                        raise ValueError('Invalid OCI whiteout')
                    whiteouts.append(('remove', (name.parent / name.name[4:]).as_posix(), rel))
                    continue
                relevant = (rel in tracked or rel.startswith('opt/traderx/')
                            or re.fullmatch(r'usr/local/bin/python(?:3(?:\.\d+)?)?', rel))
                if rel in directories | runtime_directories and not member.isdir():
                    raise ValueError('OCI required ancestor is not a directory: ' + rel)
                digest, header = None, b''
                if relevant and member.isfile():
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
                elf_valid = bool(header) and amd64_elf(header, member.size)
                item = (member.isdir(), member.isfile(), member.issym(), member.uid,
                        member.gid, member.mode & 0o7777, digest, member.linkname,
                        elf_valid, member.size) if relevant else None
                additions.append((rel, member.isdir(), member.issym(), member.islnk(), member.linkname, item))
        # OCI whiteouts mask lower layers only, irrespective of tar entry order.
        layer_links = {rel for rel, _, issym, _, _, _ in additions if issym}
        for _, _, rel in whiteouts:
            if has_symlink_ancestor(rel, links) or has_symlink_ancestor(rel, layer_links):
                raise ValueError('OCI whiteout traverses a symlink ancestor')
        for kind, name, _ in whiteouts:
            if kind == 'opaque':
                state.remove(name, include_self=False)
                links.remove(name, include_self=False)
            else:
                state.remove(name, include_self=True)
                links.remove(name, include_self=True)
        for rel, isdir, issym, islink, target, item in additions:
            if has_symlink_ancestor(rel, links) or has_symlink_ancestor(rel, layer_links):
                raise ValueError('OCI entry traverses a symlink ancestor')
            if islink:
                link_path = PurePosixPath(target)
                if (link_path.is_absolute() or '..' in link_path.parts or '\\' in target
                        or len(target) > 4096 or len(link_path.parts) > 256
                        or protected(rel) or protected(link_path.as_posix())
                        or link_path.as_posix() in links or link_path.as_posix() in layer_links
                        or has_symlink_ancestor(link_path.as_posix(), links)
                        or has_symlink_ancestor(link_path.as_posix(), layer_links)):
                    raise ValueError('OCI hardlink traverses a symlink or targets protected path')
            if not isdir:
                state.remove(rel, include_self=False)
                links.remove(rel, include_self=False)
            links.discard(rel)
            if issym:
                links.put(rel, True)
            if item is not None:
                state.put(rel, item)
        budget.used -= layer_path_bytes
    app_state = {k: v for k, v in state.items.items() if k == 'opt' or k == 'opt/traderx'
                 or k.startswith('opt/traderx/')}
    if set(app_state) != directories | set(expected):
        raise ValueError('OCI application inventory differs')
    for name in directories | runtime_directories:
        if name not in state:
            raise ValueError('Required OCI parent directory missing')
        isdir, _, _, uid, gid, mode, _, _, _, _ = state.items[name]
        if not isdir or uid != 0 or gid != 0 or mode not in (0o555, 0o755):
            raise ValueError('Unsafe OCI parent directory')
    for name, (digest, mode) in expected.items():
        _, isfile, _, uid, gid, actual_mode, actual_digest, _, _, _ = state.items[name]
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
        _, isfile, issym, uid, gid, mode, _, link, elf_valid, _ = state.items[path]
        if uid != 0 or gid != 0:
            raise ValueError('Unsafe OCI executable ownership')
        if issym and allow_python_links:
            if not re.fullmatch(r'python3(?:\.\d+)?', link):
                raise ValueError('Unreviewed Python executable link')
            path = 'usr/local/bin/' + link
            continue
        if not isfile or mode not in (0o555, 0o755) or not elf_valid:
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
    image_config = compiler.blob(layout, manifest['config'])
    config = image_config['config']
    if config.get('Entrypoint') != COMMAND or config.get('Cmd') not in (None, []) or config.get('WorkingDir') != '/opt/traderx':
        raise ValueError('People image command or working directory changed')
    if any(config.get('Labels', {}).get(k) != v for k, v in labels(revision, verified).items()):
        raise ValueError('People image labels differ')
    environment(config.get('Env'), compiler.read_json(runtime_images.LOCK)['python_version'])
    expected = {'opt/traderx/' + name.removeprefix('application/'): (compiler.sha(data), 0o444)
                for name, data in files.items() if name.startswith('application/')}
    expected.update({'opt/traderx/' + name.removeprefix('source/'): (compiler.sha(data), 0o555)
                     for name, data in files.items() if name.startswith('source/')})
    filesystem(layout, manifest, expected, image_config['rootfs']['diff_ids'])
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
