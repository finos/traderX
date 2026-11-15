import os
import unittest

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))

class TestSeam2PipelineScript(unittest.TestCase):
    def setUp(self):
        self.script_path = os.path.join(REPO_ROOT, 'pipeline', 'apply-state-patchset.sh')

    def test_line_endings_are_strict_lf(self):
        with open(self.script_path, 'rb') as f:
            data = f.read()
        self.assertNotIn(b'\r\n', data, "pipeline/apply-state-patchset.sh contains CRLF line endings")

    def test_failure_propagation_is_present(self):
        with open(self.script_path, 'r', encoding='utf-8') as f:
            content = f.read()
        self.assertIn('echo "[fail] unable to apply patch: ${patch_file}"', content)
        self.assertIn('return 1', content)

    def test_silent_reject_fallback_is_removed(self):
        with open(self.script_path, 'r', encoding='utf-8') as f:
            content = f.read()
        self.assertNotIn('--reject', content)
        self.assertNotIn('*.rej', content)
        self.assertNotIn('apply-with-reject-cleaned', content)

if __name__ == '__main__':
    unittest.main()
