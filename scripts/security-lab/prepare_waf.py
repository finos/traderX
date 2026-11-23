#!/usr/bin/env python3
"""Build the local WAF fixture from pinned Envoy and a hash-verified Coraza release."""
import argparse
from resource_operation import operation
import hashlib
import json
from pathlib import Path
import subprocess
import urllib.request
import zipfile

import lab


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime-dir', type=Path, required=True)
    args = parser.parse_args()
    root = args.runtime_dir.resolve()
    root.mkdir(parents=True, exist_ok=True)
    with operation(root, 'build'):
        build = root / 'waf-build'
        build.mkdir(exist_ok=True)
        lock = lab.read_json(lab.PROFILE / 'waf-images.lock.json')
        archive = root / 'coraza.zip'
        version = lock['coraza_release']
        if not archive.exists():
            url = f'https://github.com/corazawaf/coraza-proxy-wasm/releases/download/{version}/coraza-proxy-wasm-{version}.zip'
            with urllib.request.urlopen(url, timeout=30) as response:
                archive.write_bytes(response.read())
        if hashlib.sha256(archive.read_bytes()).hexdigest() != lock['coraza_zip_sha256']:
            raise ValueError('Coraza release archive hash mismatch')
        with zipfile.ZipFile(archive) as zipped:
            wasm = zipped.read('coraza-proxy-wasm.wasm')
        if hashlib.sha256(wasm).hexdigest() != lock['wasm_sha256']:
            raise ValueError('Coraza WASM hash mismatch')
        (build / 'coraza.wasm').write_bytes(wasm)
        (build / 'Dockerfile').write_text('FROM ' + lock['envoy']['image'] + '\nCOPY coraza.wasm /etc/envoy/coraza.wasm\n')
        (root / 'waf-images.lock.json').write_text(json.dumps(lock, indent=2) + '\n')
        subprocess.run(['docker', '--config', str(root / 'docker-client'), '--host',
            'unix://' + str(Path.home() / '.docker/run/docker.sock'), 'build', '--platform', 'linux/arm64',
            '-t', 'traderx-security-waf:coraza-0.6.0-envoy-1.40.2', str(build)], check=True, timeout=180)


if __name__ == '__main__':
    main()
