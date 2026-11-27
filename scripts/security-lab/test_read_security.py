import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from render_read_security import render,controller,PACKAGE

class ReadGenerationTests(unittest.TestCase):
    def test_reproducible_pinned_candidate_with_input_and_output_hashes(self):
        with tempfile.TemporaryDirectory() as root:
            first=Path(root)/'one';second=Path(root)/'two'
            render(first);render(second)
            self.assertEqual((first/'security-generation.json').read_bytes(),(second/'security-generation.json').read_bytes())
            manifest=json.loads((first/'security-generation.json').read_text())
            for name,digest in manifest['files'].items():self.assertEqual(hashlib.sha256((first/name).read_bytes()).hexdigest(),digest)
            for name in ['Position','Trade']:
                source=(first/'src/main/java'/PACKAGE.replace('.','/')/'controller'/(name+'Controller.java')).read_text()
                with self.assertRaises(ValueError):controller(source,name=='Trade')
    def test_existing_target_refused_without_replacing_files(self):
        with tempfile.TemporaryDirectory() as root:
            target=Path(root)/'existing';target.mkdir();(target/'canary').write_text('preserve')
            with self.assertRaises(FileExistsError):render(target)
            self.assertEqual((target/'canary').read_text(),'preserve')
            self.assertEqual([p.name for p in target.iterdir()],['canary'])
