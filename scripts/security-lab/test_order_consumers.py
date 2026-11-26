from pathlib import Path
import tempfile
import unittest
import json
import subprocess
from render_account_security import ROOT, PROFILE
from render_order_consumers import apply


class OrderConsumerTests(unittest.TestCase):
    def test_order_overlay_is_deterministic_and_refuses_pinned_shape_drift(self):
        with tempfile.TemporaryDirectory() as temp:
            first=Path(temp)/'a';second=Path(temp)/'b'
            baseline=json.loads((PROFILE/'baseline.lock.json').read_text())['generated_commit']
            for target in (first,second):
                for relative in ('trade/order-blotter/order-blotter.component.ts','trade/order-blotter/order-blotter.component.html','trade/order-ticket/order-ticket.component.ts'):
                    path=target/'main/app'/relative;path.parent.mkdir(parents=True,exist_ok=True)
                    path.write_bytes(subprocess.run(['git','show',baseline+':web-front-end/angular/main/app/'+relative],cwd=ROOT,capture_output=True,check=True,timeout=30).stdout)
                apply(target)
            for relative in ('trade/order-blotter/order-blotter.component.ts','trade/order-ticket/order-ticket.component.ts'):
                self.assertEqual((first/'main/app'/relative).read_bytes(),(second/'main/app'/relative).read_bytes())
            with self.assertRaises(ValueError):apply(first)


if __name__=='__main__':unittest.main()
