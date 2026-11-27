import unittest
from nats_fixture import Client

class ProtocolTests(unittest.TestCase):
    def client(self, chunks):
        c=Client.__new__(Client)
        c.buffer=b'';c.messages=[];c.errors=[]
        chunks=iter(chunks)
        c.receive=lambda: setattr(c,'buffer',c.buffer+next(chunks))
        c.send=lambda data: None
        return c

    def test_fragmented_message_preserves_following_denial(self):
        c=self.client([b'MS',b'G pricing.TEST 1 5\r\nab',b'cde\r',b'\n-ERR \'Permissions Violation\'\r\nPONG\r\n'])
        self.assertEqual(c.event(),'message')
        self.assertEqual(c.messages,[{'subject':'pricing.TEST','payload':'abcde'}])
        self.assertEqual(c.event(),'error')
        self.assertIn('Permissions Violation',c.errors[0])
        self.assertEqual(c.event(),'pong')

    def test_oversized_payload_rejected_before_read(self):
        c=self.client([b'MSG pricing.TEST 1 4097\r\n'])
        with self.assertRaises(AssertionError): c.event()
