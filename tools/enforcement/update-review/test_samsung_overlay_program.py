"""Execute the exact Samsung overlay shell program against owned synthetic directories."""
import os, subprocess, tempfile, unittest
from pathlib import Path

class SamsungOverlayProgram(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        ps=os.environ.get('KR_REVIEW_PS','pwsh')
        script=str(Path(__file__).resolve().with_name('Export-SamsungOverlayState.ps1'))
        if ps.endswith('.exe'):
            script='\\\\wsl.localhost\\Ubuntu-24.04'+script.replace('/','\\')
        cls.script=subprocess.check_output([ps,'-NoProfile','-ExecutionPolicy','Bypass','-File',script],text=True).replace('\r\n','\n')

    def run_state(self,root):
        return subprocess.run(['sh'],input=self.script,cwd=root,text=True,capture_output=True)

    def test_exact_ids_regular_file_is_named_runtime_metadata(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'shared_prefs';p.mkdir();f=p/'android.app.ActivityThread.IDS.xml';f.write_bytes(b'X'*108)
            r=self.run_state(d)
            self.assertEqual(r.returncode,0)
            self.assertIn('runtime_samsung_ids|PRESENT|108',r.stdout)
            self.assertIn('TOTAL|1',r.stdout)
            self.assertNotIn(str(f),r.stdout+r.stderr)

    def test_second_unknown_remains_counted(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'shared_prefs';p.mkdir();(p/'android.app.ActivityThread.IDS.xml').write_bytes(b'X')
            (p/'PRIVATE_SECOND_FILE').write_bytes(b'PRIVATE_CONTENT')
            r=self.run_state(d)
            self.assertEqual(r.returncode,0)
            self.assertIn('TOTAL|2',r.stdout)
            self.assertNotIn('PRIVATE_',r.stdout+r.stderr)

    def test_ids_symlink_is_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'shared_prefs';p.mkdir();(p/'android.app.ActivityThread.IDS.xml').symlink_to('/dev/null')
            r=self.run_state(d)
            self.assertNotEqual(r.returncode,0)

    def test_ids_directory_is_nonregular_and_rejected_by_parser_row(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'shared_prefs';p.mkdir();(p/'android.app.ActivityThread.IDS.xml').mkdir()
            r=self.run_state(d)
            self.assertEqual(r.returncode,0)
            self.assertIn('runtime_samsung_ids|UNKNOWN|0',r.stdout)

    def test_case_mismatch_remains_unknown_file(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'shared_prefs';p.mkdir();(p/'android.app.ActivityThread.ids.xml').write_bytes(b'X')
            r=self.run_state(d)
            self.assertEqual(r.returncode,0)
            self.assertIn('runtime_samsung_ids|ABSENT|0',r.stdout)
            self.assertIn('TOTAL|1',r.stdout)

if __name__=='__main__': unittest.main()
