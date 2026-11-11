#!/usr/bin/env python3
"""Regression coverage for scoped quiescence and fail-closed physical backups."""
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('deploy', Path(__file__).resolve().parents[1] / 'pipeline/deploy-verified-snapshot.py')
deploy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(deploy)
DB, APP = 'a' * 12, 'b' * 12

class RecoveryTests(unittest.TestCase):
    def exercise(self, *, project='recovery-test', still_writing=False, tar_fails=False, free=10**10):
        record = {'state': '009-order-management-matcher', 'snapshot': 'c' * 40}
        commands = []
        checks = 0
        def run(*args, **kwargs):
            nonlocal checks
            commands.append(args)
            output = ''
            if args[:3] == ('docker', 'volume', 'inspect'):
                output = json.dumps([{'Name': 'recovery-test_postgres_state_009_data', 'Mountpoint': '/test-volume'}])
            elif args[:3] == ('sudo', '-n', 'cat'): output = '16\n'
            elif args[:3] == ('sudo', '-n', 'du'): output = '1024 /test-volume'
            elif args[:3] == ('docker', 'ps', '-q'):
                if args[-1].startswith('volume='):
                    checks += 1
                    output = DB if checks == 1 or still_writing else ''
                else: output = DB + '\n' + APP
            elif args[:2] == ('docker', 'inspect'):
                output = json.dumps([{'Config': {'Labels': {'com.docker.compose.project': project, 'com.docker.compose.service': 'database'}}}])
            elif args[:3] == ('sudo', '-n', 'tar'):
                if tar_fails: raise subprocess.CalledProcessError(2, args)
                Path(args[5]).write_bytes(b'private fixture backup')
            elif args[:2] == ('tar', '-tzf'): output = './PG_VERSION\n'
            return subprocess.CompletedProcess(args, 0, output, '')
        with tempfile.TemporaryDirectory() as tmp, patch.object(deploy, 'run', side_effect=run), patch.object(deploy.shutil, 'disk_usage') as usage:
            usage.return_value.free = free
            error = None
            try: deploy.backup_state009_database(record, 'recovery-test', Path(tmp))
            except (ValueError, subprocess.CalledProcessError) as exc: error = exc
            if not error:
                self.assertEqual(Path(record['database_backup']['path']).stat().st_mode & 0o777, 0o600)
        return record, commands, error

    def test_quiesces_only_project_before_copy_and_records_private_backup(self):
        record, commands, error = self.exercise()
        self.assertIsNone(error)
        stop = ('docker', 'stop', '--time', '60', DB, APP)
        self.assertIn(stop, commands)
        self.assertLess(commands.index(stop), next(i for i,c in enumerate(commands) if c[:3] == ('sudo','-n','tar')))
        self.assertEqual(record['database_backup']['method'], 'quiesced-physical')
        self.assertEqual(len(record['database_backup']['sha256']), 64)
        self.assertFalse(any(c[:2] == ('docker','start') for c in commands))

    def test_foreign_writer_is_never_stopped(self):
        record, commands, error = self.exercise(project='another-project')
        self.assertIsInstance(error, ValueError)
        self.assertFalse(any(c[:2] == ('docker','stop') for c in commands))
        self.assertNotIn('database_backup', record)

    def test_disk_capacity_is_checked_before_downtime(self):
        _, commands, error = self.exercise(free=0)
        self.assertIsInstance(error, ValueError)
        self.assertFalse(any(c[:2] == ('docker','stop') for c in commands))

    def test_live_writer_blocks_copy_and_restores_project(self):
        record, commands, error = self.exercise(still_writing=True)
        self.assertIsInstance(error, ValueError)
        self.assertFalse(any(c[:3] == ('sudo','-n','tar') for c in commands))
        self.assertIn(('docker','start',DB,APP), commands)
        self.assertNotIn('database_backup', record)

    def test_backup_failure_restores_project(self):
        record, commands, error = self.exercise(tar_fails=True)
        self.assertIsInstance(error, subprocess.CalledProcessError)
        self.assertIn(('docker','start',DB,APP), commands)
        self.assertNotIn('database_backup', record)

if __name__ == '__main__': unittest.main()
