import copy
import io
import tarfile
import unittest
import observability_workloads as obs
from observability_migration import archive_manifest

class ObservabilityTests(unittest.TestCase):
    def test_render_preserves_source_and_does_not_touch_database(self):
        items=[]
        for name in obs.NAMES:
            items.append({'kind':'Deployment','metadata':{'name':name,'namespace':obs.NS},'spec':{'template':{'spec':{'volumes':[{'name':v,'configMap':{'name':cm}} for v,cm,_,_ in obs.CONFIGS[name]],'containers':[{'name':name,'image':'test@sha256:'+'a'*64}]}}}})
        r={'items':items};before=copy.deepcopy(r);result=obs.render(r)
        self.assertEqual(r,before);self.assertEqual(result,obs.render(r))
        for d in result['items']:
            if d['kind']=='Deployment':
                self.assertIn(d['metadata']['name'],obs.NAMES)
                self.assertEqual(d['spec']['strategy'],{'type':'Recreate'})
                self.assertTrue(d['spec']['template']['spec']['containers'][0]['securityContext']['readOnlyRootFilesystem'])
    def test_archive_rejects_traversal_and_links(self):
        import tempfile
        from pathlib import Path
        for name,kind in [('var/lib/grafana/data',tarfile.REGTYPE),('../escape',tarfile.REGTYPE),('var/lib/grafana/link',tarfile.SYMTYPE)]:
            with tempfile.TemporaryDirectory() as tmp:
                path=Path(tmp)/'backup.tar'
                with tarfile.open(path,'w') as t:
                    m=tarfile.TarInfo(name);m.type=kind;m.size=1 if kind==tarfile.REGTYPE else 0;m.linkname='/etc/passwd'
                    t.addfile(m,io.BytesIO(b'x') if m.size else None)
                if name.endswith('data'):self.assertEqual(len(archive_manifest(path,['/var/lib/grafana'])),1)
                else:
                    with self.assertRaises(ValueError):archive_manifest(path,['/var/lib/grafana'])
