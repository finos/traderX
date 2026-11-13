#!/usr/bin/env python3
"""Verify that host diagnostics export only allowlisted metadata."""
import importlib.util
import json
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    'diagnostics', Path(__file__).resolve().parents[1] / 'pipeline/diagnose-demo-history.py')
diagnostics = importlib.util.module_from_spec(spec)
spec.loader.exec_module(diagnostics)


class DiagnosticTests(unittest.TestCase):
    def test_container_events_and_kernel_logs_never_export_raw_data(self):
        labels = {'com.docker.compose.project': 'traderx-004-containerized-compose-runtime',
                  'com.docker.compose.service': 'trade-service', 'secret': 'private-marker'}
        item = {'Config': {'Labels': labels, 'Env': ['TOKEN=private-marker']},
                'State': {'Status': 'running', 'ExitCode': 0, 'OOMKilled': False},
                'RestartCount': 3, 'Mounts': [{'Source': 'private-marker'}]}
        event = {'Type': 'container', 'Action': 'oom', 'time': 1000000000,
                 'Actor': {'Attributes': labels}, 'secret': 'private-marker'}
        journal = {'MESSAGE': 'oom-kill private-marker', '__REALTIME_TIMESTAMP': '1000000000000000'}

        def fake_command(*args):
            if args[:2] == ('docker', 'ps'):
                return 'abc', None
            if args[:2] == ('docker', 'inspect'):
                return json.dumps([item]), None
            if args[:2] == ('docker', 'events'):
                return json.dumps(event), None
            return json.dumps(journal), None

        with patch.object(diagnostics, 'command', side_effect=fake_command):
            report = {'runtime': diagnostics.container_summary(), 'events': diagnostics.docker_events(),
                      'oom': diagnostics.kernel_oom()}
        self.assertNotIn('private-marker', json.dumps(report))
        self.assertEqual(report['runtime']['containers'][0]['restart_count'], 3)
        self.assertEqual(report['events']['events'][0]['event'], 'oom')
        self.assertEqual(report['oom']['matching_entries'], 1)

    def test_command_failures_do_not_export_error_output(self):
        with patch.object(diagnostics, 'command', return_value=(None, 'command_failed')):
            self.assertEqual(diagnostics.kernel_oom(), {'error': 'command_failed'})
            self.assertEqual(diagnostics.docker_events(), {'error': 'command_failed'})

    def test_service_history_discards_messages(self):
        entry = {'_SYSTEMD_UNIT': 'crond.service', 'PRIORITY': '3',
                 '__REALTIME_TIMESTAMP': '1000000000000000', 'MESSAGE': 'private-marker'}
        with patch.object(diagnostics, 'command', return_value=(json.dumps(entry), None)):
            report = diagnostics.service_journal()
        self.assertNotIn('private-marker', json.dumps(report))
        self.assertEqual(report['units']['crond.service']['entries'], 1)
        self.assertEqual(len(report['units']['crond.service']['warning_or_error_timestamps']), 1)


if __name__ == '__main__':
    unittest.main()
