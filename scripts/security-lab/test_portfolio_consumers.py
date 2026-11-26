from pathlib import Path
import json
import subprocess
import tempfile
import unittest
from render_account_security import ROOT, PROFILE
from render_application_consumers import blotter
from render_portfolio_consumers import apply


class PortfolioConsumerTests(unittest.TestCase):
    def test_deterministic_scoped_overlay_refuses_reapplication(self):
        relatives = ('trade/trade.component.ts', 'trade/trade.component.html',
                     'trade/position-blotter/position-blotter.component.ts')
        baseline = json.loads((PROFILE/'baseline.lock.json').read_text())['generated_commit']
        with tempfile.TemporaryDirectory() as temp:
            outputs = []
            for name in ('a', 'b'):
                target = Path(temp)/name
                for relative in relatives:
                    path = target/'main/app'/relative
                    path.parent.mkdir(parents=True, exist_ok=True)
                    original = subprocess.run(['git', 'show', baseline+':web-front-end/angular/main/app/'+relative],
                                              cwd=ROOT, capture_output=True, check=True, timeout=30).stdout.decode()
                    path.write_text(blotter(original, True) if 'position-blotter' in relative else original)
                apply(target)
                outputs.append([(target/'main/app'/relative).read_text() for relative in relatives])
                with self.assertRaises(ValueError):
                    apply(target)
            self.assertEqual(*outputs)
            self.assertNotIn("subscribe('pricing.*'", '\n'.join(outputs[0]))
            self.assertNotIn('allAccountsSummary', '\n'.join(outputs[0]))
            self.assertIn('Price unavailable', outputs[0][2])


if __name__ == '__main__':
    unittest.main()
