import copy
import io
import json
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest
from unittest.mock import patch

import admission_fixture
import integrated_deployment as compiler
import verify_integrated_admission as verifier


class FakeAPI:
    """Exercise orchestration/cleanup only; this is not a CEL interpreter."""
    def __init__(self,fail_ephemeral=False):
        self.parked=None;self.deleted=False;self.fail_ephemeral=fail_ephemeral
    def require(self,args,obj=None):
        if args[:2]==['get','validatingadmissionpolicy']:
            return {'metadata':{'generation':1},'status':{'observedGeneration':1,'typeChecking':{}}}
        if args[0]=='create':
            if obj['kind']=='Pod' and '--dry-run=server' not in args:self.parked=copy.deepcopy(obj)
            return obj
        if args[:2]==['get','pod']:return copy.deepcopy(self.parked)
        if args[0]=='delete':self.deleted=True;self.parked=None;return {}
        if args[0]=='get':return {'items':[]}
        raise AssertionError(args)
    def call(self,args,obj=None):
        if args[0]=='replace' and self.fail_ephemeral:raise RuntimeError('simulated transport failure')
        resource='pods' if obj['kind']=='Pod' else 'deployments'
        return subprocess.CompletedProcess(args,1,'',f'ValidatingAdmissionPolicy {admission_fixture.NAMESPACE}-images-{resource} denied request: Integrated application contract required')


class IntegratedAdmissionTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.root=Path(self.temp.name).resolve()
        self.contract=admission_fixture.contract(self.root,'0'*40)
        self.documents=json.loads(compiler.compile_bundle(self.contract)['application-core.json'])['items']
    def tearDown(self):self.temp.cleanup()

    def test_fixture_explicitly_non_runnable_and_all_workloads_staged(self):
        self.assertEqual(len(self.contract['workloads']),8)
        for entry in self.contract['workloads'].values():
            layout=Path(entry['oci_layout']);index=compiler.read_json(layout/'index.json')
            manifest=compiler.blob(layout,index['manifests'][0]);config=compiler.blob(layout,manifest['config'])
            self.assertEqual(config['config']['Labels']['traderx.security-lab.fixture'],'admission-only-non-runnable')
            raw=(layout/'blobs/sha256'/manifest['layers'][0]['digest'].split(':')[1]).read_bytes()
            with tarfile.open(fileobj=io.BytesIO(raw)) as archive:self.assertEqual(archive.getnames(),[])
            self.assertTrue(entry['image'].startswith('example.invalid/admission-only/'))
        self.assertTrue(all(d['spec']['replicas']==0 for d in self.documents if d['kind']=='Deployment'))

    def test_campaign_requires_explicit_isolated_host_before_any_external_command(self):
        with patch.object(verifier.portability,'isolated_linux',return_value=False),patch.object(verifier,'execute') as execute:
            with self.assertRaisesRegex(ValueError,'isolated GitHub'):verifier.guard(self.root/'kind',self.root)
            execute.assert_not_called()

    def test_failure_attribution_requires_intended_policy_and_rejection(self):
        policy='expected-policy'
        def result(code,message):return subprocess.CompletedProcess([],code,'',message)
        self.assertTrue(verifier.denied(result(1,policy+' denied request: Integrated application contract required'),policy))
        for value in (result(0,policy+' denied request: Integrated application contract required'),
                result(1,'other-policy denied request: Integrated application contract required'),
                result(1,policy+' unavailable'),result(1,'violates PodSecurity restricted')):
            self.assertFalse(verifier.denied(value,policy))

    def test_typecheck_rejects_warnings_and_does_not_accept_stale_generation(self):
        class Warnings:
            def require(self,_):return {'metadata':{'generation':2},'status':{'observedGeneration':2,'typeChecking':{'expressionWarnings':[{'warning':'undefined field'}]}}}
        with self.assertRaisesRegex(RuntimeError,'type checking failed'):verifier.typechecked(Warnings(),'policy',verifier.time.monotonic()+2)
        class Stale:
            def require(self,_):return {'metadata':{'generation':2},'status':{'observedGeneration':1,'typeChecking':{}}}
        with patch.object(verifier.time,'monotonic',side_effect=[0,2]),patch.object(verifier.time,'sleep'):
            with self.assertRaisesRegex(RuntimeError,'timed out'):verifier.typechecked(Stale(),'policy',1)

    def test_full_orchestration_returns_evidence_and_deletes_parked_pod(self):
        api=FakeAPI()
        with patch('sys.stderr',io.StringIO()):checks=verifier.campaign(api,self.documents)
        self.assertEqual(len(checks),30);self.assertTrue(api.deleted);self.assertIsNone(api.parked)
        self.assertTrue(any('ephemeral-container' in check for check in checks))

    def test_ephemeral_transport_failure_still_deletes_parked_pod(self):
        api=FakeAPI(fail_ephemeral=True)
        with patch('sys.stderr',io.StringIO()):
            with self.assertRaisesRegex(RuntimeError,'transport failure'):verifier.campaign(api,self.documents)
        self.assertTrue(api.deleted);self.assertIsNone(api.parked)

    def test_owned_cluster_cleanup_runs_after_campaign_failure(self):
        pins=compiler.read_json(verifier.TOOLS)
        node={'Id':'owned-node','Config':{'Image':pins['node_image']}}
        with patch.object(verifier.portability,'docker',return_value=['docker']),\
                patch.object(verifier,'owned_nodes',side_effect=[[],[node],[node],[]]),\
                patch.object(verifier,'checked',return_value='') as checked,\
                patch.object(verifier.API,'require',return_value={'gitVersion':pins['kubernetes_version']}):
            with self.assertRaisesRegex(RuntimeError,'campaign failure'):
                with verifier.cluster(self.root/'kind',self.root,pins):raise RuntimeError('campaign failure')
        commands=[call.args[0] for call in checked.call_args_list]
        self.assertEqual(sum(command[1:3]==['delete','cluster'] for command in commands),1)

    def test_cleanup_refuses_unowned_container(self):
        info={'Name':'/unrelated','Config':{'Labels':{'io.x-k8s.kind.cluster':'fixture','io.x-k8s.kind.role':'control-plane'}}}
        with patch.object(verifier,'checked',side_effect=['id',json.dumps([info])]):
            with self.assertRaisesRegex(RuntimeError,'ownership mismatch'):verifier.owned_nodes(['docker'],'fixture',{})


if __name__=='__main__':unittest.main()
