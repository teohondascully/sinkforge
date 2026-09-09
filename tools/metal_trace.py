"""Read xctrace's metal-gpu-intervals XML for ONE explicit game PID.

Export with xctrace export --input capture.trace --xpath
'/trace-toc/run[@number="1"]/data/table[@schema="metal-gpu-intervals"]' --output gpu.xml
Then: python3 tools/metal_trace.py gpu.xml --pid <launched PID from trace TOC>

These are GPU execution intervals, NOT presentation frame times. Overlapping vertex/fragment/
compute intervals are unioned, not added. Other processes remain excluded even if xctrace exported
them. Trace collection perturbs the workload; do not mix these numbers with uninstrumented FPS.
"""
import argparse
import json
import xml.etree.ElementTree as ET

VALUES = {"start-time", "duration", "gpu-channel-name", "gpu-state", "pid", "process"}


def union_ns(intervals):
    total, right = 0, -1
    for start, end in sorted(intervals):
        total += max(0, end - max(start, right))
        right = max(right, end)
    return total


def intervals(source, pid):
    """Resolve Instruments' backreferences without retaining the entire 100+ MB XML tree."""
    ids, columns = {}, []
    def value(node):
        if node is None:
            return ""
        return ids[node.attrib["ref"]] if "ref" in node.attrib else (node.text or "")
    for _, element in ET.iterparse(source, events=("end",)):
        if element.tag in VALUES and "id" in element.attrib:
            ids[element.attrib["id"]] = value(element.find("pid")) if element.tag == "process" else value(element)
        if element.tag == "schema":
            if element.get("name") != "metal-gpu-intervals":
                raise ValueError("expected the metal-gpu-intervals table")
            columns = [c.findtext("mnemonic") for c in element.findall("col")]
        if element.tag != "row":
            continue
        row = dict(zip(columns, list(element)))
        process = row["process"]
        subject = value(process) if "ref" in process.attrib else value(process.find("pid"))
        if subject == str(pid) and value(row["state"]) == "Active":
            start, duration = int(value(row["start"])), int(value(row["duration"]))
            if duration < 0:
                raise ValueError("negative GPU interval duration")
            yield start, start + duration, value(row["channel-name"])
        element.clear()


def summarise(source, pid):
    channels, all_intervals = {}, []
    for start, end, channel in intervals(source, pid):
        all_intervals.append((start, end))
        channels.setdefault(channel, []).append((start, end))
    if not all_intervals:
        raise ValueError("no active GPU intervals for the requested PID; not a zero-cost result")
    return {"pid": pid, "active_intervals": len(all_intervals),
            "active_union_ms": union_ns(all_intervals) / 1e6,
            "first_active_ms": min(a for a, _ in all_intervals) / 1e6,
            "last_active_ms": max(b for _, b in all_intervals) / 1e6,
            "max_interval_ms": max(b - a for a, b in all_intervals) / 1e6,
            "channels_ms": {k: union_ns(v) / 1e6 for k, v in channels.items()}}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("xml")
    parser.add_argument("--pid", type=int, required=True)
    args = parser.parse_args()
    print(json.dumps(summarise(args.xml, args.pid), indent=2))
