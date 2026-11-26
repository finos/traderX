import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import admission_fixture
import integrated_deployment as compiler
import runtime_images as images
import runtime_launcher as launcher


class RuntimeImageTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.root=Path(self.temp.name).resolve()
        self.wheels=self.root/'wheels';self.wheels.mkdir()
        self.lock=compiler.read_json(images.LOCK)
        for name,item in self.lock['wheels'].items():
            data=('unit-test-not-wheel-'+name).encode();(self.wheels/item['filename']).write_bytes(data)
            item.update(size=len(data),sha256=compiler.sha(data))
        self.lockfile=self.root/'test.lock';self.lockfile.write_bytes(compiler.encoded(self.lock))
        self.patcher=patch.object(images,'LOCK',self.lockfile);self.patcher.start();self.addCleanup(self.patcher.stop)
    def tearDown(self):self.temp.cleanup()

    def frontend(self):
        root=self.root/'frontend';root.mkdir()
        source=root/'main.ts';source.write_text('// synthetic unit-test frontend source')
        input='scripts/security-lab/render_application_consumers.py'
        generation={'inputs':{input:compiler.sha((compiler.ROOT/input).read_bytes())},'files':{'main.ts':compiler.sha(source.read_bytes())}}
        (root/'security-generation.json').write_bytes(compiler.encoded(generation))
        static=root/'dist/main-application/browser';static.mkdir(parents=True)
        (static/'index.html').write_text('<base href="/"><script src="main-ABCDEF.js"></script>')
        (static/'main-ABCDEF.js').write_text('// synthetic unit-test asset')
        (static/'credentials.json').write_text('private-test-marker')
        (root/'local.key').write_text('never-copy-unit-test-marker')
        return root

    def test_context_only_contains_reviewed_sources_wheels_and_public_assets(self):
        root=self.frontend();output=self.root/'browser-context'
        value=images.prepare('browser-session',self.wheels,output,'0'*40,root)
        self.assertEqual(set(p.name for p in (output/'source').iterdir()),images.FILES['browser-session'])
        self.assertNotIn('verify_account_authorization.py',images.FILES['browser-session'])
        self.assertFalse((output/'static/credentials.json').exists());self.assertFalse((output/'local.key').exists())
        self.assertEqual(value['keys'],['ca.pem','config.json','tls.crt','tls.key'])
        dockerfile=(output/'Dockerfile').read_text()
        self.assertIn('USER 10001:10001',dockerfile);self.assertIn('--no-index',dockerfile)
        self.assertIn('--require-hashes',dockerfile);self.assertIn('COPY --chmod=0555 source/',dockerfile)
        self.assertIn('RUN umask 022 && python -m pip install',dockerfile)
        self.assertNotIn('COPY . ',dockerfile);self.assertNotIn('ARG ',dockerfile)
        self.assertIn(self.lock['base']['reference'],dockerfile)
        self.assertTrue(set(value['context_files'])<={str(p.relative_to(output)) for p in output.rglob('*') if p.is_file()})

    def test_workers_use_role_bound_materializer_and_no_browser_or_static(self):
        for role in ('event-publisher','event-consumer'):
            output=self.root/role;value=images.prepare(role,self.wheels,output,'0'*40)
            self.assertEqual(value['command'],images.argv(role))
            self.assertEqual(value['command'][-4:],['--role',role,'--config',launcher.CONFIG])
            self.assertEqual(set(p.name for p in (output/'source').iterdir()),images.COMMON|{'delivery_worker.py'})
            self.assertFalse((output/'static').exists())

    def test_tampered_wheel_or_missing_frontend_refused_before_output(self):
        item=self.lock['wheels']['nats-py'];(self.wheels/item['filename']).write_bytes(b'tampered')
        with self.assertRaisesRegex(ValueError,'Unverified wheel'):images.prepare('event-publisher',self.wheels,self.root/'output','0'*40)
        self.assertFalse((self.root/'output').exists())
        with self.assertRaisesRegex(ValueError,'Angular'):images.prepare('browser-session',self.wheels,self.root/'other','0'*40)

    def test_frontend_source_drift_and_symlink_fail_closed(self):
        root=self.frontend();(root/'main.ts').write_text('changed')
        with self.assertRaisesRegex(ValueError,'source drift'):images.frontend(root)
        (root/'main.ts').unlink();(root/'main.ts').symlink_to('/etc/hosts')
        with self.assertRaisesRegex(ValueError,'regular'):images.frontend(root)

    def test_existing_destination_not_overwritten_and_lock_bound_to_source_hash(self):
        output=self.root/'context';output.mkdir()
        with self.assertRaises(FileExistsError):images.prepare('event-publisher',self.wheels,output,'0'*40)
        self.assertIn('specs/019-traderx-security-lab/system/runtime-images.lock.json',compiler.source_manifest()['files'])

    def test_oci_fragment_uses_verified_manifest_bytes_and_exact_launch_contract(self):
        role='browser-session';source=compiler.source_manifest()
        entry=admission_fixture.image(self.root,role,source,'0'*40,lambda cfg:cfg['config'].update(Entrypoint=images.argv(role)))
        value=images.inspect(role,Path(entry['oci_layout']),'local/traderx-browser','0'*40)
        self.assertEqual(value['image'].split('@')[1],entry['image'].split('@')[1])
        self.assertEqual(value['keys'],images.KEYS[role])
        with self.assertRaisesRegex(ValueError,'source'):images.inspect(role,Path(entry['oci_layout']),'local/traderx-browser','1'*40)

    def test_worker_launcher_rejects_other_role_and_loopback_tls_exception(self):
        good={'mode':'publisher','database_transport':'verify-full','broker_ca':'/run/private/config/broker-ca.pem','database_ca':'/run/private/config/database-ca.pem'}
        launcher.validate('event-publisher',good)
        for delta in ({'mode':'reference-consumer'},{'database_transport':'fixture-loopback'},{'database_ca':'/tmp/ca.pem'}):
            with self.assertRaises(ValueError):launcher.validate('event-publisher',dict(good,**delta))
        with self.assertRaises(ValueError):launcher.validate('event-consumer',good)

    def test_browser_launcher_rejects_loopback_or_incomplete_api_inventory(self):
        good={'listen_host':'0.0.0.0','listen_port':18447,'static_root':'/app/static','backends':dict.fromkeys(launcher.BACKENDS,'https://test:443'),
              'certificate':'/run/private/config/tls.crt','key':'/run/private/config/tls.key','ca_file':'/run/private/config/ca.pem'}
        launcher.validate('browser-session',good)
        for delta in ({'listen_host':'127.0.0.1'},{'listen_port':443},{'static_root':'/tmp/static'},{'backends':{}},{'key':'/tmp/key'}):
            with self.assertRaises(ValueError):launcher.validate('browser-session',dict(good,**delta))

    def test_download_is_hosted_only_and_no_local_fetch_occurs(self):
        with patch.object(images.portability,'isolated_linux',return_value=False),patch.object(images.urllib.request,'urlopen') as fetch:
            with self.assertRaisesRegex(ValueError,'hosted'):images.fetch_wheels(self.root/'download')
            fetch.assert_not_called()


if __name__=='__main__':unittest.main()
