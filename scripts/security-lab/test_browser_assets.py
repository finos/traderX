import tempfile
from pathlib import Path
import unittest
from unittest.mock import patch

from browser_assets import CSP, PublicAssets


def assets(root):
    (root/'index.html').write_text('<html><base href="/"><link rel="stylesheet" href="styles-ABC12345.css"><script src="main-ABC12345.js" type="module"></script></html>')
    (root/'main-ABC12345.js').write_text('console.log("fixture")')
    (root/'styles-ABC12345.css').write_text('body{color:black}')
    return root


class AssetTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=assets(Path(self.temp.name))

    def test_preloaded_assets_spa_and_secret_boundaries(self):
        for name in ('.env','config.json','server.key','main-ABC12345.js.map'):(self.root/name).write_text('private')
        public=PublicAssets(self.root)
        (self.root/'main-ABC12345.js').write_text('changed')
        self.assertIn(b'fixture',public.get('/main-ABC12345.js')[0])
        self.assertEqual(public.get('/trade'),public.get('/'))
        for path in ('/.env','/config.json','/server.key','/main-ABC12345.js.map','/unknown','/../index.html','/%2e%2e/index.html','//index.html','/index.html?x=1','/media\\private'):
            self.assertIsNone(public.get(path),path)
        self.assertIn("script-src 'self';",CSP)
        self.assertIn("font-src 'self' data:;",CSP)
        self.assertIn("connect-src 'self';",CSP)
        self.assertNotIn('unsafe-eval',CSP)

    def test_symlinks_and_budgets_fail_closed(self):
        (self.root/'secret-link').symlink_to(self.root/'index.html')
        with self.assertRaises(ValueError):PublicAssets(self.root)
        (self.root/'secret-link').unlink()
        with patch('browser_assets.MAX_TOTAL',8),self.assertRaises(ValueError):PublicAssets(self.root)

    def test_index_rejects_active_inline_code_and_missing_or_external_references(self):
        for html in ('<script>alert(1)</script>','<link href="styles-ABC12345.css" onload="x()">',
                     '<base href="/wrong/">','<script src="main-MISSING.js"></script>',
                     '<link href="https://other.example/styles.css">','<script src="main-ABC12345.js" src="x"></script>'):
            (self.root/'index.html').write_text(html)
            with self.assertRaises(ValueError,msg=html):PublicAssets(self.root)


if __name__=='__main__':unittest.main()
