import os
from pathlib import Path
import stat
import tempfile
import unittest
from unittest.mock import patch

from private_materializer import materialize, LIMIT


class PrivateMaterializerTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.root=Path(self.temp.name).resolve()
        self.source=self.root/'projected';self.source.mkdir()
        self.target=self.root/'private'
        self.put('config.json',b'{"private":"synthetic fixture"}')

    def tearDown(self):self.temp.cleanup()

    def put(self,name,value):
        path=self.source/name
        if path.exists():path.unlink()
        path.write_bytes(value);path.chmod(0o440)

    def test_copy_and_identical_restart_use_regular_private_files(self):
        materialize(self.source,self.target,['config.json'])
        self.assertEqual(stat.S_IMODE(self.target.stat().st_mode),0o700)
        path=self.target/'config.json';inode=path.stat().st_ino
        self.assertFalse(path.is_symlink());self.assertEqual(stat.S_IMODE(path.stat().st_mode),0o600)
        self.assertEqual(path.stat().st_uid,os.geteuid())
        materialize(self.source,self.target,['config.json'])
        self.assertEqual(path.stat().st_ino,inode)

    def test_rotation_never_overwrites_existing_private_configuration(self):
        materialize(self.source,self.target,['config.json'])
        before=(self.target/'config.json').read_bytes();self.put('config.json',b'changed')
        with self.assertRaisesRegex(ValueError,'changed'):materialize(self.source,self.target,['config.json'])
        self.assertEqual((self.target/'config.json').read_bytes(),before)

    def test_rejects_symlink_and_incomplete_or_permissive_destinations(self):
        actual=self.root/'elsewhere';actual.mkdir();self.target.symlink_to(actual,target_is_directory=True)
        with self.assertRaises(ValueError):materialize(self.source,self.target,['config.json'])
        self.target.unlink();self.target.mkdir(mode=0o700)
        with self.assertRaisesRegex(ValueError,'incomplete'):materialize(self.source,self.target,['config.json'])
        self.target.chmod(0o755)
        with self.assertRaisesRegex(ValueError,'mode'):materialize(self.source,self.target,['config.json'])

    def test_rejects_escaped_projection_unbounded_or_writable_source(self):
        escaped=self.root/'outside';escaped.write_bytes(b'outside');escaped.chmod(0o440)
        (self.source/'config.json').unlink();(self.source/'config.json').symlink_to(escaped)
        with self.assertRaisesRegex(ValueError,'escaped'):materialize(self.source,self.target,['config.json'])
        (self.source/'config.json').unlink();self.put('config.json',b'x'*(LIMIT+1))
        with self.assertRaises(ValueError):materialize(self.source,self.target,['config.json'])
        self.put('config.json',b'small');(self.source/'config.json').chmod(0o660)
        with self.assertRaises(ValueError):materialize(self.source,self.target,['config.json'])
        self.assertFalse(self.target.exists())

    def test_rejects_unknown_keys_hardlinks_and_existing_file_symlinks(self):
        for keys in ([],['../private'],['config.json','config.json']):
            with self.assertRaises(ValueError):materialize(self.source,self.target,keys)
        materialize(self.source,self.target,['config.json'])
        path=self.target/'config.json';link=self.root/'hardlink';os.link(path,link)
        with self.assertRaises(ValueError):materialize(self.source,self.target,['config.json'])
        link.unlink();path.unlink();path.symlink_to(self.source/'config.json')
        with self.assertRaises(OSError):materialize(self.source,self.target,['config.json'])

    def test_atomic_projection_generation_is_resolved_once(self):
        (self.source/'config.json').unlink()
        for version in ('old','new'):
            folder=self.source/version;folder.mkdir()
            for name in ('config.json','ca.pem'):
                p=folder/name;p.write_text(version);p.chmod(0o440)
        (self.source/'..data').symlink_to('old',target_is_directory=True)
        for name in ('config.json','ca.pem'):(self.source/name).symlink_to('../projected/..data/'+name)
        original=os.open;rotated=False
        def opening(path,*args,**kwargs):
            nonlocal rotated
            fd=original(path,*args,**kwargs)
            if not rotated and Path(path)==self.source/'old/config.json':
                rotated=True;(self.source/'..next').symlink_to('new',target_is_directory=True)
                os.replace(self.source/'..next',self.source/'..data')
            return fd
        with patch('private_materializer.os.open',side_effect=opening):materialize(self.source,self.target,['config.json','ca.pem'])
        self.assertTrue(rotated)
        self.assertEqual((self.target/'config.json').read_text(),'old')
        self.assertEqual((self.target/'ca.pem').read_text(),'old')


if __name__=='__main__':unittest.main()
