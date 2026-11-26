import hashlib
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

    def test_preview_metadata_has_no_unsupported_runtime_or_operator_routes(self):
        with tempfile.TemporaryDirectory() as temp:
            target=Path(temp)/'candidate';render(target)
            path=target/'main/assets/state-ui.json';metadata=json.loads(path.read_text())
            self.assertEqual(metadata['stateId'],'019-traderx-security-lab')
            self.assertIn('planned state preview',metadata['stateTitle'])
            self.assertIn('unpublished',metadata['sourceBranch'])
            self.assertEqual(metadata['sourceBranchUrl'],'')
            self.assertEqual(metadata['runtimeMetadataUrl'],'')
            self.assertEqual(metadata['features'],{'statusPage':False,'apiExplorer':False,'pubSubInspector':False})
            self.assertEqual(metadata['apiExplorerUrl'],'');self.assertEqual(metadata['pubSubInspectorUrl'],'')
            self.assertEqual(metadata['statusChecks'],[{'id':'browser-session','name':'Security Lab session runtime',
                'url':'/health/ready','expectedStatuses':[200]}])
            self.assertEqual(metadata['previousStates'][0]['id'],'012-platform-convergence-c3')
            self.assertTrue((target/'main/assets/img/traderx-apple-touch-icon.png').is_file())
            manifest=json.loads((target/'security-generation.json').read_text())
            self.assertEqual(manifest['files']['main/assets/state-ui.json'],hashlib.sha256(path.read_bytes()).hexdigest())
            # The existing typed client accepts an empty string and takes this
            # branch before issuing its cache-busted runtime metadata request.
            service=(target/'main/app/service/state-metadata.service.ts').read_text()
            self.assertIn('if (!runtimeMetadataUrl)',service)
