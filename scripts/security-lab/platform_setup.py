"""Prepare pinned infrastructure artifacts; explicitly create a fresh dedicated cluster only."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import tempfile
import yaml

import checkpoint
import credential_store
import cluster_identity
import storage_preflight
import lab
from resource_operation import operation_lock
from resource_preflight import require

CLUSTER='traderx-security-lab'
CONTEXT='kind-'+CLUSTER
NODE=CLUSTER+'-control-plane'


def digest(data):return hashlib.sha256(data).hexdigest()


def pins():return lab.read_json(lab.PROFILE/'infrastructure.lock.json')


def expected(chart,helm):
    lock=pins();art=lock['cilium_artifacts']
    if digest(chart)!=art['chart_sha256']:raise ValueError('Chart archive hash mismatch')
    version=subprocess.run([helm,'version','--short'],check=True,capture_output=True,text=True,timeout=15).stdout.strip().split('+')[0]
    if version!=art['helm_version']:raise ValueError('Reviewed Helm version required')
    with tempfile.TemporaryDirectory() as tmp:
        archive=Path(tmp)/'chart.tgz';archive.write_bytes(chart)
        values=Path(tmp)/'values.json';values.write_bytes(checkpoint.encoded(art['values']))
        rendered=subprocess.run([helm,'template','cilium',str(archive),'--namespace','kube-system','--kube-version',art['kube_version'],'--include-crds','--values',str(values)],check=True,capture_output=True,timeout=60).stdout
    if digest(rendered)!=art['render_sha256']:raise ValueError('Cilium render differs from reviewed artifact')
    images=[]
    for obj in yaml.safe_load_all(rendered):
        if not isinstance(obj,dict):continue
        if obj.get('kind')=='Secret':raise ValueError('Generated infrastructure must not contain Secrets')
        spec=obj.get('spec',{}).get('template',{}).get('spec',{})
        for kind in ('containers','initContainers'):
            for container in spec.get(kind,[]):
                images.append({'kind':obj['kind'],'workload':obj['metadata']['name'],
                    'container_type':kind,'container':container['name'],'image':container['image']})
    if images!=art['images']:raise ValueError('Rendered image inventory differs')
    return {'cilium.tgz':chart,'cilium.yaml':rendered,
            'kind.yaml':(lab.PROFILE/'system/kind.yaml').read_bytes(),
            'infrastructure.lock.json':checkpoint.encoded(lock)}


def prepare(chart,helm,output):
    output=Path(output)
    if output.exists() or output.is_symlink():raise ValueError('Choose a new output directory')
    files=expected(Path(chart).read_bytes(),helm)
    output.parent.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(dir=output.parent) as tmp:
        stage=Path(tmp)/'bundle';stage.mkdir(mode=0o700)
        for name,data in files.items():(stage/name).write_bytes(data);(stage/name).chmod(0o600)
        stage.rename(output)


def verify(bundle,helm):
    bundle=Path(bundle)
    if bundle.is_symlink() or not bundle.is_dir():raise ValueError('Expected ordinary bundle directory')
    names={'cilium.tgz','cilium.yaml','kind.yaml','infrastructure.lock.json'}
    if {p.name for p in bundle.iterdir()}!=names or any(p.is_symlink() or not p.is_file() for p in bundle.iterdir()):raise ValueError('Unexpected bundle contents')
    files=expected((bundle/'cilium.tgz').read_bytes(),helm)
    if any((bundle/n).read_bytes()!=data for n,data in files.items()):raise ValueError('Infrastructure bundle drift')


def plan():
    return {'status':'candidate-not-live-accepted','cluster':CLUSTER,'context':CONTEXT,
            'steps':['verify checkpoint and infrastructure bundle','acquire operation lock and check macOS ARM64/resources',
                     'refuse any existing named cluster/container or setup directory','create fresh kind cluster with explicit private kubeconfig',
                     'record kube-system UID','apply exact pinned Cilium render and wait for rollout',
                     'pull pinned application images into the node sequentially','create private SQL identities'],
            'failure':'Retain partial cluster and journal for explicit inspection; never delete, resume or adopt automatically.',
            'limitations':['No network-enforcement proof or complete state deployment is implied.','Live fresh-cluster validation remains required.']}


def create(args):
    checkpoint.verify(args.checkpoint);verify(args.bundle,args.helm)
    if platform.system()!='Darwin' or platform.machine()!='arm64':raise ValueError('Reviewed host is macOS ARM64')
    runtime=Path(args.runtime_dir).resolve()
    cluster=getattr(args,'cluster',CLUSTER)
    if cluster not in cluster_identity.CHOICES:raise ValueError('Unreviewed cluster')
    node=cluster+'-control-plane';context='kind-'+cluster
    with operation_lock(runtime):
        require(runtime,'build')
        env=dict(os.environ,DOCKER_HOST='unix://'+str(Path.home()/'.docker/run/docker.sock'),DOCKER_CONFIG=str(runtime/'docker-client'),KIND_EXPERIMENTAL_PROVIDER='docker')
        def run(command,**kwargs):
            try:
                return subprocess.run(command,env=env,check=True,capture_output=True,text=True,timeout=kwargs.pop('timeout',240),**kwargs).stdout
            except subprocess.CalledProcessError as error:
                failure=runtime/'provisioning-error.log'
                failure.write_text(error.stderr or 'Command failed without stderr');failure.chmod(0o600)
                raise
        existing=run(['kind','get','clusters']).splitlines()
        containers=run(['docker','ps','-a','--format','{{.Names}}']).splitlines()
        location=runtime/'state019-kubernetes'
        if cluster in existing or node in containers or location.exists() or location.is_symlink() or (runtime/'cluster-selection.json').exists() or (runtime/'cluster-selection.json').is_symlink():raise ValueError('Existing cluster/container/setup state; no adoption or overwrite allowed')
        location.mkdir(mode=0o700)
        cluster_identity.record(runtime,cluster)
        journal=location/'provisioning.json'
        def record(stage):journal.write_text(json.dumps({'stage':stage,'cluster':cluster,'status':'candidate-not-live-accepted'},indent=2)+'\n');journal.chmod(0o600)
        kubeconfig=location/'kubeconfig'
        record('starting')
        try:
            run(['kind','create','cluster','--name',cluster,'--config',str(Path(args.bundle).resolve()/'kind.yaml'),'--kubeconfig',str(kubeconfig),'--retain','--wait','0s'],timeout=360)
            kubeconfig.chmod(0o600)
            kubectl=['kubectl','--kubeconfig',str(kubeconfig),'--context',context,'--request-timeout=30s']
            uid=json.loads(run(kubectl+['get','namespace','kube-system','-o','json']))['metadata']['uid']
            (location/'cluster-uid').write_text(uid+'\n');(location/'cluster-uid').chmod(0o600)
            record('cluster-created')
            run(kubectl+['apply','-f',str(Path(args.bundle).resolve()/'cilium.yaml')])
            for resource in ('daemonset/cilium','daemonset/cilium-envoy','deployment/cilium-operator'):
                run(kubectl+['rollout','status','-n','kube-system',resource,'--timeout=180s'])
            run(kubectl+['wait','--for=condition=Ready','node/'+node,'--timeout=120s'])
            record('cilium-ready')
            images=lab.read_json(lab.PROFILE/'runtime-images.lock.json')['images']
            for item in images.values():
                require(runtime,'acceptance')
                storage_preflight.require(run(['docker','exec',node,'df','-Pk','/var/lib/containerd']))
                run(['docker','exec',node,'ctr','-n','k8s.io','images','pull','--platform',item['platform'],item['image']])
            credential_store.create(location/'identities')
            record('prepared-needs-enforcement-and-runtime-tests')
        except BaseException:
            record('failed-inspect-retained-resources')
            raise RuntimeError('Fresh setup failed; retained cluster/private journal require inspection. No cleanup or retry attempted.') from None
    print('Fresh platform prepared; run enforcement probes, doctor and candidate lifecycle. Not full security acceptance.')


def main():
    parser=argparse.ArgumentParser(description=__doc__);sub=parser.add_subparsers(dest='action',required=True)
    sub.add_parser('plan')
    prep=sub.add_parser('prepare');prep.add_argument('--chart',type=Path,required=True);prep.add_argument('--output',type=Path,required=True);prep.add_argument('--helm',required=True)
    check=sub.add_parser('verify');check.add_argument('--bundle',type=Path,required=True);check.add_argument('--helm',required=True)
    start=sub.add_parser('create');start.add_argument('--checkpoint',type=Path,required=True);start.add_argument('--bundle',type=Path,required=True);start.add_argument('--helm',required=True);start.add_argument('--runtime-dir',type=Path,required=True);start.add_argument('--cluster',choices=cluster_identity.CHOICES,default=CLUSTER)
    args=parser.parse_args()
    if args.action=='plan':print(json.dumps(plan(),indent=2))
    elif args.action=='prepare':prepare(args.chart,args.helm,args.output)
    elif args.action=='verify':verify(args.bundle,args.helm)
    else:create(args)


if __name__=='__main__':main()
