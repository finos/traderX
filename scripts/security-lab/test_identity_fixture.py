import json
import time
import unittest
import jwt
from cryptography.hazmat.primitives.asymmetric import rsa
from identity_fixture import TokenVerifier, ISSUER, AUDIENCE, accounts_for, realm


class IdentityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        cls.jwk = json.loads(jwt.algorithms.RSAAlgorithm.to_jwk(cls.key.public_key()))
        cls.jwk.update(kid='fixture-key', alg='RS256', use='sig')

    def setUp(self):
        self.verifier = TokenVerifier({'keys': [self.jwk]})
        self.claims = dict(iss=ISSUER, aud=AUDIENCE, sub='lab-reader',
                           iat=int(time.time()), exp=int(time.time()) + 60)

    def token(self, claims=None, key=None, **headers):
        return jwt.encode(self.claims if claims is None else claims, key or self.key,
                          algorithm='RS256', headers={'kid': 'fixture-key', **headers})

    def test_valid_and_server_owned_entitlements(self):
        self.claims.update(accounts=[62654], role='operator')
        self.assertEqual(accounts_for(self.verifier.verify(self.token())), {22214})
        self.claims['sub'] = 'lab-operator'
        self.assertEqual(accounts_for(self.verifier.verify(self.token())), set())
        self.claims['sub'] = 'unknown'
        self.assertEqual(accounts_for(self.verifier.verify(self.token())), set())

    def test_signed_wrong_claims(self):
        for claim, value in [('iss', ISSUER + '/other'), ('aud', 'another-api'),
                             ('exp', int(time.time())-1), ('iat', int(time.time())+60),
                             ('nbf', int(time.time())+60), ('sub', '')]:
            with self.subTest(claim=claim), self.assertRaises(jwt.InvalidTokenError):
                self.verifier.verify(self.token({**self.claims, claim: value}))
        for claim in ['iss', 'aud', 'exp', 'iat', 'sub']:
            missing = dict(self.claims); del missing[claim]
            with self.subTest(missing=claim), self.assertRaises(jwt.InvalidTokenError):
                self.verifier.verify(self.token(missing))

    def test_signature_algorithm_and_format(self):
        other = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        for token in [self.token(key=other), self.token(kid='unknown'),
                      jwt.encode(self.claims, '', algorithm='none'),
                      jwt.encode(self.claims, 'a' * 32, algorithm='HS256'),
                      'malformed', '', 'a'*16385]:
            with self.subTest(token_type=token[:8]), self.assertRaises(jwt.InvalidTokenError):
                self.verifier.verify(token)

    def test_expiring_keys_and_no_token_key_url(self):
        clock = [0]
        verifier = TokenVerifier({'keys': [self.jwk]}, clock=lambda: clock[0])
        verifier.verify(self.token(jku='https://untrusted.invalid/keys'))
        clock[0] = 300
        with self.assertRaises(jwt.InvalidTokenError):
            verifier.verify(self.token())
        with self.assertRaises(ValueError):
            TokenVerifier({'keys': [self.jwk, self.jwk]})

    def test_realm_disables_password_and_implicit_grants(self):
        config = realm(dict(reader='one', trader='two', operator='three'))
        client = config['clients'][0]
        self.assertEqual(client['attributes']['pkce.code.challenge.method'], 'S256')
        self.assertFalse(client['directAccessGrantsEnabled'])
        self.assertFalse(client['implicitFlowEnabled'])
        self.assertFalse(client['serviceAccountsEnabled'])
        self.assertEqual(len(client['redirectUris']), 1)
        self.assertEqual(len(config['users']), 3)


if __name__ == '__main__': unittest.main()
