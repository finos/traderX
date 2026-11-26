import asyncio
import hashlib
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

from authenticated_delivery import deliver
from browser_journey_fixture import AccountService, chromium_trust, driver_checks, order_id, run_driver, verified_frontend

CHECKS=['check-'+name for name in ('one','two','three','four','five','six','seven','eight')]


class BrowserJourneyTests(unittest.TestCase):
    def test_order_identity_cannot_be_sql_or_path_input(self):
        self.assertEqual(order_id('ord-013-42'),'ord-013-42')
        for value in ('../order',"ord-013-42';DROP TABLE orderbook;--",None,'ord-013-'+('1'*25)):
            with self.assertRaises(ValueError):order_id(value)

    def test_account_build_drift_is_rejected_before_launch(self):
        with tempfile.TemporaryDirectory() as temp:
            runtime=Path(temp);target=runtime/'account-security-build';target.mkdir();(runtime/'evidence').mkdir()
            jar=target/'candidate.jar';jar.write_bytes(b'changed')
            (runtime/'evidence/account-security-build.json').write_text(json.dumps(dict(
                status='built-and-unit-tested-not-deployed',jar=str(jar),jar_sha256='wrong',generation={})))
            with patch('subprocess.Popen') as launch:
                with self.assertRaisesRegex(ValueError,'Account jar drift'):AccountService(runtime,runtime,{},None,runtime/'trust')
                launch.assert_not_called()

    def test_frontend_source_manifest_is_checked_before_serving_assets(self):
        with tempfile.TemporaryDirectory() as temp:
            runtime=Path(temp);target=runtime/'application-consumers';target.mkdir()
            (target/'main.ts').write_text('candidate')
            (target/'security-generation.json').write_text(json.dumps(dict(inputs={},files={'main.ts':'wrong'})))
            with self.assertRaisesRegex(ValueError,'Browser candidate source drift'):verified_frontend(runtime)

    def test_trust_change_is_hosted_only_and_removes_only_owned_nickname(self):
        with patch('browser_journey_fixture.portability.isolated_linux',return_value=False),patch('subprocess.run') as run:
            with self.assertRaises(ValueError):
                with chromium_trust(Path('/unused/certificate')):pass
            run.assert_not_called()
        with tempfile.TemporaryDirectory() as temp:
            home=Path(temp);db=home/'.pki/nssdb';db.mkdir(parents=True);(db/'cert9.db').write_bytes(b'existing')
            before=dict(os.environ)
            with patch('browser_journey_fixture.portability.isolated_linux',return_value=True),patch('browser_journey_fixture.shutil.which',return_value='/hosted/certutil'),patch('browser_journey_fixture.Path.home',return_value=home),patch('subprocess.run') as run:
                with self.assertRaisesRegex(RuntimeError,'fixture failure'):
                    with chromium_trust(home/'fixture.pem'):raise RuntimeError('fixture failure')
            calls=[call.args[0] for call in run.call_args_list]
            self.assertEqual(len(calls),2);self.assertEqual(calls[0][1],'-A');self.assertEqual(calls[1][1],'-D')
            self.assertEqual(calls[0][calls[0].index('-n')+1],calls[1][calls[1].index('-n')+1])
            self.assertTrue(calls[0][calls[0].index('-n')+1].startswith('traderx-journey-'))
            self.assertEqual(dict(os.environ),before);self.assertEqual((db/'cert9.db').read_bytes(),b'existing')

    def test_driver_check_contract_is_bounded_and_does_not_emit_import_errors(self):
        with patch('subprocess.run',return_value=Mock(stdout=json.dumps(CHECKS).encode())):
            self.assertEqual(driver_checks('node',Path('/absolute/driver.mjs')),CHECKS)
        with patch('subprocess.run',return_value=Mock(stdout=b'{"secret":"private"}')):
            with self.assertRaisesRegex(RuntimeError,'check contract unavailable'):driver_checks('node',Path('/absolute/driver.mjs'))


class DriverProtocolTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.private=Path(self.temp.name);self.script=self.private/'driver.py'
        self.config=self.private/'private.json';self.config.write_text('{}');self.config.chmod(0o600)

    async def test_real_pipe_stages_wait_for_independent_checks_and_exact_result(self):
        final=dict(status='passed',checks=CHECKS,orderId='ord-013-1',cancelOrderId='ord-013-2')
        self.script.write_text('import json\nfor stage in ("ready_for_price","ready_for_delivery"):\n print(json.dumps(dict(stage=stage,orderId="ord-013-1")),flush=True)\n assert json.loads(input())=={"ok":True}\nprint('+repr(json.dumps(final))+',flush=True)\n')
        observed=[]
        async def stage(name,order):observed.append((name,order))
        result=await run_driver(sys.executable,self.script,self.config,self.private,stage,CHECKS)
        self.assertEqual(result,final)
        self.assertEqual(observed,[('ready_for_price','ord-013-1'),('ready_for_delivery','ord-013-1')])

    async def test_unexpected_stage_never_reaches_sql_callback(self):
        self.script.write_text('print(\'{"stage":"ready_for_delivery","orderId":"ord-013-1"}\',flush=True)\ninput()\n')
        async def forbidden(*_):raise AssertionError('Stage validation bypassed')
        with self.assertRaisesRegex(RuntimeError,'Unexpected browser journey stage'):
            await run_driver(sys.executable,self.script,self.config,self.private,forbidden,CHECKS)

    async def test_failure_returns_only_fixed_phase_without_private_body(self):
        self.script.write_text('print(\'{"status":"failed","phase":"trader_login","error":"secret-password"}\',flush=True)\n')
        async def unused(*_):pass
        with self.assertRaises(RuntimeError) as error:
            await run_driver(sys.executable,self.script,self.config,self.private,unused,CHECKS)
        self.assertIn('trader_login',str(error.exception));self.assertNotIn('secret-password',str(error.exception))

    async def test_delivery_event_bound_checked_before_connecting(self):
        for count in (0,1,True,100):
            with self.assertRaisesRegex(ValueError,'Bounded settlement event count'):
                await deliver(None,None,None,None,None,None,expected_events=count)


if __name__=='__main__':unittest.main()
