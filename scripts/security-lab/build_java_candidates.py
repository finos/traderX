#!/usr/bin/env python3
"""Package verified local Java service builds as unpublished candidate images."""
import argparse
from resource_operation import operation
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile


def sha(data):return hashlib.sha256(data).hexdigest()

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--runtime-dir',type=Path,default=Path('/private/tmp/traderx-security-runtime'));a=p.parse_args();runtime=a.runtime_dir.resolve()
    with operation(runtime, 'build'):
        root=Path(__file__).resolve().parents[2];profile=root/'specs/012-platform-convergence-c3/security-lab';recipe=profile/'generation/java-client.Dockerfile';builds=runtime/'java-service-builds'
        evidence=json.loads((runtime/'evidence/java-adapter-lifecycle/nats-result.json').read_text())
        if evidence['status']!='passed' or len(evidence['java_adapter_lifecycle']['cases'])!=5:raise ValueError('All five adapter lifecycle results required')
        docker=['docker','--config',str(runtime/'docker-client'),'--host','unix://'+str(Path.home()/'.docker/run/docker.sock')]
        def run(*args):return subprocess.run(docker+list(args),capture_output=True,text=True,check=True,timeout=300).stdout
        records=[]
        for service,state in [('trade-service','006-messaging-nats-replacement'),('trade-processor','006-messaging-nats-replacement'),('order-matcher','009-order-management-matcher')]:
            for name,digest in evidence['java_adapter_lifecycle']['tested_build_hashes'][service].items():
                assert sha((builds/service/name).read_bytes())==digest,'Build changed since lifecycle test'
            build=builds/service;canonical=root/'specs'/state/'generation/runtime-overrides'/service
            hashes={}
            for source in canonical.rglob('*.java'):
                relative=source.relative_to(canonical);assert source.read_bytes()==(build/relative).read_bytes(),'Canonical source drift'
                hashes[str(relative)]=sha(source.read_bytes())
            helper=root/'specs/006-messaging-nats-replacement/generation/nats/NatsSecurity.java';helper_target=build/'src/main/java/finos/traderx/messaging/nats/NatsSecurity.java'
            assert helper.read_bytes()==helper_target.read_bytes();hashes[str(helper_target.relative_to(build))]=sha(helper.read_bytes())
            jars=[p for p in (build/'build/libs').glob('*.jar') if not p.name.endswith('-plain.jar')];assert len(jars)==1
            jar=jars[0]
            with zipfile.ZipFile(jar) as archive:
                classes=list((build/'build/classes/java/main').rglob('*.class'))
                for cls in classes:
                    name=str(cls.relative_to(build/'build/classes/java/main'))
                    assert archive.read('BOOT-INF/classes/'+name)==cls.read_bytes(),'Packaged bytecode drift'
            digest=sha(jar.read_bytes());tag='traderx-security-'+service+':nats-'+digest[:12]
            with tempfile.TemporaryDirectory(prefix='java-candidate-',dir=runtime) as folder:
                context=Path(folder);shutil.copyfile(recipe,context/'Dockerfile');shutil.copyfile(jar,context/'app.jar')
                run('build','--platform','linux/amd64','--network','none','-t',tag,str(context))
            info=json.loads(run('image','inspect',tag))[0];assert info['Config']['User']=='10001:10001'
            output=run('run','--rm','--network','none','--read-only','--cap-drop=ALL','--security-opt=no-new-privileges','--entrypoint','sha256sum',info['Id'],'/opt/app/app.jar')
            assert output.split()[0]==digest
            run('run','--rm','--network','none','--read-only','--cap-drop=ALL','--security-opt=no-new-privileges','--entrypoint','java',info['Id'],'-version')
            records.append({'service':service,'tag':tag,'local_image_config_id':info['Id'],'jar_sha256':digest,'platform':'linux/amd64','user':info['Config']['User'],'canonical_source_hashes':hashes})
            print(service+': candidate packaged and Java runtime verified.',flush=True)
        record={'status':'candidate-images-built-not-deployed','base_image':recipe.read_text().splitlines()[0].split()[1],'dockerfile_sha256':sha(recipe.read_bytes()),'lifecycle_run_id':evidence['run_id'],'images':records,'limitations':['Local config IDs are not registry manifest digests; no push, signatures or admission changes.','Container JAR hashes and Java startup checked; full Spring startup/trading in these images remains pending.','Pinned JRE base without unpinned OS upgrades; vulnerability scanning remains a separate gate.']}
        (runtime/'evidence/java-candidate-images.json').write_text(json.dumps(record,indent=2)+'\n')

if __name__=='__main__':main()
