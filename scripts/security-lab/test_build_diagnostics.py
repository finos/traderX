from contextlib import redirect_stdout
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

from build_diagnostics import bounded_text, record_failure, summarize


class BuildDiagnosticsTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name);self.target=self.root/'candidate';self.target.mkdir()
        self.log=self.root/'private.log';self.log.write_text('')

    def test_dependency_failure_emits_fixed_labels_without_urls_secrets_or_paths(self):
        self.log.write_text('> Task :compileJava FAILED\nCould not GET https://user:private-password@private.example/dependency\nserver returned status code 429\n')
        result=summarize('order-matcher',self.target,self.log,subprocess.CalledProcessError(1,['secret-command']))
        self.assertEqual(result['failed_tasks'],['compileJava'])
        self.assertIn('dependency-download',result['categories']);self.assertIn('remote-rate-limit',result['categories'])
        for private in ('private-password','private.example','secret-command',str(self.root)):
            self.assertNotIn(private,json.dumps(result))

    def test_failed_suite_names_require_manifest_verified_source_and_omit_failure_content(self):
        source=self.target/'src/test/java/finos/traderx/security/BoundaryTest.java';source.parent.mkdir(parents=True);source.write_text('trusted test')
        digest=hashlib.sha256(source.read_bytes()).hexdigest()
        (self.target/'security-generation.json').write_text(json.dumps({'files':{str(source.relative_to(self.target)):digest}}))
        tests=self.target/'build/test-results/test';tests.mkdir(parents=True)
        (tests/'TEST-approved.xml').write_text('<testsuite name="finos.traderx.security.BoundaryTest" tests="3" failures="1" errors="0" skipped="0"><testcase name="secret-method"><failure message="private-password">private SQL</failure></testcase></testsuite>')
        (tests/'TEST-untrusted.xml').write_text('<testsuite name="private-secret-name" tests="2" failures="1"/>')
        self.log.write_text('> Task :module:test FAILED\nThere were failing tests\n')
        result=summarize('trade-processor',self.target,self.log,subprocess.CalledProcessError(1,[]))
        self.assertEqual(result['failed_suites'],['finos.traderx.security.BoundaryTest'])
        self.assertEqual(result['tests'],dict(tests=5,failures=2,errors=0,skipped=0))
        self.assertEqual(result['failed_tasks'],['test']);self.assertNotIn('private',json.dumps(result))
        source.write_text('drifted test')
        self.assertEqual(summarize('trade-processor',self.target,self.log,subprocess.CalledProcessError(1,[]))['failed_suites'],[])

    def test_timeout_and_bounded_tail_do_not_leak_subprocess_output(self):
        self.log.write_text('secret-prefix\n'+'x'*140000+'\nGradle build daemon disappeared unexpectedly\n')
        self.assertLessEqual(len(bounded_text(self.log).encode()),131072)
        self.assertNotIn('secret-prefix',bounded_text(self.log))
        error=subprocess.TimeoutExpired(['private-command'],600,output=b'private-output')
        result=summarize('account-service',self.target,self.log,error)
        self.assertTrue(result['timed_out']);self.assertIsNone(result['exit_code'])
        self.assertIn('build-timeout',result['categories']);self.assertIn('gradle-daemon-exit',result['categories'])
        self.assertNotIn('private',json.dumps(result))

    def test_summary_file_and_stdout_have_only_sanitized_schema(self):
        self.log.write_text('SSLHandshakeException: private-token\n')
        stdout=io.StringIO()
        with redirect_stdout(stdout):result=record_failure(self.root,'order-matcher',self.target,self.log,subprocess.CalledProcessError(2,[]))
        saved=json.loads((self.root/'evidence/build-failure-order-matcher.json').read_text())
        self.assertEqual(saved,result);self.assertEqual(json.loads(stdout.getvalue()),result)
        self.assertNotIn('private-token',stdout.getvalue())
        with self.assertRaises(ValueError):summarize('caller-selected-secret',self.target,self.log,Exception())

    def test_symlink_logs_and_malformed_xml_are_not_exported(self):
        link=self.root/'linked.log';link.symlink_to(self.log)
        self.assertEqual(bounded_text(link),'')
        tests=self.target/'build/test-results/test';tests.mkdir(parents=True)
        (tests/'TEST-bad.xml').write_text('<private-password>')
        result=summarize('order-matcher',self.target,self.log,Exception())
        self.assertEqual(result['failed_suites'],[]);self.assertEqual(result['categories'],['unclassified'])


if __name__=='__main__':unittest.main()
