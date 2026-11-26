"""Synthetic unit tests; these do not constitute a real .NET or image run."""
import io
import json
from pathlib import Path
import tarfile
import tempfile
import unittest
from unittest.mock import patch

import admission_fixture
import build_people_image as build
import integrated_deployment as compiler
import people_images as images
import people_runtime
from render_people_security import render


class PeopleImageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.source = self.root / 'source'
        render(self.source)
        self.publish = self.root / 'publish'
        self.publish.mkdir()
        self.assembly = b'synthetic assembly, not executed'
        dll = self.source / build.DLL
        dll.parent.mkdir(parents=True)
        dll.write_bytes(self.assembly)
        deps = compiler.encoded({'runtimeTarget': {'name': '.NETCoreApp,Version=v9.0'},
                                 'targets': {'.NETCoreApp,Version=v9.0': {
                                     'app/1.0': {'runtime': {'PeopleService.WebApi.dll': {}}},
                                     'dependency/1.0': {'runtime': {'dependency.dll': {}}}}}})
        for name, data in {'PeopleService.WebApi.dll': self.assembly,
                           'PeopleService.WebApi.deps.json': deps,
                           'PeopleService.WebApi.runtimeconfig.json': b'{}',
                           'dependency.dll': b'dependency'}.items():
            (self.publish / name).write_bytes(data)
            (dll.parent / name).write_bytes(data)
        fixture = {'status': 'passed', 'assembly_sha256': compiler.sha(self.assembly),
                   'directory_sha256': compiler.sha((self.source / build.ASSET).read_bytes()),
                   'scope': 'Live Keycloak and generated .NET operator-only people API; not deployed',
                   'checks': build.fixture_checks()}
        self.report = self.root / 'report.json'
        self.value = {'schema_version': 1, 'service': images.ROLE, 'status': build.STATUS,
                      'source_manifest': compiler.source_manifest(), 'dotnet_sdk': '9.0.321',
                      **build.artifacts(self.source, self.publish, fixture)}
        self.report.write_bytes(compiler.encoded(self.value))

    def inspect(self, layout):
        return images.inspect(layout, 'local/people:unit', '0' * 40,
                              self.source, self.publish, self.report)

    def layout(self, file_change=None, directory_change=None, config_change=None, extra=None):
        layout = self.root / ('oci-' + str(len(list(self.root.glob('oci-*')))))
        layout.mkdir()
        files, verified = images.inputs(self.source, self.publish, self.report)
        paths = {'opt/traderx/' + name.split('/', 1)[1]:
                 (data, 0o444 if name.startswith('application/') else 0o555)
                 for name, data in files.items()}
        if file_change:
            file_change(paths)
        archive = io.BytesIO()
        with tarfile.open(fileobj=archive, mode='w') as tar:
            for name in ('opt', 'opt/traderx', 'opt/traderx/MockDirectory'):
                member = tarfile.TarInfo(name)
                member.type, member.mode = tarfile.DIRTYPE, 0o755
                if directory_change:
                    directory_change(member)
                tar.addfile(member)
            for name, (data, mode) in paths.items():
                member = tarfile.TarInfo(name)
                member.size, member.mode = len(data), mode
                tar.addfile(member, io.BytesIO(data))
            if extra:
                tar.addfile(extra)
        layer = admission_fixture.put(layout, archive.getvalue(), False)
        layer['mediaType'] = 'application/vnd.oci.image.layer.v1.tar'
        env = ['PATH=/usr/local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
               'LANG=C.UTF-8', 'PYTHON_VERSION=3.14.10',
               'PYTHON_SHA256=de414a57119abef52784d8993e341d53aed635fc2b05c2607d9f98a2c5b72032',
               'PYTHONDONTWRITEBYTECODE=1', 'PYTHONUNBUFFERED=1']
        config = {'architecture': 'amd64', 'os': 'linux',
                  'rootfs': {'type': 'layers', 'diff_ids': [layer['digest']]},
                  'config': {'User': '10001:10001', 'Entrypoint': images.COMMAND, 'Cmd': None,
                             'WorkingDir': '/opt/traderx', 'Env': env,
                             'Labels': images.labels('0' * 40, verified)}}
        if config_change:
            config_change(config)
        descriptor = admission_fixture.put(layout, config)
        descriptor['mediaType'] = 'application/vnd.oci.image.config.v1+json'
        manifest = {'schemaVersion': 2, 'mediaType': 'application/vnd.oci.image.manifest.v1+json',
                    'config': descriptor, 'layers': [layer]}
        descriptor = admission_fixture.put(layout, manifest)
        descriptor['mediaType'] = manifest['mediaType']
        (layout / 'index.json').write_bytes(compiler.encoded({'schemaVersion': 2, 'manifests': [descriptor]}))
        (layout / 'oci-layout').write_bytes(compiler.encoded({'imageLayoutVersion': '1.0.0'}))
        return layout

    def test_context_is_explicit_and_private_interface_fixed(self):
        result = images.prepare(self.source, self.publish, self.report, self.root / 'context', '0' * 40)
        self.assertEqual(result['keys'], sorted(people_runtime.FILES))
        recipe = (self.root / 'context/Dockerfile').read_text()
        for value in ('USER 10001:10001', '/usr/share/dotnet/', 'EXPOSE 18089', 'chmod 0755'):
            self.assertIn(value, recipe)
        self.assertNotIn('COPY . ', recipe)
        self.assertEqual((self.root / 'context/application/MockDirectory/people.json').read_bytes(),
                         (self.source / build.ASSET).read_bytes())
        self.assertEqual(images.COMMAND[-1], '/opt/traderx/people_runtime.py')

    def test_source_publish_fixture_and_report_drift_fail(self):
        self.assertEqual(build.verify(self.source, self.publish, self.report)['status'], build.STATUS)
        dll = self.publish / 'PeopleService.WebApi.dll'
        dll.write_bytes(b'changed')
        with self.assertRaises(ValueError):
            build.verify(self.source, self.publish, self.report)
        dll.write_bytes(self.assembly)
        (self.source / 'unknown.cs').write_text('unexpected')
        with self.assertRaises(ValueError):
            build.verify(self.source, self.publish, self.report)
        (self.source / 'unknown.cs').unlink()
        value = json.loads(self.report.read_text())
        value['fixture']['assembly_sha256'] = '0' * 64
        self.report.write_bytes(compiler.encoded(value))
        with self.assertRaises(ValueError):
            build.verify(self.source, self.publish, self.report)

    def test_extra_publish_assembly_is_bound_and_symlinks_refused(self):
        (self.publish / 'new.dll').write_bytes(b'extra')
        with self.assertRaises(ValueError):
            build.verify(self.source, self.publish, self.report)
        (self.publish / 'new.dll').unlink()
        (self.publish / 'link.dll').symlink_to(self.publish / 'dependency.dll')
        with self.assertRaises(ValueError):
            build.verify(self.source, self.publish, self.report)

    def test_tested_dependency_and_metadata_must_match_publish(self):
        for name in ('dependency.dll', 'PeopleService.WebApi.deps.json',
                     'PeopleService.WebApi.runtimeconfig.json'):
            path = self.source / build.PROJECT / 'bin/Release/net9.0' / name
            original = path.read_bytes()
            path.write_bytes(b'changed')
            with self.subTest(name=name), self.assertRaises(ValueError):
                build.verify(self.source, self.publish, self.report)
            path.write_bytes(original)
        path = self.source / build.PROJECT / 'bin/Release/net9.0/unpublished.dll'
        path.write_bytes(b'extra')
        with self.assertRaises(ValueError):
            build.verify(self.source, self.publish, self.report)
        (self.publish / 'unpublished.dll').write_bytes(b'extra')
        with self.assertRaises(ValueError):
            build.artifacts(self.source, self.publish, self.value['fixture'])

    def test_incomplete_fixture_checks_are_rejected(self):
        fixture = dict(self.value['fixture'])
        fixture['checks'] = ['arbitrary'] * 30
        with self.assertRaises(ValueError):
            build.artifacts(self.source, self.publish, fixture)

    def test_oci_exact_bytes_inventory_and_directories(self):
        self.assertEqual(self.inspect(self.layout())['keys'], sorted(people_runtime.FILES))
        for change in (
                lambda p: p.__setitem__('opt/traderx/PeopleService.WebApi.dll', (b'changed', 0o444)),
                lambda p: p.__setitem__('opt/traderx/MockDirectory/people.json', (b'changed', 0o444)),
                lambda p: p.__setitem__('opt/traderx/extra.py', (b'evil', 0o555)),
                lambda p: p.__setitem__('opt/traderx/dependency.dll', (b'dependency', 0o666)),
                lambda p: p.pop('opt/traderx/people_runtime.py')):
            with self.assertRaises(ValueError):
                self.inspect(self.layout(file_change=change))
        for name, attr, value in (('opt', 'mode', 0o700), ('opt/traderx', 'mode', 0o444),
                                  ('opt/traderx/MockDirectory', 'uid', 10001)):
            def mutate(member):
                if member.name == name:
                    setattr(member, attr, value)
            with self.assertRaises(ValueError):
                self.inspect(self.layout(directory_change=mutate))
        for kind in (tarfile.SYMTYPE, tarfile.LNKTYPE):
            member = tarfile.TarInfo('opt/traderx/MockDirectory')
            member.type, member.linkname = kind, 'elsewhere'
            with self.assertRaises(ValueError):
                self.inspect(self.layout(extra=member))

    def test_oci_environment_commands_labels_and_platform_fail_closed(self):
        for item in ('DOTNET_X=1', 'ASPNETCORE_URLS=http://x', 'LAB_X=1', 'A__B=x',
                     'PYTHONPATH=/evil', 'PYTHONSTARTUP=/evil', 'LD_PRELOAD=/evil',
                     'LD_LIBRARY_PATH=/evil', 'PATH=/evil'):
            with self.subTest(item=item), self.assertRaises(ValueError):
                self.inspect(self.layout(config_change=lambda c: c['config']['Env'].append(item)))
        for mutate in (
                lambda c: c['config'].__setitem__('User', '0:0'),
                lambda c: c['config'].__setitem__('Cmd', ['--unsafe']),
                lambda c: c['config'].__setitem__('Entrypoint', ['/bin/sh']),
                lambda c: c['config'].__setitem__('WorkingDir', '/'),
                lambda c: c['config']['Labels'].__setitem__('traderx.security-lab.port', '80'),
                lambda c: c.__setitem__('architecture', 'arm64')):
            with self.assertRaises(ValueError):
                self.inspect(self.layout(config_change=mutate))

    def test_hosted_guard_rejects_local_execution(self):
        with patch.object(build.portability, 'isolated_linux', return_value=False):
            with self.assertRaisesRegex(ValueError, 'hosted Linux'):
                build.build(self.root)


if __name__ == '__main__':
    unittest.main()
