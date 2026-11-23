import unittest
from unittest.mock import patch
from account_oidc import verify_user

class AccountOidcTests(unittest.TestCase):
    def test_provider_token_cannot_pass_with_overbroad_accounts(self):
        with patch('account_oidc.request',return_value=(200,[{'id':22214},{'id':62654}])):
            with self.assertRaisesRegex(ValueError,'scope mismatch'):
                verify_user('reader',{'access_token':'fixture','id_token':'identity'},lambda _:None)

    def test_provider_token_cannot_pass_if_write_accepted(self):
        def reply(method,path,token,body=None):
            if path=='/account/':return (200,[{'id':22214}])
            if path=='/accountuser/':return (200,[{'accountId':22214}])
            return (200,None) if path=='/account/22214' else (403,None)
        with patch('account_oidc.request',side_effect=reply):
            with self.assertRaisesRegex(ValueError,'write accepted'):
                verify_user('reader',{'access_token':'fixture','id_token':'identity'},lambda _:None)

if __name__=='__main__':unittest.main()
