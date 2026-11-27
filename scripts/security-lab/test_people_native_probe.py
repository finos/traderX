"""Source/build-contract tests only; no .NET compiler or runtime is executed."""
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import build_people_native_probe as probe


class NativeProbeTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.runtime = Path(self.temporary.name).resolve()
        self.root = self.runtime / 'people-native-probe'
        self.commands = []

    def run_command(self, argv, **kwargs):
        self.commands.append((argv, kwargs))
        if argv == ['dotnet', '--version']:
            return subprocess.CompletedProcess(argv, 0, stdout=b'9.0.321\n')
        if argv[1] == 'publish':
            publish = self.root / 'publish'; publish.mkdir()
            for name in probe.ARTIFACTS:
                (publish / name).write_bytes(b'Synthetic unexecuted artifact: ' + name.encode())
        return subprocess.CompletedProcess(argv, 0)

    def build(self):
        with patch.object(probe.portability, 'isolated_linux', return_value=True), \
             patch.dict(probe.os.environ, {'GITHUB_ACTIONS': 'true'}), \
             patch.object(probe.subprocess, 'run', side_effect=self.run_command):
            return probe.build(self.runtime)

    def test_framework_dependent_offline_build_and_readable_mount(self):
        report = self.build()
        self.assertEqual(probe.verify(self.root), report)
        self.assertEqual(report['status'], 'built-native-runtime-not-executed')
        self.assertEqual(set(report['artifacts']), probe.ARTIFACTS)
        self.assertEqual(report['command'], ['/usr/share/dotnet/dotnet', '/run/native-probe/PeopleNativeProbe.dll'])
        restore, publish = self.commands[1][0], self.commands[2][0]
        self.assertIn('--configfile', restore)
        self.assertIn('--no-restore', publish)
        self.assertEqual(publish[publish.index('--self-contained') + 1], 'false')
        self.assertIn('<clear />', (self.root / 'source/NuGet.Config').read_text())
        self.assertNotIn('PackageReference', probe.PROJECT)
        self.assertIn('<UseAppHost>false</UseAppHost>', probe.PROJECT)
        self.assertIn('<InvariantGlobalization>false</InvariantGlobalization>', probe.PROJECT)
        self.assertEqual(json.loads((self.root / 'source/global.json').read_text()),
                         {'sdk': {'version': '9.0.321', 'rollForward': 'disable'}})
        for name in probe.ARTIFACTS:
            self.assertEqual((self.root / 'publish' / name).stat().st_mode & 0o777, 0o644)
        self.assertEqual((self.root / 'publish').stat().st_mode & 0o777, 0o755)

    def test_native_semantics_and_fixed_nonsecret_output(self):
        self.assertIn('GetCultureInfo("tr-TR").TextInfo.ToUpper("i") == "\\u0130"', probe.PROGRAM)
        self.assertIn('1234.5m.ToString("F1", CultureInfo.GetCultureInfo("fr-FR")) == "1234,5"', probe.PROGRAM)
        self.assertIn('if (!turkish || !french) throw', probe.PROGRAM)
        self.assertNotIn('Environment', probe.PROGRAM)
        self.assertNotIn('args', probe.PROGRAM)
        self.assertNotIn('Exception ex', probe.PROGRAM)
        self.assertEqual(probe.SUCCESS, {'status': 'passed', 'turkish_uppercase': True, 'french_decimal': True})

    def test_hosted_only_and_fresh_directory(self):
        with patch.object(probe.portability, 'isolated_linux', return_value=False), \
             patch.object(probe.subprocess, 'run') as run:
            with self.assertRaises(ValueError): probe.build(self.runtime)
            run.assert_not_called()
        self.assertFalse(self.root.exists())
        self.build()
        with self.assertRaises(FileExistsError): self.build()

    def test_source_and_artifact_drift_are_refused(self):
        self.build()
        path = self.root / 'source/Program.cs'
        original = path.read_bytes(); path.write_bytes(original + b'// drift')
        with self.assertRaisesRegex(ValueError, 'source changed'): probe.verify(self.root)
        path.write_bytes(original)
        dll = self.root / 'publish/PeopleNativeProbe.dll'
        dll.write_bytes(b'different')
        with self.assertRaisesRegex(ValueError, 'report or artifacts changed'): probe.verify(self.root)

    def test_extra_file_symlink_and_unreadable_artifact_are_refused(self):
        self.build()
        extra = self.root / 'publish/unapproved.so'; extra.write_bytes(b'x')
        with self.assertRaisesRegex(ValueError, 'inventory'): probe.verify(self.root)
        extra.unlink()
        artifact = self.root / 'publish/PeopleNativeProbe.dll'
        artifact.chmod(0o600)
        with self.assertRaisesRegex(ValueError, 'regular'): probe.verify(self.root)
        artifact.unlink(); artifact.symlink_to(self.root / 'source/Program.cs')
        with self.assertRaisesRegex(ValueError, 'regular'): probe.verify(self.root)

    def test_failure_output_is_sanitized_and_no_report_is_written(self):
        with patch.object(probe.portability, 'isolated_linux', return_value=True), \
             patch.dict(probe.os.environ, {'GITHUB_ACTIONS': 'true'}), \
             patch.object(probe.subprocess, 'run', side_effect=subprocess.CalledProcessError(1, 'private', stderr=b'secret')):
            with self.assertRaisesRegex(RuntimeError, '^Native probe build failed; output withheld$'):
                probe.build(self.runtime)
        self.assertFalse((self.root / 'report.json').exists())

    def test_report_cannot_claim_execution(self):
        self.build()
        path = self.root / 'report.json'; report = json.loads(path.read_text())
        report['status'] = 'passed'; path.write_bytes(probe.encoded(report))
        with self.assertRaisesRegex(ValueError, 'report or artifacts changed'): probe.verify(self.root)


if __name__ == '__main__':
    unittest.main()
