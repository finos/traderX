#!/usr/bin/env python3
"""Offline C3 inventory, candidate policy compiler and evidence consistency checks."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
PROFILE = ROOT / 'specs/012-platform-convergence-c3/security-lab'


def read_json(path):
    return json.loads(Path(path).read_text())


def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT), *args], text=True)


def object_text(commit, path):
    if not re.fullmatch(r'[0-9a-f]{40}', commit):
        raise ValueError('Expected full immutable Git SHA')
    return git('show', f'{commit}:{path}')


def inventory(lock):
    import yaml
    sha = lock['generated_commit']
    readme = object_text(sha, 'README.md')
    if f"Source Commit: `{lock['canonical_source_commit']}`" not in readme:
        raise ValueError('Snapshot source does not match baseline lock')
    base = 'kubernetes-runtime/manifests/base'
    paths = git('ls-tree', '-r', '--name-only', sha, base).splitlines()
    workloads, services, configs, hashes, kinds = [], [], {}, {}, []
    for path in paths:
        raw = object_text(sha, path)
        hashes[path] = hashlib.sha256(raw.encode()).hexdigest()
        if not path.endswith(('.yaml', '.yml')):
            continue
        for doc in yaml.safe_load_all(raw):
            if not isinstance(doc, dict):
                continue
            kind = doc.get('kind')
            kinds.append(kind)
            name = doc.get('metadata', {}).get('name')
            if kind == 'Deployment':
                pod = doc['spec']['template']['spec']
                containers = []
                for container in pod['containers']:
                    env = container.get('env', [])
                    containers.append({
                        'name': container['name'], 'image': container['image'],
                        'image_digest_pinned': '@sha256:' in container['image'],
                        'security_context': container.get('securityContext', {}),
                        'resources': container.get('resources', {}),
                        # Deliberately omit environment values, including demo credentials.
                        'literal_credential_fields': sorted(e['name'] for e in env
                            if 'value' in e and re.search(r'PASS|SECRET|TOKEN|DBUSER|POSTGRES_USER', e['name'])),
                        'secret_refs': sorted({e['valueFrom']['secretKeyRef']['name'] for e in env
                            if 'secretKeyRef' in e.get('valueFrom', {})}),
                        'dependency_fields': sorted(e['name'] for e in env
                            if e['name'].endswith(('_HOST', '_URL'))),
                    })
                workloads.append({'name': name, 'source': path,
                    'service_account': pod.get('serviceAccountName', 'default'),
                    'automount_token': pod.get('automountServiceAccountToken', 'inherited'),
                    'pod_security_context': pod.get('securityContext', {}), 'containers': containers})
            elif kind == 'Service':
                services.append({'name': name, 'source': path,
                    'type': doc['spec'].get('type', 'ClusterIP'), 'ports': doc['spec']['ports']})
            elif kind == 'ConfigMap':
                configs[name] = doc.get('data', {})
    edge = '\n'.join(configs.get('edge-proxy-config', {}).values())
    nats = '\n'.join(configs.get('nats-config', {}).values())
    if not edge or not nats or not workloads:
        raise ValueError('Expected C3 manifest structure missing; inventory requires review')
    return {'status': 'static-observations-only', 'baseline': lock,
        'source_hashes': hashes, 'workloads': workloads, 'services': services,
        'edge_locations': re.findall(r'location\s+(?:[=~^]+\s+)?([^\s{]+)\s*\{', edge),
        'network_policy_count': kinds.count('NetworkPolicy'),
        'nats_authentication_configured': bool(re.search(r'\b(authorization|accounts|operator)\s*[:{]', nats)),
        'nats_websocket_no_tls': bool(re.search(r'no_tls\s*:\s*true', nats)),
        'limitations': ['Configuration observations only; no exploitation or enforcement proof',
            'See baseline lock for image-pin status; static inventory is not runtime reproduction']}


def render_network(contract):
    namespace = contract['namespace']
    if namespace != 'traderx-security-lab':
        raise ValueError('Candidate policies must target isolated lab namespace')
    ports_by_app = contract['workloads']
    resources = []

    def add(name, spec):
        resources.append({'apiVersion': 'networking.k8s.io/v1', 'kind': 'NetworkPolicy',
            'metadata': {'name': name, 'namespace': namespace}, 'spec': spec})

    def selector(app):
        return {'matchLabels': {'app': app}}

    add('default-deny', {'podSelector': {}, 'policyTypes': ['Ingress', 'Egress']})
    for app in sorted(ports_by_app):
        add(f'{app}-dns', {'podSelector': selector(app), 'policyTypes': ['Egress'], 'egress': [{
            'to': [{'namespaceSelector': {'matchLabels': {'kubernetes.io/metadata.name': 'kube-system'}},
                    'podSelector': {'matchLabels': {'k8s-app': 'kube-dns'}}}],
            'ports': [{'protocol': proto, 'port': 53} for proto in ['UDP', 'TCP']]}]})
    seen = set()
    for flow in sorted(contract['flows'], key=lambda f: (f['from'], f['to'], f['port'])):
        src, dst, port = flow['from'], flow['to'], flow['port']
        if src not in ports_by_app or dst not in ports_by_app or type(port) is not int or port not in ports_by_app[dst]:
            raise ValueError(f'Unknown workload or undeclared destination port: {flow}')
        key = (src, dst, port)
        if key in seen:
            raise ValueError(f'Duplicate flow: {flow}')
        seen.add(key)
        ports = [{'protocol': 'TCP', 'port': port}]
        add(f'{src}-to-{dst}-{port}', {'podSelector': selector(src), 'policyTypes': ['Egress'],
            'egress': [{'to': [{'podSelector': selector(dst)}], 'ports': ports}]})
        add(f'{dst}-from-{src}-{port}', {'podSelector': selector(dst), 'policyTypes': ['Ingress'],
            'ingress': [{'from': [{'podSelector': selector(src)}], 'ports': ports}]})
    return {'apiVersion': 'v1', 'kind': 'List', 'items': resources}


def validate_evidence(result, scenarios):
    errors = []
    scenario = next((s for s in scenarios if s['id'] == result.get('scenario_id')), None)
    if scenario is None:
        return ['Unknown scenario_id']
    for name in ['run_id', 'configuration_sha256', 'generated_commit', 'profile', 'collector_ref']:
        if not isinstance(result.get(name), str) or not result[name].strip():
            errors.append(f'Missing {name}')
    if not re.fullmatch(r'[0-9a-f]{64}', result.get('configuration_sha256', '')):
        errors.append('configuration_sha256 must be a SHA256 digest')
    if not re.fullmatch(r'[0-9a-f]{40}', result.get('generated_commit', '')):
        errors.append('generated_commit must be a full Git SHA')
    if result.get('profile') not in ['reference', 'hardened-observation', 'hardened-enforcement', 'candidate', 'combined']:
        errors.append('Unknown profile')
    outcome = result.get('outcome')
    if outcome not in ['prevented', 'detected', 'contained', 'allowed', 'inconclusive']:
        errors.append('Unknown outcome')
    for name in ['positive_control_passed', 'attempt_executed', 'asynchronous_settled',
                 'normal_workflow_passed', 'effect_observed', 'alert_observed', 'containment_observed']:
        if type(result.get(name)) is not bool:
            errors.append(f'{name} must be boolean')
    if outcome != 'inconclusive':
        for name in ['positive_control_passed', 'attempt_executed', 'asynchronous_settled', 'normal_workflow_passed']:
            if result.get(name) is not True:
                errors.append(f'Conclusive result requires {name}')
        for name in ['before_ref', 'after_ref', 'application_receipt_ref']:
            if not isinstance(result.get(name), str) or not result[name].strip():
                errors.append(f'Conclusive result requires {name}')
    if outcome == 'prevented':
        if result.get('effect_observed') is not False:
            errors.append('Prevention requires independently verified absence of effect')
        if result.get('intervening_layer') not in scenario['layers']:
            errors.append('Intervening layer inconsistent with scenario')
        if not result.get('decision_ref'):
            errors.append('Prevention requires attributed decision evidence')
    if outcome == 'detected' and result.get('alert_observed') is not True:
        errors.append('Detection requires alert evidence')
    if outcome == 'contained' and result.get('containment_observed') is not True:
        errors.append('Containment requires containment evidence')
    if outcome in ['detected', 'contained'] and not result.get('decision_ref'):
        errors.append('Detection/containment requires decision evidence')
    if outcome == 'allowed' and result.get('effect_observed') is not True:
        errors.append('Allowed requires observed effect')
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['inventory', 'render-network', 'validate-evidence'])
    parser.add_argument('--output', type=Path)
    parser.add_argument('--input', type=Path)
    args = parser.parse_args()
    if args.command == 'inventory':
        result = inventory(read_json(PROFILE / 'baseline.lock.json'))
    elif args.command == 'render-network':
        result = render_network(read_json(PROFILE / 'system/flows.json'))
    else:
        if not args.input:
            parser.error('validate-evidence requires --input')
        errors = validate_evidence(read_json(args.input), read_json(PROFILE / 'contracts/scenarios.json'))
        print(json.dumps({'valid': not errors, 'errors': errors}, indent=2))
        return 1 if errors else 0
    text = json.dumps(result, indent=2, sort_keys=True) + '\n'
    if args.output:
        args.output.write_text(text)
    else:
        print(text, end='')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError) as error:
        print(f'lab: {error}', file=sys.stderr)
        sys.exit(1)
