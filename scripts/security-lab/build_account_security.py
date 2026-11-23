#!/usr/bin/env python3
"""Build/test the canonical account security overlay with bounded host Java resources."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
from account_dev import ROOT
from render_account_security import render
from resource_operation import operation


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime-dir',type=Path,default=Path('/private/tmp/traderx-security-runtime'))
    parser.add_argument('--java-home',type=Path,default=Path('/Library/Java/JavaVirtualMachines/zulu-21.jdk/Contents/Home'))
    args=parser.parse_args();runtime=args.runtime_dir.resolve();target=runtime/'account-security-build'
    with operation(runtime,'build'):
        if not target.exists(): render(target)
        manifest=json.loads((target/'security-generation.json').read_text())
        for group,base in [('inputs',ROOT),('files',target)]:
            for name,digest in manifest[group].items():
                if hashlib.sha256((base/name).read_bytes()).hexdigest()!=digest:
                    raise ValueError('Build input drift; render into a fresh private build directory')
        env=dict(os.environ,JAVA_HOME=str(args.java_home),GRADLE_OPTS='-Dorg.gradle.daemon=false -Dorg.gradle.workers.max=1')
        log=runtime/'evidence/account-security-build.log';log.parent.mkdir(exist_ok=True)
        with log.open('w') as out:
            subprocess.run(['bash','gradlew','--no-daemon','--max-workers=1','-Dorg.gradle.jvmargs=-Xmx384m -XX:MaxMetaspaceSize=256m','test','bootJar'],cwd=target,env=env,stdout=out,stderr=subprocess.STDOUT,check=True,timeout=600)
        jars=[p for p in (target/'build/libs').glob('*.jar') if not p.name.endswith('-plain.jar')]
        if len(jars)!=1: raise ValueError('Expected one bootJar')
        result={'status':'built-and-unit-tested-not-deployed','jar':str(jars[0]),'jar_sha256':hashlib.sha256(jars[0].read_bytes()).hexdigest(),'generation':manifest}
        (runtime/'evidence/account-security-build.json').write_text(json.dumps(result,indent=2)+'\n')
        print('Account security candidate built and unit tested.',flush=True)

if __name__=='__main__':main()
