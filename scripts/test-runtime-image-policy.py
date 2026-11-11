#!/usr/bin/env python3
"""Exercise final image/config normalization against canonical state patch fixtures."""
import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('runtime_policy', ROOT / 'pipeline/install-runtime-image-policy.py')
policy_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(policy_module)


def patch_fixture(target, number):
    # Use complete newly-added runtime assets from the real state patch, not
    # mocked copies of the normalization algorithm's expected output.
    patch = next((ROOT / 'specs').glob(f'{number:03d}-*/generation/patches/0001-state-overlay.patch'))
    for block in patch.read_text().split('diff --git ')[1:]:
        header, _, body = block.partition('\n')
        if 'new file mode' not in body:
            continue
        path = header.split(' b/', 1)[1]
        if path.endswith('.md') or not any(s in path for s in ['docker-compose.yml', '/observability/', 'kubernetes-runtime/']):
            continue
        text = '\n'.join(line[1:] for line in body.splitlines() if line.startswith('+') and not line.startswith('+++')) + '\n'
        dest = target / path
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(text)


class ImagePolicyTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.target = Path(self.tmp.name)
        self.policy = policy_module.load_policy()

    def tearDown(self):
        self.tmp.cleanup()

    def test_h2_states_are_untouched(self):
        p = self.target / 'database/Dockerfile.compose'
        p.parent.mkdir();p.write_text('FROM example/h2:original\n')
        for n in (1, 4):
            policy_module.install(f'{n:03d}-fixture', self.target, self.policy)
            self.assertEqual(p.read_text(), 'FROM example/h2:original\n')

    def test_compose_states_render_pinned_images_and_compatible_configs(self):
        for number in (5, 6, 7, 8, 9):
            with self.subTest(state=number):
                patch_fixture(self.target, number)
                runtime = self.target / policy_module.COMPOSE_DIRS[number]
                if number in (6, 8):
                    # These states rename the parent compose rather than adding a
                    # complete file; use that real parent content for this fixture.
                    parent = self.target / policy_module.COMPOSE_DIRS[number - 1]
                    runtime.mkdir(exist_ok=True)
                    shutil.copyfile(parent / 'docker-compose.yml', runtime / 'docker-compose.yml')
                    if number == 6:
                        p = runtime / 'docker-compose.yml'
                        p.write_text(p.read_text() + '\n  nats-broker:\n    restart: unless-stopped\n    image: nats:2.14-alpine\n')
                    if number == 8:
                        shutil.copytree(parent / 'observability', runtime / 'observability', dirs_exist_ok=True)
                ingress = self.target / 'ingress/nginx.traderx.conf.template'
                ingress.parent.mkdir(exist_ok=True)
                ingress.write_text('location /prometheus/ { proxy_pass http://prometheus:9090; }\n')
                policy_module.install(f'{number:03d}-fixture', self.target, self.policy)
                compose = (runtime / 'docker-compose.yml').read_text()
                self.assertIn(f'traderx-remediation/postgres:{number:03d}', compose)
                self.assertIn('FROM postgres:16-alpine@sha256:', (self.target / 'database/Dockerfile.compose').read_text())
                if number >= 7:
                    self.assertIn('timberio/vector:0.61.0-alpine@sha256:', compose)
                    self.assertNotIn('image: grafana/promtail:', compose)
                    self.assertIn('--web.external-url=/prometheus', compose)
                    self.assertIn('--web.route-prefix=/', compose)
                    self.assertIn('proxy_pass http://prometheus:9090/;', ingress.read_text())
                    self.assertNotIn('otel-collector:13133', (runtime / 'observability/prometheus/prometheus.yml').read_text())
                    self.assertIn('target: all', (runtime / 'observability/tempo/config.yaml').read_text())
                    self.assertIn('debug:', (runtime / 'observability/otel-collector/config.yaml').read_text())
                before = {p.relative_to(self.target):p.read_bytes() for p in self.target.rglob('*') if p.is_file()}
                policy_module.install(f'{number:03d}-fixture', self.target, self.policy)
                after = {p.relative_to(self.target):p.read_bytes() for p in self.target.rglob('*') if p.is_file()}
                self.assertEqual(before, after)

    def test_kubernetes_descendants_preserve_rebuilds_and_kubernetes_log_collection(self):
        for number in (10, 12, 14):
            with self.subTest(state=number):
                patch_fixture(self.target, 10)
                manifests = self.target / 'kubernetes-runtime/manifests/base'
                tilt = self.target / 'tilt-kubernetes-dev-loop'
                if tilt.exists():shutil.rmtree(tilt)
                shutil.copytree(manifests, tilt / 'manifests/base')
                (tilt / 'upstream-build-plan.json').write_text('{}')
                (tilt / 'tilt').mkdir()
                (tilt / 'tilt/Tiltfile').write_text("k8s_yaml('../manifests/base/*.yaml')\ndocker_build('old', '../old')\n")
                if number == 14:
                    companion = self.target / 'fdc3-intent-interoperability/sail/docker-compose.yml'
                    companion.parent.mkdir(parents=True, exist_ok=True)
                    renderer = (ROOT / 'pipeline/render-state-014-fdc3-intent-interoperability.sh').read_text()
                    compose = renderer.split('name: traderx-state-014-sail', 1)[1].split('\nEOF', 1)[0]
                    companion.write_text('name: traderx-state-014-sail' + compose)
                policy_module.install(f'{number:03d}-fixture', self.target, self.policy)
                if number == 14:
                    self.assertIn(self.policy['docker']['infrastructure']['sail']['image'], companion.read_text())
                    self.assertNotIn('node:20-bookworm', companion.read_text())
                plan = json.loads((self.target / 'kubernetes-runtime/build-plan.json').read_text())
                by_name = {i['name']:i for i in plan['images']}
                for name in ('database','blackbox-exporter','prometheus','loki','tempo'):
                    entry = by_name[name]
                    self.assertTrue((self.target / entry['context'] / entry['dockerfile']).is_file())
                    self.assertNotIn('@@', (self.target / entry['context'] / entry['dockerfile']).read_text())
                for directory in (manifests, tilt / 'manifests/base'):
                    for service in self.policy['docker']['infrastructure']:
                        file = directory / f'{service}-deployment.yaml'
                        if file.exists():self.assertIn(policy_module.image_ref(self.policy,service,number),file.read_text())
                    ds = (directory / 'promtail-daemonset.yaml').read_text()
                    self.assertIn('fieldPath: spec.nodeName', ds)
                    self.assertIn('/var/log/pods', ds)
                    self.assertNotIn('docker.sock', ds)
                    self.assertIn('readOnly: true', ds)
                    for config_name in ('promtail', 'tempo', 'otel'):
                        cm = (directory / f'observability-{config_name}-configmap.yaml').read_text()
                        name = 'otel-collector' if config_name == 'otel' else config_name
                        self.assertIn(f'  name: observability-{name}-config', cm)
                        self.assertIn('  namespace: traderx', cm)
                        self.assertIn('\ndata:\n', cm)
                    config = (directory / 'observability-promtail-configmap.yaml').read_text()
                    self.assertIn('type = "kubernetes_logs"', config)
                    self.assertIn('metadata.namespace=traderx', config)
                    self.assertNotIn('${VECTOR_NAMESPACE}', config)
                    self.assertIn('get', (directory / 'promtail-clusterrole.yaml').read_text())
                    self.assertNotIn('otel-collector:13133', (directory / 'observability-prometheus-configmap.yaml').read_text())
                self.assertEqual(json.loads((tilt / 'upstream-build-plan.json').read_text()),plan)
                before = {p.relative_to(self.target):p.read_bytes() for p in self.target.rglob('*') if p.is_file()}
                policy_module.install(f'{number:03d}-fixture', self.target, self.policy)
                self.assertEqual(before,{p.relative_to(self.target):p.read_bytes() for p in self.target.rglob('*') if p.is_file()})

    def test_runtime_image_replacement_preserves_unrelated_sidecar_images(self):
        patch_fixture(self.target,10)
        path = self.target / 'kubernetes-runtime/manifests/base/grafana-deployment.yaml'
        text=path.read_text().replace('      containers:\n', '      containers:\n        - name: independent-sidecar\n          image: example/sidecar:original\n')
        path.write_text(text)
        policy_module.install('010-fixture',self.target,self.policy)
        self.assertIn('image: example/sidecar:original',path.read_text())
        self.assertIn(self.policy['docker']['infrastructure']['grafana']['image'],path.read_text())

    def test_all_application_build_stages_use_selected_digests(self):
        path = self.target / 'example/Dockerfile.compose'
        path.parent.mkdir()
        path.write_text('FROM eclipse-temurin:21-jdk AS build\nFROM eclipse-temurin:21-jre\n')
        policy_module.install('004-fixture', self.target, self.policy)
        self.assertIn(self.policy['docker']['baseImages']['eclipse-temurin:21-jdk'] + ' AS build', path.read_text())
        self.assertIn(self.policy['docker']['baseImages']['eclipse-temurin:21-jre'], path.read_text())
        self.assertNotIn('postgres',path.read_text())

    def test_tracing_is_limited_to_observability_spring_services(self):
        path = self.target / 'account-service/build.gradle'
        path.parent.mkdir()
        original = "plugins { id 'org.springframework.boot' version '4.0.8' }\nimplementation 'org.springframework.boot:spring-boot-starter-actuator'\n"
        path.write_text(original)
        policy_module.install('004-fixture',self.target,self.policy)
        self.assertEqual(path.read_text(),original)
        for number in (7,10):
            patch_fixture(self.target,number)
            policy_module.install(f'{number:03d}-fixture',self.target,self.policy)
            self.assertEqual(path.read_text().count('spring-boot-starter-opentelemetry'),1)
            if number == 7:
                text = (self.target / 'observability-lgtm-compose/docker-compose.yml').read_text()
                self.assertIn('MANAGEMENT_OPENTELEMETRY_TRACING_EXPORT_OTLP_ENDPOINT: "http://otel-collector:4318/v1/traces"',text)
            else:
                text = (self.target / 'kubernetes-runtime/manifests/base/account-service-deployment.yaml').read_text()
                self.assertIn('name: MANAGEMENT_OPENTELEMETRY_TRACING_EXPORT_OTLP_ENDPOINT',text)
                self.assertIn('value: "http://otel-collector:4318/v1/traces"',text)
            before = {p.relative_to(self.target):p.read_bytes() for p in self.target.rglob('*') if p.is_file()}
            policy_module.install(f'{number:03d}-fixture',self.target,self.policy)
            self.assertEqual(before,{p.relative_to(self.target):p.read_bytes() for p in self.target.rglob('*') if p.is_file()})

    def test_rebuild_recipe_reads_central_patch_versions(self):
        self.policy['docker']['rebuilds']['tempo']['goDependencies']=['golang.org/x/net@v0.62.99']
        output = policy_module.recipe_text(self.policy,'tempo')
        self.assertIn('golang.org/x/net@v0.62.99',output)
        self.assertNotIn('@@',output)
        self.assertIn(self.policy['docker']['buildImages']['go'],output)


if __name__ == '__main__':unittest.main()
