import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import labctl

class LabctlTests(unittest.TestCase):
    def test_existing_certificate_is_not_replaced_or_ca_installed(self):
        with tempfile.TemporaryDirectory() as root:
            tls=Path(root)/'browser-tls';tls.mkdir();(tls/'cert.pem').write_text('existing')
            with patch('labctl.validate_tls') as validate,patch('labctl.run') as run:
                self.assertIn('preserved',labctl.setup_tls(Path(root),True))
                validate.assert_called_once_with(tls);run.assert_not_called()
    def test_reset_requires_explicit_confirmation_before_stop(self):
        with patch('sys.argv',['labctl','reset']),patch('labctl.stop') as stop:
            with self.assertRaisesRegex(ValueError,'confirm-reset'):labctl.main()
            stop.assert_not_called()
    def test_stale_pid_is_not_treated_as_running(self):
        with tempfile.TemporaryDirectory() as root:
            Path(root,'browser-lab.json').write_text(json.dumps({'status':'ready','pid':12,'process_identity':'expected'}))
            with patch('labctl.subprocess.run') as run:
                run.return_value.returncode=0;run.return_value.stdout='unrelated'
                self.assertIsNone(labctl.active(Path(root)))
    def test_start_is_idempotent_for_owned_running_lab(self):
        with patch('labctl.active',return_value={'status':'ready','url':'https://localhost:18447'}),patch('labctl.verify_candidate') as verify:
            labctl.start(Path('/unused'),4);verify.assert_not_called()
    def test_mkcert_trust_install_is_not_implicit(self):
        with tempfile.TemporaryDirectory() as root,patch('labctl.shutil.which',return_value='/bin/mkcert'),patch('labctl.run') as run:
            run.return_value.stdout=str(Path(root)/'missing-ca')
            with self.assertRaisesRegex(ValueError,'install-ca'):labctl.setup_tls(Path(root))
            self.assertEqual(run.call_count,1)
            self.assertEqual(run.call_args.args[0],['mkcert','-CAROOT'])

if __name__=='__main__':unittest.main()
