# Synthetic filesystem only; no ADB and no personal app data.
import hashlib
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).with_name('Read-SyncRetry.sh').read_bytes()
class RetryProgramTest(unittest.TestCase):
    def run_case(self, kind):
        with tempfile.TemporaryDirectory(prefix='od51-retry-script-') as d:
            root=Path(d); folder=root/'no_backup'; target=folder/'sync-retry'
            if kind!='missing_dir': folder.mkdir()
            payload=b'12345678\nSYNTHETIC_ONLY'
            if kind=='valid': target.write_bytes(payload)
            if kind=='oversize': target.write_bytes(b'X'*1025)
            if kind=='symlink': target.symlink_to('/dev/null')
            if kind=='directory': target.mkdir()
            if kind=='parent_symlink': folder.rmdir();folder.symlink_to(root/'absent')
            if kind=='backup_only': (folder/'sync-retry.bak').write_bytes(b'PRIVATE_BACKUP_MUST_NOT_BE_READ')
            before={str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in root.rglob('*') if p.is_file() and not p.is_symlink()}
            r=subprocess.run(['sh'],input=SCRIPT,cwd=d,capture_output=True,timeout=5)
            after={str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in root.rglob('*') if p.is_file() and not p.is_symlink()}
            self.assertEqual(before,after);self.assertEqual(r.returncode,0);self.assertEqual(r.stderr,b'')
            return r.stdout
    def test_exact_single_file_and_framing(self): self.assertEqual(self.run_case('valid'),b'OD51RETRY|DATA\n12345678\nSYNTHETIC_ONLY\nOD51RETRY|END\n')
    def test_missing_directory(self): self.assertEqual(self.run_case('missing_dir'),b'OD51RETRY|MISSING\n')
    def test_missing_base(self): self.assertEqual(self.run_case('missing'),b'OD51RETRY|MISSING\n')
    def test_backup_never_read(self): self.assertEqual(self.run_case('backup_only'),b'OD51RETRY|MISSING\n')
    def test_oversize_never_copied(self): self.assertEqual(self.run_case('oversize'),b'OD51RETRY|TOO_LARGE\n')
    def test_file_symlink(self): self.assertEqual(self.run_case('symlink'),b'OD51RETRY|NONREGULAR\n')
    def test_parent_symlink(self): self.assertEqual(self.run_case('parent_symlink'),b'OD51RETRY|NONREGULAR\n')
    def test_directory_not_read(self): self.assertEqual(self.run_case('directory'),b'OD51RETRY|NONREGULAR\n')
if __name__=='__main__': unittest.main()
