"""GPU evidence must isolate a PID and union overlapping work, never call it frame time."""
import io
import unittest

try:
    import metal_trace
except ImportError:
    metal_trace = None

SAMPLE = '''<trace-query-result><node><schema name="metal-gpu-intervals">
<col><mnemonic>start</mnemonic></col><col><mnemonic>duration</mnemonic></col>
<col><mnemonic>channel-name</mnemonic></col><col><mnemonic>state</mnemonic></col>
<col><mnemonic>process</mnemonic></col></schema>
<row><start-time>1000000</start-time><duration id="d">2000000</duration>
<gpu-channel-name>Fragment</gpu-channel-name><gpu-state>Active</gpu-state>
<process id="p"><pid>42</pid></process></row>
<row><start-time>2000000</start-time><duration ref="d"/>
<gpu-channel-name>Vertex</gpu-channel-name><gpu-state>Active</gpu-state><process ref="p"/></row>
<row><start-time>4000000</start-time><duration>99000000</duration>
<gpu-channel-name>Fragment</gpu-channel-name><gpu-state>Active</gpu-state>
<process><pid>99</pid></process></row></node></trace-query-result>'''


class MetalTraceTests(unittest.TestCase):
    def test_pid_isolation_and_overlap(self):
        self.assertIsNotNone(metal_trace, "GPU trace has no reproducible timing reader")
        result = metal_trace.summarise(io.StringIO(SAMPLE), 42)
        self.assertEqual(result["active_intervals"], 2)
        self.assertEqual(result["active_union_ms"], 3.0)
        self.assertEqual(result["channels_ms"], {"Fragment": 2.0, "Vertex": 2.0})

    def test_missing_subject_is_not_zero_cost(self):
        self.assertIsNotNone(metal_trace)
        with self.assertRaises(ValueError):
            metal_trace.summarise(io.StringIO(SAMPLE), 123)


if __name__ == "__main__":
    unittest.main()
