"""Build and exercise the generated people API before preparing an image."""
import argparse
import os
from pathlib import Path
import re
import subprocess
import tempfile

import integrated_deployment as compiler
import portability
from render_people_security import render
from resource_operation import operation

PROJECT = 'PeopleService.WebApi'
DLL = PROJECT + '/bin/Release/net9.0/PeopleService.WebApi.dll'
ASSET = PROJECT + '/MockDirectory/people.json'
STATUS = 'loopback-fixture-passed-image-not-accepted'
LIMIT = 256 * 1024 * 1024
METADATA = {'PeopleService.WebApi.deps.json', 'PeopleService.WebApi.runtimeconfig.json',
            'PeopleService.WebApi.staticwebassets.endpoints.json'}
STATIC_ENDPOINTS = 'PeopleService.WebApi.staticwebassets.endpoints.json'

def fixture_checks():
    checks = []
    for path in ('/People/GetPerson', '/People/GetMatchingPeople', '/People/ValidatePerson'):
        checks.extend(['anonymous ' + path + ' denied',
                       'reader ' + path + ' denied without directory data',
                       'trader ' + path + ' denied without directory data',
                       'operator ' + path + ' allowed',
                       'directory response has no CORS grant and no cache'])
    checks.append('operator receives expected synthetic person')
    checks.extend('unapproved route ' + path + ' unavailable' for path in (
        '/swagger/index.html', '/People/GetPerson/', '/people/GetPerson', '/metrics'))
    checks.append('directory mutations unavailable')
    checks.extend('bounded query ' + path + ' rejected' for path in (
        '/People/GetMatchingPeople', '/People/GetMatchingPeople', '/People/GetPerson'))
    checks.extend(['wrong signature rejected', 'wrong audience rejected', 'wrong issuer rejected',
                   'valid identity before trust expiry allowed', 'expired trust snapshot denied',
                   'directory bytes unchanged'])
    return checks


def declared_assemblies(publish):
    deps = compiler.read_json(Path(publish) / 'PeopleService.WebApi.deps.json')
    target = deps.get('runtimeTarget', {}).get('name')
    libraries = deps.get('targets', {}).get(target)
    if not isinstance(libraries, dict) or not libraries:
        raise ValueError('Runtime dependency inventory required')
    names = set()
    for library in libraries.values():
        if not isinstance(library, dict) or library.get('native') or library.get('runtimeTargets'):
            raise ValueError('Unreviewed native or runtime-specific dependency')
        runtime = library.get('runtime', {})
        if not isinstance(runtime, dict):
            raise ValueError('Invalid runtime dependency inventory')
        for path in runtime:
            if not isinstance(path, str) or not path.endswith('.dll') or '\\' in path:
                raise ValueError('Unreviewed runtime dependency')
            name = Path(path).name
            if name in names:
                raise ValueError('Duplicate runtime dependency assembly')
            names.add(name)
    if 'PeopleService.WebApi.dll' not in names:
        raise ValueError('Application missing from dependency inventory')
    return names


def regular(path, limit=LIMIT):
    path = Path(path)
    if not path.is_absolute() or path.resolve() != path or not path.is_file() or path.stat().st_nlink != 1:
        raise ValueError('Regular non-linked artifact required')
    if path.stat().st_size > limit:
        raise ValueError('Artifact exceeds size limit')
    data = path.read_bytes()
    if len(data) > limit:
        raise ValueError('Artifact exceeds size limit')
    return data


def generation(root):
    root = Path(root)
    if not root.is_absolute() or root.resolve() != root:
        raise ValueError('Absolute non-symlink source root required')
    actual = compiler.read_json(root / 'security-generation.json')
    with tempfile.TemporaryDirectory(prefix='people-canonical-', dir=root.parent) as temp:
        target = Path(temp) / 'source'
        render(target)
        expected = compiler.read_json(target / 'security-generation.json')
    if actual != expected:
        raise ValueError('People generation differs from canonical renderer')
    allowed = set(expected['files']) | {'security-generation.json'}
    for path in root.rglob('*'):
        relative = path.relative_to(root)
        # Build outputs are not source inputs; all other paths are closed.
        if len(relative.parts) > 1 and relative.parts[0] == PROJECT and relative.parts[1] in ('bin', 'obj'):
            if path.is_symlink():
                raise ValueError('Symlinked build output')
            continue
        if path.is_symlink() or (path.is_file() and relative.as_posix() not in allowed):
            raise ValueError('Unexpected generated source input')
    for name, digest in expected['files'].items():
        if compiler.sha(regular(root / name)) != digest:
            raise ValueError('People source drift')
    return expected


def publish_files(root):
    root = Path(root)
    if not root.is_absolute() or root.resolve() != root or not root.is_dir():
        raise ValueError('Absolute non-symlink publish directory required')
    files, inventory = {}, {}
    for path in sorted(root.rglob('*')):
        relative = path.relative_to(root).as_posix()
        if path.is_symlink():
            raise ValueError('Symlinked publish output')
        if path.is_dir():
            if relative != 'MockDirectory':
                raise ValueError('Unexpected publish directory')
            continue
        # Package only managed assemblies and their runtime metadata. Debug,
        # config, source and native apphost are not runtime inputs.
        digest = compiler.sha(regular(path))
        inventory[relative] = digest
        if '/' not in relative and (relative.endswith('.dll') or relative in METADATA):
            files[relative] = digest
        elif relative not in ('PeopleService.WebApi', 'PeopleService.WebApi.pdb',
                              'appsettings.json', 'appsettings.Development.json',
                              'MockDirectory/people.json', 'web.config'):
            raise ValueError('Unexpected publish output')
    required = {'PeopleService.WebApi.dll', 'PeopleService.WebApi.deps.json',
                'PeopleService.WebApi.runtimeconfig.json'}
    if not required.issubset(files) or len(inventory) > 128:
        raise ValueError('Incomplete or excessive publish inventory')
    return files, inventory


def tested_files(root):
    binary = Path(root) / PROJECT / 'bin/Release/net9.0'
    return {p.name: compiler.sha(regular(p)) for p in binary.iterdir()
            if p.name.endswith('.dll') or p.name in METADATA}


def artifacts(root, publish, fixture):
    generated = generation(root)
    files, inventory = publish_files(publish)
    assembly = compiler.sha(regular(Path(root) / DLL))
    asset = compiler.sha(regular(Path(root) / ASSET))
    tested = tested_files(root)
    comparable = dict(files)
    if STATIC_ENDPOINTS in files or STATIC_ENDPOINTS in tested:
        # The SDK deliberately marks the build and publish manifests differently.
        # This API serves no static assets: allow only the exact empty manifests,
        # keeping the published bytes in the inventory and image binding.
        for directory, kind in ((Path(root) / PROJECT / 'bin/Release/net9.0', 'Build'),
                                (Path(publish), 'Publish')):
            manifest = compiler.read_json(directory / STATIC_ENDPOINTS)
            if manifest != {'Version': 1, 'ManifestType': kind, 'Endpoints': []}:
                raise ValueError('Unexpected static asset endpoint manifest')
        comparable[STATIC_ENDPOINTS] = tested[STATIC_ENDPOINTS]
    if comparable != tested:
        # Only bounded artifact names, never configuration or file contents.
        changed = sorted(name for name in comparable.keys() | tested.keys()
                         if comparable.get(name) != tested.get(name))
        safe = [name for name in changed if re.fullmatch(r'[A-Za-z0-9_.-]{1,160}', name)]
        raise ValueError('Published assemblies or runtime metadata differ from loopback build: '
                         + ', '.join(safe[:128]))
    if {name for name in files if name.endswith('.dll')} != declared_assemblies(publish):
        raise ValueError('Assemblies differ from declared runtime dependencies')
    if files['PeopleService.WebApi.dll'] != assembly:
        raise ValueError('Published assembly differs from loopback-tested assembly')
    if 'MockDirectory/people.json' in inventory and inventory['MockDirectory/people.json'] != asset:
        raise ValueError('Published synthetic directory differs from tested asset')
    checks = fixture.get('checks')
    if (fixture.get('status') != 'passed' or fixture.get('assembly_sha256') != assembly
            or fixture.get('directory_sha256') != asset or checks != fixture_checks()
            or fixture.get('scope') != 'Live Keycloak and generated .NET operator-only people API; not deployed'):
        raise ValueError('Loopback fixture evidence does not bind tested assembly and asset')
    return {'generation_sha256': compiler.sha(compiler.encoded(generated)),
            'assembly_sha256': assembly, 'directory_sha256': asset,
            'publish_files': files, 'publish_inventory': inventory, 'fixture': fixture}


def verify(root, publish, report):
    value = compiler.read_json(Path(report))
    sdk = value.get('dotnet_sdk')
    if not isinstance(sdk, str) or not re.fullmatch(r'9\.0\.\d{3}', sdk):
        raise ValueError('Reviewed .NET 9 SDK evidence required')
    expected = {'schema_version': 1, 'service': 'people-service', 'status': STATUS,
                'source_manifest': compiler.source_manifest(), 'dotnet_sdk': sdk,
                **artifacts(Path(root), Path(publish), value.get('fixture', {}))}
    if value != expected:
        raise ValueError('People build report or artifacts drift')
    return value


def build(runtime):
    if not portability.isolated_linux() or os.environ.get('GITHUB_ACTIONS') != 'true':
        raise ValueError('People build requires isolated hosted Linux')
    import verify_people_security
    runtime = Path(runtime).resolve()
    with operation(runtime, 'build'):
        target, publish = runtime / 'people-service', runtime / 'people-publish'
        report = runtime / 'people-build.json'
        if any(path.exists() for path in (target, publish, report)):
            raise ValueError('Fresh people build paths required')
        render(target)
        generation(target)
        try:
            sdk = subprocess.run(['dotnet', '--version'], stdout=subprocess.PIPE,
                                 stderr=subprocess.DEVNULL, check=True, timeout=30).stdout.decode().strip()
            if not re.fullmatch(r'9\.0\.\d{3}', sdk):
                raise ValueError('Select a .NET 9 SDK before building')
            subprocess.run(['dotnet', 'build', str(target / PROJECT / 'PeopleService.WebApi.csproj'),
                           '--configuration', 'Release', '--nologo'],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True, timeout=600)
            generation(target)
            before = tested_files(target)
            try:
                fixture = verify_people_security.campaign(runtime)
            except Exception:
                raise RuntimeError('People loopback fixture failed; details withheld') from None
            if tested_files(target) != before:
                raise ValueError('Tested assemblies or metadata changed during fixture')
            subprocess.run(['dotnet', 'publish', str(target / PROJECT / 'PeopleService.WebApi.csproj'),
                           '--configuration', 'Release', '--no-build', '--no-restore',
                           '--output', str(publish), '--nologo'],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True, timeout=600)
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
            raise RuntimeError('People build or publish failed or timed out; output withheld') from None
        value = {'schema_version': 1, 'service': 'people-service', 'status': STATUS,
                 'source_manifest': compiler.source_manifest(), 'dotnet_sdk': sdk,
                 **artifacts(target, publish, fixture)}
        with report.open('x') as output:
            output.write(compiler.encoded(value).decode())
        return value


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime-dir', type=Path, required=True)
    args = parser.parse_args()
    build(args.runtime_dir)
    print('People build and loopback fixture passed; image acceptance remains pending.')


if __name__ == '__main__':
    main()
