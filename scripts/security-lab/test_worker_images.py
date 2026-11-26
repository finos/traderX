import copy
import json
from pathlib import Path
import subprocess
import tempfile
from types import SimpleNamespace as NS
import unittest
from unittest.mock import Mock, patch

import verify_worker_images as campaign


def result(stdout='', returncode=0):
    return subprocess.CompletedProcess([], returncode, stdout, '')


class WorkerImageTests(unittest.TestCase):
    def setUp(self):
        self.fixture = {'database': {'host': 'database'},
            'broker': {'endpoint': 'tls://nats-broker:4222', 'passwords': {'publisher': 'secret-p', 'consumer-a': 'secret-c'}}}
        self.passwords = {'event_publisher': 'db-p', 'event_consumer_a': 'db-c'}

    def test_role_configs_use_verified_tls_exact_scoped_identities_and_materialized_trust(self):
        publisher = campaign.worker_config('event-publisher', self.fixture, self.passwords)
        consumer = campaign.worker_config('event-consumer', self.fixture, self.passwords)
        self.assertEqual(publisher['mode'], 'publisher')
        self.assertEqual(consumer['mode'], 'reference-consumer')
        self.assertEqual(consumer['database_user'], 'event_consumer_a')
        self.assertEqual((consumer['account_id'], consumer['durable']), (22214, 'ACCOUNT_A'))
        for config in (publisher, consumer):
            self.assertEqual(config['database_transport'], 'verify-full')
            self.assertEqual(config['database_host'], 'database')
            self.assertEqual(config['database_ca'], '/run/private/config/database-ca.pem')
            self.assertEqual(config['broker_ca'], '/run/private/config/broker-ca.pem')
            self.assertEqual(config['batch_size'], 1)

    def test_negative_cases_change_exactly_one_transport_input_and_preserve_source(self):
        original = campaign.worker_config('event-publisher', self.fixture, self.passwords)
        saved = copy.deepcopy(original)
        trusted = {'database-ca.pem': b'db-ca', 'broker-ca.pem': b'broker-ca'}
        for kind in campaign.NEGATIVES:
            config, certs = campaign.negative_config(original, kind, trusted, b'untrusted')
            changes = sum(config[key] != original[key] for key in original)
            changes += sum(certs[key] != trusted[key] for key in trusted)
            self.assertEqual(changes, 1, kind)
            self.assertEqual(config['database_transport'], 'verify-full')
            self.assertEqual(set(config), set(original))
        self.assertEqual(original, saved)
        self.assertEqual(trusted['database-ca.pem'], b'db-ca')
        with self.assertRaises(ValueError):
            campaign.negative_config(original, 'unapproved', trusted, b'untrusted')

    def test_log_and_failure_evidence_never_copies_raw_private_values(self):
        raw = '\n'.join(['secret-sentinel', '{broken', json.dumps({'status': 'starting', 'secret': 'sentinel'}),
                         json.dumps({'status': 'terminal'}), json.dumps({'status': 'private-sentinel'})])
        self.assertEqual(campaign.statuses(raw), ['starting', 'terminal'])
        for error in (RuntimeError('secret-sentinel'), campaign.Failure('secret-sentinel')):
            evidence = campaign.failure(error)
            self.assertNotIn('secret-sentinel', json.dumps(evidence))
            self.assertEqual(evidence['error'], 'worker_image_campaign_failed')
        self.assertEqual(campaign.failure(campaign.Failure('worker_oom_result'))['error'], 'worker_oom_result')

    def postcommit(self):
        initial = NS(ack_floor=NS(consumer_seq=0, stream_seq=0))
        info = NS(num_ack_pending=1, ack_floor=NS(consumer_seq=0, stream_seq=0), delivered=NS(stream_seq=2))
        delivered = NS(data=b'{"eventId":"synthetic:trade"}', subject='/accounts/22214/trades')
        return [True, (1, 1, 0), initial, info, delivered, 'synthetic']

    def test_postcommit_proof_requires_exact_event_commit_ack_floor_and_running_worker(self):
        self.assertTrue(campaign.postcommit_visible(*self.postcommit()))
        variants = []
        args = self.postcommit(); args[0] = False; variants.append(args)
        args = self.postcommit(); args[1] = (0, 0, 0); variants.append(args)
        args = self.postcommit(); args[3].num_ack_pending = 0; variants.append(args)
        args = self.postcommit(); args[3].ack_floor.consumer_seq = 1; variants.append(args)
        args = self.postcommit(); args[3].ack_floor.stream_seq = 1; variants.append(args)
        args = self.postcommit(); args[4].data = b'{"eventId":"other:trade"}'; variants.append(args)
        args = self.postcommit(); args[4].subject = '/accounts/62654/trades'; variants.append(args)
        for args in variants:
            self.assertFalse(campaign.postcommit_visible(*args))

    def worker(self, docker):
        instance = object.__new__(campaign.WorkerImage)
        instance.docker, instance.name = docker, 'owned'
        instance.all_secrets = ['private-sentinel']
        return instance

    def test_kill_requires_running_actual_exit137_and_no_oom(self):
        for running, code, oom, passes in ((True, '137', False, True), (False, '137', False, False),
                                          (True, '2', False, False), (True, '137', True, False)):
            docker = Mock(side_effect=lambda *args, **kw: result(json.dumps([{'State': {'Running': running, 'OOMKilled': oom}}]))
                          if args[0] == 'inspect' else result(code if args[0] == 'wait' else ''))
            worker = self.worker(docker)
            if passes:
                worker.signal('SIGKILL', 137)
                self.assertIn(('kill', '--signal', 'SIGKILL', 'owned'), [call.args for call in docker.call_args_list])
            else:
                with self.assertRaises(campaign.Failure): worker.signal('SIGKILL', 137)

    def test_secret_log_detection_prevents_success(self):
        worker = self.worker(Mock(return_value=result('private-sentinel')))
        with self.assertRaisesRegex(campaign.Failure, '^worker_output_secret$'): worker.logs()

    def test_every_restart_revalidates_immutable_identity_and_owned_cleanup_on_failure(self):
        digest = 'sha256:' + 'a' * 64
        metadata = {'Image': digest, 'Config': {'Image': digest},
                    'State': {'Running': True, 'ExitCode': 0, 'OOMKilled': False}}
        def docker(*args, **kwargs):
            if args[:2] == ('inspect', '--format'): return result('owner\n')
            if args[0] == 'inspect': return result(json.dumps([metadata]))
            return result()
        cli = Mock(side_effect=docker)
        worker = self.worker(cli)
        worker.image = worker.config_digest = digest
        worker.fixture = {'owner': 'owner', 'network': 'network'}
        worker.target, worker.started, worker.role = Path('/projected'), False, 'event-publisher'
        with self.assertRaisesRegex(ValueError, 'intentional'):
            with worker.run(): raise ValueError('intentional')
        self.assertIn(('rm', '-f', 'owned'), [call.args for call in cli.call_args_list])
        self.assertEqual(cli.call_args_list[0].args[-1], digest)
        campaign.DIAGNOSTIC.clear()
        metadata['Config']['Image'] = 'mutable:tag'
        with self.assertRaisesRegex(campaign.Failure, '^worker_image_changed$'):
            with worker.run(): self.fail('Unverified image entered campaign')
        campaign.DIAGNOSTIC.clear()

    def test_projection_materializes_only_known_ca_and_private_config_files(self):
        with tempfile.TemporaryDirectory() as temp, patch.object(campaign.subprocess, 'run', return_value=result()) as run:
            root = Path(temp)
            path = campaign.projection(root, 'worker', {'mode': 'publisher'},
                {'database-ca.pem': b'database', 'broker-ca.pem': b'broker'})
            self.assertEqual({p.name for p in path.iterdir()}, {'config.json', 'database-ca.pem', 'broker-ca.pem'})
            self.assertTrue(all(p.stat().st_mode & 0o777 == 0o440 for p in path.iterdir()))
            self.assertEqual(run.call_count, 2)
            self.assertIn('0:10001', run.call_args.args[0])
            with self.assertRaises(ValueError): campaign.projection(root, 'bad', {}, {'unexpected': b'secret'})


if __name__ == '__main__':
    unittest.main()
