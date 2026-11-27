import fcntl
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from resource_operation import operation, operation_lock

class OperationTests(unittest.TestCase):
    def test_contention_blocks_before_preflight(self):
        with tempfile.TemporaryDirectory() as root, patch.dict(os.environ,{},clear=True):
            with operation_lock(Path(root)), patch('resource_operation.require') as preflight:
                with self.assertRaises(BlockingIOError):
                    with operation(Path(root),'build'): pass
                preflight.assert_not_called()

    def test_inherited_lock_still_checks_capacity_and_keeps_parent_lock(self):
        with tempfile.TemporaryDirectory() as root, patch.dict(os.environ,{},clear=True):
            with operation_lock(Path(root)) as fd:
                with patch.dict(os.environ,{'TRADERX_LAB_LOCK_FD':str(fd)}), patch('resource_operation.require',return_value={'status':'ready'}) as check:
                    with operation(Path(root),'build'): pass
                    check.assert_called_once_with(Path(root),'build')
                with self.assertRaises(BlockingIOError):
                    with operation_lock(Path(root)): pass
            with operation_lock(Path(root)): pass

    def test_bounded_wait_allows_exiting_owner_to_release(self):
        with tempfile.TemporaryDirectory() as root, patch.dict(os.environ,{},clear=True), patch('resource_operation.fcntl.flock',side_effect=[BlockingIOError(),None]) as lock, patch('resource_operation.time.sleep') as sleep:
            with operation_lock(Path(root),wait_seconds=10):pass
            self.assertEqual(lock.call_count,2);sleep.assert_called_once()

    def test_wait_remains_bounded(self):
        with tempfile.TemporaryDirectory() as root, patch.dict(os.environ,{},clear=True), patch('resource_operation.fcntl.flock',side_effect=BlockingIOError()), patch('resource_operation.time.monotonic',side_effect=[0,11]):
            with self.assertRaises(BlockingIOError):
                with operation_lock(Path(root),wait_seconds=10):pass


class BuildEntryPointTests(unittest.TestCase):
    def test_all_builders_stop_before_subprocess_when_capacity_blocked(self):
        import sys
        import build_java_candidates, build_nats_publisher, prepare_waf, build_account_security, build_trading_security
        for module in (build_java_candidates, build_nats_publisher, prepare_waf, build_account_security, build_trading_security):
            with self.subTest(builder=module.__name__), tempfile.TemporaryDirectory() as root, patch.dict(os.environ,{},clear=True):
                with patch.object(sys,'argv',[module.__name__,'--runtime-dir',root]), patch('resource_operation.require',side_effect=RuntimeError('capacity blocked')), patch.object(module.subprocess,'run') as run:
                    with self.assertRaisesRegex(RuntimeError,'capacity blocked'): module.main()
                    run.assert_not_called()

if __name__=='__main__': unittest.main()
