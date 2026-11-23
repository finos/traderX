import json
from pathlib import Path
import tempfile
import unittest
import zipfile
from unittest.mock import patch, call
from account_dev import compose, render, verify_files, PROFILE

class AccountDevTests(unittest.TestCase):
    def test_other_runtime_compose_project_is_rejected(self):
        from account_dev import check_ownership
        from types import SimpleNamespace
        labels={'traderx.security-lab.account-dev':'true','com.docker.compose.project.config_files':'/another/runtime/account-dev/compose.json'}
        results=[SimpleNamespace(stdout='container-id'),SimpleNamespace(stdout=json.dumps([{'Config':{'Labels':labels}}]))]
        with patch('account_dev.subprocess.run',side_effect=results):
            with self.assertRaisesRegex(ValueError,'another runtime'):check_ownership(Path('/private/expected'))

    def test_start_retains_images_before_next_pull(self):
        from account_dev import start_services
        runtime=Path('/private/runtime'); folder=runtime/'account-dev'
        with patch('account_dev.run_compose') as run:
            start_services(runtime,folder)
        self.assertEqual(run.call_args_list,[
            call(runtime,folder,'up','--no-start','--no-deps',service)
            for service in ('database','people','account')
        ]+[call(runtime,folder,'up','-d','--pull','never')])

    def test_identity_render_copies_public_trust_but_not_signer(self):
        with tempfile.TemporaryDirectory() as root:
            root=Path(root); config=root/'identity'; config.mkdir()
            for name in ('public.pem','entitlements.properties','issuer','audience','key-not-after'):
                (config/name).write_text('fixture-'+name)
            (config/'signing-key.pem').write_text('PRIVATE SIGNER MUST NOT BE MOUNTED')
            jar=root/'candidate.jar'
            with zipfile.ZipFile(jar,'w') as archive:
                for name in ('AccountServiceApplication','security/AccountSecurity'):
                    archive.writestr('BOOT-INF/classes/finos/traderx/accountservice/'+name+'.class',b'fixture')
            folder=root/'dev'; render(folder,jar,config); verify_files(folder)
            self.assertTrue(json.loads((folder/'manifest.json').read_text())['identity_configured'])
            self.assertEqual((folder/'account/public.pem').read_text(),'fixture-public.pem')
            self.assertFalse(any(p.name=='signing-key.pem' for p in folder.rglob('*')))
            self.assertNotIn(str(config),(folder/'compose.json').read_text())

    def test_pinned_bounded_services_and_only_loopback_exposure(self):
        pins=json.loads((PROFILE/'baseline.lock.json').read_text())['image_digests']
        config=compose(Path('/private/test'),pins)
        self.assertEqual(set(config['services']),{'database','people','account'})
        for service in config['services'].values():
            self.assertIn('@sha256:',service['image'])
            self.assertTrue(service['read_only'])
            self.assertEqual(service['cap_drop'],['ALL'])
            self.assertEqual(service['mem_limit'],service['memswap_limit'])
        self.assertEqual(config['services']['account']['ports'],['127.0.0.1:18488:18088'])
        self.assertNotIn('ports',config['services']['database'])
        self.assertNotIn('ports',config['services']['people'])
        self.assertNotIn('DATABASE_DBPASS',config['services']['account']['environment'])
        self.assertNotIn('volumes',config)  # no persisted database or C3 volume reuse

    def test_private_render_drift_and_no_silent_secret_rotation(self):
        with tempfile.TemporaryDirectory() as root:
            folder=Path(root)/'dev'; render(folder)
            verify_files(folder)
            secret=(folder/'account/spring.datasource.password').read_text()
            self.assertNotIn(secret,(folder/'compose.json').read_text())
            self.assertEqual(folder.stat().st_mode & 0o777,0o700)
            with self.assertRaises(FileExistsError): render(folder)
            (folder/'people-stub.js').write_text('changed')
            with self.assertRaises(ValueError): verify_files(folder)

if __name__=='__main__': unittest.main()
