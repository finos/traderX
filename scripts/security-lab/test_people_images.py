"""Synthetic unit tests; these do not constitute a real .NET or image run."""
import io
import gzip
import json
from pathlib import Path
import struct
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

    def layout(self, file_change=None, directory_change=None, config_change=None, extra=None,
               runtime_change=None):
        layout = self.root / ('oci-' + str(len(list(self.root.glob('oci-*')))))
        layout.mkdir()
        files, verified = images.inputs(self.source, self.publish, self.report)
        paths = {'opt/traderx/' + name.split('/', 1)[1]:
                 (data, 0o444 if name.startswith('application/') else 0o555)
                 for name, data in files.items()}
        if file_change:
            file_change(paths)
        elf = bytearray(4096)
        elf[:16] = b'\x7fELF\x02\x01\x01' + b'\0' * 9
        struct.pack_into('<HHIQQQIHHHHHH', elf, 16, 3, 62, 1, 4096, 64, 0, 0, 64, 56, 2, 0, 0, 0)
        struct.pack_into('<IIQQQQQQ', elf, 64, 1, 5, 0, 0, 0, len(elf), len(elf), 4096)
        struct.pack_into('<IIQQQQQQ', elf, 120, 3, 4, 512, 0, 0, 28, 28, 1)
        elf = bytes(elf)  # Deliberately synthetic; never executed.
        runtime = {}
        for name in ('usr', 'usr/local', 'usr/local/bin', 'usr/share', 'usr/share/dotnet',
                     'usr/lib', images.NATIVE_DIR):
            member = tarfile.TarInfo(name)
            member.type, member.mode = tarfile.DIRTYPE, 0o755
            runtime[name] = (member, b'')
        for name, target in (('usr/local/bin/python', 'python3'),
                             ('usr/local/bin/python3', 'python3.14')):
            member = tarfile.TarInfo(name)
            member.type, member.linkname, member.mode = tarfile.SYMTYPE, target, 0o777
            runtime[name] = (member, b'')
        for name in ('usr/local/bin/python3.14', 'usr/share/dotnet/dotnet'):
            member = tarfile.TarInfo(name)
            member.size, member.mode = len(elf), 0o755
            runtime[name] = (member, elf)
        for target in images.NATIVE_LIBRARIES.values():
            name = images.NATIVE_DIR + '/' + target
            member = tarfile.TarInfo(name)
            member.size, member.mode = len(elf), 0o444
            runtime[name] = (member, elf)
        if runtime_change:
            runtime_change(runtime)
        archive = io.BytesIO()
        with tarfile.open(fileobj=archive, mode='w') as tar:
            for name in ('opt', 'opt/traderx', 'opt/traderx/MockDirectory'):
                member = tarfile.TarInfo(name)
                member.type, member.mode = tarfile.DIRTYPE, 0o755
                if directory_change:
                    directory_change(member)
                tar.addfile(member)
            for member, data in runtime.values():
                tar.addfile(member, io.BytesIO(data) if member.isfile() else None)
            for name, (data, mode) in paths.items():
                member = tarfile.TarInfo(name)
                member.size, member.mode = len(data), mode
                tar.addfile(member, io.BytesIO(data))
            if extra:
                for member in extra if isinstance(extra, list) else [extra]:
                    tar.addfile(member, io.BytesIO(b'x' * member.size) if member.isfile() else None)
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

    def add_layer(self, layout, members, *, compressed=False, wrong_diff=False):
        archive = io.BytesIO()
        with tarfile.open(fileobj=archive, mode='w') as tar:
            for entry in members:
                member, data = entry if isinstance(entry, tuple) else (entry, b'x' * entry.size)
                tar.addfile(member, io.BytesIO(data) if member.isfile() else None)
        raw = archive.getvalue()
        layer = admission_fixture.put(layout, gzip.compress(raw) if compressed else raw, False)
        layer['mediaType'] = ('application/vnd.oci.image.layer.v1.tar+gzip' if compressed
                              else 'application/vnd.oci.image.layer.v1.tar')
        index = compiler.read_json(layout / 'index.json')
        manifest = compiler.blob(layout, index['manifests'][0])
        config = compiler.blob(layout, manifest['config'])
        manifest['layers'].append(layer)
        # A digest omitting only trailing tar padding still must not validate.
        config['rootfs']['diff_ids'].append('sha256:' + compiler.sha(raw[:-512] if wrong_diff else raw))
        config_descriptor = admission_fixture.put(layout, config)
        config_descriptor['mediaType'] = 'application/vnd.oci.image.config.v1+json'
        manifest['config'] = config_descriptor
        descriptor = admission_fixture.put(layout, manifest)
        descriptor['mediaType'] = manifest['mediaType']
        index['manifests'] = [descriptor]
        (layout / 'index.json').write_bytes(compiler.encoded(index))

    @staticmethod
    def member(name, size=0):
        member = tarfile.TarInfo(name)
        member.mode, member.size = 0o444, size
        return member

    @staticmethod
    def symlink(name, target):
        member = tarfile.TarInfo(name)
        member.type, member.linkname, member.mode = tarfile.SYMTYPE, target, 0o777
        return member

    def test_context_is_explicit_and_private_interface_fixed(self):
        result = images.prepare(self.source, self.publish, self.report, self.root / 'context', '0' * 40)
        self.assertEqual(result['keys'], sorted(people_runtime.FILES))
        recipe = (self.root / 'context/Dockerfile').read_text()
        for value in ('USER 10001:10001', '/usr/share/dotnet/', 'EXPOSE 18089', 'chmod 0755'):
            self.assertIn(value, recipe)
        self.assertIn('aspnet:9.0-bookworm-slim@sha256:a60942190e73c283ebb767e76f847ec2a442a6d31795f9d335aa939557555249', recipe)
        self.assertEqual(result['native_libraries'], images.NATIVE_LIBRARIES)
        for source, target in images.NATIVE_LIBRARIES.items():
            self.assertIn(f'COPY --from=dotnet --chmod=0444 {source} /{images.NATIVE_DIR}/{target}', recipe)
            self.assertIn('/' + images.NATIVE_DIR + '/' + target,
                          next(line for line in recipe.splitlines() if line.startswith('RUN rm -f ')))
        self.assertLess(recipe.index('RUN rm -f '), recipe.index('COPY --from=dotnet --chmod=0444'))
        self.assertNotIn('DOTNET_', recipe)
        self.assertNotIn('ASPNETCORE_', recipe)
        self.assertNotIn('COPY . ', recipe)
        self.assertEqual((self.root / 'context/application/MockDirectory/people.json').read_bytes(),
                         (self.source / build.ASSET).read_bytes())
        self.assertEqual(images.COMMAND[-1], '/opt/traderx/people_runtime.py')

    def test_sdk_empty_static_manifests_allow_only_build_publish_marker(self):
        built = (self.source / build.DLL).parent / build.STATIC_ENDPOINTS
        published = self.publish / build.STATIC_ENDPOINTS
        built.write_bytes(compiler.encoded({'Version': 1, 'ManifestType': 'Build', 'Endpoints': []}))
        accepted = {'Version': 1, 'ManifestType': 'Publish', 'Endpoints': []}
        published.write_bytes(compiler.encoded(accepted))
        value = build.artifacts(self.source, self.publish, self.value['fixture'])
        self.assertEqual(value['publish_files'][build.STATIC_ENDPOINTS], compiler.sha(published.read_bytes()))
        for invalid in ({**accepted, 'Endpoints': [{'Route': '/unexpected'}]},
                        {**accepted, 'Version': 2}, {**accepted, 'ManifestType': 'Build'},
                        {**accepted, 'Unknown': True}):
            published.write_bytes(compiler.encoded(invalid))
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                build.artifacts(self.source, self.publish, self.value['fixture'])
        published.write_bytes(compiler.encoded(accepted))
        (self.publish / 'dependency.dll').write_bytes(b'changed dependency')
        with self.assertRaisesRegex(ValueError, 'differ from loopback build'):
            build.artifacts(self.source, self.publish, self.value['fixture'])

    def test_native_libraries_are_required_regular_safe_amd64(self):
        for target in images.NATIVE_LIBRARIES.values():
            name = images.NATIVE_DIR + '/' + target
            with self.subTest(target=target), self.assertRaises(ValueError):
                self.inspect(self.layout(runtime_change=lambda paths: paths.pop(name)))
            for mode in (0o666, 0o555):
                def change(paths):
                    paths[name][0].mode = mode
                with self.subTest(target=target, mode=mode), self.assertRaises(ValueError):
                    self.inspect(self.layout(runtime_change=change))
            def link(paths):
                member = paths[name][0]
                member.type, member.linkname, member.size = tarfile.SYMTYPE, 'elsewhere', 0
                paths[name] = (member, b'')
            with self.subTest(target=target, link=True), self.assertRaises(ValueError):
                self.inspect(self.layout(runtime_change=link))
            def wrong_elf(paths):
                member, data = paths[name]
                paths[name] = (member, b'\0' * len(data))
            with self.subTest(target=target, elf=True), self.assertRaises(ValueError):
                self.inspect(self.layout(runtime_change=wrong_elf))

    def test_native_inventory_and_lock_label_are_bound(self):
        layout = self.layout()
        lock = images.runtime_lock()
        with patch.object(images, 'runtime_lock', return_value={**lock, 'native_libraries': {}}):
            with self.assertRaises(ValueError):
                self.inspect(layout)
        path = self.root / 'bad-lock.json'
        path.write_bytes(compiler.encoded({**lock, 'native_libraries': {}}))
        with patch.object(images, 'LOCK', path), self.assertRaises(ValueError):
            images.runtime_lock()

    def test_web_config_is_recorded_but_not_packaged(self):
        path = self.publish / 'web.config'
        path.write_bytes(b'published IIS configuration')
        self.value.update(build.artifacts(self.source, self.publish, self.value['fixture']))
        self.report.write_bytes(compiler.encoded(self.value))
        record = images.prepare(self.source, self.publish, self.report, self.root / 'context', '0' * 40)
        self.assertIn('web.config', self.value['publish_inventory'])
        self.assertNotIn('web.config', self.value['publish_files'])
        self.assertNotIn('application/web.config', record['context_files'])
        path.write_bytes(b'changed')
        with self.assertRaises(ValueError):
            build.verify(self.source, self.publish, self.report)

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

    def test_whiteout_only_removes_lower_layer_entries(self):
        extra = self.member('opt/traderx/extra.py', 1)
        whiteout = self.member('opt/traderx/.wh.extra.py')
        lower = self.layout(extra=extra)
        self.add_layer(lower, [whiteout])
        self.inspect(lower)
        for members in ([extra, whiteout], [whiteout, extra]):
            layout = self.layout()
            self.add_layer(layout, members)
            with self.assertRaises(ValueError):
                self.inspect(layout)
        files, _ = images.inputs(self.source, self.publish, self.report)
        directory = tarfile.TarInfo('opt/traderx/MockDirectory')
        directory.type, directory.mode = tarfile.DIRTYPE, 0o755
        replacements = [directory]
        for name, data in files.items():
            path = 'opt/traderx/' + name.split('/', 1)[1]
            member = self.member(path, len(data))
            member.mode = 0o444 if name.startswith('application/') else 0o555
            replacements.append((member, data))
        opaque = self.member('opt/traderx/.wh..wh..opq')
        layout = self.layout(extra=extra)
        self.add_layer(layout, replacements + [opaque])
        self.inspect(layout)
        for added in (replacements + [extra, opaque], [opaque, extra] + replacements):
            layout = self.layout()
            self.add_layer(layout, added)
            with self.assertRaises(ValueError):
                self.inspect(layout)

    def test_alias_ancestors_are_tracked_across_all_paths_and_layers(self):
        for target in ('/opt/traderx', '/usr/share/dotnet', '/usr/local/bin'):
            alias = self.symlink('untracked-alias', target)
            layout = self.layout(extra=alias)
            self.inspect(layout)  # A symlink alone, including Python's chain, is permitted.
            self.add_layer(layout, [self.member('untracked-alias/injected', 1)])
            with self.subTest(target=target), self.assertRaisesRegex(ValueError, 'symlink ancestor'):
                self.inspect(layout)
            for members in ([alias, self.member('untracked-alias/injected', 1)],
                            [self.member('untracked-alias/injected', 1), alias]):
                layout = self.layout()
                self.add_layer(layout, members)
                with self.assertRaisesRegex(ValueError, 'symlink ancestor'):
                    self.inspect(layout)
        for marker in ('untracked-alias/.wh.injection', 'untracked-alias/.wh..wh..opq'):
            layout = self.layout(extra=self.symlink('untracked-alias', '/opt/traderx'))
            self.add_layer(layout, [self.member(marker)])
            with self.subTest(marker=marker), self.assertRaisesRegex(ValueError, 'symlink ancestor'):
                self.inspect(layout)
            layout = self.layout()
            self.add_layer(layout, [self.member(marker), self.symlink('untracked-alias', '/opt/traderx')])
            with self.assertRaisesRegex(ValueError, 'symlink ancestor'):
                self.inspect(layout)

    def test_whiteout_can_remove_alias_before_new_directory_entries(self):
        for order in (False, True):
            layout = self.layout(extra=self.symlink('untracked-alias', '/opt/traderx'))
            directory = tarfile.TarInfo('untracked-alias')
            directory.type, directory.mode = tarfile.DIRTYPE, 0o755
            whiteout = self.member('.wh.untracked-alias')
            additions = [directory, self.member('untracked-alias/unrelated', 1)]
            self.add_layer(layout, additions + [whiteout] if order else [whiteout] + additions)
            self.inspect(layout)

    def test_hardlink_cannot_use_symlink_target_or_ancestor(self):
        for target in ('untracked-alias', 'untracked-alias/people_runtime.py'):
            hardlink = tarfile.TarInfo('unrelated-hardlink')
            hardlink.type, hardlink.linkname = tarfile.LNKTYPE, target
            test_layout = self.layout(extra=self.symlink('untracked-alias', '/opt/traderx'))
            self.add_layer(test_layout, [hardlink])
            with self.subTest(target=target), self.assertRaisesRegex(ValueError, 'hardlink traverses'):
                self.inspect(test_layout)

    def test_hardlink_cannot_alias_protected_application_or_runtime_files(self):
        for target in ('opt/traderx/people_runtime.py', 'opt/traderx/MockDirectory/people.json',
                       'usr/share/dotnet/dotnet', 'usr/local/bin/python3.14',
                       'usr/share/dotnet/shared/Microsoft.NETCore.App/runtime.dll'):
            alias = tarfile.TarInfo('untracked-hardlink')
            alias.type, alias.linkname, alias.mode = tarfile.LNKTYPE, target, 0o777
            indirect = tarfile.TarInfo('another-hardlink')
            indirect.type, indirect.linkname = tarfile.LNKTYPE, 'untracked-hardlink'
            for members in ([alias], [alias, indirect], [indirect, alias]):
                layout = self.layout()
                self.add_layer(layout, members)
                with self.subTest(target=target), self.assertRaisesRegex(ValueError, 'protected path'):
                    self.inspect(layout)
        protected_alias = tarfile.TarInfo('usr/share/dotnet/shared/alias')
        protected_alias.type, protected_alias.linkname = tarfile.LNKTYPE, 'unrelated-file'
        layout = self.layout()
        self.add_layer(layout, [self.member('unrelated-file', 1), protected_alias])
        with self.assertRaisesRegex(ValueError, 'protected path'):
            self.inspect(layout)
        benign = tarfile.TarInfo('unrelated-link')
        benign.type, benign.linkname = tarfile.LNKTYPE, 'unrelated-file'
        layout = self.layout()
        self.add_layer(layout, [self.member('unrelated-file', 1), benign])
        self.inspect(layout)

    def test_actual_uncompressed_layer_digest_for_tar_and_gzip(self):
        for compressed in (False, True):
            layout = self.layout()
            self.add_layer(layout, [self.member('unrelated', 1)], compressed=compressed)
            self.inspect(layout)
            layout = self.layout()
            self.add_layer(layout, [self.member('unrelated', 1)], compressed=compressed, wrong_diff=True)
            with self.subTest(compressed=compressed), self.assertRaisesRegex(ValueError, 'uncompressed layer digest'):
                self.inspect(layout)

    def test_many_unrelated_paths_use_indexed_removal_without_scanning(self):
        class NoScan(dict):
            def __iter__(self):
                raise AssertionError('Full index scan')

            def items(self):
                raise AssertionError('Full index scan')

            def values(self):
                raise AssertionError('Full index scan')

        index = images.PathInventory()
        for number in range(5000):
            index.put('unrelated-%05d/leaf' % number, True)
        index.put('selected', True)
        index.put('selected/child', True)
        index.put('selected/nested/child', True)
        index.items = NoScan(index.items)
        index.descendants = NoScan(index.descendants)
        for number in range(5000):
            index.remove('different-%05d' % number, include_self=False)
        index.remove('selected', include_self=False)
        self.assertIn('selected', index)
        self.assertNotIn('selected/child', index)
        self.assertNotIn('selected/nested/child', index)
        self.assertEqual(len(index), 5001)
        self.assertIn('unrelated-00001/leaf', index)
        index.remove('selected', include_self=True)
        self.assertNotIn('selected', index)
        self.assertEqual(len(index), 5000)
        index.remove('.', include_self=False)
        self.assertEqual(len(index), 0)
        self.assertEqual(index.references, 0)

    def test_many_unrelated_symlinks_are_valid_and_index_is_bounded(self):
        members = [self.symlink('alias-%05d' % n, '/opt/traderx') for n in range(3000)]
        members += [self.member('ordinary-%05d' % n, 1) for n in range(3000)]
        self.inspect(self.layout(extra=members))
        with patch.object(images.PathInventory, 'LIMIT', 2):
            index = images.PathInventory()
            index.put('a', True)
            index.put('b', True)
            with self.assertRaisesRegex(ValueError, 'index exceeds bound'):
                index.put('c', True)
        with patch.object(images.PathInventory, 'REFERENCE_LIMIT', 2):
            index = images.PathInventory()
            with self.assertRaisesRegex(ValueError, 'index exceeds bound'):
                index.put('a/b/c/d', True)
            self.assertEqual(len(index), 0)

    def test_aggregate_index_byte_budget_bounds_deep_distinct_paths(self):
        budget = images.IndexBudget()
        state = images.PathInventory(budget)
        links = images.PathInventory(budget)
        for number in range(200):
            part = '%04dabcdefghijk' % number
            name = '/'.join([part] * 255 + ['leaf%04d' % number])
            self.assertLessEqual(len(name), 4096)
            self.assertEqual(len(name.split('/')), 256)
            try:
                (state if number % 2 == 0 else links).put(name, True)
            except ValueError as error:
                self.assertIn('aggregate path index bytes', str(error))
                break
        else:
            self.fail('Deep paths must exhaust the shared byte budget')
        self.assertGreater(len(state), 0)
        self.assertGreater(len(links), 0)
        self.assertLessEqual(budget.used, budget.BYTE_LIMIT)
        self.assertEqual(budget.used, state.bytes_used + links.bytes_used)
        state.remove('.', include_self=False)
        self.assertEqual(budget.used, links.bytes_used)
        links.remove('.', include_self=False)
        self.assertEqual(budget.used, 0)

    def test_layer_path_names_also_consume_shared_byte_budget(self):
        names = [self.symlink(('name-%03d-' % n) + 'x' * 180, '/opt/traderx') for n in range(100)]
        layout = self.layout(extra=names)
        with patch.object(images.IndexBudget, 'BYTE_LIMIT', 8000):
            with self.assertRaisesRegex(ValueError, 'aggregate path index bytes'):
                self.inspect(layout)

    def test_many_application_whiteouts_remove_only_indexed_entries(self):
        names = ['extra-%04d' % n for n in range(3000)]
        lower = self.layout(extra=[self.member('opt/traderx/' + name, 1) for name in names])
        with self.assertRaisesRegex(ValueError, 'inventory'):
            self.inspect(lower)
        self.add_layer(lower, [self.member('opt/traderx/.wh.' + name) for name in names])
        self.inspect(lower)

    def test_runtime_executables_and_ancestors_are_required_and_safe(self):
        for name in ('usr/local/bin/python', 'usr/local/bin/python3', 'usr/local/bin/python3.14',
                     'usr/share/dotnet/dotnet', 'usr', 'usr/local', 'usr/local/bin',
                     'usr/share', 'usr/share/dotnet'):
            with self.subTest(missing=name), self.assertRaises(ValueError):
                self.inspect(self.layout(runtime_change=lambda paths: paths.pop(name)))
        for name, attr, value in (
                ('usr/local/bin/python3.14', 'mode', 0o777),
                ('usr/share/dotnet/dotnet', 'mode', 0o644),
                ('usr/share/dotnet/dotnet', 'uid', 10001),
                ('usr/local/bin/python', 'uid', 10001),
                ('usr/share', 'mode', 0o700),
                ('usr/local/bin', 'gid', 10001),
                ('usr/local/bin/python', 'linkname', '../../evil'),
                ('usr/local/bin/python3', 'linkname', 'python3')):
            def mutate(paths):
                setattr(paths[name][0], attr, value)
            with self.subTest(name=name, attr=attr), self.assertRaises(ValueError):
                self.inspect(self.layout(runtime_change=mutate))
        for name in ('usr/local/bin/python3.14', 'usr/share/dotnet/dotnet', 'usr/local/bin'):
            def replace(paths):
                member = paths[name][0]
                member.type, member.linkname, member.size = tarfile.LNKTYPE, 'elsewhere', 0
                paths[name] = (member, b'')
            with self.subTest(hardlink=name), self.assertRaises(ValueError):
                self.inspect(self.layout(runtime_change=replace))
        def non_elf(paths):
            member = paths['usr/share/dotnet/dotnet'][0]
            member.size = 3
            paths[member.name] = (member, b'bad')
        with self.assertRaises(ValueError):
            self.inspect(self.layout(runtime_change=non_elf))
        def dotnet_symlink(paths):
            member = paths['usr/share/dotnet/dotnet'][0]
            member.type, member.linkname, member.size = tarfile.SYMTYPE, 'elsewhere', 0
            paths[member.name] = (member, b'')
        with self.assertRaises(ValueError):
            self.inspect(self.layout(runtime_change=dotnet_symlink))

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
