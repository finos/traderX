import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from render_account_security import render,read_only_controller


class AccountSecurityGenerationTests(unittest.TestCase):
    def test_read_only_profile_eliminates_people_calls_and_preserves_scoped_reads(self):
        with tempfile.TemporaryDirectory() as temp:
            first=Path(temp)/'one';second=Path(temp)/'two';render(first);render(second)
            self.assertEqual((first/'security-generation.json').read_bytes(),(second/'security-generation.json').read_bytes())
            package=first/'src/main/java/finos/traderx/accountservice'
            self.assertFalse((package/'service/PeopleValidationService.java').exists())
            for name in ('AccountController','AccountUserController'):
                source=(package/'controller'/f'{name}.java').read_text()
                for absent in ('PeopleValidationService','PostMapping','PutMapping','RequestBody','upsertAccount'):
                    self.assertNotIn(absent,source)
                self.assertIn('accountAccess.requireAccount(id)',source)
                self.assertIn('var allowed = accountAccess.accounts()',source)
                self.assertEqual(source.count('@GetMapping'),2)
                with self.assertRaises(ValueError):read_only_controller(source,name=='AccountUserController')
            self.assertNotIn('people.service.url',(first/'src/main/resources/application.properties').read_text())
            security=(package/'security/AccountSecurity.java').read_text()
            self.assertIn('.anyRequest().denyAll()',security)
            manifest=json.loads((first/'security-generation.json').read_text())
            for name,digest in manifest['files'].items():self.assertEqual(hashlib.sha256((first/name).read_bytes()).hexdigest(),digest)


if __name__=='__main__':unittest.main()
