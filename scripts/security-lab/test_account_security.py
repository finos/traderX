import unittest
from render_account_security import secure_controller, ROOT, PROFILE
import subprocess

class RendererTests(unittest.TestCase):
    def test_protected_controllers_filter_before_return_and_deny_before_lookup(self):
        import json
        commit=json.loads((PROFILE/'baseline.lock.json').read_text())['generated_commit']
        for name, membership in [('AccountController',False),('AccountUserController',True)]:
            source=subprocess.run(['git','show',commit+':account-service/src/main/java/finos/traderx/accountservice/controller/'+name+'.java'],cwd=ROOT,capture_output=True,text=True,check=True).stdout
            result=secure_controller(source,membership)
            self.assertNotIn('@CrossOrigin',result)
            self.assertIn('var allowed = accountAccess.accounts();',result)
            self.assertIn('@ExceptionHandler(AccessDeniedException.class)',result)
            self.assertLess(result.index('accountAccess.requireAccount(id)'),result.index('return ResponseEntity.ok(account'+('User' if membership else '')+'Service.getAccount'))
            with self.assertRaises(ValueError): secure_controller(result,membership)

if __name__=='__main__':unittest.main()
