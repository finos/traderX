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
    def exercise(self, *, project='recovery-test', still_writing=False, tar_fails=False, free=10**10, symlink=False, nested_mount=False, host_mount=False):
        record = {'state': '009-order-management-matcher', 'snapshot': 'c' * 40}
        commands = []
        checks = 0
        def run(*args, **kwargs):
            nonlocal checks
            commands.append(args)
            output = ''
            if args[:3] == ('docker', 'volume', 'inspect'):
                output = json.dumps([{'Name': 'recovery-test_postgres_state_009_data', 'Mountpoint': '/test-volume'}])
            elif args[:3] == ('sudo', '-n', 'cat'):
                output = ('1 0 0:1 / /test-volume/pg_wal rw - tmpfs tmpfs rw\n' if host_mount else '') if args[-1] == '/proc/self/mountinfo' else '16\n'
            elif args[:3] == ('sudo', '-n', 'find'): output = '/test-volume/pg_wal' if symlink else ''
            elif args[:3] == ('sudo', '-n', 'du'): output = '1024 /test-volume'
            elif args[:3] == ('docker', 'ps', '-q'):
                if args[-1].startswith('volume='):
                    checks += 1
                    output = DB if checks == 1 or still_writing else ''
                else: output = DB + '\n' + APP
            elif args[:2] == ('docker', 'inspect'):
                output = json.dumps([{'Mounts': [{'Name': 'recovery-test_postgres_state_009_data', 'Destination': '/data'}] + ([{'Destination': '/data/pg_wal'}] if nested_mount else []), 'Config': {'Labels': {'com.docker.compose.project': project, 'com.docker.compose.service': 'database'}}}])
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
        self.assertIn(('docker','start',APP), commands)
        self.assertNotIn('database_backup', record)

    def test_backup_failure_restores_project(self):
        record, commands, error = self.exercise(tar_fails=True)
        self.assertIsInstance(error, subprocess.CalledProcessError)
        self.assertIn(('docker','start',DB,APP), commands)
        self.assertNotIn('database_backup', record)

    def test_external_data_layout_is_rejected_before_downtime(self):
        for option in ('symlink', 'nested_mount', 'host_mount'):
            with self.subTest(option=option):
                record, commands, error = self.exercise(**{option: True})
                self.assertIsInstance(error, ValueError)
                self.assertFalse(any(c[:2] == ('docker', 'stop') for c in commands))
                self.assertNotIn('database_backup', record)

    def test_partial_replacement_resumes_only_unique_unchanged_stopped_services(self):
        def container(cid, service, running=False):
            return {'Id': cid * (64 // len(cid)) + cid[:64 % len(cid)], 'State': {'Running': running},
                    'Config': {'Labels': {'com.docker.compose.project': 'recovery-test',
                                          'com.docker.compose.service': service}}}
        old_db = container('a', 'database')
        old_app = container('b', 'application')
        new_db = container('c', 'database', True)
        running = container('d', 'running-service', True)
        replaced = container('e', 'replaced-service')
        commands = []
        def run(*args, **kwargs):
            commands.append(args)
            output = ' '.join(x['Id'] for x in containers) if args[:3] == ('docker', 'ps', '-aq') else json.dumps(containers)
            return subprocess.CompletedProcess(args, 0, output, '')
        containers = [old_db, new_db, old_app, running, replaced]
        with patch.object(deploy, 'run', side_effect=run):
            deploy.resume_unchanged_containers('recovery-test', [DB, APP, 'd'*12, 'f'*12])
        self.assertEqual([c for c in commands if c[:2] == ('docker', 'start')],
                         [('docker', 'start', old_app['Id'])])
        # A second recovery attempt must not restart the already resumed app.
        old_app['State']['Running'] = True
        commands.clear()
        with patch.object(deploy, 'run', side_effect=run):
            deploy.resume_unchanged_containers('recovery-test', [DB, APP])
        self.assertFalse(any(c[:2] == ('docker', 'start') for c in commands))

    def test_startup_recovery_refuses_database_when_foreign_volume_writer_exists(self):
        old = {'Id': 'a'*64, 'State': {'Running': False},
               'Config': {'Labels': {'com.docker.compose.project': 'recovery-test',
                                     'com.docker.compose.service': 'database'}}}
        commands = []
        def run(*args, **kwargs):
            commands.append(args)
            if args[:2] == ('docker', 'inspect'):
                output = json.dumps([old])
            elif args[:3] == ('docker', 'ps', '-aq'):
                output = DB
            else:
                output = 'c'*12  # Writer outside this Compose project.
            return subprocess.CompletedProcess(args, 0, output, '')
        with patch.object(deploy, 'run', side_effect=run):
            deploy.resume_unchanged_containers('recovery-test', [DB])
        self.assertFalse(any(c[:2] == ('docker', 'start') for c in commands))

if __name__ == '__main__': unittest.main()
