"""Build only the generated position candidate and bind its JAR to passing tests."""
import argparse
import os
from pathlib import Path
import re
import subprocess
import tempfile
import xml.etree.ElementTree as ET

import integrated_deployment as compiler
import portability
from build_diagnostics import record_failure
from render_read_security import render
from resource_operation import operation

JAR = 'build/libs/position-service-specfirst-0.1.0.jar'
STATUS = 'built-and-tested-not-deployed'
LIMIT = 256 * 1024 * 1024


def regular(path, limit=4 * 1024 * 1024):
    path = Path(path)
    if path.is_symlink() or path.resolve() != path or not path.is_file() or path.stat().st_size > limit:
        raise ValueError('Bounded regular build artifact required')
    data = path.read_bytes()
    if len(data) > limit:
        raise ValueError('Build artifact exceeds limit')
    return data


def generation(root):
    """Re-render canonical source: a self-declared or incomplete hash list is insufficient."""
    root = Path(root)
    if not root.is_absolute() or root.resolve() != root:
        raise ValueError('Absolute non-symlink generated root required')
    actual = compiler.read_json(root / 'security-generation.json')
    with tempfile.TemporaryDirectory(prefix='position-source-check-') as temporary:
        expected_root = Path(temporary).resolve() / 'source'
        render(expected_root)
        expected = compiler.read_json(expected_root / 'security-generation.json')
    if actual != expected:
        raise ValueError('Generated position manifest differs from canonical renderer')
    for name, digest in expected['files'].items():
        if compiler.sha(regular(root / name)) != digest:
            raise ValueError('Generated position source drift')
    # Additional Java/resources/build inputs cannot silently affect the tested JAR.
    allowed = set(expected['files']) | {'security-generation.json'}
    for path in root.rglob('*'):
        relative = path.relative_to(root)
        if relative.parts[0] in ('build', '.gradle'):
            continue
        if path.is_symlink() or (path.is_file() and relative.as_posix() not in allowed):
            raise ValueError('Unexpected generated source input')
    return actual


def test_results(root):
    root = Path(root)
    paths = sorted((root / 'build/test-results/test').glob('TEST-*.xml'))
    if not paths or len(paths) > 64:
        raise ValueError('Bounded Java test reports required')
    totals = dict(tests=0, failures=0, errors=0, skipped=0)
    files = {}
    passed = set()
    for path in paths:
        data = regular(path)
        suite = ET.fromstring(data)
        if suite.tag != 'testsuite':
            raise ValueError('JUnit test suite required')
        counts = {key: int(suite.attrib.get(key, '0')) for key in totals}
        cases = suite.findall('testcase')
        if counts['tests'] != len(cases) or any(value < 0 for value in counts.values()):
            raise ValueError('Inconsistent Java test totals')
        if any(counts[key] for key in ('failures', 'errors', 'skipped')) or any(
                case.find(tag) is not None for case in cases for tag in ('failure', 'error', 'skipped')):
            raise ValueError('Failed or skipped Java test evidence')
        for case in cases:
            identity = (case.attrib.get('classname'), case.attrib.get('name', '').removesuffix('()'))
            if identity in passed:
                raise ValueError('Duplicate Java test result')
            passed.add(identity)
        for key in totals:
            totals[key] += counts[key]
        files[path.relative_to(root).as_posix()] = compiler.sha(data)
    required = set()
    package = root / 'src/test/java/finos/traderx/positionservice/security'
    for name in ('ReadApiSecurityTest', 'ReadDatabaseAuthorizationTest'):
        text = regular(package / (name + '.java')).decode()
        methods = re.findall(r'@Test\s+void\s+(\w+)\s*\(', text)
        if not methods:
            raise ValueError('Required security tests absent')
        required.update(('finos.traderx.positionservice.security.' + name, method) for method in methods)
    if not required.issubset(passed) or len(required) < 11:
        raise ValueError('Required position authorization tests did not pass')
    return {'files': files, 'totals': totals}


def artifacts(root):
    root = Path(root)
    generated = generation(root)
    jars = sorted(path.relative_to(root).as_posix() for path in (root / 'build/libs').glob('*.jar')
                  if not path.name.endswith('-plain.jar'))
    if jars != [JAR]:
        raise ValueError('Exactly the approved position bootJar is required')
    data = regular(root / JAR, LIMIT)
    return {'generation_sha256': compiler.sha(compiler.encoded(generated)),
            'jar': {'path': JAR, 'sha256': compiler.sha(data), 'size': len(data)},
            'test_results': test_results(root)}


def verify(root, report):
    regular(Path(report))
    actual = compiler.read_json(Path(report))
    expected = {'schema_version': 1, 'service': 'position-service', 'status': STATUS,
                'source_manifest': compiler.source_manifest(), **artifacts(Path(root))}
    if actual != expected:
        raise ValueError('Position build report, source, JAR or test evidence drift')
    return actual


def build(runtime, java_home):
    if not portability.isolated_linux() or os.environ.get('GITHUB_ACTIONS') != 'true':
        raise ValueError('Position Java build requires isolated hosted Linux')
    runtime = Path(runtime).resolve()
    with operation(runtime, 'build'):
        target = runtime / 'position-security-build'
        report = runtime / 'evidence/position-security-build.json'
        if target.exists() or report.exists():
            raise ValueError('Fresh position build directory required')
        render(target)
        generation(target)
        report.parent.mkdir(exist_ok=True)
        env = dict(os.environ, JAVA_HOME=str(java_home), GRADLE_OPTS='-Dorg.gradle.daemon=false -Dorg.gradle.workers.max=1')
        log_path = report.parent / 'position-security-build.log'
        try:
            with log_path.open('x') as log:
                subprocess.run(['bash', 'gradlew', '--no-daemon', '--max-workers=1',
                    '-Dorg.gradle.jvmargs=-Xmx384m -XX:MaxMetaspaceSize=256m', 'clean', 'test', 'bootJar'],
                    cwd=target, env=env, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=600)
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
            record_failure(runtime, 'position-service', target, log_path, error)
            raise RuntimeError('Position build failed; bounded diagnostics recorded') from None
        value = {'schema_version': 1, 'service': 'position-service', 'status': STATUS,
                 'source_manifest': compiler.source_manifest(), **artifacts(target)}
        with report.open('x') as output:
            output.write(compiler.encoded(value).decode())
        return value


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime-dir', type=Path, required=True)
    parser.add_argument('--java-home', type=Path, required=True)
    args = parser.parse_args()
    build(args.runtime_dir, args.java_home)
    print('Position candidate built with verified source, JAR and passing authorization tests.')


if __name__ == '__main__':
    main()
