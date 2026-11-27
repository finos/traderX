import copy
import json
import unittest
from render_progression import PROFILE,render

class ProgressionTests(unittest.TestCase):
    def setUp(self):self.model=json.loads((PROFILE/'progression.json').read_text())
    def test_claim_requires_evidence(self):
        model=copy.deepcopy(self.model);model['checkpoints'][0]['evidence']=[]
        with self.assertRaises(ValueError):render(model)
    def test_missing_or_cyclic_prerequisite_fails(self):
        for edge in [{'from':'missing','to':'baseline'},{'from':'learning','to':'baseline'}]:
            model=copy.deepcopy(self.model);model['edges'].append(edge)
            with self.assertRaises(ValueError):render(model)
    def test_generated_page_is_current(self):
        self.assertEqual(render(self.model),(PROFILE/'progression.md').read_text())
