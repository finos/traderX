import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import checkpoint
import prepare_runtime


class CheckpointTests(unittest.TestCase):
    def test_no_overwrite_and_exact_verification(self):
        files = {'reference.json': b'{}\n', 'checkpoint.json': b'{}\n'}
        with tempfile.TemporaryDirectory() as temp, patch.object(checkpoint, 'compile_checkpoint', return_value=files):
            output = Path(temp) / 'out'
            checkpoint.generate(output)
            checkpoint.verify(output)
            with self.assertRaisesRegex(ValueError, 'already exists'):
                checkpoint.generate(output)
            (output / 'reference.json').write_bytes(b'{"changed":true}\n')
            with self.assertRaisesRegex(ValueError, 'differs'):
                checkpoint.verify(output)
            (output / 'reference.json').write_bytes(files['reference.json'])
            (output / 'extra').write_bytes(b'')
            with self.assertRaisesRegex(ValueError, 'Unexpected'):
                checkpoint.verify(output)

    def test_symlink_is_not_a_verified_artifact(self):
        with tempfile.TemporaryDirectory() as temp, patch.object(checkpoint, 'compile_checkpoint', return_value={'a':b'one'}):
            out = Path(temp)/'out'
            checkpoint.generate(out)
            target = Path(temp)/'outside'; target.write_bytes(b'one')
            (out/'a').unlink(); (out/'a').symlink_to(target)
            with self.assertRaisesRegex(ValueError, 'differs'):
                checkpoint.verify(out)

    def test_compile_failure_leaves_no_output(self):
        with tempfile.TemporaryDirectory() as temp, patch.object(checkpoint, 'compile_checkpoint', side_effect=ValueError('missing pin')):
            out = Path(temp)/'out'
            with self.assertRaises(ValueError): checkpoint.generate(out)
            self.assertFalse(out.exists())

    def test_missing_snapshot_requires_explicit_fetch(self):
        with patch.object(checkpoint, 'baseline_available', return_value=False):
            with self.assertRaisesRegex(ValueError, 'fetch-baseline'):
                checkpoint.compile_checkpoint()


class OfflinePinTests(unittest.TestCase):
    def fixture(self):
        sha='a'*40; digest='sha256:'+'b'*64
        lock={'generated_commit':sha,'canonical_source_commit':'c'*40,'image_digests':{'example:v1':'example@'+digest}}
        images={'generated_commit':sha,'images':{'example:v1':{'source':'example:v1','platform':'linux/arm64','digest':digest,'image':'example@'+digest}}}
        docs={'README.md':'Source Commit: `'+lock['canonical_source_commit']+'`',
              'kubernetes-runtime/manifests/base/kustomization.yaml':'resources: [app.yaml]',
              'kubernetes-runtime/build-plan.json':'{"images":[]}',
              'kubernetes-runtime/manifests/base/app.yaml':json.dumps({'kind':'Deployment','metadata':{'name':'app','namespace':'traderx'},'spec':{'template':{'spec':{'containers':[{'image':'example:v1'}]}}}})}
        return lock,images,docs

    def test_offline_never_resolves_missing_images(self):
        lock,images,docs=self.fixture(); images['images']={}
        with patch.object(prepare_runtime.lab,'object_text',side_effect=lambda sha,p:docs[p]), patch.object(prepare_runtime,'resolve_image') as resolve:
            with self.assertRaisesRegex(ValueError,'Missing pinned image'):
                prepare_runtime.render_reference(lock,images,offline=True)
            resolve.assert_not_called()

    def test_reject_corrupt_digest_source_platform_and_baseline(self):
        lock,images,docs=self.fixture()
        for field,value in [('digest','sha256:bad'),('image','example:mutable'),('source','other:v1'),('platform','linux/amd64')]:
            with self.subTest(field=field):
                bad=copy.deepcopy(images);bad['images']['example:v1'][field]=value
                with patch.object(prepare_runtime.lab,'object_text',side_effect=lambda sha,p:docs[p]), self.assertRaises(ValueError):
                    prepare_runtime.render_reference(lock,bad,offline=True)
        images['images']['example:v1']['image']='elsewhere@'+images['images']['example:v1']['digest']
        with patch.object(prepare_runtime.lab,'object_text',side_effect=lambda sha,p:docs[p]), self.assertRaisesRegex(ValueError,'baseline pin'):
            prepare_runtime.render_reference(lock,images,offline=True)

    def test_repeatable_offline_manifest(self):
        lock,images,docs=self.fixture()
        with patch.object(prepare_runtime.lab,'object_text',side_effect=lambda sha,p:docs[p]), patch.object(prepare_runtime,'resolve_image') as resolve:
            a=prepare_runtime.render_reference(lock,images,offline=True)
            b=prepare_runtime.render_reference(lock,images,offline=True)
        self.assertEqual(a,b);resolve.assert_not_called()
        self.assertEqual(a['items'][0]['metadata']['namespace'],'traderx-security-lab')
