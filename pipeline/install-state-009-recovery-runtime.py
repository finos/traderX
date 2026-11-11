#!/usr/bin/env python3
"""Install the reproducible state-009 recovery runtime from canonical inputs."""
from pathlib import Path
import re
import shutil
import sys

root = Path(__file__).resolve().parents[1]
target = Path(sys.argv[1])
state = target / 'order-management-matcher'
compose = state / 'docker-compose.yml'
text = compose.read_text().replace("  # Keep the service name so existing Compose/dashboard labels remain compatible.\n  # Vector replaces the retired Promtail implementation.\n", "")
for service, recipe in [('database', 'postgres'), ('blackbox-exporter', 'blackbox-exporter'),
                        ('prometheus', 'prometheus'), ('loki', 'loki'), ('tempo', 'tempo')]:
    dest = target / 'database' if service == 'database' else state / 'runtime-images' / service
    dest.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(root / 'templates/runtime-image-rebuilds' / recipe / 'Dockerfile', dest / 'Dockerfile.compose')
    context = '../database' if service == 'database' else './runtime-images/' + service
    pattern = rf'(  {re.escape(service)}:\n)    image: [^\n]+\n(?:    build:\n      context: [^\n]+\n      dockerfile: Dockerfile.compose\n)?'
    replacement = rf'\g<1>    image: traderx-remediation/{recipe}:009\n    build:\n      context: {context}\n      dockerfile: Dockerfile.compose\n'
    text, count = re.subn(pattern, replacement, text)
    if count != 1:
        raise ValueError(f'expected one {service} image definition')
text = re.sub(r'(  otel-collector:\n    image:) [^\n]+', r'\1 otel/opentelemetry-collector-contrib:0.165.0@sha256:e40d61f10c9a617cca1ffd1be4d7e2b3a4b0f0001798ff07e58cabe82e618cea', text)
text = re.sub(r'(  grafana:\n    image:) [^\n]+', r'\1 grafana/grafana:12.4.15@sha256:2894082f6cf7081aefdc1389265c04000812309208c190d75e8c65f7a30e4b7e', text)
text = re.sub(r'  promtail:\n.*?(?=\n  tempo:)', '''  promtail:
    image: timberio/vector:0.61.0-alpine@sha256:3bb7ed5152910ed51729e256937b1d8a4bf67ff624e9d565e8e5877bffd015c7
    command: ["--config", "/etc/vector/vector.toml"]
    volumes:
      - ./observability/vector/vector.toml:/etc/vector/vector.toml:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
    depends_on:
      - loki
''', text, flags=re.S)
compose.write_text(text)
collector = state / 'observability/otel-collector/config.yaml'
collector.write_text(collector.read_text().replace('logging:', 'debug:').replace(', logging]', ', debug]'))
vector = state / 'observability/vector/vector.toml'
vector.parent.mkdir(exist_ok=True)
vector.write_text('''data_dir = "/tmp/vector"
[sources.docker]
type = "docker_logs"
docker_host = "unix:///var/run/docker.sock"

[transforms.labels]
type = "remap"
inputs = ["docker"]
source = \'\'\'
.service = .label."com.docker.compose.service" ?? "unknown"
.compose_project = .label."com.docker.compose.project" ?? "unknown"
.container = .container_name
\'\'\'

[sinks.loki]
type = "loki"
inputs = ["labels"]
endpoint = "http://loki:3100"
encoding.codec = "text"
[sinks.loki.labels]
job = "traderx-docker"
service = "{{ service }}"
compose_project = "{{ compose_project }}"
container = "{{ container }}"
''')
print('[ok] installed state-009 recovery runtime')
