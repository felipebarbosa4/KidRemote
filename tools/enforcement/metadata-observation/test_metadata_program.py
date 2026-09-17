"""Execute the fixed metadata-only structural program in owned synthetic directories."""
import os, stat, subprocess, tempfile, unittest
from pathlib import Path

class MetadataProgram(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        ps=os.environ.get("KR_METADATA_PS","pwsh")
        script=str(Path(__file__).resolve().with_name("Export-MetadataScript.ps1"))
        if ps.endswith(".exe"):
            script="\\\\wsl.localhost\\Ubuntu-24.04"+script.replace("/","\\")
        cls.program=subprocess.check_output([ps,"-NoProfile","-ExecutionPolicy","Bypass","-File",script],text=True).replace("\r\n","\n")

    def run_program(self,root):
        return subprocess.run(["sh"],input=self.program,cwd=root,text=True,capture_output=True)

    def test_empty_and_known_file(self):
        with tempfile.TemporaryDirectory() as root:
            result=self.run_program(root)
            self.assertEqual(result.returncode,0)
            self.assertIn("COUNTS|0|0|0",result.stdout)
            folder=Path(root)/"files";folder.mkdir();known=folder/"profileInstalled";known.write_bytes(b"PRIVATE_CONTENT_NOT_OUTPUT")
            result=self.run_program(root)
            self.assertEqual(result.returncode,0)
            self.assertIn("KNOWN|runtime_profile|26",result.stdout)
            self.assertIn("COUNTS|1|1|0",result.stdout)
            self.assertNotIn("PRIVATE_CONTENT",result.stdout+result.stderr)

    def test_one_and_multiple_unexpected_regular_files(self):
        with tempfile.TemporaryDirectory() as root:
            files=Path(root)/"files";db=Path(root)/"databases";files.mkdir();db.mkdir()
            (files/"one.dat").write_bytes(b"123")
            result=self.run_program(root)
            self.assertEqual(result.returncode,0)
            self.assertIn("UNEXPECTED|files|one.dat|3",result.stdout)
            (db/"nested").mkdir();(db/"nested"/"two.db").write_bytes(b"12345")
            result=self.run_program(root)
            self.assertEqual(result.returncode,0)
            self.assertIn("UNEXPECTED|databases|nested/two.db|5",result.stdout)
            self.assertIn("COUNTS|2|0|2",result.stdout)

    def test_symlink_nonregular_unreadable_and_bounds_refuse(self):
        with tempfile.TemporaryDirectory() as root:
            folder=Path(root)/"files";folder.mkdir();(folder/"link").symlink_to("/dev/null")
            self.assertEqual(self.run_program(root).returncode,21)
        with tempfile.TemporaryDirectory() as root:
            folder=Path(root)/"files";folder.mkdir();os.mkfifo(folder/"pipe")
            self.assertEqual(self.run_program(root).returncode,21)
        with tempfile.TemporaryDirectory() as root:
            folder=Path(root)/"files";folder.mkdir();folder.chmod(0)
            try:
                result=self.run_program(root)
                if os.geteuid()!=0:self.assertEqual(result.returncode,20)
            finally:folder.chmod(stat.S_IRWXU)
        with tempfile.TemporaryDirectory() as root:
            folder=Path(root)/"files";folder.mkdir()
            for index in range(65):(folder/(f"extra-{index}.dat")).write_bytes(b"x")
            result=self.run_program(root)
            self.assertEqual(result.returncode,22)
            self.assertLessEqual(result.stdout.count("UNEXPECTED|"),64)

    def test_unsafe_structural_name_refuses_without_content(self):
        with tempfile.TemporaryDirectory() as root:
            folder=Path(root)/"files";folder.mkdir();(folder/"unsafe name").write_bytes(b"SECRET_NOT_OUTPUT")
            result=self.run_program(root)
            self.assertEqual(result.returncode,22)
            self.assertNotIn("SECRET_NOT_OUTPUT",result.stdout+result.stderr)

if __name__=="__main__":unittest.main()
