#!/usr/bin/env python3
"""Apply canonical runtime versions after state patch composition, before CI packaging."""
import argparse
import json
import os
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
COMPOSE_DIRS = {5: 'postgres-database-replacement', 6: 'messaging-nats-replacement',
                7: 'observability-lgtm-compose', 8: 'pricing-awareness-market-data',
                9: 'order-management-matcher'}


def load_policy():
    path = Path(os.environ.get('TRADERX_DEPENDENCY_TARGETS_FILE', ROOT / 'catalog/dependency-version-targets.json'))
    policy = json.loads(path.read_text())
    for name, item in policy['docker']['infrastructure'].items():
        if not re.fullmatch(r'[^\s@]+@sha256:[0-9a-f]{64}', item['image']):
            raise ValueError(f'infrastructure image {name} is not digest-pinned')
        if 'recipe' in item and policy['docker']['rebuilds'][item['recipe']]['baseImage'] != item['image']:
            raise ValueError(f'rebuild base differs from infrastructure image: {name}')
    return policy


def image_ref(policy, service, number):
    item = policy['docker']['infrastructure'][service]
    return f"traderx-remediation/{item['recipe']}:{number:03d}" if 'recipe' in item else item['image']


def recipe_text(policy, recipe):
    item = policy['docker']['rebuilds'][recipe]
    tokens = {'BASE_IMAGE': item['baseImage'], 'GO_BUILDER_IMAGE': policy['docker']['buildImages']['go'],
              'SOURCE_COMMIT': item['sourceCommit'], 'SOURCE_REPOSITORY': item['sourceRepository'],
              'SOURCE_TAG': item.get('sourceTag', ''), 'VERSION': item.get('version', ''),
              'GO_DEPENDENCIES': ' '.join(item.get('goDependencies', [])),
              'UI_ARCHIVE': item.get('uiArchive', ''), 'UI_ARCHIVE_SHA256': item.get('uiArchiveSha256', '')}
    text = (ROOT / 'templates/runtime-image-rebuilds' / recipe / 'Dockerfile').read_text()
    for name, value in tokens.items():
        text = text.replace('@@' + name + '@@', value)
    if '@@' in text:
        raise ValueError(f'unresolved rebuild template: {recipe}')
    return text


def install_recipe(policy, service, target, runtime):
    recipe = policy['docker']['infrastructure'][service]['recipe']
    directory = target / 'database' if service == 'database' else runtime / 'runtime-images' / service
    directory.mkdir(parents=True, exist_ok=True)
    (directory / 'Dockerfile.compose').write_text(recipe_text(policy, recipe))
    return directory.relative_to(target).as_posix()


def metrics_config(text):
    # Health extension serves HTTP health, not Prometheus exposition.
    return re.sub(r',?\s*["\']otel-collector:13133["\']\s*,?', '', text)


def template(name):
    return (ROOT / 'templates/runtime-observability' / name).read_text()


def install_compose(target, number, policy):
    runtime = target / COMPOSE_DIRS[number]
    path = runtime / 'docker-compose.yml'
    if not path.is_file():
        raise ValueError(f'missing active Compose runtime: {path}')
    text = path.read_text()
    for service, item in policy['docker']['infrastructure'].items():
        pattern = rf'(^  {re.escape(service)}:\n)(.*?)(?=^  [a-zA-Z0-9_-]+:|^[^ \n]|\Z)'
        match = re.search(pattern, text, flags=re.M | re.S)
        if not match:
            continue
        body = re.sub(r'^    image: [^\n]+\n', '', match[2], flags=re.M)
        body = re.sub(r'^    build:\n(?:^      [^\n]*\n)+', '', body, flags=re.M)
        replacement = match[1] + f'    image: {image_ref(policy, service, number)}\n'
        if 'recipe' in item:
            context = install_recipe(policy, service, target, runtime)
            context = os.path.relpath(target / context, runtime)
            replacement += f'    build:\n      context: {context}\n      dockerfile: Dockerfile.compose\n'
        replacement += body
        text = text[:match.start()] + replacement + text[match.end():]
    if number >= 7:
        vector = image_ref(policy, 'promtail', number)
        text, count = re.subn(r'  promtail:\n.*?(?=\n  [a-zA-Z0-9_-]+:|\n[^ \n]|\Z)', f'''  promtail:
    image: {vector}
    command: ["--config", "/etc/vector/vector.toml"]
    volumes:
      - ./observability/vector/vector.toml:/etc/vector/vector.toml:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
    depends_on:
      - loki
''', text, flags=re.S)
        if count != 1:
            raise ValueError('missing log collector service')
        text = text.replace('"--web.enable-lifecycle"]', '"--web.enable-lifecycle", "--web.external-url=/prometheus", "--web.route-prefix=/"]')
        obs = runtime / 'observability'
        (obs / 'vector').mkdir(exist_ok=True)
        (obs / 'vector/vector.toml').write_text(template('vector-compose.toml'))
        (obs / 'tempo/config.yaml').write_text(template('tempo.yaml'))
        (obs / 'otel-collector/config.yaml').write_text(template('collector.yaml'))
        prom = obs / 'prometheus/prometheus.yml'
        prom.write_text(metrics_config(prom.read_text()))
        ingress = target / 'ingress/nginx.traderx.conf.template'
        if ingress.is_file():
            ingress.write_text(ingress.read_text().replace('proxy_pass http://prometheus:9090;', 'proxy_pass http://prometheus:9090/;'))
    path.write_text(text)


def write_configmap(path, namespace, key, content):
    # Keep existing metadata and replace the single generated data payload.
    prefix = path.read_text().split('data:\n', 1)[0]
    path.write_text(prefix + f'data:\n  {key}: |\n' + ''.join('    ' + line + '\n' for line in content.splitlines()))


def vector_daemonset(namespace, image):
    return f'''apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: promtail
  namespace: {namespace}
  labels:
    app: promtail
spec:
  selector:
    matchLabels:
      app: promtail
  template:
    metadata:
      labels:
        app: promtail
    spec:
      serviceAccountName: promtail
      containers:
        - name: promtail
          image: {image}
          args: ["--config", "/etc/vector/vector.toml"]
          env:
            - name: VECTOR_SELF_NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
            - name: VECTOR_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
          securityContext:
            runAsUser: 0
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
          volumeMounts:
            - name: vector-config
              mountPath: /etc/vector/vector.toml
              subPath: vector.toml
              readOnly: true
            - name: varlogpods
              mountPath: /var/log/pods
              readOnly: true
            - name: run
              mountPath: /run/vector
      volumes:
        - name: vector-config
          configMap:
            name: observability-promtail-config
        - name: varlogpods
          hostPath:
            path: /var/log/pods
            type: Directory
        - name: run
          emptyDir: {{}}
'''


def normalize_manifests(directory, number, policy):
    namespace = re.search(r'^  namespace: (\S+)', (directory / 'promtail-daemonset.yaml').read_text(), re.M)[1]
    for service in policy['docker']['infrastructure']:
        file = directory / f'{service}-deployment.yaml'
        if file.is_file():
            pattern = rf'(^ +[-] name: {re.escape(service)}\n +image:) [^\n]+'
            text, count = re.subn(pattern, rf'\1 {image_ref(policy, service, number)}', file.read_text(), flags=re.M)
            if count != 1:
                raise ValueError(f'expected one named {service} container in {file}')
            file.write_text(text)
    write_configmap(directory / 'observability-tempo-configmap.yaml', namespace, 'config.yaml', template('tempo.yaml'))
    write_configmap(directory / 'observability-otel-configmap.yaml', namespace, 'config.yaml', template('collector.yaml'))
    write_configmap(directory / 'observability-promtail-configmap.yaml', namespace, 'vector.toml', template('vector-kubernetes.toml'))
    (directory / 'promtail-daemonset.yaml').write_text(vector_daemonset(namespace, image_ref(policy, 'promtail', number)))
    role = directory / 'promtail-clusterrole.yaml'
    role.write_text(role.read_text().replace(', "services"', ''))
    prom = directory / 'observability-prometheus-configmap.yaml'
    prom.write_text(metrics_config(prom.read_text()))


def install_kubernetes(target, number, policy):
    runtime = target / 'kubernetes-runtime'
    plan_file = runtime / 'build-plan.json'
    if not plan_file.is_file():
        raise ValueError('missing Kubernetes build plan')
    plan = json.loads(plan_file.read_text())
    rebuilt = []
    for service, item in policy['docker']['infrastructure'].items():
        if 'recipe' in item:
            context = install_recipe(policy, service, target, runtime)
            rebuilt.append({'name': service, 'image': image_ref(policy, service, number),
                            'context': context, 'dockerfile': 'Dockerfile.compose'})
    names = {e['name'] for e in rebuilt}
    plan['images'] = [e for e in plan['images'] if e['name'] not in names] + rebuilt
    plan_file.write_text(json.dumps(plan, indent=2) + '\n')
    for directory in [runtime / 'manifests/base', target / 'tilt-kubernetes-dev-loop/manifests/base']:
        if directory.is_dir():
            normalize_manifests(directory, number, policy)
    for file in target.glob('*/upstream-build-plan.json'):
        file.write_text(json.dumps(plan, indent=2) + '\n')
    # Radius reads the component images from the generated state010 spec.
    for file in runtime.glob('spec-source/*.json'):
        spec = json.loads(file.read_text())
        if 'components' not in spec:
            continue
        for component in spec['components']:
            if component['name'] in policy['docker']['infrastructure']:
                component['image'] = image_ref(policy, component['name'], number)
        spec['runtime']['edge']['image'] = image_ref(policy, 'edge-proxy', number)
        file.write_text(json.dumps(spec, indent=2) + '\n')
    radius = target / 'radius-kubernetes-platform/radius/app.bicep'
    if radius.is_file():
        text = radius.read_text()
        for old, service in [('postgres:16-alpine', 'database'), ('nats:2.14-alpine', 'nats-broker'), ('nginx:1.27-alpine', 'edge-proxy')]:
            text = text.replace("image: '" + old + "'", "image: '" + image_ref(policy, service, number) + "'")
        radius.write_text(text)
    # Existing Tiltfile has root-relative build-plan paths; regenerate only build calls.
    tilt = target / 'tilt-kubernetes-dev-loop/tilt/Tiltfile'
    if tilt.is_file():
        text = re.sub(r'^docker_build\([^\n]+\)\n', '', tilt.read_text(), flags=re.M)
        lines = []
        for item in plan['images']:
            context = os.path.relpath(target / item['context'], tilt.parent)
            lines.append(f"docker_build('{item['image']}', '{context}', dockerfile='{context}/{item['dockerfile']}')")
        tilt.write_text(text.rstrip() + '\n' + '\n'.join(lines) + '\n')


TRACE_ENV = {
    'MANAGEMENT_OPENTELEMETRY_TRACING_EXPORT_OTLP_ENDPOINT': 'http://otel-collector:4318/v1/traces',
    'MANAGEMENT_TRACING_SAMPLING_PROBABILITY': '1.0',
    'MANAGEMENT_OTLP_METRICS_EXPORT_ENABLED': 'false',
}


def normalize_base_images(target, policy):
    references = policy['docker'].get('baseImages', {})
    for path in target.rglob('Dockerfile*'):
        if not path.is_file() or any(part in {'node_modules', 'runtime-cache', '.git'} for part in path.parts):
            continue
        def replace(match):
            source = match[2].split('@', 1)[0]
            return match[1] + references.get(source, match[2])
        path.write_text(re.sub(r'^(FROM\s+(?:--platform=\S+\s+)?)(\S+)', replace, path.read_text(), flags=re.M | re.I))


def install_application_tracing(target, number):
    modules = []
    for path in target.glob('*/build.gradle'):
        text = path.read_text()
        if 'org.springframework.boot' not in text or 'spring-boot-starter-actuator' not in text:
            continue
        modules.append(path.parent.name)
        if 'spring-boot-starter-opentelemetry' not in text:
            text = text.replace("implementation 'org.springframework.boot:spring-boot-starter-actuator'",
                                "implementation 'org.springframework.boot:spring-boot-starter-actuator'\n  implementation 'org.springframework.boot:spring-boot-starter-opentelemetry'")
            path.write_text(text)
    if number <= 9:
        path = target / COMPOSE_DIRS[number] / 'docker-compose.yml'
        text = path.read_text()
        for module in modules:
            pattern = rf'(^  {re.escape(module)}:\n)(.*?)(?=^  [a-zA-Z0-9_-]+:|^[^ \n]|\Z)'
            match = re.search(pattern, text, flags=re.M | re.S)
            if not match:
                continue
            body = match[2]
            for key in TRACE_ENV:
                body = re.sub(rf'^      {key}:.*\n', '', body, flags=re.M)
            env = ''.join(f'      {key}: "{value}"\n' for key, value in TRACE_ENV.items())
            if '    environment:\n' not in body:
                body += '    environment:\n' + env
            else:
                body = body.replace('    environment:\n', '    environment:\n' + env, 1)
            text = text[:match.start()] + match[1] + body + text[match.end():]
        path.write_text(text)
    else:
        for directory in [target / 'kubernetes-runtime/manifests/base', target / 'tilt-kubernetes-dev-loop/manifests/base']:
            for module in modules:
                path = directory / f'{module}-deployment.yaml'
                if not path.is_file():
                    continue
                text = path.read_text()
                for key in TRACE_ENV:
                    text = re.sub(rf'^ +[-] name: {key}\n +value: [^\n]*\n', '', text, flags=re.M)
                match = re.search(r'^( +)env:\n', text, flags=re.M)
                if not match:
                    raise ValueError(f'missing container environment in {path}')
                indent = match[1]
                env = ''.join(f'{indent}  - name: {key}\n{indent}    value: "{value}"\n' for key,value in TRACE_ENV.items())
                text = text[:match.end()] + env + text[match.end():]
                path.write_text(text)
        for path in (target / 'kubernetes-runtime/spec-source').glob('*.json'):
            spec = json.loads(path.read_text())
            for component in spec.get('components', []):
                if component['name'] in modules:
                    component['env'] = [e for e in component.get('env', []) if e['name'] not in TRACE_ENV] + [
                        {'name': key, 'value': value} for key,value in TRACE_ENV.items()]
            path.write_text(json.dumps(spec, indent=2) + '\n')


def install_sail_companion(target, policy):
    path = target / 'fdc3-intent-interoperability/sail/docker-compose.yml'
    if not path.is_file():
        raise ValueError('state014 Sail companion Compose is missing')
    text, count = re.subn(r'(^  sail:\n(?:    [^\n]*\n)*?    image:)[^\n]*',
                          lambda match: match[1] + ' ' + policy['docker']['infrastructure']['sail']['image'],
                          path.read_text(), count=1, flags=re.M)
    if count != 1:
        raise ValueError('state014 Sail companion image is missing')
    path.write_text(text)


def install(state_id, target, policy=None):
    number = int(state_id.split('-', 1)[0])
    policy = policy or load_policy()
    if number < 5:
        normalize_base_images(target, policy)
        return  # State004 and earlier retain H2; never replace its database image.
    if number in COMPOSE_DIRS:
        install_compose(target, number, policy)
    else:
        install_kubernetes(target, number, policy)
    normalize_base_images(target, policy)
    if number >= 14:
        install_sail_companion(target, policy)
    if number >= 7:
        install_application_tracing(target, number)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('state_id')
    parser.add_argument('target', type=Path)
    args = parser.parse_args()
    install(args.state_id, args.target)
    print(f'[ok] installed canonical runtime image policy for {args.state_id}')
