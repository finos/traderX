from contextlib import redirect_stdout
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock,patch
import zipfile

from cryptography.hazmat.primitives.asymmetric import rsa
import jwt

import verify_account_image as campaign
import verify_position_image as position


class AccountImageTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.signing=rsa.generate_private_key(public_exponent=65537,key_size=2048)
        cls.other=rsa.generate_private_key(public_exponent=65537,key_size=2048)

    def test_account_config_is_explicit_private_and_does_not_mutate_position(self):
        original=position.ISSUER
        config=campaign.configuration({'identities':{'account-service':{'username':'lab_account','password':'private-password'}}},'private-tls-password')
        self.assertEqual(config['role'],'account-service');self.assertEqual(config['database']['username'],'lab_account')
        self.assertEqual(config['identity']['audience'],'traderx-api');self.assertEqual(position.ISSUER,original)
        self.assertNotIn('people',json.dumps(config))
        claims=jwt.decode(campaign.token(self.signing),self.signing.public_key(),algorithms=['RS256'],issuer=campaign.ISSUER,audience=campaign.AUDIENCE)
        self.assertEqual(claims['sub'],'lab-reader')
        for variant,key,error in (('malformed',self.signing,jwt.DecodeError),('invalid_signature',self.other,jwt.InvalidSignatureError),
            ('foreign_issuer',self.signing,jwt.InvalidIssuerError),('foreign_audience',self.signing,jwt.InvalidAudienceError),('expired',self.signing,jwt.ExpiredSignatureError)):
            with self.assertRaises(error):jwt.decode(campaign.token(key,variant=variant),self.signing.public_key(),algorithms=['RS256'],issuer=campaign.ISSUER,audience=campaign.AUDIENCE)

    def test_sql_row_proof_checks_values_shapes_scope_duplicates_and_extra_fields(self):
        accounts=[{'id':22214,'displayName':'Synthetic account'}]
        members=[{'accountId':22214,'username':'a'},{'accountId':22214,'username':'b'}]
        self.assertTrue(campaign.rows_match(json.dumps(accounts),accounts,'account',22214))
        self.assertTrue(campaign.rows_match(json.dumps(accounts[0]),accounts,'account',22214,True))
        self.assertTrue(campaign.rows_match(json.dumps(members),members,'accountuser',22214))
        self.assertTrue(campaign.rows_match(json.dumps(members[0]),members,'accountuser',22214,True))
        for wrong in ([],[dict(accounts[0],id=62654)],[dict(accounts[0],displayName='wrong')],accounts*2,
                      [dict(accounts[0],secret='leaked')],[dict(accounts[0],id='22214')],{'id':22214}):
            self.assertFalse(campaign.rows_match(json.dumps(wrong),accounts,'account',22214))
        self.assertFalse(campaign.rows_match(json.dumps(members[1]),members,'accountuser',22214,True))

    def test_known_people_dependency_and_legacy_handlers_are_checked_in_jar(self):
        prefix='BOOT-INF/classes/finos/traderx/accountservice/'
        with tempfile.TemporaryDirectory() as temporary:
            jar=Path(temporary)/'application.jar'
            def write(extra=None,controller=b'GetMapping',properties=b'server.port=18088'):
                with zipfile.ZipFile(jar,'w') as archive:
                    archive.writestr(prefix+'controller/AccountController.class',controller)
                    archive.writestr(prefix+'controller/AccountUserController.class',b'GetMapping')
                    archive.writestr('BOOT-INF/classes/application.properties',properties)
                    if extra:archive.writestr(prefix+extra[0],extra[1])
            write();self.assertTrue(campaign.no_people_dependency(jar))
            for extra in (('service/PeopleValidationService.class',b''),('service/Other.class',b'org/springframework/web/client/RestTemplate')):
                write(extra=extra);self.assertFalse(campaign.no_people_dependency(jar))
            for marker in (b'PostMapping',b'PutMapping',b'RequestBody'):
                write(controller=marker);self.assertFalse(campaign.no_people_dependency(jar))
            write(properties=b'people.service.url=http://people');self.assertFalse(campaign.no_people_dependency(jar))

    def expected(self):
        return {(kind,account):[({'id':account,'displayName':'account-'+str(account)} if kind=='account' else
                               {'accountId':account,'username':'owner-'+str(account)})]
            for kind in ('account','accountuser') for account in (22214,62654)}

    def app(self,expected,allow_write=False):
        def request(context,path,bearer=None,hostname=None,method='GET',body=None,headers=None):
            try:claims=jwt.decode(bearer or '',self.signing.public_key(),algorithms=['RS256'],issuer=campaign.ISSUER,audience=campaign.AUDIENCE)
            except jwt.PyJWTError:return 401,b''
            if method!='GET':return (200,b'bad') if allow_write else (403,b'')
            parts=path.strip('/').split('/');kind=parts[0]
            if kind not in ('account','accountuser'):return 403,b''
            subject=claims['sub'];account={'lab-reader':22214,'lab-trader':62654}.get(subject)
            if subject=='lab-operator':return (200,b'[]') if len(parts)==1 else (403,b'')
            if account is None:return 403,b''
            if len(parts)>1 and parts[1]!=str(account):return 403,b''
            rows=expected[kind,account]
            return 200,json.dumps(rows[0] if len(parts)>1 else rows).encode()
        return Mock(request=Mock(side_effect=request))

    def test_authorization_campaign_exercises_every_write_method_and_operator_boundary(self):
        expected=self.expected();app=self.app(expected);checks=[]
        def check(value,name):
            self.assertTrue(value,name);self.assertIn(name,campaign.CHECKS);checks.append(name)
        campaign.authorize(app,object(),self.signing,self.other,expected,check)
        writes=[call for call in app.request.call_args_list if call.kwargs.get('method') in ('POST','PUT','PATCH','DELETE') and call.args[1].startswith(('/account/','/accountuser/'))]
        self.assertEqual(len(writes),48)
        self.assertEqual({call.kwargs['method'] for call in writes},{'POST','PUT','PATCH','DELETE'})
        self.assertIn('operator_has_no_implicit_account_scope',checks)
        self.assertIn('reader_and_operator_privileged_routes_denied',checks)
        self.assertEqual(len(checks),30)
        def strict(value,name):
            if not value:raise campaign.Failure(name)
        with self.assertRaisesRegex(campaign.Failure,'all_identity_write_routes_denied'):
            campaign.authorize(self.app(expected,True),object(),self.signing,self.other,expected,strict)

    def test_local_guard_stops_before_docker_and_failure_redacts_unknown_text(self):
        with patch.object(campaign.portability,'isolated_linux',return_value=False),patch.object(campaign.images,'Docker') as docker:
            with self.assertRaisesRegex(campaign.Failure,'hosted_linux_required'):campaign.campaign(Path('/unused'),{})
            docker.assert_not_called()
        for error in (ValueError('private-password'),campaign.Failure('private-password')):
            self.assertNotIn('private-password',json.dumps(campaign.failure(error)))
        with self.assertRaises(ValueError):campaign.phase('private-path')


if __name__=='__main__':unittest.main()
