"""Bounded build-only diagnostics; never export raw Gradle or test output."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import xml.etree.ElementTree as ET

SERVICES=frozenset(('trade-service','order-matcher','trade-processor','account-service','position-service'))
MARKERS={
    'Compilation failed':'compiler','error: cannot find symbol':'compiler-symbol','does not exist':'missing-package',
    'incompatible types':'compiler-types','Could not resolve all':'dependency-resolution',
    'Could not resolve ':'dependency-resolution','Could not GET ':'dependency-download',
    'Could not HEAD ':'dependency-download','Could not download ':'dependency-download',
    'Read timed out':'network-timeout','Connect timed out':'network-timeout',
    'Connection reset':'connection-reset','UnknownHostException':'dns',
    'status code 429':'remote-rate-limit','status code 502':'remote-unavailable','status code 503':'remote-unavailable',
    'PKIX path building failed':'certificate-chain','SSLHandshakeException':'tls-handshake',
    'There were failing tests':'tests-failed','AssertionFailedError':'test-assertion',
    'OutOfMemoryError':'memory','Java heap space':'memory','OutOfMemoryError: Metaspace':'metaspace-memory',
    'daemon disappeared':'gradle-daemon-exit','DaemonDisappearedException':'gradle-daemon-exit',
    'No space left on device':'storage-full','Permission denied':'filesystem-permission',
    'UnsupportedClassVersionError':'java-version','Unsupported class file major version':'java-version',
    'Could not find or load main class':'missing-main-class',
}
TASKS=('compileJava','compileTestJava','test','bootJar')


def bounded_text(path,limit=131072):
    path=Path(path)
    if path.is_symlink() or not path.is_file():return ''
    with path.open('rb') as source:
        source.seek(0,2);length=source.tell();source.seek(max(0,length-limit))
        return source.read(limit).decode('utf-8',errors='replace')


def test_counts(target):
    target=Path(target);totals=dict(tests=0,failures=0,errors=0,skipped=0);failed=[]
    approved=set()
    manifest=target/'security-generation.json'
    if manifest.is_file() and not manifest.is_symlink() and manifest.stat().st_size<=1048576:
        try:
            for name,digest in json.loads(manifest.read_text()).get('files',{}).items():
                match=re.fullmatch(r'src/test/java/((?:[A-Za-z_$][A-Za-z0-9_$]*/)+[A-Za-z_$][A-Za-z0-9_$]*)\.java',name)
                if match:
                    source=target/name
                    if source.is_file() and not source.is_symlink() and source.stat().st_size<=1048576 and hashlib.sha256(source.read_bytes()).hexdigest()==digest:
                        approved.add(match[1].replace('/','.'))
        except (OSError,ValueError,TypeError):pass
    paths=sorted((target/'build/test-results/test').glob('TEST-*.xml'))[:128]
    for path in paths:
        if path.is_symlink() or path.stat().st_size>1048576:continue
        try:
            root=ET.fromstring(path.read_bytes())
            if root.tag!='testsuite':continue
            numbers={key:int(root.get(key,'0')) for key in totals}
            if any(not 0<=value<=100000 for value in numbers.values()):continue
            for key,value in numbers.items():totals[key]+=value
            name=root.get('name')
            if (numbers['failures'] or numbers['errors']) and name in approved:failed.append(name)
        except (OSError,ValueError,ET.ParseError):continue
    return totals,sorted(set(failed))[:32]


def summarize(service,target,log,error):
    if service not in SERVICES:raise ValueError('Fixed candidate service required')
    text=bounded_text(log)
    categories=sorted({category for marker,category in MARKERS.items() if marker.lower() in text.lower()})
    timed_out=isinstance(error,subprocess.TimeoutExpired)
    if timed_out:categories.append('build-timeout')
    code=getattr(error,'returncode',None)
    if type(code) is not int or not -255<=code<=255:code=None
    counts,suites=test_counts(target)
    stages=[task for task in TASKS if re.search(r'> Task (?::[A-Za-z0-9_-]+)*:'+task+r' FAILED\b',text)]
    return dict(version=1,scope='build-only-sanitized-diagnostics',service=service,status='failed',
        exit_code=code,timed_out=timed_out,categories=categories or ['unclassified'],failed_tasks=stages,
        tests=counts,failed_suites=suites)


def record_failure(runtime,service,target,log,error):
    value=summarize(service,target,log,error)
    path=Path(runtime)/'evidence'/('build-failure-'+service+'.json')
    path.parent.mkdir(exist_ok=True)
    with path.open('x') as output:json.dump(value,output,indent=2);output.write('\n')
    print(json.dumps(value,sort_keys=True),flush=True)
    return value
