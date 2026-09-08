"""Hand-derived interval checks: summed seat work must never be called batch elapsed time."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest


class TimingReportTests(unittest.TestCase):
    def test_report_contract(self):
        path = Path(__file__).resolve().parents[1]/'playtest'/'timing_report.py'
        self.assertTrue(path.exists(), 'timing report not implemented')
        spec = importlib.util.spec_from_file_location('timing_report', path)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            seats = []
            for n, sent in [(1, 2000), (2, 2500)]:
                seat = root / str(n)
                seat.mkdir()
                seats.append({'session': str(seat), 'number': n})
                (seat/'batch.json').write_text(json.dumps({'build':'abc', 'mission_sha256':str(n)}))
                (seat/'response.json').write_text('{"quit":true}')
                (seat/'input_0001.json').write_text(json.dumps({'sent_at':float(sent)}))
                row = {'id':1, 'think_ms':1000, 'pickup_ms':10, 'play_ms':980,
                       'capture_ms':10, 'wall_ms':2000}
                (seat/'timing.jsonl').write_text(json.dumps(row)+'\n')
            batch = root/'batch.json'
            batch.write_text(json.dumps({'head':'abc','seats':seats}))
            out = mod.report(batch)
            self.assertEqual(out['summed_seat_ms'], 4000)
            self.assertEqual(out['observed_span_ms'], 2500)
            self.assertEqual(out['observed_union_ms'], 2500)
            self.assertEqual(out['totals_ms']['think_ms'], 2000)
            self.assertEqual(out['warnings'], [])
            (root/'1'/'timing.jsonl').write_text(json.dumps(row)+'\n'+json.dumps(row)+'\nBAD\n')
            (root/'2'/'batch.json').write_text('{"build":"other"}')
            (root/'2'/'response.json').write_text('{}')
            out = mod.report(batch)
            self.assertEqual(out['summed_seat_ms'], 4000, 'duplicate must not inflate timing')
            self.assertTrue(any('duplicate' in w for w in out['warnings']))
            self.assertTrue(any('malformed' in w for w in out['warnings']))
            self.assertTrue(any('build' in w for w in out['warnings']))
            self.assertTrue(any('incomplete' in w for w in out['warnings']))
            (root/'1'/'input_0001.json').unlink()
            out = mod.report(batch)
            self.assertIsNone(out['observed_span_ms'], 'missing timestamps cannot certify elapsed time')
            (root/'1'/'command.json').write_text('{"id":1,"sent_at":2000,"quit":true}')
            out = mod.report(batch)
            self.assertEqual(out['observed_span_ms'],2500,'quit is retained as command.json, not input_N')


if __name__ == '__main__':
    unittest.main()
