"""Execute the actual fixed read-only shell program against owned synthetic directories."""
import os, subprocess, tempfile, unittest
from pathlib import Path
class StateProgram(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        ps=os.environ.get('KR_REVIEW_PS','pwsh')
        script=str(Path(__file__).resolve().with_name('Export-State.ps1'))
        if ps.endswith('.exe'):
            script='\\\\wsl.localhost\\Ubuntu-24.04'+script.replace('/','\\')
        cls.script=subprocess.check_output([ps,'-NoProfile','-ExecutionPolicy','Bypass','-File',script],text=True).replace('\r\n','\n')
    def run_state(self,root):
        return subprocess.run(['sh'],input=self.script,cwd=root,text=True,capture_output=True)
    def test_empty(self):
        with tempfile.TemporaryDirectory() as d:
            r=self.run_state(d);self.assertEqual(r.returncode,0);self.assertIn('TOTAL|0',r.stdout)
    def test_marker_is_metadata_only(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'no_backup';p.mkdir();f=p/'device-identity';f.write_bytes(b'SYNTHETIC_SECRET_DO_NOT_PRINT')
            r=self.run_state(d);self.assertEqual(r.returncode,0);self.assertIn('identity|PRESENT|29',r.stdout)
            self.assertNotIn('SYNTHETIC_SECRET',r.stdout+r.stderr);self.assertEqual(f.read_bytes(),b'SYNTHETIC_SECRET_DO_NOT_PRINT')
    def test_unknown_name_not_disclosed(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'files';p.mkdir();(p/'PRIVATE_UNKNOWN_NAME').write_text('PRIVATE_CONTENT')
            r=self.run_state(d);self.assertEqual(r.returncode,0);self.assertIn('TOTAL|1',r.stdout)
            self.assertNotIn('PRIVATE_',r.stdout+r.stderr)
    def test_symlink_refuses(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'files';p.mkdir();(p/'link').symlink_to('/dev/null')
            r=self.run_state(d);self.assertNotEqual(r.returncode,0)
if __name__=='__main__':unittest.main()
