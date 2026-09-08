"""Receipts are historical local evidence, never a substitute for a fresh CI verdict."""
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import gate_status
import shutil


class ReceiptTests(unittest.TestCase):
    def test_receipt_identity(self):
        path = Path(__file__).with_name('verification_receipt.py')
        self.assertTrue(path.exists(), 'receipt implementation missing')
        spec = importlib.util.spec_from_file_location('verification_receipt',path)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)/'repo'
            root.mkdir()
            def git(*args):
                subprocess.run(['git','-C',str(root),*args],check=True,capture_output=True)
            git('init')
            (root/'input').write_text('one')
            git('add','input')
            git('-c','user.name=Test','-c','user.email=test@example.invalid','commit','-m','fixture')
            store = mod.ReceiptStore(root,Path(tmp)/'receipts',max_age=60)
            self.assertIsNone(store.lookup('true'))
            self.assertEqual(store.run('true'),0)
            self.assertEqual(store.lookup('true')['result'],'PASS')
            cache = mod.ReceiptResults(store)
            step = {'job':'gates','name':'fixture','run':'true','coe':False}
            with patch.object(gate_status,'run_locally',side_effect=AssertionError('unexpected re-execution')):
                status, details = gate_status.resolve_status([step], {'fixture':'skipped'},cache)
            self.assertEqual(status,'SKIPPED')
            self.assertIn('NOT freshly executed',' '.join(details))
            self.assertIsNone(store.lookup('false'))
            self.assertEqual(store.run('false'),1)
            self.assertEqual(store.lookup('false')['result'],'FAIL')
            (root/'input').write_text('changed')
            self.assertIsNone(store.lookup('true'))
            (root/'input').write_text('one')
            os.environ['SINKFORGE_RECEIPT_TEST']='changed'
            try:
                self.assertIsNone(store.lookup('true'))
            finally:
                del os.environ['SINKFORGE_RECEIPT_TEST']
            old=mod.ReceiptStore(root,Path(tmp)/'receipts',max_age=-1)
            self.assertIsNone(old.lookup('true'))
            record=next((Path(tmp)/'receipts').glob('*.json'))
            record.write_text('bad json')
            # Unreadable evidence is rejected rather than interpreted as a pass.
            self.assertTrue(store.lookup('true') is None or store.lookup('false') is None)

    def test_battery_receipt_can_be_reused_by_reporter(self):
        import verification_receipt as mod
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)/'repo'
            (root/'tools').mkdir(parents=True)
            for name in ('run_local_battery.sh','verification_receipt.py'):
                shutil.copy2(Path(__file__).with_name(name),root/'tools'/name)
            (root/'tools/list_ci_gates.py').write_text("print('true',end='')")
            subprocess.run(['git','init',str(root)],check=True,capture_output=True)
            subprocess.run(['git','-C',str(root),'add','.'],check=True,capture_output=True)
            subprocess.run(['git','-C',str(root),'-c','user.name=Test','-c','user.email=test@example.invalid',
                            'commit','-m','fixture'],check=True,capture_output=True)
            directory=Path(tmp)/'receipts'
            with patch.dict(os.environ,{'LOCAL_GATE_RECEIPTS':str(directory),'GATES_ONLY':'1'}):
                result=subprocess.run(['bash',str(root/'tools/run_local_battery.sh'),'/usr/bin/true'],
                                      capture_output=True,text=True)
                self.assertEqual(result.returncode,0,result.stdout+result.stderr)
                receipt=mod.ReceiptStore(root,directory).lookup('true')
                self.assertIsNotNone(receipt,'battery-to-reporter environment mismatch')


if __name__ == '__main__':
    unittest.main()
