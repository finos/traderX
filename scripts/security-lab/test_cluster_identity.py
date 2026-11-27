import json
from pathlib import Path
import tempfile
import unittest

import cluster_identity as identity
from resource_preflight import assess,GIB


class IdentityTests(unittest.TestCase):
    def test_explicit_selection_and_no_overwrite(self):
        with tempfile.TemporaryDirectory() as root:
            self.assertEqual(identity.selected(root),identity.DEFAULT)
            identity.record(root,identity.VALIDATION)
            self.assertEqual(identity.selected(root),identity.VALIDATION)
            with self.assertRaises(FileExistsError):identity.record(root,identity.DEFAULT)

    def test_foreign_and_symlink_selection_refused(self):
        with tempfile.TemporaryDirectory() as root:
            p=Path(root)/'cluster-selection.json';p.write_text(json.dumps({'cluster':'production'}))
            with self.assertRaises(ValueError):identity.selected(root)
            p.unlink();p.symlink_to(Path(root)/'missing')
            with self.assertRaises(ValueError):identity.selected(root)

    def test_only_selected_cluster_can_run(self):
        names=[identity.VALIDATION+'-control-plane']
        snapshot={'host_pressure':'normal','docker_memory_bytes':6*GIB,'containers':[{'name':n,'memory_bytes':GIB} for n in names]}
        self.assertEqual(assess(snapshot,'acceptance',identity.VALIDATION)['status'],'ready')
        self.assertEqual(assess(snapshot,'acceptance')['status'],'blocked')
        snapshot['containers'].append({'name':identity.DEFAULT+'-control-plane','memory_bytes':GIB})
        self.assertEqual(assess(snapshot,'acceptance',identity.VALIDATION)['status'],'blocked')

    def test_build_refuses_browser_runtime(self):
        snapshot={'host_pressure':'normal','docker_memory_bytes':6*GIB,'containers':[{'name':'traderx-account-dev-account-1','memory_bytes':GIB}]}
        self.assertEqual(assess(snapshot,'build')['status'],'blocked')
