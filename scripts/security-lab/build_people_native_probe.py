"""Build a separate bounded .NET globalization probe on an isolated hosted runner."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess

import portability

NAME = 'PeopleNativeProbe'
SUCCESS = {'status': 'passed', 'turkish_uppercase': True, 'french_decimal': True}
PROGRAM = '''using System;
using System.Globalization;

try
{
    bool turkish = CultureInfo.GetCultureInfo("tr-TR").TextInfo.ToUpper("i") == "\\u0130";
    bool french = 1234.5m.ToString("F1", CultureInfo.GetCultureInfo("fr-FR")) == "1234,5";
    if (!turkish || !french) throw new InvalidOperationException();
    Console.WriteLine("{\\"status\\":\\"passed\\",\\"turkish_uppercase\\":true,\\"french_decimal\\":true}");
    return 0;
}
catch
{
    Console.WriteLine("{\\"status\\":\\"failed\\"}");
    return 1;
}
'''
PROJECT = '''<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net9.0</TargetFramework>
    <UseAppHost>false</UseAppHost>
    <SelfContained>false</SelfContained>
    <DebugType>None</DebugType>
    <DebugSymbols>false</DebugSymbols>
    <Deterministic>true</Deterministic>
    <NuGetAudit>false</NuGetAudit>
    <InvariantGlobalization>false</InvariantGlobalization>
  </PropertyGroup>
</Project>
'''
NUGET = '<?xml version="1.0" encoding="utf-8"?>\n<configuration><packageSources><clear /></packageSources></configuration>\n'
SOURCES = {'Program.cs': PROGRAM.encode(), NAME + '.csproj': PROJECT.encode(),
           'NuGet.Config': NUGET.encode()}
ARTIFACTS = frozenset(NAME + suffix for suffix in ('.dll', '.deps.json', '.runtimeconfig.json'))
LIMIT = 4 * 1024 * 1024
STATUS = 'built-native-runtime-not-executed'


def encoded(value):
    return (json.dumps(value, indent=2, sort_keys=True) + '\n').encode()


def digest(value):
    return hashlib.sha256(value).hexdigest()


def directory(path):
    path = Path(path)
    if not path.is_absolute() or path.resolve(strict=True) != path:
        raise ValueError('Absolute non-linked probe directory required')
    info = path.lstat()
    if not stat.S_ISDIR(info.st_mode) or stat.S_IMODE(info.st_mode) != 0o755:
        raise ValueError('Searchable immutable-to-container probe directory required')
    return path


def regular(path, limit=LIMIT):
    info = path.lstat()
    if (not stat.S_ISREG(info.st_mode) or info.st_nlink != 1
            or stat.S_IMODE(info.st_mode) != 0o644 or not 0 < info.st_size <= limit):
        raise ValueError('Bounded regular probe file required')
    raw = path.read_bytes()
    if len(raw) != info.st_size:
        raise ValueError('Probe file changed')
    return raw


def sdk_sources(sdk):
    if not isinstance(sdk, str) or not re.fullmatch(r'9\.0\.\d{3}', sdk):
        raise ValueError('Selected .NET 9 SDK required')
    return dict(SOURCES, **{'global.json': encoded({'sdk': {'version': sdk, 'rollForward': 'disable'}})})


def inventory(root, sdk):
    source, publish = directory(root / 'source'), directory(root / 'publish')
    sources = sdk_sources(sdk)
    # bin/obj are local compiler products, never mounted or hashed as probe input.
    if set(p.name for p in source.iterdir()) - {'bin', 'obj'} != set(sources):
        raise ValueError('Unexpected probe source inventory')
    for name, raw in sources.items():
        if regular(source / name) != raw:
            raise ValueError('Fixed probe source changed')
    if set(p.name for p in publish.iterdir()) != ARTIFACTS:
        raise ValueError('Exact probe publish inventory required')
    artifacts = {name: digest(regular(publish / name)) for name in sorted(ARTIFACTS)}
    return {'sources': {name: digest(raw) for name, raw in sorted(sources.items())},
            'artifacts': artifacts}


def verify(root):
    root = directory(root)
    if set(p.name for p in root.iterdir()) != {'source', 'publish', 'report.json'}:
        raise ValueError('Exact probe root inventory required')
    report = json.loads(regular(root / 'report.json', 65536))
    if not isinstance(report, dict):
        raise ValueError('Probe report required')
    expected = {'schema_version': 1, 'status': STATUS, 'dotnet_sdk': report.get('dotnet_sdk'),
                'builder_sha256': digest(Path(__file__).read_bytes()),
                'command': ['/usr/share/dotnet/dotnet', '/run/native-probe/' + NAME + '.dll'],
                'expected_stdout': SUCCESS, **inventory(root, report.get('dotnet_sdk'))}
    if report != expected:
        raise ValueError('Probe report or artifacts changed')
    return report


def command(argv, cwd, *, capture=False):
    try:
        result = subprocess.run(argv, cwd=cwd, stdout=subprocess.PIPE if capture else subprocess.DEVNULL,
                                stderr=subprocess.DEVNULL, check=True, timeout=180)
    except (subprocess.SubprocessError, OSError):
        raise RuntimeError('Native probe build failed; output withheld') from None
    if capture:
        if len(result.stdout) > 4096:
            raise ValueError('Bounded SDK identification required')
        return result.stdout.decode('ascii').strip()


def build(runtime):
    if not portability.isolated_linux() or os.environ.get('GITHUB_ACTIONS') != 'true':
        raise ValueError('Probe build requires isolated hosted Linux')
    runtime = Path(runtime)
    if not runtime.is_absolute() or runtime.resolve(strict=True) != runtime or not runtime.is_dir():
        raise ValueError('Existing absolute non-linked runtime directory required')
    root = runtime / 'people-native-probe'
    root.mkdir(mode=0o755)
    root.chmod(0o755)
    sdk = command(['dotnet', '--version'], runtime, capture=True)
    sources = sdk_sources(sdk)
    source = root / 'source'
    source.mkdir(mode=0o755); source.chmod(0o755)
    for name, raw in sources.items():
        path = source / name
        with path.open('xb') as output: output.write(raw)
        path.chmod(0o644)
    project = source / (NAME + '.csproj')
    command(['dotnet', 'restore', str(project), '--configfile', str(source / 'NuGet.Config'),
             '--nologo'], source)
    command(['dotnet', 'publish', str(project), '--configuration', 'Release', '--no-restore',
             '--self-contained', 'false', '--output', str(root / 'publish'), '--nologo'], source)
    publish = root / 'publish'
    # Build products must be plain files before making them readable to UID10001.
    if publish.is_symlink() or not publish.is_dir():
        raise ValueError('Regular probe publish directory required')
    publish.chmod(0o755)
    if set(p.name for p in publish.iterdir()) != ARTIFACTS:
        raise ValueError('Exact probe publish inventory required')
    for path in publish.iterdir():
        info = path.lstat()
        if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
            raise ValueError('Regular probe artifacts required')
        path.chmod(0o644)
    report = {'schema_version': 1, 'status': STATUS, 'dotnet_sdk': sdk,
              'builder_sha256': digest(Path(__file__).read_bytes()),
              'command': ['/usr/share/dotnet/dotnet', '/run/native-probe/' + NAME + '.dll'],
              'expected_stdout': SUCCESS, **inventory(root, sdk)}
    with (root / 'report.json').open('xb') as output: output.write(encoded(report))
    (root / 'report.json').chmod(0o644)
    return verify(root)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime-dir', type=Path, required=True)
    args = parser.parse_args()
    build(args.runtime_dir)
    print('Native probe built; execution in the verified image remains required.')


if __name__ == '__main__':
    main()
