"""Explicit active image overlay; never changes immutable baseline references."""
import copy
import re

SERVICES={'trade-service','trade-processor','order-matcher','price-publisher'}

def overlay(reference, state):
    result=copy.deepcopy(reference)
    if not state or not state.get('active'):return result
    images=state['images']
    if set(images)!=SERVICES:raise ValueError('Incomplete candidate image set')
    for service,image in images.items():
        if not re.fullmatch(r'docker.io/library/traderx-security-'+re.escape(service)+r'@sha256:[0-9a-f]{64}',image):
            raise ValueError('Unexpected candidate manifest reference')
    seen=set()
    for item in result['items']:
        name=item.get('metadata',{}).get('name')
        if item['kind']=='Deployment' and name in images:
            containers=item['spec']['template']['spec']['containers']
            if len(containers)!=1 or containers[0]['name']!=name:raise ValueError('Unexpected candidate container')
            containers[0]['image']=images[name];containers[0]['imagePullPolicy']='IfNotPresent';seen.add(name)
    if seen!=SERVICES:raise ValueError('Missing candidate deployment')
    return result
