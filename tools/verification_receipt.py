"""Opt-in local gate receipts. Historical evidence, NOT fresh verification or CI certification.

Store outside the repository. Reuse requires a clean unchanged checkout, matching environment/tool
identity, intact log, command, and age within one hour. External services are not snapshotted; fresh
checks remain the default. Environment values are hashed, never written into receipts.
"""
import argparse
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import time

# Shell bookkeeping and runner controls are not gate inputs. Commands whose behavior depends on
# these fields are not eligible for this opt-in historical-evidence path; use fresh reporting.
INCIDENTAL_ENV = {'_', 'SHLVL', 'PWD', 'OLDPWD', 'LOCAL_GATE_RECEIPTS', 'GATES_ONLY'}


def digest(value):
    return hashlib.sha256(value).hexdigest()


class ReceiptStore:
    def __init__(self, root, directory, max_age=3600):
        self.root = Path(root).resolve()
        self.directory = Path(directory).resolve()
        if self.directory == self.root or self.root in self.directory.parents:
            raise ValueError('receipt directory must be outside the repository')
        self.max_age = max_age

    def identity(self):
        def git(*args):
            return subprocess.check_output(['git',*args],cwd=self.root,stderr=subprocess.DEVNULL)
        try:
            if git('status','--porcelain','--untracked-files=all').strip():
                return None
            tools = {}
            for name in ('bash','git','python3'):
                path = Path(shutil.which(name) or '').resolve()
                tools[name] = [str(path),digest(path.read_bytes())]
            packages = sorted((d.metadata.get('Name',''),d.version) for d in importlib.metadata.distributions())
            return {'root':str(self.root),'head':git('rev-parse','HEAD').decode().strip(),
                    'index':digest(git('ls-files','--stage')), 'tools':tools,
                    'python':sys.version,'platform':platform.platform(),
                    'packages':digest(json.dumps(packages).encode()),
                    'environment':digest(json.dumps({k:v for k,v in os.environ.items() if k not in INCIDENTAL_ENV},sort_keys=True).encode()),
                    'recorder':digest(Path(__file__).read_bytes())}
        except (OSError, subprocess.CalledProcessError):
            return None

    def record_path(self, command):
        return self.directory/(digest(command.strip().encode())+'.json')

    def lookup(self, command):
        try:
            record = json.loads(self.record_path(command).read_text())
            identity = self.identity()
            age = time.time()-record['finished_at']
            log = self.directory/record['log']
            if (record['version'] != 1 or record['command'] != command.strip()
                    or identity is None or identity != record['identity']
                    or not 0 <= age <= self.max_age or record['result'] not in ('PASS','FAIL')
                    or log.parent.resolve() != self.directory
                    or digest(log.read_bytes()) != record['log_sha256']):
                return None
            return record
        except (OSError, ValueError, KeyError, TypeError):
            return None

    def run(self, command):
        before = self.identity()
        result = subprocess.run(['bash','-c',command],cwd=self.root,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
        sys.stdout.buffer.write(result.stdout)
        after = self.identity()
        if before is None or before != after:
            print('verification_receipt: not recorded (dirty or changed inputs)',file=sys.stderr)
            return result.returncode
        self.directory.mkdir(parents=True,exist_ok=True)
        record_path = self.record_path(command)
        log = record_path.with_suffix('.log')
        log.write_bytes(result.stdout)
        record = {'version':1,'command':command.strip(),'identity':before,'finished_at':time.time(),
                  'result':'PASS' if result.returncode == 0 else 'FAIL','exit_code':result.returncode,
                  'log':log.name,'log_sha256':digest(result.stdout)}
        temporary = record_path.with_suffix('.tmp')
        temporary.write_text(json.dumps(record))
        temporary.replace(record_path)
        return result.returncode


class ReceiptResults(dict):
    """Per-report result cache with explicit provenance on every reused step."""
    def __init__(self, store):
        super().__init__()
        self.store = store
        self.provenance = {}

    def __contains__(self, key):
        if not super().__contains__(key):
            record = self.store.lookup(key[2])
            if record is not None:
                self[key] = record['result']
                self.provenance[key] = f"reused local evidence from {record['finished_at']:.3f}; NOT freshly executed"
        return super().__contains__(key)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1])
    parser.add_argument('--store',type=Path,required=True)
    parser.add_argument('command')
    args = parser.parse_args()
    raise SystemExit(ReceiptStore(args.root,args.store).run(args.command))
