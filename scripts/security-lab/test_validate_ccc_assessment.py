import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import validate_ccc_assessment as validator


class CccAssessmentTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.document = json.loads(validator.MAP.read_text(encoding="utf-8"))

    def test_committed_map_validates_offline(self):
        controls, requirements = validator.validate_mapping(self.document)
        self.assertEqual(controls, 10)
        self.assertEqual(requirements, 32)

    def test_paths_must_exist_and_remain_repository_relative(self):
        for bad_path in ("../outside.json", "/tmp/outside.json", "missing/evidence.json"):
            with self.subTest(path=bad_path):
                document = copy.deepcopy(self.document)
                document["controls"][0]["evidence_paths"] = [bad_path]
                with self.assertRaises(ValueError):
                    validator.validate_mapping(document)

    def test_path_symlink_cannot_escape_repository(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "repository"
            root.mkdir()
            (root / "implementation.py").write_text("", encoding="utf-8")
            outside = Path(temporary) / "outside.json"
            outside.write_text("{}", encoding="utf-8")
            (root / "escape.json").symlink_to(outside)
            document = {
                "schema_version": 1,
                "controls": [
                    {
                        "id": "CCC.LB.CN11",
                        "title": "WAF",
                        "catalog_version": "v2026.11",
                        "catalog_source_url": "https://github.com/finos/common-cloud-controls/blob/56a388a18a6f2fdf13d933a0f9eddb16c8c9ccac/catalogs/networking/loadbalancer/controls.yaml",
                        "implementation_paths": ["implementation.py"],
                        "test_command": "offline",
                        "evidence_paths": ["escape.json"],
                        "requirements": [
                            {
                                "id": "CCC.LB.CN11.AR01",
                                "requirement": "A test requirement.",
                                "result": "partial",
                                "status": "local-fixture",
                                "scope": "A local fixture.",
                                "limitation": "No deployment coverage.",
                            }
                        ],
                    }
                ],
            }
            try:
                with self.assertRaisesRegex(ValueError, "outside repository"):
                    validator.validate_mapping(document, root)
            finally:
                outside.unlink()

    def test_invalid_status_and_result_pair_are_rejected(self):
        for field, value in (("status", "passed"), ("result", "certified")):
            with self.subTest(field=field):
                document = copy.deepcopy(self.document)
                document["controls"][0]["requirements"][0][field] = value
                with self.assertRaises(ValueError):
                    validator.validate_mapping(document)

    def test_catalog_source_must_be_official_and_commit_pinned(self):
        document = copy.deepcopy(self.document)
        document["controls"][0]["catalog_source_url"] = "https://ccc.finos.org/catalogs"
        with self.assertRaisesRegex(ValueError, "immutable FINOS CCC catalog URL"):
            validator.validate_mapping(document)

    def test_catalog_source_family_must_match_control_id(self):
        document = copy.deepcopy(self.document)
        document["controls"][0]["catalog_source_url"] = document["controls"][1]["catalog_source_url"]
        with self.assertRaisesRegex(ValueError, "catalog source does not match control family"):
            validator.validate_mapping(document)

    def test_cli_works_outside_repository_and_does_not_need_network(self):
        script = Path(validator.__file__).resolve()
        with tempfile.TemporaryDirectory() as working_directory:
            result = subprocess.run(
                [sys.executable, str(script)],
                cwd=working_directory,
                capture_output=True,
                text=True,
                check=False,
            )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("10 controls, 32 requirements", result.stdout)
        self.assertIn("offline path/status checks only", result.stdout)


if __name__ == "__main__":
    unittest.main()
