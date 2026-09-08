"""Run real shell runners in a disposable tree; only the Godot process is a fixture."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class RunnerContracts(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root/'tools').mkdir()
        for name in ('run_suites.sh', 'run_gd_test.sh', 'run_local_battery.sh'):
            shutil.copy2(ROOT/'tools'/name, self.root/'tools'/name)
        self.engine = self.root/'engine'
        self.engine.write_text('#!/bin/bash\necho "ALL PASS fixture"\n')
        self.engine.chmod(0o755)

    def run_suites(self, *suites, jobs='2', env=None):
        return subprocess.run(['bash',str(self.root/'tools/run_suites.sh'),str(self.engine),jobs,*suites],
                              capture_output=True, text=True, env=env)

    def test_duplicate_rejected(self):
        result = self.run_suites('res://tests/a.gd','res://tests/a.gd')
        self.assertNotEqual(result.returncode, 0, result.stdout)

    def test_same_basename_both_counted(self):
        result = self.run_suites('res://tests/a/x.gd','res://tests/b/x.gd')
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertIn('2 passed, 0 failed, of 2', result.stdout)

    def test_missing_worker_result_is_failure(self):
        # External scheduler failure must not let one completed result certify two requested suites.
        bindir = self.root/'bin'
        bindir.mkdir()
        fake = bindir/'xargs'
        fake.write_text('#!/bin/bash\nexit 0\n')
        fake.chmod(0o755)
        env = dict(os.environ, PATH=str(bindir)+os.pathsep+os.environ['PATH'])
        result = self.run_suites('res://tests/a.gd',env=env)
        self.assertNotEqual(result.returncode,0,result.stdout)
        fake.write_text('#!/bin/bash\nIFS= read -r first\nprintf "%s\\n" "$first" | /usr/bin/xargs "$@"\n')
        result = self.run_suites('res://tests/a.gd','res://tests/b.gd',env=env)
        self.assertNotEqual(result.returncode,0,result.stdout)
        self.assertIn('missing worker result',result.stdout)

    def test_failure_diagnostic_kept(self):
        self.engine.write_text('#!/bin/bash\necho "UNFILTERED_DIAGNOSTIC"\necho "ALL PASS fixture"\nexit 3\n')
        result = self.run_suites('res://tests/a.gd')
        self.assertNotEqual(result.returncode,0)
        self.assertIn('UNFILTERED_DIAGNOSTIC',result.stdout)

    def test_invalid_jobs(self):
        for jobs in ('0','-1','999','wat'):
            with self.subTest(jobs=jobs):
                self.assertNotEqual(self.run_suites('res://tests/a.gd',jobs=jobs).returncode,0)

    def battery(self, gate_parser="print('true',end='')", suite_parser="print('res://tests/a.gd')"):
        for name, source in [('list_ci_gates.py',gate_parser),('list_ci_suites.py',suite_parser)]:
            (self.root/'tools'/name).write_text(source+'\n')
        return subprocess.run(['bash',str(self.root/'tools/run_local_battery.sh'),str(self.engine),'2'],
                              capture_output=True,text=True)

    def test_battery_delegates_bounded_jobs(self):
        result = self.battery()
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertIn('(jobs=2)',result.stdout)

    def test_partial_gate_parser_failure(self):
        result = self.battery(gate_parser="import sys; print('true\\0',end=''); sys.exit(2)")
        self.assertNotEqual(result.returncode,0,result.stdout)

    def test_partial_suite_parser_failure(self):
        result = self.battery(suite_parser="import sys; print('res://tests/a.gd'); sys.exit(2)")
        self.assertNotEqual(result.returncode,0,result.stdout)

    def test_gate_log_does_not_overwrite_shared_path(self):
        old = os.environ.get('TMPDIR')
        os.environ['TMPDIR'] = str(self.root)
        sentinel = self.root/'gate.log'
        sentinel.write_text('another process owns this')
        try:
            result = self.battery()
        finally:
            if old is None: os.environ.pop('TMPDIR',None)
            else: os.environ['TMPDIR']=old
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertEqual(sentinel.read_text(),'another process owns this')


if __name__ == '__main__':
    unittest.main()
