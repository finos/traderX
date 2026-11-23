#!/usr/bin/env python3
"""Build a local NATS publisher candidate from pinned Node and locked dependencies."""
import argparse
from resource_operation import operation
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--runtime-dir',type=Path,default=Path('/private/tmp/traderx-security-runtime'));a=p.parse_args()
    root=Path(__file__).resolve().parents[2];runtime=a.runtime_dir.resolve();profile=root/'specs/012-platform-convergence-c3/security-lab'
    with operation(runtime, 'build'):
        dockerfile=profile/'generation/price-publisher.Dockerfile'
        base=dockerfile.read_text().splitlines()[0].split()[1]
        source=root/'templates/state-010-pricing-awareness-market-data-overlay/price-publisher'
        docker=['docker','--config',str(runtime/'docker-client'),'--host','unix://'+str(Path.home()/'.docker/run/docker.sock')]
        def run(*args):return subprocess.run(docker+list(args),check=True,capture_output=True,text=True,timeout=300).stdout
        hashes={name:hashlib.sha256((source/name).read_bytes()).hexdigest() for name in ['src/main.js','src/nats-options.js','package.json','package-lock.json']}
        tag='traderx-security-price-publisher:nats-'+hashes['src/main.js'][:12]
        with tempfile.TemporaryDirectory(prefix='nats-publisher-build-',dir=runtime) as folder:
            build=Path(folder)
            for name in ['package.json','package-lock.json']:shutil.copyfile(source/name,build/name)
            for name in ['src','data']:shutil.copytree(source/name,build/name)
            shutil.copyfile(dockerfile,build/'Dockerfile')
            run('build','--platform','linux/amd64','-t',tag,str(build))
        info=json.loads(run('image','inspect',tag))[0]
        assert info['Config']['User'] in ['node','1000','1000:1000']
        assert info['Architecture']=='amd64'
        for name in ['src/main.js','src/nats-options.js']:
            code="process.stdout.write(require('node:crypto').createHash('sha256').update(require('node:fs').readFileSync("+json.dumps('/app/'+name)+")).digest('hex'))"
            actual=run('run','--rm','--network','none','--read-only','--cap-drop=ALL','--security-opt=no-new-privileges',info['Id'],'node','-e',code).strip()
            assert actual==hashes[name],'Candidate source mismatch'
        result={'status':'built-source-verified-not-deployed','tag':tag,'local_image_config_id':info['Id'],'base_manifest_image':base,'dockerfile_sha256':hashlib.sha256(dockerfile.read_bytes()).hexdigest(),'platform':'linux/amd64','source_hashes':hashes,'limitations':['Local config ID is not a registry manifest digest; no image signature or publication.','Full dependency rebuild from current lock; pinned OS base without unpinned package upgrades. No fresh vulnerability assessment.','Authenticated candidate container runtime validation remains a separate gate.']}
        (runtime/'evidence/nats-publisher-image.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))

if __name__=='__main__':main()
