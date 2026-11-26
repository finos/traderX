import io
import json
from pathlib import Path
import re
import tarfile
import tempfile
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET
import zipfile

import admission_fixture
import build_position_security as build
import integrated_deployment as compiler
import java_images as images
import java_runtime
from render_read_security import render


def synthetic_build(root, role):
    """Small non-executable artifacts for Python binding tests; never Java acceptance."""
    spec=build.role_spec(role)
    generated=root/'generated';build.render_role(generated,role)
    jar=generated/spec['jar'];jar.parent.mkdir(parents=True)
    with zipfile.ZipFile(jar,'w') as archive:
        archive.writestr('META-INF/MANIFEST.MF','Main-Class: org.springframework.boot.loader.launch.JarLauncher\nStart-Class: '+spec['package']+'.'+spec['application']+'\n')
        for name in (spec['application'],*spec['classes']):
            archive.writestr('BOOT-INF/classes/'+spec['package'].replace('.','/')+'/'+name+'.class',b'synthetic-not-bytecode')
    results=generated/'build/test-results/test';results.mkdir(parents=True)
    for name in spec['tests']:
        source=generated/'src/test/java'/spec['package'].replace('.','/')/'security'/(name+'.java')
        methods=re.findall(r'@Test\s+void\s+(\w+)\s*\(',source.read_text())
        classname=spec['package']+'.security.'+name
        suite=ET.Element('testsuite',name=classname,tests=str(len(methods)),failures='0',errors='0',skipped='0')
        for method in methods:ET.SubElement(suite,'testcase',classname=classname,name=method+'()')
        (results/('TEST-'+classname+'.xml')).write_bytes(ET.tostring(suite))
    report=root/'build.json'
    value={'schema_version':1,'service':role,'status':build.STATUS,
           'source_manifest':compiler.source_manifest(),**build.artifacts(generated,role)}
    report.write_bytes(compiler.encoded(value))
    return generated,report,jar


class JavaImageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.generated = self.root / 'generated'
        render(self.generated)
        self.jar = self.generated / build.JAR
        self.jar.parent.mkdir(parents=True)
        with zipfile.ZipFile(self.jar, 'w') as archive:
            archive.writestr('META-INF/MANIFEST.MF', 'Main-Class: org.springframework.boot.loader.launch.JarLauncher\nStart-Class: finos.traderx.positionservice.PositionServiceApplication\n')
            for name in ('PositionServiceApplication', 'security/ReadSecurity', 'security/TradingAccess',
                         'controller/PositionController', 'controller/TradeController'):
                archive.writestr('BOOT-INF/classes/finos/traderx/positionservice/' + name + '.class', b'unit-test-placeholder-not-Java-bytecode')
        results = self.generated / 'build/test-results/test'
        results.mkdir(parents=True)
        for name in ('ReadApiSecurityTest', 'ReadDatabaseAuthorizationTest'):
            source = self.generated / 'src/test/java/finos/traderx/positionservice/security' / (name + '.java')
            methods = re.findall(r'@Test\s+void\s+(\w+)\s*\(', source.read_text())
            classname = 'finos.traderx.positionservice.security.' + name
            suite = ET.Element('testsuite', name=classname, tests=str(len(methods)), failures='0', errors='0', skipped='0')
            for method in methods:
                ET.SubElement(suite, 'testcase', classname=classname, name=method + '()')
            (results / ('TEST-' + classname + '.xml')).write_bytes(ET.tostring(suite))
        self.report = self.root / 'build.json'
        self.write_report()

    def write_report(self):
        self.value = {'schema_version': 1, 'service': images.ROLE, 'status': build.STATUS,
                      'source_manifest': compiler.source_manifest(), **build.artifacts(self.generated)}
        self.report.write_bytes(compiler.encoded(self.value))

    def test_context_exact_jar_sources_and_fixed_nonroot_private_entrypoint(self):
        # Unrelated files outside generated source can never enter the context.
        (self.root / 'credential.json').write_text('unit-private-marker')
        output = self.root / 'context'
        record = images.prepare(self.generated, self.report, output, '0' * 40)
        expected = {'.dockerignore', 'Dockerfile', 'application.jar', 'image-build.json',
                    'source/java_runtime.py', 'source/private_materializer.py', 'source/startup-check.sql'}
        self.assertEqual({p.relative_to(output).as_posix() for p in output.rglob('*') if p.is_file()}, expected)
        self.assertEqual((output / 'source/startup-check.sql').read_bytes(), b'SELECT 1;\n')
        self.assertEqual(record['command'][-6:], ['/usr/local/bin/python', '/opt/traderx/java_runtime.py', '--role', images.ROLE, '--config', str(java_runtime.CONFIG)])
        self.assertEqual(record['keys'], java_runtime.KEYS)
        recipe = (output / 'Dockerfile').read_text()
        self.assertIn('USER 10001:10001', recipe)
        self.assertIn('COPY --from=jre /opt/java/openjdk/ /opt/java/openjdk/', recipe)
        self.assertIn('RUN chmod 0755 /app', recipe)
        self.assertIn('--version', recipe)
        self.assertNotIn('COPY . ', recipe)
        self.assertNotIn('apt-get', recipe)
        self.assertNotIn('pip install', recipe)
        self.assertIn('@sha256:', recipe)
        with self.assertRaises(FileExistsError):
            images.prepare(self.generated, self.report, output, '0' * 40)

    def test_source_manifest_cannot_drop_files_or_add_build_inputs(self):
        source = self.generated / 'security-generation.json'
        value = json.loads(source.read_text())
        value['files'].pop(next(iter(value['files'])))
        source.write_text(json.dumps(value))
        with self.assertRaisesRegex(ValueError, 'canonical renderer'):
            build.verify(self.generated, self.report)

    def test_extra_source_and_symlink_are_rejected(self):
        extra = self.generated / 'src/main/java/Extra.java'
        extra.write_text('class Extra {}')
        with self.assertRaisesRegex(ValueError, 'Unexpected generated'):
            build.generation(self.generated)
        extra.unlink()
        original = self.generated / 'build.gradle'
        moved = self.root / 'gradle'
        original.rename(moved)
        original.symlink_to(moved)
        with self.assertRaisesRegex(ValueError, 'regular'):
            build.generation(self.generated)

    def test_jar_and_report_drift_and_extra_bootjar_fail_closed(self):
        self.jar.write_bytes(self.jar.read_bytes() + b'changed')
        with self.assertRaisesRegex(ValueError, 'report'):
            images.prepare(self.generated, self.report, self.root / 'bad', '0' * 40)
        self.assertFalse((self.root / 'bad').exists())
        (self.jar.parent / 'other.jar').write_bytes(b'unreviewed')
        with self.assertRaisesRegex(ValueError, 'Exactly'):
            build.artifacts(self.generated)

    def test_failed_skipped_or_missing_required_test_cannot_be_accepted(self):
        path = next((self.generated / 'build/test-results/test').glob('TEST-*ReadApiSecurityTest.xml'))
        original = path.read_bytes()
        for mutation in ('skipped', 'failure', 'missing', 'count'):
            suite = ET.fromstring(original)
            if mutation in ('skipped', 'failure'):
                ET.SubElement(suite.find('testcase'), mutation)
            elif mutation == 'missing':
                suite.find('testcase').set('name', 'unexpectedCase()')
            else:
                suite.set('tests', '0')
            path.write_bytes(ET.tostring(suite))
            with self.assertRaises(ValueError):
                build.test_results(self.generated)
        path.write_bytes(original)
        self.assertEqual(build.test_results(self.generated)['totals'], dict(tests=11, failures=0, errors=0, skipped=0))

    def test_wrong_bootjar_entrypoint_or_missing_security_class_is_refused(self):
        with zipfile.ZipFile(self.jar, 'w') as archive:
            archive.writestr('META-INF/MANIFEST.MF', 'Main-Class: unsafe.Main\n')
        self.write_report()
        with self.assertRaisesRegex(ValueError, 'security classes'):
            images.prepare(self.generated, self.report, self.root / 'bad', '0' * 40)

    def layout(self, alter_file=None, alter_config=None, alter_directory=None, role=images.ROLE):
        layout = self.root / ('oci-' + str(len(list(self.root.glob('oci-*')))))
        layout.mkdir()
        source, verified = images.inputs(self.generated, self.report, role=role)
        files = {'app/application.jar': (source['application.jar'], 0o444)}
        files.update({'opt/traderx/' + name.removeprefix('source/'): (data, 0o555)
                      for name, data in source.items() if name.startswith('source/')})
        if alter_file:
            alter_file(files)
        archive = io.BytesIO()
        with tarfile.open(fileobj=archive, mode='w') as tar:
            for name in ('app', 'opt', 'opt/traderx'):
                member = tarfile.TarInfo(name)
                member.type = tarfile.DIRTYPE
                member.mode = 0o755
                if alter_directory:
                    alter_directory(member)
                tar.addfile(member)
            for name, (data, mode) in files.items():
                member = tarfile.TarInfo(name)
                member.size = len(data)
                member.mode = mode
                tar.addfile(member, io.BytesIO(data))
        layer = admission_fixture.put(layout, archive.getvalue(), False)
        layer['mediaType'] = 'application/vnd.oci.image.layer.v1.tar'
        config = {'architecture': 'amd64', 'os': 'linux', 'rootfs': {'type': 'layers', 'diff_ids': [layer['digest']]},
                  'config': {'User': '10001:10001', 'Entrypoint': images.argv(role), 'Cmd': None,
                             'Labels': images.labels('0' * 40, verified, role=role)}}
        if alter_config:
            alter_config(config)
        config_descriptor = admission_fixture.put(layout, config)
        config_descriptor['mediaType'] = 'application/vnd.oci.image.config.v1+json'
        manifest = {'schemaVersion': 2, 'mediaType': 'application/vnd.oci.image.manifest.v1+json',
                    'config': config_descriptor, 'layers': [layer]}
        descriptor = admission_fixture.put(layout, manifest)
        descriptor['mediaType'] = manifest['mediaType']
        (layout / 'index.json').write_bytes(compiler.encoded({'schemaVersion': 2, 'manifests': [descriptor]}))
        (layout / 'oci-layout').write_bytes(compiler.encoded({'imageLayoutVersion': '1.0.0'}))
        return layout

    def test_real_oci_bytes_are_verified_and_bound_to_tested_jar(self):
        layout = self.layout()
        entry = images.inspect(layout, 'local/position-service:unit', '0' * 40, self.generated, self.report)
        self.assertEqual(entry['keys'], images.KEYS)
        self.assertTrue(entry['image'].startswith('local/position-service:unit@sha256:'))
        for mutation in (
            lambda files: files.__setitem__('app/application.jar', (b'changed-but-valid-OCI-hash', 0o444)),
            lambda files: files.__setitem__('opt/traderx/startup-check.sql', (b'DELETE FROM positions;\n', 0o555)),
            lambda files: files.__setitem__('opt/traderx/json.py', (b'unexpected-import', 0o555)),
            lambda files: files.__setitem__('app/application.jar', (self.jar.read_bytes(), 0o666)),
            lambda files: files.pop('app/application.jar')):
            with self.assertRaises(ValueError):
                images.inspect(self.layout(alter_file=mutation), 'local/position-service:unit', '0' * 40, self.generated, self.report)

    def test_oci_parent_directory_traversal_and_ownership_are_required(self):
        # Correct file bytes/mode cannot compensate for an inaccessible parent:
        # this is the actual hosted JVM "Unable to access jarfile" failure.
        for name, attribute, value in (
                ('app', 'mode', 0o444), ('app', 'mode', 0o700),
                ('app', 'uid', 10001), ('app', 'gid', 10001),
                ('opt/traderx', 'mode', 0o666), ('opt', 'mode', 0o777)):
            def mutate(member):
                if member.name == name:
                    setattr(member, attribute, value)
            with self.assertRaisesRegex(ValueError, 'parent directory'):
                images.inspect(self.layout(alter_directory=mutate), 'local/position-service:unit',
                               '0' * 40, self.generated, self.report)

    def test_later_chmod_layer_repairs_implicit_copy_parent_mode(self):
        layout = self.layout(alter_directory=lambda member: setattr(member, 'mode', 0o444)
                             if member.name == 'app' else None)
        manifest = compiler.blob(layout, compiler.read_json(layout / 'index.json')['manifests'][0])
        archive = io.BytesIO()
        with tarfile.open(fileobj=archive, mode='w') as tar:
            member = tarfile.TarInfo('app')
            member.type = tarfile.DIRTYPE
            member.mode = 0o755
            tar.addfile(member)
        repaired = admission_fixture.put(layout, archive.getvalue(), False)
        repaired['mediaType'] = 'application/vnd.oci.image.layer.v1.tar'
        manifest['layers'].append(repaired)
        files, verified = images.inputs(self.generated, self.report)
        expected = {'app/application.jar': (verified['jar']['sha256'], 0o444)}
        expected.update({'opt/traderx/' + name.removeprefix('source/'): (compiler.sha(data), 0o555)
                         for name, data in files.items() if name.startswith('source/')})
        images.filesystem(layout, manifest, expected)

    def test_wrong_oci_labels_platform_uid_and_entrypoint_rejected(self):
        for mutation in (
            lambda cfg: cfg['config']['Labels'].__setitem__('traderx.security-lab.jar-sha256', '1' * 64),
            lambda cfg: cfg.__setitem__('architecture', 'arm64'),
            lambda cfg: cfg['config'].__setitem__('User', '0:0'),
            lambda cfg: cfg['config'].__setitem__('Entrypoint', ['/usr/bin/java', '-jar', '/app/application.jar'])):
            with self.assertRaises(ValueError):
                images.inspect(self.layout(alter_config=mutation), 'local/position-service:unit', '0' * 40, self.generated, self.report)

    def test_hosted_build_guard_refuses_local_work_without_subprocess(self):
        with patch.object(build.portability, 'isolated_linux', return_value=False), patch.object(build.subprocess, 'run') as run:
            with self.assertRaisesRegex(ValueError, 'hosted'):
                build.build(self.root / 'runtime', Path('/not-java'))
            run.assert_not_called()

    def test_additional_roles_bind_their_own_source_tests_jar_entrypoint_and_private_keys(self):
        for role in ('account-service','trade-processor'):
            root=self.root/role;root.mkdir()
            self.generated,self.report,self.jar=synthetic_build(root,role)
            contract=java_runtime.role_contract(role)
            record=images.prepare(self.generated,self.report,root/'context','0'*40,role=role)
            self.assertEqual(record['role'],role)
            self.assertEqual(record['keys'],contract['keys'])
            self.assertEqual(record['command'][-3],role)
            self.assertIn('EXPOSE '+str(contract['port']),(root/'context/Dockerfile').read_text())
            self.assertEqual(build.test_results(self.generated,role)['totals']['tests'],build.SPECS[role]['minimum_tests'])
            layout=self.layout(role=role)
            entry=images.inspect(layout,'local/'+role,'0'*40,self.generated,self.report,role=role)
            self.assertEqual(entry['secret'],'private-'+role)
            self.assertEqual(entry['keys'],contract['keys'])
            # Even hash-consistent metadata cannot substitute another role's
            # launch contract, test evidence or build report.
            def wrong_role(config):config['config']['Entrypoint'][-3]='position-service'
            with self.assertRaisesRegex(ValueError,'adapter'):
                images.inspect(self.layout(role=role,alter_config=wrong_role),'local/'+role,'0'*40,self.generated,self.report,role=role)
            with self.assertRaises(ValueError):build.verify(self.generated,self.report,role='position-service')
            test=next((self.generated/'build/test-results/test').glob('TEST-*.xml'))
            suite=ET.fromstring(test.read_bytes());suite.find('testcase').set('classname','foreign.role.Test')
            test.write_bytes(ET.tostring(suite))
            with self.assertRaisesRegex(ValueError,'required|Required'):build.test_results(self.generated,role)

    def test_arbitrary_build_role_and_cross_role_jar_are_not_accepted(self):
        for role in ('order-matcher','arbitrary',None):
            with self.assertRaisesRegex(ValueError,'Reviewed'):build.role_spec(role)
            with self.assertRaisesRegex(ValueError,'Reviewed'):images.argv(role)
        root=self.root/'processor';root.mkdir()
        generated,report,jar=synthetic_build(root,'trade-processor')
        jar.write_bytes(self.jar.read_bytes())
        with self.assertRaisesRegex(ValueError,'security classes'):images.jar_bytes(generated,'trade-processor')


if __name__ == '__main__':
    unittest.main()
