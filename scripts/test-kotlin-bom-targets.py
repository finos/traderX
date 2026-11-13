#!/usr/bin/env python3
"""Keep transitive Kotlin on the centrally selected family."""
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
TEMPLATE = ROOT / 'templates/trade-service-specfirst/build.gradle'

class KotlinBomTests(unittest.TestCase):
    def test_missing_and_stale_kotlin_are_rejected_independently(self):
        original = TEMPLATE.read_text()
        for text, error in [
            (re.sub(r"ext\['kotlin.version'\].*\n", '', original), 'missing kotlin.version'),
            (original.replace("ext['kotlin.version'] = '2.4.21'", "ext['kotlin.version'] = '2.2.21'"), 'kotlin.version property')]:
            with self.subTest(error=error), tempfile.TemporaryDirectory() as tmp:
                (Path(tmp) / 'build.gradle').write_text(text)
                result = subprocess.run(['bash', str(ROOT / 'pipeline/validate-generated-dependency-targets.sh'), tmp], capture_output=True, text=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(error, result.stdout + result.stderr)

    def test_refresh_installs_kotlin_family_and_is_idempotent(self):
        with tempfile.TemporaryDirectory() as tmp:
            gradle = Path(tmp) / 'build.gradle'
            gradle.write_text(re.sub(r"ext\['kotlin.version'\].*\n", '', TEMPLATE.read_text()).replace("'3.1.7'", "'3.1.5'"))
            command = ['bash', str(ROOT / 'pipeline/refresh-generated-java-dependency-baseline.sh'), tmp]
            subprocess.run(command, check=True, capture_output=True)
            normalized = gradle.read_text()
            self.assertIn("ext['kotlin.version'] = '2.4.21'", normalized)
            self.assertIn("ext['jackson-bom.version'] = '3.1.7'", normalized)
            subprocess.run(command, check=True, capture_output=True)
            self.assertEqual(normalized, gradle.read_text())

if __name__ == '__main__':
    unittest.main()
