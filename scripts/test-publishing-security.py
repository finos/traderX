#!/usr/bin/env python3
"""Offline regression tests for scanner deadlines and deployment authorization."""
import importlib.util
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


def module(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'pipeline' / (name + '.py'))
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


verify = module('verify-deployment-snapshot')
deploy = module('deploy-verified-snapshot')
SHA = 'a' * 40
DIGEST = 'sha256:' + 'b' * 64


class AuthorizationTests(unittest.TestCase):
    def run_record(self, **overrides):
        record = dict(id=10, run_attempt=2, head_sha=SHA, head_branch='code/generated-state-004',
                      event='push', path='.github/workflows/security.yml', status='completed',
                      conclusion='success')
        return record | overrides

    def select(self, runs):
        return verify.successful_run(runs, SHA, 'code/generated-state-004', 'security.yml')

    def test_statuses_fail_closed(self):
        for status, conclusion in [('queued', None), ('in_progress', None), ('completed', 'failure'),
                                   ('completed', 'cancelled'), ('completed', 'timed_out'),
                                   ('completed', 'skipped'), ('completed', 'neutral')]:
            with self.subTest(status=status, conclusion=conclusion), self.assertRaises(ValueError):
                self.select([self.run_record() | dict(status=status, conclusion=conclusion)])

    def test_snapshot_branch_workflow_and_event_matching(self):
        for update in [dict(head_sha='c' * 40), dict(head_branch='other'),
                       dict(path='.github/workflows/build-and-publish.yml'), dict(event='pull_request')]:
            with self.subTest(update=update), self.assertRaises(ValueError):
                self.select([self.run_record() | update])
        with self.assertRaises(ValueError):
            self.select([])

    def test_latest_failure_cannot_use_older_success(self):
        with self.assertRaises(ValueError):
            self.select([self.run_record(), self.run_record(id=11, conclusion='failure')])
        self.assertEqual(self.select([self.run_record()])['id'], 10)

    def test_missing_skipped_or_failed_jobs_rejected(self):
        good = dict(name='dependency', status='completed', conclusion='success')
        verify.successful_jobs([good], ['dependency'])
        for jobs in [[], [good | dict(name='build')], [good | dict(conclusion='skipped')],
                     [good | dict(conclusion='failure')]]:
            with self.assertRaises(ValueError):
                verify.successful_jobs(jobs, ['dependency'])

    def test_digest_bound_to_run_attempt_and_snapshot(self):
        image = 'ghcr.io/finos/traderx-c1/ingress'
        record = dict(snapshot=SHA, image=image, digest=DIGEST, run_id='10', run_attempt='2')
        self.assertEqual(verify.validate_image(record, SHA, image, self.run_record()), image + '@' + DIGEST)
        for update in [dict(snapshot='c' * 40), dict(digest='latest'), dict(run_attempt='1'),
                       dict(run_id='9'), dict(image='other')]:
            with self.assertRaises(ValueError):
                verify.validate_image(record | update, SHA, image, self.run_record())

    def test_verifier_end_to_end_blocks_failed_dependency_scan(self):
        import base64
        branch = 'code/generated-state-004-containerized-compose-runtime'
        image = 'ghcr.io/finos/traderx-c0/ingress'
        metadata = dict(stateId='004-containerized-compose-runtime', modules=dict(
            node=['svc'], dotnet=[], gradle=[], docker=[{'imageName': 'ingress'}]))
        jobs = {
            '1': ['Build and test snapshot'],
            '2': ['svc-node-scan', 'ingress-docker-scan'],
            '3': ['Build and push ingress'],
        }
        failed = False
        def api(*args):
            endpoint = args[-1]
            if '/commits/' in endpoint:
                return {'sha': SHA}
            if '/contents/' in endpoint:
                return {'content': base64.b64encode(json.dumps(metadata).encode()).decode()}
            if '/workflows/' in endpoint:
                workflow = endpoint.split('/workflows/')[1].split('/')[0]
                rid = {'build-and-test.yml': 1, 'security.yml': 2, 'build-and-publish.yml': 3}[workflow]
                record = self.run_record(id=rid, head_branch=branch, path='.github/workflows/' + workflow,
                                         html_url=f'https://example.test/{rid}')
                if failed and rid == 2:
                    record['conclusion'] = 'failure'
                return [{'workflow_runs': [record]}]
            rid = endpoint.split('/runs/')[1].split('/')[0]
            return [{'jobs': [dict(name=n, status='completed', conclusion='success') for n in jobs[rid]]}]
        def download(args, **kwargs):
            dest = Path(args[-1])
            dest.mkdir(parents=True)
            (dest / 'image.json').write_text(json.dumps(dict(snapshot=SHA, image=image, digest=DIGEST,
                                                            run_id='3', run_attempt='2')))
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / 'verified.json'
            argv = ['verify', '--snapshot', SHA, '--target', 'demo.traderx.finos.org', '--output', str(output)]
            with patch.object(sys, 'argv', argv), patch.object(verify, 'gh_json', side_effect=api), \
                 patch.object(verify.subprocess, 'run', side_effect=download):
                verify.main()
                self.assertEqual(json.loads(output.read_text())['images'], {image: image + '@' + DIGEST})
                output.unlink()
                failed = True
                with self.assertRaises(ValueError):
                    verify.main()
                self.assertFalse(output.exists())

    def test_compose_uses_verified_digest_and_removes_build(self):
        image = 'ghcr.io/finos/traderx-c1/ingress'
        result = deploy.pin_services({'services': {'ingress': {'image': image + ':' + SHA,
                                                              'build': {'context': '.'}}}},
                                     {image: image + '@' + DIGEST})
        self.assertEqual(result['services']['ingress'], {'image': image + '@' + DIGEST})
        with self.assertRaises(ValueError):
            deploy.pin_services({'services': {'unverified': {'build': { 'context': '.' }}}}, {})

    def test_success_records_deployed_snapshot(self):
        with tempfile.TemporaryDirectory() as tmp:
            work = Path(tmp)
            (work / '.git').mkdir()
            manifest = work / 'manifest.json'
            image = 'ghcr.io/finos/traderx-c1/ingress'
            manifest.write_text(json.dumps(dict(snapshot=SHA, state='004-test', target='demo.test',
                                                repository='finos/traderX', images={image: image + '@' + DIGEST})))
            config = {'services': {'ingress': {'image': image + ':' + SHA, 'build': {'context': '.'}}}}
            def fake_run(*args, **kwargs):
                return subprocess.CompletedProcess(args, 0, stdout=json.dumps(config))
            with patch.object(sys, 'argv', ['deploy', str(manifest), '--workdir', str(work)]), \
                 patch.object(deploy, 'run', side_effect=fake_run) as commands, \
                 patch.object(deploy.subprocess, 'check_output', return_value=SHA + '\n'):
                deploy.main()
            audit = json.loads((work / '.traderx-deploy/deployed.json').read_text())
            self.assertEqual(audit['snapshot'], SHA)
            self.assertEqual(audit['services']['ingress'], image + '@' + DIGEST)
            self.assertTrue(any('--no-build' in call.args and '--wait' in call.args for call in commands.call_args_list))


class ScannerTests(unittest.TestCase):
    def command(self, tmp, phase, program):
        return [sys.executable, str(ROOT / 'pipeline/bounded-security-command.py'), '--timeout', '1',
                '--phase', phase, '--result', str(Path(tmp) / 'result.json'), '--', sys.executable, '-c', program]

    def test_deadlines_for_acquisition_and_scan(self):
        for phase in ['acquisition', 'scan']:
            with tempfile.TemporaryDirectory() as tmp:
                start = time.monotonic()
                result = subprocess.run(self.command(tmp, phase, 'import time; time.sleep(60)'), capture_output=True)
                self.assertEqual(result.returncode, 124)
                self.assertLess(time.monotonic() - start, 3)
                self.assertEqual(json.loads((Path(tmp) / 'result.json').read_text())['status'], 'timeout')

    def test_results(self):
        for phase, rc, expected, status in [('scan', 0, 0, 'success'), ('scan', 1, 10, 'findings'),
                                             ('scan', 13, 20, 'infrastructure_failure'),
                                             ('acquisition', 1, 20, 'infrastructure_failure')]:
            with tempfile.TemporaryDirectory() as tmp:
                result = subprocess.run(self.command(tmp, phase, f'raise SystemExit({rc})'), capture_output=True)
                self.assertEqual(result.returncode, expected)
                self.assertEqual(json.loads((Path(tmp) / 'result.json').read_text())['status'], status)

    def test_cancellation_and_unrelated_process_survives(self):
        unrelated = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(60)'])
        try:
            with tempfile.TemporaryDirectory() as tmp:
                ready = Path(tmp) / 'ready'
                program = f'from pathlib import Path; import time; Path({str(ready)!r}).touch(); time.sleep(60)'
                proc = subprocess.Popen(self.command(tmp, 'scan', program), stdout=subprocess.DEVNULL)
                limit = time.monotonic() + 5
                while not ready.exists() and time.monotonic() < limit:
                    time.sleep(.02)
                proc.send_signal(signal.SIGTERM)
                self.assertEqual(proc.wait(timeout=3), 130)
                self.assertIsNone(unrelated.poll())
        finally:
            unrelated.kill()
            unrelated.wait()

    def test_timeout_kills_scanner_descendants(self):
        with tempfile.TemporaryDirectory() as tmp:
            pidfile = Path(tmp) / 'child.pid'
            program = ("import subprocess, sys, time; from pathlib import Path; "
                       "child = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(60)']); "
                       f"Path({str(pidfile)!r}).write_text(str(child.pid)); time.sleep(60)")
            result = subprocess.run(self.command(tmp, 'scan', program), capture_output=True)
            self.assertEqual(result.returncode, 124)
            child_pid = pidfile.read_text()
            time.sleep(.05)
            state = subprocess.run(['ps', '-o', 'stat=', '-p', child_pid], capture_output=True, text=True).stdout.strip()
            self.assertTrue(not state or state.startswith('Z'), state)

    def test_container_cleanup_is_scoped(self):
        bounded = module('bounded-security-command')
        with tempfile.TemporaryDirectory() as tmp:
            args = self.command(tmp, 'scan', 'raise SystemExit(0)')
            args[2:2] = ['--container', 'traderx-security-unique']
            with patch.object(sys, 'argv', args[1:]), patch.object(bounded.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, '', '')) as cleanup:
                self.assertEqual(bounded.main(), 0)
            self.assertEqual(cleanup.call_args.args[0], ['docker', 'rm', '-f', 'traderx-security-unique'])


if __name__ == '__main__':
    unittest.main()
