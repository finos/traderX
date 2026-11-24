"""Read-only checks for the reviewed macOS ARM64 candidate platform; never provisions it."""
import json
from pathlib import Path
import platform
import subprocess

import credential_store
import lab
import resource_preflight

NODE='traderx-security-lab-control-plane'
CONTEXT='kind-traderx-security-lab'


def assess_cluster(observed, expected_uid, pins):
    checks={}
    checks['cluster_identity']=observed['uid']==expected_uid
    nodes=observed['nodes']['items']
    checks['single_reviewed_node']=len(nodes)==1 and nodes[0]['metadata']['name']==NODE
    expected_version=pins['kind_node'].split(':v',1)[1].split('@',1)[0]
    checks['node_version_architecture_ready']=bool(nodes) and all(
        n.get('status',{}).get('nodeInfo',{}).get('kubeletVersion')=='v'+expected_version and
        n['status']['nodeInfo'].get('architecture')=='arm64' and
        any(c.get('type')=='Ready' and c.get('status')=='True' for c in n['status'].get('conditions',[])) for n in nodes)
    container=observed['container']
    checks['owned_kind_node']=container.get('Config',{}).get('Labels',{}).get('io.x-k8s.kind.cluster')=='traderx-security-lab'
    checks['pinned_node_image']=container.get('Config',{}).get('Image')==pins['kind_node']
    ds=observed['cilium'].get('status',{})
    checks['cilium_ready']=ds.get('desiredNumberScheduled')==1 and ds.get('numberReady')==1 and ds.get('updatedNumberScheduled')==1
    allowed={r['image_id'] for r in pins['cilium_running_images']}
    pods=observed['cilium_pods']['items']
    agents=[c for p in pods for c in p.get('status',{}).get('containerStatuses',[]) if c.get('name')=='cilium-agent']
    checks['observed_cilium_agent_digest']=len(agents)==1 and agents[0].get('ready') is True and agents[0].get('imageID','').removeprefix('docker-pullable://') in allowed
    return checks


def inspect(args):
    checks={'supported_host':platform.system()=='Darwin' and platform.machine()=='arm64',
            'explicit_context':args.context==CONTEXT}
    result={'status':'blocked','checks':checks,'limitations':[
        'Readiness does not prove NetworkPolicy enforcement; run bounded positive/negative probes separately.',
        'Doctor checks the observed Cilium agent only; the separate setup bundle verifies chart and rendered image pins. Signatures remain pending.',
        'No cluster creation, resume, image pulls, workload changes or certificate trust changes are performed.',
        'No independent clean-machine or complete hardened-state acceptance is implied.']}
    try:
        credential_store.load(Path(args.store));checks['private_sql_identities']=True
    except (OSError,ValueError):checks['private_sql_identities']=False
    capacity=resource_preflight.check(Path(args.runtime_dir),'acceptance')
    result['capacity']=capacity;checks['resource_capacity']=capacity['status']=='ready'
    # Do not contact an unavailable cluster or wait on a private kubeconfig while the lightweight lab runs.
    if not all(checks.values()):return result
    def read(command):
        return json.loads(subprocess.run(command,check=True,capture_output=True,text=True,timeout=35).stdout)
    try:
        kube=['kubectl','--kubeconfig',str(args.kubeconfig),'--context',args.context,'--request-timeout=15s']
        uid=read(kube+['get','namespace','kube-system','-o','json'])['metadata']['uid']
        if uid!=args.cluster_uid:
            checks['cluster_identity']=False;return result
        docker=['docker','--config',str(Path(args.runtime_dir)/'docker-client'),'--host','unix://'+str(Path.home()/'.docker/run/docker.sock')]
        observed={'uid':uid,'nodes':read(kube+['get','nodes','-o','json']),
                  'container':read(docker+['inspect',NODE])[0],
                  'cilium':read(kube+['get','daemonset','cilium','-n','kube-system','-o','json']),
                  'cilium_pods':read(kube+['get','pods','-n','kube-system','-l','k8s-app=cilium','-o','json'])}
        pins=lab.read_json(lab.PROFILE/'infrastructure.lock.json')
        checks.update(assess_cluster(observed,args.cluster_uid,pins))
    except (OSError,subprocess.SubprocessError,ValueError,KeyError,TypeError,IndexError):
        checks['cluster_observation_available']=False
    result['status']='ready' if all(checks.values()) else 'blocked'
    return result
