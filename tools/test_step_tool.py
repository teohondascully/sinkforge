"""Exercise the real command adapter with a disposable filesystem seat, never a live game."""
import base64
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
PNG = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aT0sAAAAASUVORK5CYII=')


class StepToolTests(unittest.TestCase):
    def load_module(self):
        path=ROOT/'playtest/step_tool.py'
        self.assertTrue(path.exists(),'combined image tool missing')
        spec=importlib.util.spec_from_file_location('step_tool',path)
        mod=importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        return mod

    def test_real_command_returns_original_image_without_diagnostics(self):
        mod=self.load_module()
        with tempfile.TemporaryDirectory() as tmp:
            session=Path(tmp)
            (session/'response.json').write_text('{"id":0,"tick":0}')
            image=session/'frame_0001.png'
            image.write_bytes(PNG)
            def answer():
                deadline=time.monotonic()+5
                while not (session/'command.json').exists() and time.monotonic()<deadline:
                    time.sleep(.01)
                response={'id':1,'tick':1,'sim_seconds':1/60,'screenshot':str(image),
                          'state':{'secret':'not player visible'},'refusal':'hidden'}
                temp=session/'reply.tmp'
                temp.write_text(json.dumps(response))
                temp.replace(session/'response.json')
            worker=threading.Thread(target=answer)
            worker.start()
            result=mod.step(session,{'ticks':1},'look',timeout=2)
            worker.join()
            self.assertFalse(result.get('isError',False),result)
            self.assertEqual(base64.b64decode(result['content'][1]['data']),PNG)
            text=result['content'][0]['text']
            self.assertNotIn('secret',text)
            self.assertNotIn('refusal',text)
            self.assertTrue((session/'timing.jsonl').exists())
            self.assertIn('look',(session/'JOURNAL.md').read_text())
            self.assertTrue(mod.step(session,{'save':'forbidden'},'',timeout=1)['isError'])

    def test_image_boundary(self):
        mod=self.load_module()
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            seat=root/'seat'
            seat.mkdir()
            outside=root/'frame_0001.png'
            outside.write_bytes(PNG)
            for path in (outside,seat/'missing.png'):
                with self.assertRaises((ValueError,OSError)):
                    mod.image_content(seat,{'id':1,'screenshot':str(path)})
            bad=seat/'frame_0001.png'
            bad.write_bytes(b'not png')
            with self.assertRaises(ValueError):
                mod.image_content(seat,{'id':1,'screenshot':str(bad)})

    def test_stdio_negotiation_and_unknown_tool(self):
        self.load_module()
        with tempfile.TemporaryDirectory() as tmp:
            messages=[{'jsonrpc':'2.0','id':1,'method':'initialize','params':{'protocolVersion':'2025-11-25'}},
                      {'jsonrpc':'2.0','method':'notifications/initialized'},
                      {'jsonrpc':'2.0','id':2,'method':'tools/list'},
                      {'jsonrpc':'2.0','id':3,'method':'tools/call','params':{'name':'missing','arguments':{}}}]
            result=subprocess.run([sys.executable,str(ROOT/'playtest/step_tool.py'),'--session',tmp],
                                  input='\n'.join(map(json.dumps,messages))+'\n',capture_output=True,text=True,timeout=5)
            self.assertEqual(result.returncode,0,result.stderr)
            rows=[json.loads(s) for s in result.stdout.splitlines()]
            self.assertEqual(len(rows),3)
            self.assertEqual(rows[0]['result']['protocolVersion'],'2025-11-25')
            self.assertEqual(rows[1]['result']['tools'][0]['name'],'play_step')
            self.assertIn('error',rows[2])


if __name__ == '__main__':
    unittest.main()
