#!/usr/bin/env python3
"""Resolve snapshot images and render an isolated reference deployment; never apply it."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import urllib.error
import urllib.parse
import urllib.request

import yaml
import lab

ACCEPT = ', '.join(['application/vnd.oci.image.index.v1+json',
    'application/vnd.docker.distribution.manifest.list.v2+json',
    'application/vnd.oci.image.manifest.v1+json',
    'application/vnd.docker.distribution.manifest.v2+json'])


def parse_image(image):
    first, _, rest = image.partition('/')
    if rest and ('.' in first or ':' in first or first == 'localhost'):
        registry, path = first, rest
        if registry == 'docker.io':
            registry = 'registry-1.docker.io'
            if '/' not in path:
                path = 'library/' + path
    else:
        registry, path = 'registry-1.docker.io', image
        if '/' not in path:
            path = 'library/' + path
    if '@' in path:
        repo, ref = path.split('@', 1)
        repo = repo.split(':', 1)[0]
    else:
        repo, _, ref = path.rpartition(':')
        if not repo:
            repo, ref = path, 'latest'
    return registry, repo, ref


def resolve_image(image, architecture):
    registry, repo, ref = parse_image(image)
    headers = {'Accept': ACCEPT}

    def fetch(ref, resource='manifests'):
        url = f'https://{registry}/v2/{repo}/{resource}/{ref}'
        try:
            response = urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=30)
        except urllib.error.HTTPError as error:
            if error.code != 401:
                raise
            auth = dict(re.findall(r'(\w+)="([^"]+)"', error.headers['WWW-Authenticate']))
            token_url = auth['realm'] + '?' + urllib.parse.urlencode({
                'service': auth.get('service', registry), 'scope': f'repository:{repo}:pull'})
            with urllib.request.urlopen(token_url, timeout=30) as token_response:
                token = json.load(token_response)
            headers['Authorization'] = 'Bearer ' + (token.get('token') or token['access_token'])
            response = urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=30)
        with response:
            raw = response.read()
            digest = 'sha256:' + hashlib.sha256(raw).hexdigest()
            if response.headers.get('Docker-Content-Digest', digest) != digest:
                raise ValueError('Registry digest mismatch')
            if ref.startswith('sha256:') and ref != digest:
                raise ValueError('Requested digest mismatch')
            return json.loads(raw), digest

    manifest, index_digest = fetch(ref)
    digest = index_digest
    if 'manifests' in manifest:
        candidates = [m for m in manifest['manifests']
                      if m.get('platform', {}).get('os') == 'linux'
                      and m['platform'].get('architecture') == architecture]
        if len(candidates) != 1:
            raise ValueError(f'Expected exactly one linux/{architecture} manifest for {image}')
        manifest, digest = fetch(candidates[0]['digest'])
    config, _ = fetch(manifest['config']['digest'], 'blobs')
    if config.get('architecture') != architecture or config.get('os') != 'linux':
        raise ValueError(f'Image config platform mismatch for {image}')
    public_registry = 'docker.io' if registry == 'registry-1.docker.io' else registry
    return {'source': image, 'index_digest': index_digest, 'digest': digest,
            'platform': f'linux/{architecture}', 'image': f'{public_registry}/{repo}@{digest}'}


def validate_pin(original, entry, baseline):
    """Reject inconsistent digest/platform metadata before emitting any manifest."""
    digest = entry.get('digest', '')
    if not re.fullmatch(r'sha256:[0-9a-f]{64}', digest):
        raise ValueError('Invalid image digest: ' + original)
    if not entry.get('image', '').endswith('@' + digest):
        raise ValueError('Image reference/digest mismatch: ' + original)
    pinned = baseline.get('image_digests', {}).get(original)
    if pinned and pinned != entry['image']:
        raise ValueError('Image differs from baseline pin: ' + original)


def render_reference(lock, image_lock, *, offline=False):
    """Compile the pinned snapshot. Offline mode never resolves registry tags."""
    sha = lock['generated_commit']
    if f"Source Commit: `{lock['canonical_source_commit']}`" not in lab.object_text(sha, 'README.md'):
        raise ValueError('Snapshot source mismatch')
    base = 'kubernetes-runtime/manifests/base/'
    resources = yaml.safe_load(lab.object_text(sha, base + 'kustomization.yaml'))['resources']
    docs = [yaml.safe_load(lab.object_text(sha, base + path)) for path in resources]
    plan = json.loads(lab.object_text(sha, 'kubernetes-runtime/build-plan.json'))
    published = {item['image']: ('ingress' if item['name'] == 'edge-proxy' else item['name'])
                 for item in plan['images']}
    if image_lock['generated_commit'] != sha:
        raise ValueError('Existing image lock belongs to another snapshot')
    for doc in docs:
        meta = doc['metadata']
        if doc['kind'] == 'Namespace':
            meta['name'] = 'traderx-security-lab'
        elif 'namespace' in meta:
            meta['namespace'] = 'traderx-security-lab'
        for subject in doc.get('subjects', []):
            if subject.get('namespace') == 'traderx':
                subject['namespace'] = 'traderx-security-lab'
        if doc['kind'] == 'ConfigMap' and meta['name'] == 'observability-promtail-config':
            # Vector's explicit namespace selector is embedded in TOML, not metadata.
            doc['data'] = {k: v.replace('metadata.namespace=traderx"',
                                        'metadata.namespace=traderx-security-lab"')
                           for k, v in doc['data'].items()}
        if doc['kind'] not in ['Deployment', 'DaemonSet']:
            continue
        pod = doc['spec']['template']['spec']
        for container in pod.get('containers', []) + pod.get('initContainers', []):
            for env in container.get('env', []):
                if env['name'] == 'CORS_ALLOWED_ORIGINS':
                    env['value'] = 'http://127.0.0.1:18080'
            original = container['image']
            component = published.get(original)
            source = f'ghcr.io/finos/traderx-c3/{component}:{sha}' if component else original
            arch = 'amd64' if component else 'arm64'
            if original not in image_lock['images']:
                if offline:
                    raise ValueError('Missing pinned image: ' + original)
                print(f'Resolving {meta["name"]}: {source} (linux/{arch})', flush=True)
                image_lock['images'][original] = resolve_image(source, arch)
            entry = image_lock['images'][original]
            if entry['source'] != source or entry['platform'] != f'linux/{arch}':
                raise ValueError('Existing image lock does not match expected source/platform')
            validate_pin(original, entry, lock)
            container['image'] = entry['image']
            container['imagePullPolicy'] = 'IfNotPresent'
    return {'apiVersion': 'v1', 'kind': 'List', 'items': docs}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--offline', action='store_true', help='Require every image pin; never contact a registry')
    args = parser.parse_args()
    out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=True)
    lock = lab.read_json(lab.PROFILE / 'baseline.lock.json')
    lock_path = out / 'images.lock.json'
    committed_lock = lab.PROFILE / 'runtime-images.lock.json'
    seed = lock_path if lock_path.exists() else committed_lock
    image_lock = json.loads(seed.read_text()) if seed.exists() else {'generated_commit': lock['generated_commit'], 'images': {}}
    manifest = render_reference(lock, image_lock, offline=args.offline)
    lock_path.write_text(json.dumps(image_lock, indent=2) + '\n')
    (out / 'reference.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(f"Rendered {len(manifest['items'])} resources. No cluster was modified.")


if __name__ == '__main__':
    main()
