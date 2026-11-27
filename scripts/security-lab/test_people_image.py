import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock,patch

from cryptography.hazmat.primitives.asymmetric import rsa
import jwt
import people_image_fixture as fixture
import verify_people_image as campaign

class PeopleImageTests(unittest.TestCase):
    def test_oci_reinspection_binds_exact_manifest_argument_order(self):
        entry={'image':'fixture','oci_layout':'/layout','secret':'private-people-service','keys':[]}
        manifest={'source_commit':'0'*40,'image':entry,'runtime_reference':'local/image','generated_root':'/source',
                  'publish_dir':'/publish','build_report':'/report','native_probe':'/probe'}
        docker=Mock()
        with patch.object(fixture.people_images,'inspect',return_value={'different':True}) as inspect:
            with self.assertRaises(fixture.Failure):fixture.verified_image(manifest,docker)
            inspect.assert_called_once_with('/layout','local/image','0'*40,'/source','/publish','/report')
            docker.assert_not_called()
        with self.assertRaises(fixture.Failure):fixture.verified_image(dict(manifest,extra='unreviewed'),docker)

    def test_identity_variants_do_not_substitute_role_claims_for_private_grants(self):
        key=rsa.generate_private_key(public_exponent=65537,key_size=2048)
        alternate=rsa.generate_private_key(public_exponent=65537,key_size=2048)
        token=campaign.bearer(key,alternate,'provider_role_only')
        claims=jwt.decode(token,key.public_key(),algorithms=['RS256'],audience=campaign.AUDIENCE,issuer=campaign.ISSUER)
        self.assertEqual(claims['sub'],'lab-reader');self.assertEqual(claims['realm_access']['roles'],['operator'])
        with self.assertRaises(jwt.InvalidAudienceError):
            jwt.decode(campaign.bearer(key,alternate,'wrong_audience'),key.public_key(),algorithms=['RS256'],audience=campaign.AUDIENCE)
        with self.assertRaises(jwt.InvalidSignatureError):
            jwt.decode(campaign.bearer(key,alternate,'wrong_signature'),key.public_key(),algorithms=['RS256'],audience=campaign.AUDIENCE)
        self.assertIsNone(campaign.bearer(key,alternate,'anonymous'))

    def test_diagnostics_export_only_fixed_categories(self):
        value=fixture.diagnostic({'Running':False,'ExitCode':1,'OOMKilled':False},'private-token\nUnhandled exception\nprivate-key')
        self.assertEqual(value,{'running':False,'exit_code':1,'oom_killed':False,'markers':['unhandled_exception']})
        self.assertNotIn('private-',json.dumps(value))
        self.assertEqual(fixture.daemon_categories('private-token: failed to initialize logging driver: max-file'),
                         ['failed to initialize logging driver','max-file'])

    def test_cleanup_log_failure_preserves_primary_launch_failure(self):
        app=fixture.PeopleImage.__new__(fixture.PeopleImage)
        app.name='owned';app.target=Path('/projection');app.identity={'runtime_id':'sha256:fixed'}
        app.f={'names':[],'network':'owned-network','owner':'owned'}
        app.docker=Mock(side_effect=[Mock(returncode=1,stderr='failed to initialize logging driver'),
                                    Mock(returncode=0),Mock(returncode=0)])
        app.inspect=Mock(return_value={})
        app.diagnostics=Mock(side_effect=fixture.Failure('container_logs_unavailable'))
        with self.assertRaises(fixture.Failure) as caught:
            with app.run():self.fail('Failed container cannot yield')
        self.assertEqual(caught.exception.code,'container_launch_refused')
        self.assertEqual(caught.exception.diagnostic,{'daemon_categories':['failed to initialize logging driver']})
        self.assertEqual(app.docker.call_args.args,('rm','-f','owned'))
        launch=app.docker.call_args_list[0].args
        options=[launch[index+1] for index,value in enumerate(launch) if value=='--log-opt']
        self.assertIn('max-file=1',options)
        self.assertIn('compress=false',options)

    def test_projected_secret_is_one_generation_and_has_exact_keys(self):
        names=set(fixture.people_runtime.FILES)-{'config.json'}
        with tempfile.TemporaryDirectory() as temp,patch.object(fixture.subprocess,'run',return_value=Mock(returncode=0)):
            path=fixture.projected(Path(temp),campaign.configuration(),{name:b'synthetic' for name in names})
            self.assertEqual((path/'..data').readlink(),Path('..generation'))
            self.assertEqual({p.name for p in path.iterdir() if not p.name.startswith('..')},set(fixture.people_runtime.FILES))
            for name in fixture.people_runtime.FILES:
                self.assertEqual((path/name).readlink(),Path('..data')/name)
                self.assertEqual((path/name).stat().st_mode&0o777,0o440)
            with self.assertRaises(fixture.Failure):fixture.projected(Path(temp),{}, {'unexpected':b'value'})

    def test_local_execution_guard_does_not_start_containers(self):
        with patch.object(fixture.portability,'isolated_linux',return_value=False),patch.object(fixture.images,'Docker') as docker:
            with self.assertRaises(fixture.Failure):
                with fixture.fixture(Path('/unused')):pass
            docker.assert_not_called()

if __name__=='__main__':unittest.main()
