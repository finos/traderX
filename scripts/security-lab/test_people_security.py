import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from render_people_security import render


class PeopleGenerationTests(unittest.TestCase):
    def test_deterministic_manifest_and_existing_target_refusal(self):
        with tempfile.TemporaryDirectory() as temp:
            a=Path(temp)/'a';b=Path(temp)/'b';render(a);render(b)
            self.assertEqual((a/'security-generation.json').read_bytes(),(b/'security-generation.json').read_bytes())
            for name,digest in json.loads((a/'security-generation.json').read_text())['files'].items():
                self.assertEqual(hashlib.sha256((a/name).read_bytes()).hexdigest(),digest)
            with self.assertRaises(FileExistsError):render(a)


if __name__=='__main__':unittest.main()
