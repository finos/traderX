from contextlib import nullcontext
from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest
from unittest.mock import patch

import platform_setup as setup


class SetupTests(unittest.TestCase):
    def test_corrupt_chart_rejected_before_helm(self):
        with patch.object(setup.subprocess,'run') as run:
            with self.assertRaisesRegex(ValueError,'archive hash'):setup.expected(b'corrupt','helm')
            run.assert_not_called()

    def test_wrong_helm_rejected(self):
        lock={'cilium_artifacts':{'chart_sha256':setup.digest(b'chart'),'helm_version':'v3.17.3'}}
        with patch.object(setup,'pins',return_value=lock),patch.object(setup.subprocess,'run',return_value=SimpleNamespace(stdout='v0.0.0')):
            with self.assertRaisesRegex(ValueError,'Helm version'):setup.expected(b'chart','helm')

    def test_prepare_no_overwrite_and_atomic_failure(self):
        with tempfile.TemporaryDirectory() as tmp:
            out=Path(tmp)/'bundle';out.mkdir()
            with self.assertRaisesRegex(ValueError,'new output'):setup.prepare('unused','helm',out)
            chart=Path(tmp)/'chart';chart.write_bytes(b'bad')
            with self.assertRaises(ValueError):setup.prepare(chart,'helm',Path(tmp)/'new')
            self.assertFalse((Path(tmp)/'new').exists())

    def test_bundle_rejects_symlink_and_drift(self):
        files={n:b'expected' for n in ('cilium.tgz','cilium.yaml','kind.yaml','infrastructure.lock.json')}
        with tempfile.TemporaryDirectory() as tmp,patch.object(setup,'expected',return_value=files):
            root=Path(tmp)/'bundle';root.mkdir()
            for name,data in files.items():(root/name).write_bytes(data)
            setup.verify(root,'helm')
            (root/'kind.yaml').write_bytes(b'wrong')
            with self.assertRaisesRegex(ValueError,'drift'):setup.verify(root,'helm')
            (root/'kind.yaml').unlink();(root/'kind.yaml').symlink_to(root/'cilium.yaml')
            with self.assertRaisesRegex(ValueError,'contents'):setup.verify(root,'helm')

    def test_invalid_checkpoint_never_reaches_create(self):
        args=SimpleNamespace(checkpoint='bad')
        with patch.object(setup.checkpoint,'verify',side_effect=ValueError('drift')),patch.object(setup.subprocess,'run') as run:
            with self.assertRaises(ValueError):setup.create(args)
            run.assert_not_called()

    def test_existing_cluster_and_container_never_adopted(self):
        for existing in ('cluster','container'):
            with self.subTest(existing=existing),tempfile.TemporaryDirectory() as tmp:
                args=SimpleNamespace(checkpoint='ok',bundle='ok',helm='helm',runtime_dir=tmp)
                replies=[SimpleNamespace(stdout=setup.CLUSTER if existing=='cluster' else ''),SimpleNamespace(stdout=setup.NODE if existing=='container' else '')]
                with patch.object(setup.checkpoint,'verify'),patch.object(setup,'verify'),patch.object(setup.platform,'system',return_value='Darwin'),patch.object(setup.platform,'machine',return_value='arm64'),patch.object(setup,'operation_lock',return_value=nullcontext()),patch.object(setup,'require'),patch.object(setup.subprocess,'run',side_effect=replies) as run:
                    with self.assertRaisesRegex(ValueError,'no adoption'):setup.create(args)
                    self.assertEqual(run.call_count,2);self.assertFalse((Path(tmp)/'state019-kubernetes').exists())

    def test_failed_creation_retains_journal_without_delete(self):
        with tempfile.TemporaryDirectory() as tmp:
            args=SimpleNamespace(checkpoint='ok',bundle='ok',helm='helm',runtime_dir=tmp)
            with patch.object(setup.checkpoint,'verify'),patch.object(setup,'verify'),patch.object(setup.platform,'system',return_value='Darwin'),patch.object(setup.platform,'machine',return_value='arm64'),patch.object(setup,'operation_lock',return_value=nullcontext()),patch.object(setup,'require'),patch.object(setup.subprocess,'run',side_effect=[SimpleNamespace(stdout=''),SimpleNamespace(stdout=''),RuntimeError('private failure')]) as run:
                with self.assertRaisesRegex(RuntimeError,'retained cluster'):setup.create(args)
                self.assertEqual(run.call_count,3)
                text=(Path(tmp)/'state019-kubernetes/provisioning.json').read_text()
                self.assertIn('failed-inspect',text);self.assertNotIn('private failure',text)

    def test_plan_has_no_commands(self):
        with patch.object(setup.subprocess,'run') as run:
            self.assertEqual(setup.plan()['status'],'candidate-not-live-accepted');run.assert_not_called()

    def test_creation_sequence_records_identity_and_keeps_explicit_context(self):
        with tempfile.TemporaryDirectory() as tmp:
            args=SimpleNamespace(checkpoint='ok',bundle=tmp,helm='helm',runtime_dir=tmp)
            calls=[]
            def run(command,**kwargs):
                calls.append(command)
                self.assertIn('DOCKER_HOST',kwargs['env'])
                if command[:3]==['kind','create','cluster']:
                    self.assertIn('--retain',command)
                    self.assertEqual(command[command.index('--wait')+1],'0s')
                    Path(command[command.index('--kubeconfig')+1]).write_text('private kubeconfig')
                if 'df' in command:return SimpleNamespace(stdout='Filesystem 1024-blocks Used Available Capacity Mounted on\n/dev/vda1 20000000 1000000 19000000 5% /var\n')
                if 'kube-system' in command and 'namespace' in command:return SimpleNamespace(stdout='{"metadata":{"uid":"new-uid"}}')
                return SimpleNamespace(stdout='')
            with patch.object(setup.checkpoint,'verify'),patch.object(setup,'verify'),patch.object(setup.platform,'system',return_value='Darwin'),patch.object(setup.platform,'machine',return_value='arm64'),patch.object(setup,'operation_lock',return_value=nullcontext()),patch.object(setup,'require'),patch.object(setup.subprocess,'run',side_effect=run),patch.object(setup.lab,'read_json',return_value={'images':{'one':{'platform':'linux/arm64','image':'example@sha256:abc'}}}),patch.object(setup.credential_store,'create') as credentials:
                setup.create(args)
                credentials.assert_called_once_with(Path(tmp).resolve()/'state019-kubernetes/identities')
                self.assertEqual((Path(tmp)/'state019-kubernetes/cluster-uid').read_text(),'new-uid\n')
                for command in calls:
                    self.assertNotIn('delete',command)
                    if command[0]=='kubectl':
                        self.assertIn('--kubeconfig',command);self.assertIn(setup.CONTEXT,command)
                self.assertIn('prepared-needs-enforcement', (Path(tmp)/'state019-kubernetes/provisioning.json').read_text())
