import json
import unittest
from database_rotation import public_result

class RotationEvidenceTests(unittest.TestCase):
    def test_only_allowlisted_evidence_can_leave_private_record(self):
        state={'phase':'complete','old_pod_uid':'before','new_pod_uid':'after','old_password':'SECRET_OLD','new_password':'SECRET_NEW','unexpected_credentials':{'token':'SECRET_TOKEN'}}
        result=public_result(state);self.assertNotIn('SECRET',json.dumps(result));self.assertNotIn('unexpected_credentials',result);self.assertEqual(result['new_pod_uid'],'after')
    def test_incomplete_rotation_is_not_published_as_passed(self):
        with self.assertRaises(ValueError):public_result({'phase':'password-changed'})
