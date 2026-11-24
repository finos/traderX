#!/usr/bin/env python3
"""Bounded live network/admission checks in the dedicated lab cluster only."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time
from datetime import datetime, timezone

import cluster_identity
from prepare_runtime import resolve_image

NAMESPACE = 'security-platform-check'
CONTEXT = 'kind-traderx-security-lab'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--kubeconfig', type=Path, required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--cluster',choices=cluster_identity.CHOICES,default=cluster_identity.DEFAULT)
    parser.add_argument('--cluster-uid')
    args = parser.parse_args()
    if args.cluster!=cluster_identity.DEFAULT and not args.cluster_uid:parser.error('Validation cluster requires recorded --cluster-uid')
    args.output_dir.mkdir(parents=True, exist_ok=True)
    base = ['kubectl', '--kubeconfig', str(args.kubeconfig), '--context', 'kind-'+args.cluster,
            '--request-timeout=20s']
    observations = []

    def run(*argv, data=None, required=True):
        result = subprocess.run(base + list(argv), input=data, capture_output=True, text=True, timeout=45)
        if required and result.returncode:
            raise RuntimeError(result.stderr)
        return result

    def apply(items):
        return run('apply', '-f', '-', data=json.dumps({'apiVersion': 'v1', 'kind': 'List', 'items': items}))

    # This context is hard-coded, not the current user context. Check actual node name too.
    nodes = json.loads(run('get', 'nodes', '-o', 'json').stdout)['items']
    if len(nodes) != 1 or nodes[0]['metadata']['name'] != args.cluster+'-control-plane':
        raise ValueError('Refusing to test an unexpected cluster')
    if args.cluster_uid and json.loads(run('get','namespace','kube-system','-o','json').stdout)['metadata']['uid']!=args.cluster_uid:
        raise ValueError('Cluster identity mismatch')
    pin_path = args.output_dir / 'platform-image.lock.json'
    pin = json.loads(pin_path.read_text()) if pin_path.exists() else resolve_image('busybox:1.37.0', 'arm64')
    pin_path.write_text(json.dumps(pin, indent=2) + '\n')
    apply([{'apiVersion': 'v1', 'kind': 'Namespace', 'metadata': {'name': NAMESPACE,
        'labels': {'pod-security.kubernetes.io/enforce': 'restricted',
                   'pod-security.kubernetes.io/enforce-version': 'v1.35'}}}])
    # Reset only this script's two policies; no other namespace or workload is touched.
    run('-n', NAMESPACE, 'delete', 'networkpolicy', 'default-deny', 'server-from-allowed',
        'allowed-to-server', '--ignore-not-found=true')
    run('-n', NAMESPACE, 'delete', 'pod', 'server', 'allowed', 'denied',
        '--ignore-not-found=true', '--grace-period=1', '--timeout=20s')

    def pod(name, command):
        return {'apiVersion': 'v1', 'kind': 'Pod', 'metadata': {'name': name, 'namespace': NAMESPACE,
            'labels': {'app': name}}, 'spec': {'automountServiceAccountToken': False,
            'securityContext': {'runAsNonRoot': True, 'runAsUser': 1000,
                                'seccompProfile': {'type': 'RuntimeDefault'}},
            'containers': [{'name': name, 'image': pin['image'], 'command': command,
                'securityContext': {'allowPrivilegeEscalation': False,
                                    'capabilities': {'drop': ['ALL']}, 'readOnlyRootFilesystem': True},
                'resources': {'requests': {'cpu': '10m', 'memory': '8Mi'},
                              'limits': {'cpu': '100m', 'memory': '32Mi'}},
                'volumeMounts': [{'name': 'tmp', 'mountPath': '/tmp'}]}],
            'volumes': [{'name': 'tmp', 'emptyDir': {}}]}}

    apply([pod('server', ['sh', '-c', 'echo security-lab-ok > /tmp/index.html; exec httpd -f -p 8080 -h /tmp']),
           pod('allowed', ['sleep', '3600']), pod('denied', ['sleep', '3600'])])
    run('-n', NAMESPACE, 'wait', '--for=condition=Ready', 'pod', '--all', '--timeout=40s')
    ip = json.loads(run('-n', NAMESPACE, 'get', 'pod', 'server', '-o', 'json').stdout)['status']['podIP']

    def probe(name, phase):
        result = run('-n', NAMESPACE, 'exec', name, '--', 'wget', '-T', '2', '-qO-',
                     f'http://{ip}:8080', required=False)
        observations.append({'phase': phase, 'client': name, 'exit_code': result.returncode,
                             'stdout': result.stdout.strip(), 'stderr': result.stderr.strip()})
        return result

    def good(result):
        return result.returncode == 0 and result.stdout.strip() == 'security-lab-ok'

    try:
        for name in ['allowed', 'denied']:
            if not good(probe(name, 'before-policy')):
                raise RuntimeError('Baseline connectivity failed; negative checks would be inconclusive')

        def policy(name, spec):
            return {'apiVersion': 'networking.k8s.io/v1', 'kind': 'NetworkPolicy',
                    'metadata': {'name': name, 'namespace': NAMESPACE}, 'spec': spec}

        policies = [policy('default-deny', {'podSelector': {}, 'policyTypes': ['Ingress', 'Egress']}),
            policy('server-from-allowed', {'podSelector': {'matchLabels': {'app': 'server'}},
                'policyTypes': ['Ingress'], 'ingress': [{'from': [{'podSelector': {'matchLabels': {'app': 'allowed'}}}],
                    'ports': [{'protocol': 'TCP', 'port': 8080}]}]}),
            policy('allowed-to-server', {'podSelector': {'matchLabels': {'app': 'allowed'}},
                'policyTypes': ['Egress'], 'egress': [{'to': [{'podSelector': {'matchLabels': {'app': 'server'}}}],
                    'ports': [{'protocol': 'TCP', 'port': 8080}]}]})]
        apply(policies)
        denied = None
        for _ in range(10):
            allowed = probe('allowed', 'after-policy')
            denied = probe('denied', 'after-policy')
            if good(allowed) and denied.returncode != 0 and 'timed out' in denied.stderr.lower():
                break
            time.sleep(1)
        else:
            raise RuntimeError('Expected allowed/denied pair did not converge')
        if not good(probe('allowed', 'after-denial-positive-control')):
            raise RuntimeError('Server unavailable after denial; result inconclusive')
        unsafe = pod('unsafe-admission-probe', ['sleep', '10'])
        unsafe['spec']['securityContext']['runAsUser'] = 0
        unsafe['spec']['containers'][0]['securityContext']['privileged'] = True
        unsafe['spec']['containers'][0]['securityContext']['allowPrivilegeEscalation'] = True
        response = run('create', '--dry-run=server', '-f', '-', data=json.dumps(unsafe), required=False)
        admission = response.returncode != 0 and 'violates PodSecurity' in response.stderr
        observations.append({'phase': 'admission-negative-server-dry-run', 'exit_code': response.returncode,
                             'stderr': response.stderr.strip()})
        if not admission:
            raise RuntimeError('Unsafe pod was not rejected by Restricted admission')
        result = {'status': 'passed', 'scope': 'platform probes only; not hardened C3',
            'recorded_at': datetime.now(timezone.utc).isoformat(),
            'node_uid': nodes[0]['metadata']['uid'],
            'context': 'kind-'+args.cluster, 'cluster_uid': args.cluster_uid, 'image': pin, 'node_kernel': nodes[0]['status']['nodeInfo']['kernelVersion'],
            'network_allowed_and_denied_verified': True, 'restricted_admission_verified': True,
            'policy_sha256': hashlib.sha256(json.dumps(policies, sort_keys=True).encode()).hexdigest(),
            'observations': observations}
    except Exception as error:
        result = {'status': 'inconclusive', 'error': str(error), 'observations': observations}
        raise
    finally:
        (args.output_dir / 'platform-result.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
