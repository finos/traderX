"""Bounded identity fixture policy; not a live TraderX authentication adapter."""
import time
import jwt

IMAGE = 'quay.io/keycloak/keycloak@sha256:7e66a96e4739239070aeaf72e4c5decf0f7f682cfc725b9f7ea2b336eaba38b3'
BASE = 'https://localhost:18446'
ISSUER = BASE + '/realms/traderx-lab'
CLIENT = 'security-lab-browser'
AUDIENCE = 'traderx-account-api'
REDIRECT = 'http://127.0.0.1:18447/callback'
SUBJECTS = {'reader': 'lab-reader', 'trader': 'lab-trader', 'operator': 'lab-operator'}
ROLES = {'reader': 'read-only', 'trader': 'trader', 'operator': 'operator'}
# Configuration owned by the server. No caller-provided account or role grants.
ENTITLEMENTS = {(ISSUER, 'lab-reader'): frozenset({22214}),
                (ISSUER, 'lab-trader'): frozenset({62654}),
                (ISSUER, 'lab-operator'): frozenset()}


def realm(passwords):
    return {'realm': 'traderx-lab', 'enabled': True, 'sslRequired': 'all',
            'registrationAllowed': False, 'resetPasswordAllowed': False,
            'accessTokenLifespan': 120, 'defaultSignatureAlgorithm': 'RS256',
            'roles': {'realm': [{'name': role} for role in ROLES.values()]},
            'clients': [{'clientId': CLIENT, 'protocol': 'openid-connect',
                         'publicClient': True, 'standardFlowEnabled': True,
                         'implicitFlowEnabled': False, 'directAccessGrantsEnabled': False,
                         'serviceAccountsEnabled': False, 'fullScopeAllowed': True,
                         'redirectUris': [REDIRECT], 'webOrigins': [],
                         'attributes': {'pkce.code.challenge.method': 'S256'},
                         'protocolMappers': [{'name': 'account-api', 'protocol': 'openid-connect',
                             'protocolMapper': 'oidc-audience-mapper', 'config': {
                             'included.custom.audience': AUDIENCE, 'access.token.claim': 'true',
                             'id.token.claim': 'false'}}]}],
            'users': [{'id': SUBJECTS[name], 'username': name, 'enabled': True,
                       'email': name + '@example.invalid', 'emailVerified': True,
                       'firstName': 'Synthetic', 'lastName': name,
                       'realmRoles': [ROLES[name]], 'requiredActions': [],
                       'credentials': [{'type': 'password', 'value': password, 'temporary': False}]}
                      for name, password in passwords.items()]}


class TokenVerifier:
    """Verify against a trusted, finite-lived key snapshot; never token-selected URLs."""
    def __init__(self, jwks, issuer=ISSUER, audience=AUDIENCE, clock=time.monotonic):
        self.issuer, self.audience, self.clock = issuer, audience, clock
        self.loaded = clock()
        self.keys = {}
        for key in jwks['keys']:
            if key.get('use') == 'sig' and key.get('alg') == 'RS256' and key.get('kty') == 'RSA':
                if key['kid'] in self.keys:
                    raise ValueError('Duplicate signing key')
                self.keys[key['kid']] = jwt.PyJWK.from_dict(key).key
        if not self.keys:
            raise ValueError('No approved signing keys')

    def verify(self, token):
        if not isinstance(token, str) or len(token) > 16384:
            raise jwt.InvalidTokenError('Invalid token size/type')
        if self.clock() - self.loaded >= 300:
            raise jwt.InvalidTokenError('Signing-key snapshot expired')
        header = jwt.get_unverified_header(token)
        if header.get('alg') != 'RS256' or header.get('kid') not in self.keys:
            raise jwt.InvalidTokenError('Unapproved algorithm or signing key')
        claims = jwt.decode(token, self.keys[header['kid']], algorithms=['RS256'],
                            issuer=self.issuer, audience=self.audience, leeway=0,
                            options={'require': ['iss', 'aud', 'exp', 'iat', 'sub']})
        if not isinstance(claims['sub'], str) or not claims['sub']:
            raise jwt.InvalidTokenError('Missing subject')
        return claims


def accounts_for(verified_claims):
    return ENTITLEMENTS.get((verified_claims['iss'], verified_claims['sub']), frozenset())
