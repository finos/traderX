import unittest
from browser_session import Store,BrowserServer,SESSION

class BrowserSessionTests(unittest.TestCase):
    def test_session_and_pending_expire_at_boundary(self):
        now=[100];store=Store(lambda:now[0]);store.sessions['s']={'until':101};store.pending['p']={'until':101}
        self.assertIsNotNone(store.session('s'));now[0]=101
        self.assertIsNone(store.session('s'));self.assertEqual(store.pending,{})
    def test_host_cookie_has_secure_scope(self):
        cookie=BrowserServer.cookie(SESSION,'fixture',120)
        for value in ('__Host-','Secure','HttpOnly','SameSite=Lax','Path=/','Max-Age=120'):self.assertIn(value,cookie)
        self.assertNotIn('Domain=',cookie)

if __name__=='__main__':unittest.main()
