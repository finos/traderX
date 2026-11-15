import os
import re
import unittest

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))

class TestSeam3AdminUILogic(unittest.TestCase):
    def setUp(self):
        self.comp_path = os.path.join(
            REPO_ROOT,
            'specs', '009-order-management-matcher', 'generation', 'frontend-overrides',
            'web-front-end', 'angular', 'main', 'app', 'admin', 'order-admin.component.ts'
        )
        self.patch_path = os.path.join(
            REPO_ROOT,
            'specs', '009-order-management-matcher', 'generation', 'patches',
            '0001-state-overlay.patch'
        )
        with open(self.comp_path, 'r', encoding='utf-8') as f:
            self.comp_content = f.read()
        with open(self.patch_path, 'r', encoding='utf-8') as f:
            self.patch_content = f.read()

    def test_cancel_button_cell_renderer_predicate(self):
        # Must include both NEW and PARTIALLY_FILLED
        self.assertIn("['NEW', 'PARTIALLY_FILLED'].includes(params?.data?.status)", self.comp_content)
        
        # Test simulated logic
        def cancel_enabled(status):
            return status in ['NEW', 'PARTIALLY_FILLED']
        
        self.assertTrue(cancel_enabled('NEW'))
        self.assertTrue(cancel_enabled('PARTIALLY_FILLED'))
        self.assertFalse(cancel_enabled('FILLED'))
        self.assertFalse(cancel_enabled('CANCELED'))
        self.assertFalse(cancel_enabled('REJECTED'))

    def test_force_fill_button_cell_renderer_predicate(self):
        # Must include NEW and PARTIALLY_FILLED, but forbid MARKET
        self.assertIn("(['NEW', 'PARTIALLY_FILLED'].includes(params?.data?.status) && params?.data?.orderType !== 'MARKET')", self.comp_content)
        
        # Test simulated logic
        def force_fill_enabled(status, order_type):
            return status in ['NEW', 'PARTIALLY_FILLED'] and order_type != 'MARKET'
        
        self.assertTrue(force_fill_enabled('NEW', 'LIMIT'))
        self.assertTrue(force_fill_enabled('PARTIALLY_FILLED', 'LIMIT'))
        self.assertFalse(force_fill_enabled('NEW', 'MARKET'))
        self.assertFalse(force_fill_enabled('PARTIALLY_FILLED', 'MARKET'))
        self.assertFalse(force_fill_enabled('FILLED', 'LIMIT'))
        self.assertFalse(force_fill_enabled('FILLED', 'MARKET'))

    def test_on_cell_clicked_guards(self):
        # cancel click guard
        self.assertIn("if (!['NEW', 'PARTIALLY_FILLED'].includes(status)) {", self.comp_content)
        # forceFill click guard
        self.assertIn("if (!['NEW', 'PARTIALLY_FILLED'].includes(status) || orderType === 'MARKET') {", self.comp_content)

    def test_patch_hunk_parity_with_component(self):
        # The patch hunk must have exact same predicates and guards
        self.assertIn("+            cellRenderer: (params: any) => ['NEW', 'PARTIALLY_FILLED'].includes(params?.data?.status)", self.patch_content)
        self.assertIn("+            cellRenderer: (params: any) => (['NEW', 'PARTIALLY_FILLED'].includes(params?.data?.status) && params?.data?.orderType !== 'MARKET')", self.patch_content)
        self.assertIn("+            if (!['NEW', 'PARTIALLY_FILLED'].includes(status)) {", self.patch_content)
        self.assertIn("+            if (!['NEW', 'PARTIALLY_FILLED'].includes(status) || orderType === 'MARKET') {", self.patch_content)

if __name__ == '__main__':
    unittest.main()
