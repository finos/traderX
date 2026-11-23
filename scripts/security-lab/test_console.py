import http.client
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from unittest.mock import patch

import console


class ConsoleApiTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.server = console.ThreadingHTTPServer(('127.0.0.1', 0), console.Handler)
        self.server.runner = console.Runner(self.temp.name)
        self.port = self.server.server_address[1]
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()
        self.temp.cleanup()

    def request(self, method, path, data=None, headers=None):
        conn = http.client.HTTPConnection('127.0.0.1', self.port, timeout=5)
        base = {'Content-Type': 'application/json', 'X-Lab-CSRF': self.server.runner.token}
        base.update(headers or {})
        conn.request(method, path, json.dumps(data) if data is not None else None, base)
        response = conn.getresponse()
        status, body, response_headers = response.status, response.read(), dict(response.getheaders())
        conn.close()
        return status, body, response_headers

    def test_host_origin_and_token_are_enforced(self):
        for headers in [{'Host': 'untrusted.example'}, {'Origin': 'https://untrusted.example'}, {'X-Lab-CSRF': 'wrong'}]:
            self.assertEqual(self.request('POST', '/api/runs', {'scenario': 'platform'}, headers)[0], 403)
        self.assertEqual(self.request('GET', '/api/state', headers={'Host': 'untrusted.example'})[0], 403)

    def test_explicit_remote_origin_preserves_csrf_and_host_boundaries(self):
        self.server.public_origin = 'https://lab.example'
        headers = {'Host': 'lab.example', 'Origin': 'https://lab.example'}
        self.assertEqual(self.request('GET', '/api/state', headers=headers)[0], 200)
        with patch.object(self.server.runner, 'start', return_value={'id':'test'}) as start:
            self.assertEqual(self.request('POST', '/api/runs', {'scenario':'platform'}, headers)[0], 202)
            self.assertEqual(start.call_count, 1)
            for extra in [{'Origin':'https://evil.example'}, {'Origin':'http://lab.example'}, {'X-Lab-CSRF':'wrong'}, {'Host':'evil.example'}]:
                self.assertEqual(self.request('POST', '/api/runs', {'scenario':'platform'}, headers | extra)[0], 403)
            self.assertEqual(self.request('POST', '/api/runs', {'scenario':'platform'}, {'Host':'lab.example'})[0], 403)
            self.assertEqual(start.call_count, 1)
        self.assertEqual(self.request('GET', '/api/state', headers={'Host':'evil.example','X-Forwarded-Host':'lab.example'})[0], 403)

    def test_public_origin_rejects_ambiguous_configuration(self):
        import argparse
        for value in ['http://lab.example','https://lab.example/','https://u:p@lab.example','https://lab.example:443','https://lab.example?x=1']:
            with self.assertRaises(argparse.ArgumentTypeError):console.public_origin(value)

    def test_arbitrary_commands_targets_and_bad_json_are_rejected(self):
        for payload in [{'scenario': 'shell'}, {'scenario': 'platform', 'command': 'echo bad'},
                        {'scenario': 'platform', 'target': 'remote'}, {'scenario': []}, []]:
            self.assertEqual(self.request('POST', '/api/runs', payload)[0], 400)
        self.assertEqual(self.request('POST', '/api/runs', {'scenario': 'platform'}, {'Content-Type': 'text/plain'})[0], 415)

    def test_no_arbitrary_files_or_runs_are_exposed(self):
        for path in ['/../baseline.lock.json', '/api/runs/../evidence', '/kubeconfig', '/reference.json']:
            self.assertEqual(self.request('GET', path)[0], 404)

    def test_asset_and_state_have_security_headers(self):
        status, body, headers = self.request('GET', '/api/state')
        self.assertEqual(status, 200)
        self.assertEqual({s['id'] for s in json.loads(body)['scenarios']}, {'platform','waf','baseline','workloads','support','database','collector','observability','sql','nats'})
        self.assertIn("frame-ancestors 'none'", headers['Content-Security-Policy'])
        self.assertEqual(headers['Cache-Control'], 'no-store')
        self.assertNotIn('Access-Control-Allow-Origin', headers)


class RunnerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.runner = console.Runner(self.temp.name)
        self.capacity = patch.object(console, 'check_resources', return_value={'status':'ready','reasons':[]})
        self.capacity.start()
        self.addCleanup(self.capacity.stop)

    def tearDown(self):
        deadline = time.monotonic() + 4
        while self.runner.active and time.monotonic() < deadline:
            time.sleep(.02)
        self.temp.cleanup()

    def wait(self, run):
        deadline = time.monotonic() + 4
        while self.runner.active and time.monotonic() < deadline:
            time.sleep(.02)
        self.assertIsNone(self.runner.active)
        return self.runner.read(run['id'], download=True)

    def test_success_evidence_and_concurrent_refusal(self):
        with patch.object(self.runner, 'command', return_value=[sys.executable, '-c', 'import time; time.sleep(.2); print("verified fixture")']):
            run = self.runner.start('baseline')
            with self.assertRaises(BlockingIOError):
                self.runner.start('platform')
            result = self.wait(run)
        self.assertEqual(result['run']['status'], 'passed')
        self.assertIn('verified fixture', result['log'])
        self.assertEqual(len(result['log_sha256']), 64)
        self.assertTrue(result['run']['source_hashes'])

    def test_nonzero_exit_is_failure(self):
        with patch.object(self.runner, 'command', return_value=[sys.executable, '-c', 'raise SystemExit(2)']):
            result = self.wait(self.runner.start('baseline'))
        self.assertEqual(result['run']['status'], 'failed')
        self.assertEqual(result['run']['exit_code'], 2)

    def test_timeout_is_inconclusive(self):
        with patch.object(console, 'RUN_TIMEOUT', .05), patch.object(self.runner, 'command', return_value=[sys.executable, '-c', 'import time; time.sleep(2)']):
            result = self.wait(self.runner.start('baseline'))
        self.assertEqual(result['run']['status'], 'inconclusive')

    def test_restart_marks_interrupted_run_inconclusive(self):
        import uuid
        folder = self.runner.runs / str(uuid.uuid4())
        folder.mkdir()
        self.runner.save(folder, {'id': folder.name, 'status': 'running', 'started_at': console.now()})
        resumed = console.Runner(self.temp.name)
        self.assertEqual(resumed.read(folder.name)['run']['status'], 'inconclusive')

    def test_blocked_preflight_never_constructs_or_launches_command(self):
        with patch.object(console, 'check_resources', return_value={'status':'blocked','reasons':['Low memory']}), patch.object(self.runner, 'command') as command:
            result = self.wait(self.runner.start('waf'))
        self.assertEqual(result['run']['status'], 'blocked')
        self.assertEqual(result['run']['mode'], 'build')
        self.assertNotIn('exit_code', result['run'])
        command.assert_not_called()
        self.assertIn('Low memory', result['run']['error'])
