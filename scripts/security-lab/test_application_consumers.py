import json
from pathlib import Path
import tempfile
import unittest
from render_application_consumers import render

class ApplicationConsumerGenerationTests(unittest.TestCase):
    def test_repeated_generation_identical_and_existing_target_refused(self):
        with tempfile.TemporaryDirectory() as temp:
            a=Path(temp)/'a'; b=Path(temp)/'b'
            render(a); render(b)
            self.assertEqual((a/'security-generation.json').read_bytes(),(b/'security-generation.json').read_bytes())
            manifest=json.loads((a/'security-generation.json').read_text())
            self.assertIn('main/app/security/settlement-consumers.spec.ts',manifest['files'])
            with self.assertRaises(FileExistsError): render(a)
