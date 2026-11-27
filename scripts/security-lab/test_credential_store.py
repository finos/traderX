import contextlib
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import credential_store as store


class CredentialStoreTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / 'sql-identities'

    def test_create_reuse_and_refuse_replacement(self):
        store.create(self.path)
        original = store.load(self.path)
        with self.assertRaises(FileExistsError):
            store.create(self.path)
        self.assertEqual(original, store.load(self.path))
        self.assertEqual(0o600, (self.path/'identities.json').stat().st_mode & 0o777)

    def test_incomplete_store_never_reinitialized(self):
        self.path.mkdir(mode=0o700)
        with self.assertRaises(ValueError): store.load(self.path)
        with self.assertRaises(FileExistsError): store.create(self.path)

    def test_symlink_directory_and_file_rejected(self):
        store.create(self.path)
        alias = self.path.parent/'alias'
        alias.symlink_to(self.path)
        with self.assertRaises(OSError): store.load(alias)
        source = self.path/'identities.json'
        moved = self.path.parent/'saved'
        source.rename(moved)
        source.symlink_to(moved)
        with self.assertRaises(OSError): store.load(self.path)

    def test_permissions_and_hardlinks_rejected(self):
        store.create(self.path)
        source = self.path/'identities.json'
        source.chmod(0o644)
        with self.assertRaises(ValueError): store.load(self.path)
        source.chmod(0o600)
        os.link(source, self.path.parent/'extra-link')
        with self.assertRaises(ValueError): store.load(self.path)

    def test_corruption_and_extra_files_rejected(self):
        store.create(self.path)
        source = self.path/'identities.json'
        original = source.read_bytes()
        value = json.loads(original)
        value['payload']['runtime']['account-service']['password'] = 'a'*48
        source.write_text(json.dumps(value))
        with self.assertRaises(ValueError): store.load(self.path)
        source.write_bytes(original)
        (self.path/'unexpected').touch()
        with self.assertRaises(ValueError): store.load(self.path)

    def test_changed_contract_refuses_reuse(self):
        store.create(self.path)
        with patch.object(store, 'contract', return_value='changed'):
            with self.assertRaises(ValueError): store.load(self.path)

    def test_parent_must_be_private(self):
        self.path.parent.chmod(0o755)
        with self.assertRaises(ValueError): store.create(self.path)
        self.assertFalse(self.path.exists())

    def test_bootstrap_adapter_reuses_verified_identities(self):
        store.create(self.path)
        identities = store.load(self.path)
        with patch.object(store.bootstrap_database, 'pinned_reference', return_value={'test': True}), patch.object(store.bootstrap_database, 'render', return_value='private SQL') as render:
            self.assertEqual('private SQL', store.bootstrap_sql(self.path))
            render.assert_called_once_with({'test': True}, identities['runtime'])
        self.assertEqual(identities, store.load(self.path))

    def test_cli_never_prints_credentials(self):
        stdout = io.StringIO()
        with patch('sys.argv', ['credential_store', 'create', '--store', str(self.path)]), contextlib.redirect_stdout(stdout):
            store.main()
        self.assertEqual('Private SQL identities verified; no credentials displayed.\n', stdout.getvalue())
        for entry in store.load(self.path)['runtime'].values():
            self.assertNotIn(entry['password'], stdout.getvalue())
