import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from browser_lab import main
from browser_session import BrowserServer
from account_oidc import replace_trust

class BrowserLabTests(unittest.TestCase):
    def test_stop_refuses_reused_process_id(self):
        with tempfile.TemporaryDirectory() as root:
            Path(root,'browser-lab.json').write_text(json.dumps({'status':'ready','pid':42,'process_identity':'original'}))
            with patch('sys.argv',['browser_lab','stop','--runtime-dir',root]),patch('browser_lab.process_identity',return_value='unrelated'),patch('browser_lab.os.kill') as kill:
                with self.assertRaisesRegex(ValueError,'identity changed'):main()
                kill.assert_not_called()
    def test_trust_duration_is_bounded_before_changes(self):
        for hours in (0,-1,9):
            with self.assertRaises(ValueError):replace_trust(Path('/unused'),{},hours)
    def test_switch_redirect_has_no_tokens_and_exact_return(self):
        import urllib.parse
        parsed=urllib.parse.urlsplit(BrowserServer.switch_url())
        self.assertEqual(parsed.scheme,'https');self.assertEqual(parsed.netloc,'localhost:18446')
        self.assertEqual(urllib.parse.parse_qs(parsed.query),{'client_id':['security-lab-browser'],'post_logout_redirect_uri':['https://localhost:18447/']})

if __name__=='__main__':unittest.main()
