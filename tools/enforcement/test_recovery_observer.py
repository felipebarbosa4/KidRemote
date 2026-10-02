"""Content-free OS dump fixtures; no device interaction."""
import unittest
from recovery_observer import binding

APP = 'dev.kidremote.child.unassigned.debug'
LABEL = 'Service[label=KidRemote Child Local, feedbackType[FEEDBACK_GENERIC], capabilities=0]'
DUMP = 'app=ProcessRecord{token 4934:' + APP + '/u0a100}\nClient=ProcessRecord{token 679:system/1000}\nrequested=true received=true hasBound=true doRebind=false'


class BindingContract(unittest.TestCase):
    def test_dynamic_system_pid_and_component_process(self):
        result = binding(LABEL, DUMP, APP)
        self.assertTrue(result['bound'])
        self.assertEqual(result['servicePid'], 4934)

    def test_process_or_label_alone_is_not_connection(self):
        for label, dump in [('', DUMP), (LABEL, DUMP.replace('received=true', 'received=false')),
                            (LABEL, DUMP.replace('system/1000', 'ordinary/u0a100')),
                            (LABEL, DUMP.replace(APP, 'another.package'))]:
            self.assertFalse(binding(label, dump, APP)['bound'])

    def test_missing_schema_fails_closed(self):
        self.assertFalse(binding('', '', APP)['bound'])
        self.assertIsNone(binding(LABEL, 'app=null', APP)['servicePid'])

if __name__ == '__main__':
    unittest.main()
