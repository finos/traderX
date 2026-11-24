import contextlib
import io
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import checkpoint
import state_candidate as candidate


class CandidateTests(unittest.TestCase):
    def arguments(self, action):
        args=[action]
        if action!='stop':args+=['--checkpoint','/reviewed artifacts']
        for name in candidate.RUNTIME_ARGS:args+=['--'+name,'explicit '+name]
        if action=='test':args+=['--output','/private evidence/result.json']
        return candidate.parser().parse_args(args)

    def test_modified_bundle_cannot_start_or_test(self):
        for action in ('start','test'):
            with self.subTest(action=action),patch.object(checkpoint,'verify',side_effect=ValueError('drift')),patch.object(candidate.subprocess,'run') as run:
                with self.assertRaises(ValueError):candidate.execute(self.arguments(action))
                run.assert_not_called()

    def test_verified_dispatch_preserves_explicit_paths_without_shell(self):
        for action in ('start','test'):
            with self.subTest(action=action),patch.object(checkpoint,'verify') as verify,patch.object(candidate.subprocess,'run') as run:
                candidate.execute(self.arguments(action))
                verify.assert_called_once_with(Path('/reviewed artifacts'))
                command=run.call_args.args[0]
                self.assertEqual(command[:3],[sys.executable,str(candidate.SCRIPT),action])
                self.assertIn('explicit cluster-uid',command)
                self.assertIn('explicit kubeconfig',command)
                self.assertEqual(run.call_args.kwargs,{'check':True})
                if action=='test':self.assertEqual(command[-2:],['--output','/private evidence/result.json'])

    def test_stop_does_not_depend_on_broken_artifacts(self):
        with patch.object(checkpoint,'verify',side_effect=ValueError('drift')) as verify,patch.object(candidate.subprocess,'run') as run:
            candidate.execute(self.arguments('stop'))
            verify.assert_not_called();run.assert_called_once()

    def test_runtime_identity_never_defaulted(self):
        with contextlib.redirect_stderr(io.StringIO()),self.assertRaises(SystemExit):
            candidate.parser().parse_args(['start','--checkpoint','out'])

    def test_help_from_unrelated_working_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            result=subprocess.run([sys.executable,str(Path(candidate.__file__).resolve()),'--help'],cwd=directory,capture_output=True,text=True,check=True)
        self.assertIn('fetch-baseline',result.stdout)

    def test_local_lifecycle_dependencies_are_hashed(self):
        paths=checkpoint.source_paths()
        for name in ('state_candidate','state_lifecycle','verify_telemetry_lifecycle','verify_trading_lifecycle','resource_operation','resource_preflight'):
            self.assertIn('scripts/security-lab/'+name+'.py',paths)
        self.assertEqual(paths,sorted(set(paths)))

    def test_plan_is_read_only(self):
        with patch.object(checkpoint,'verify'),patch.object(candidate.subprocess,'run') as run,contextlib.redirect_stdout(io.StringIO()) as output:
            candidate.execute(candidate.parser().parse_args(['plan','--checkpoint','out']))
            run.assert_not_called();self.assertIn('not a direct kubectl apply',output.getvalue())
