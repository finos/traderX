"""Compose reviewed controls into one candidate, with explicit migration prerequisites."""
import copy
import re

import workloads
import support_workloads
import database_workload
import observability_workloads
import collector_boundary
import database_permissions

NS = workloads.NS
INFRA = collector_boundary.INFRA
APP_NAMES = set(workloads.NAMES + support_workloads.NAMES + database_workload.NAMES + observability_workloads.NAMES)
LEGACY = {
    ('v1', 'ServiceAccount', NS, 'promtail'),
    ('rbac.authorization.k8s.io/v1', 'ClusterRole', '', 'promtail-traderx'),
    ('rbac.authorization.k8s.io/v1', 'ClusterRoleBinding', '', 'promtail-traderx'),
    ('apps/v1', 'DaemonSet', NS, 'promtail'),
    ('v1', 'ConfigMap', NS, 'observability-promtail-config'),
    ('v1', 'ConfigMap', NS, 'database-init-sql'),
}


def key(doc):
    meta = doc['metadata']
    return (doc['apiVersion'], doc['kind'], meta.get('namespace', ''), meta['name'])


def index(items):
    result = {}
    for doc in items:
        identity = key(doc)
        if identity in result:
            raise ValueError('Duplicate Kubernetes object: ' + '/'.join(identity))
        result[identity] = copy.deepcopy(doc)
    return result


def overlay(objects, items, replacements):
    incoming = index(items)
    if not replacements <= (set(objects) & set(incoming)):
        raise ValueError('Missing declared overlay replacement')
    for identity, doc in incoming.items():
        if identity in objects and identity not in replacements:
            raise ValueError('Undeclared overlay collision: ' + '/'.join(identity))
        objects[identity] = doc


def application_replacements(names):
    return {('apps/v1', 'Deployment', NS, n) for n in names}


def validate(candidate):
    objects = index(candidate['items'])
    deployments = [d for d in objects.values() if d['kind'] == 'Deployment']
    if len(deployments) != 19 or {d['metadata']['name'] for d in deployments} != APP_NAMES:
        raise ValueError('Expected all nineteen reviewed application deployments')
    if set(objects) & LEGACY:
        raise ValueError('Legacy collector privileges or database initialization retained')
    for namespace, level in ((NS, 'restricted'), (INFRA, 'privileged')):
        labels = objects[('v1', 'Namespace', '', namespace)]['metadata'].get('labels', {})
        if labels.get('pod-security.kubernetes.io/enforce') != level or labels.get('pod-security.kubernetes.io/enforce-version') != 'v1.35':
            raise ValueError('Namespace security contract changed')
    policy_names = {prefix + suffix for prefix in (
        workloads.POLICY, support_workloads.POLICY, database_workload.POLICY,
        observability_workloads.POLICY, database_permissions.POLICY) for suffix in ('', '-pods')}
    policy_names |= {collector_boundary.POLICY + suffix for suffix in ('-pods', '-daemonset')}
    for kind in ('ValidatingAdmissionPolicy', 'ValidatingAdmissionPolicyBinding'):
        if {d['metadata']['name'] for d in objects.values() if d['kind'] == kind} != policy_names:
            raise ValueError('Admission inventory incomplete')
    missing_secrets = {}
    for d in deployments:
        if d['metadata']['namespace'] != NS:
            raise ValueError('Application workload escaped its namespace')
        p = d['spec']['template']['spec']
        if p.get('automountServiceAccountToken') is not False or p.get('serviceAccountName') != 'lab-' + d['metadata']['name']:
            raise ValueError('Unreviewed application identity')
        if p.get('securityContext', {}).get('runAsNonRoot') is not True or p['securityContext'].get('seccompProfile') != {'type': 'RuntimeDefault'}:
            raise ValueError('Application pod restrictions missing')
        if len(p['containers']) != 1 or p.get('initContainers') or p.get('ephemeralContainers'):
            raise ValueError('Unreviewed application containers')
        if any(p.get(field) for field in ('hostNetwork', 'hostPID', 'hostIPC')):
            raise ValueError('Host namespace access in application')
        c = p['containers'][0]
        s = c.get('securityContext', {})
        if s.get('allowPrivilegeEscalation') is not False or s.get('readOnlyRootFilesystem') is not True or s.get('capabilities') != {'drop': ['ALL']}:
            raise ValueError('Application container restrictions missing')
        if not re.fullmatch(r'.+@sha256:[0-9a-f]{64}', c['image']):
            raise ValueError('Unpinned application image')
        required = [('v1', 'ServiceAccount', NS, p['serviceAccountName'])]
        service_account = objects.get(required[0], {})
        if service_account.get('automountServiceAccountToken') is not False:
            raise ValueError('Service account token restriction missing')
        for v in p.get('volumes', []):
            if 'hostPath' in v or 'projected' in v or 'secret' in v:
                raise ValueError('Unreviewed application volume')
            if 'configMap' in v: required.append(('v1', 'ConfigMap', NS, v['configMap']['name']))
            if 'persistentVolumeClaim' in v: required.append(('v1', 'PersistentVolumeClaim', NS, v['persistentVolumeClaim']['claimName']))
        for identity in required:
            if identity not in objects: raise ValueError('Dangling workload reference: ' + '/'.join(identity))
        if c.get('envFrom'):
            raise ValueError('Unreviewed bulk environment')
        for env in c.get('env', []):
            ref = env.get('valueFrom', {}).get('secretKeyRef')
            if ref:
                if ref.get('optional'): raise ValueError('Required SQL secret marked optional')
                missing_secrets.setdefault(ref['name'], set()).add(ref['key'])
            if env['name'] in ('DATABASE_DBUSER', 'DATABASE_DBPASS', 'POSTGRES_PASSWORD') and not ref:
                raise ValueError('Literal database credential in candidate')
    expected = {database_permissions.secret_name(n): {'username', 'password'} for n in database_permissions.NAMES}
    expected['lab-sql-bootstrap'] = {'password'}
    if missing_secrets != expected or any(d['kind'] == 'Secret' for d in objects.values()):
        raise ValueError('SQL credential requirements differ from reviewed contract')
    ds = [d for d in objects.values() if d['kind'] == 'DaemonSet']
    if len(ds) != 1 or ds[0]['metadata']['namespace'] != INFRA or ds[0]['metadata']['name'] != 'promtail':
        raise ValueError('Expected one isolated infrastructure collector')
    # Collector retains a narrowly specified root/host-log/API exception, not application privileges.
    image = ds[0]['spec']['template']['spec']['containers'][0]['image']
    if ds[0]['spec']['template']['spec'] != collector_boundary.pod_spec(image):
        raise ValueError('Collector exception changed')
    for d in objects.values():
        if d['kind'] == 'ValidatingAdmissionPolicyBinding':
            name = d['spec']['policyName']
            if ('admissionregistration.k8s.io/v1', 'ValidatingAdmissionPolicy', '', name) not in objects:
                raise ValueError('Dangling admission binding')
    return {name: sorted(keys) for name, keys in sorted(missing_secrets.items())}


def render(reference):
    objects = index(reference['items'])
    if {d['metadata']['name'] for d in objects.values() if d['kind'] == 'Deployment'} != APP_NAMES:
        raise ValueError('Reference deployment inventory changed')
    for identity in LEGACY:
        if identity not in objects: raise ValueError('Missing expected legacy resource: ' + '/'.join(identity))
        del objects[identity]
    business = database_permissions.transform(workloads.render(reference))
    support = support_workloads.render(reference)
    database = database_workload.render(reference)
    database['items'] = [database_permissions.bootstrap_deployment(reference) if d['kind'] == 'Deployment' else d for d in database['items']]
    groups = [
        (business, application_replacements(workloads.NAMES)),
        (support, application_replacements(support_workloads.NAMES) | {('v1', 'Service', NS, 'api-explorer')}),
        (database, application_replacements(database_workload.NAMES)),
        (observability_workloads.render(reference), application_replacements(observability_workloads.NAMES)),
        (collector_boundary.render(reference), set()),
        ({'items': database_permissions.admission(reference)}, set()),
    ]
    for group, replacements in groups: overlay(objects, group['items'], replacements)
    namespace = objects[('v1', 'Namespace', '', NS)]
    namespace['metadata'].setdefault('labels', {}).update({
        'pod-security.kubernetes.io/enforce': 'restricted',
        'pod-security.kubernetes.io/enforce-version': 'v1.35'})
    result = {'apiVersion': 'v1', 'kind': 'List', 'items': [objects[k] for k in sorted(objects)]}
    secrets = validate(result)
    plan = {
        'schema_version': 1, 'status': 'blocked-for-deployment',
        'candidate': 'controls-candidate.json',
        'application_deployments': sorted(APP_NAMES),
        'required_secrets': secrets,
        'legacy_resources_removed_from_candidate': [list(k) for k in sorted(LEGACY)],
        'preconditions': [
            'Explicit owned-cluster identity and one-cluster-at-a-time capacity/operation lock.',
            'Create private bootstrap/runtime SQL credentials outside source and evidence.',
            'Restore or explicitly initialize the synthetic schema/data; database overlay suppresses automatic seed scripts.',
            'Establish scoped SQL grants before application rollout; Secret references alone do not create database roles.',
            'For existing deployments: preserve database/telemetry data and collector checkpoints before replacing resources.',
            'Verify all nineteen workloads and collector delivery before enabling Restricted on an existing namespace.',
        ],
        'phases': ['preflight-and-ownership', 'private-credentials', 'storage-and-dataset',
                   'sql-role-grants', 'admission-and-workload-rollout', 'collector-cutover',
                   'namespace-restriction', 'positive-and-negative-acceptance'],
        'pending_integrations': ['fresh-cluster-bootstrap', 'lifecycle-orchestration', 'business-authorization',
            'authenticated-live-nats', 'gateway-waf-tls', 'complete-network-graph', 'image-signature-admission',
            'independent-evidence', 'runtime-observation-enforcement'],
        'limitations': ['Composition is static, not server admission or runtime acceptance.',
            'The application namespace is Restricted; the separate collector namespace has an explicit privileged-PSS exception constrained by its admission policies.',
            'Reference data and telemetry preservation require ordered lifecycle operations; never apply this list directly to an existing cluster.',
            'An offline plan does not inspect or reserve host resources.']}
    return result, plan
