"""Build direct-API candidates sequentially; do not replace runtime images or enable cutover."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
from render_trading_security import ROOT, SERVICES, render
from resource_operation import operation
from build_diagnostics import record_failure


def build(runtime,java_home):
    with operation(runtime,'build'):
        results=[]
        for service in SERVICES:
            target=runtime/'trading-security-build'/service
            if not target.exists():render(target,service)
            manifest=json.loads((target/'security-generation.json').read_text())
            for group,base in [('inputs',ROOT),('files',target)]:
                for name,digest in manifest[group].items():
                    if hashlib.sha256((base/name).read_bytes()).hexdigest()!=digest:
                        raise ValueError('Build input drift; render into a fresh private build directory')
            evidence=runtime/'evidence';evidence.mkdir(exist_ok=True)
            env=dict(os.environ,JAVA_HOME=str(java_home),GRADLE_OPTS='-Dorg.gradle.daemon=false -Dorg.gradle.workers.max=1')
            log_path=evidence/(service+'-authorization-build.log')
            try:
                with log_path.open('w') as log:
                    subprocess.run(['bash','gradlew','--no-daemon','--max-workers=1','-Dorg.gradle.jvmargs=-Xmx384m -XX:MaxMetaspaceSize=256m','test','bootJar'],cwd=target,env=env,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=600)
            except (subprocess.CalledProcessError,subprocess.TimeoutExpired) as error:
                record_failure(runtime,service,target,log_path,error)
                raise RuntimeError(service+' candidate build failed; bounded diagnostics recorded') from None
            jars=[p for p in (target/'build/libs').glob('*.jar') if not p.name.endswith('-plain.jar')]
            if len(jars)!=1:raise ValueError('Expected one bootJar')
            import xml.etree.ElementTree as ET
            suites=[ET.parse(p).getroot() for p in sorted((target/'build/test-results/test').glob('TEST-*.xml'))]
            if not suites or any(int(s.get('failures','0')) or int(s.get('errors','0')) for s in suites):raise ValueError('Missing or failed Java test evidence')
            results.append({'service':service,'jar_sha256':hashlib.sha256(jars[0].read_bytes()).hexdigest(),
                'tests':sum(int(s.get('tests','0')) for s in suites),'generation':manifest})
            print(service+': built and tested; runtime unchanged.',flush=True)
        (runtime/'evidence/trading-security-build.json').write_text(json.dumps({'status':'built-and-tested-not-deployed','services':results},indent=2)+'\n')


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--runtime-dir',type=Path,required=True)
    parser.add_argument('--java-home',type=Path,default=Path('/Library/Java/JavaVirtualMachines/zulu-21.jdk/Contents/Home'))
    args=parser.parse_args();build(args.runtime_dir.resolve(),args.java_home)


if __name__=='__main__':main()
