"""Replay a stranger's physical inputs on a fresh seat and compare the runs tick for tick (D0454).

    python3 playtest/replay.py <source-session-dir> <new-session-dir> [--bursts N] [--seat playtest/seat.sh]

The source's `input_NNNN.json` files are the exact bursts the agent sent (ticks, keys, mouse, buttons,
composed moves, settle, until): each is re-sent in order with the same capture policy, so the new seat
runs the same tick cadence. Before the first burst the two builds are compared (the source's `batch.json`
build SHA against HEAD) and the two boot lines (site, seed, start) must match. After every burst the
signatures are compared independently of any report: the sim tick, the HUD state (rung, progress, pack,
lesson), the cells broken, the refusal and what ended the burst. The first divergence is named with both
sides; a run that matches to the end prints IDENTICAL with the tick reached.
"""
import argparse
import glob
import json
import os
import re
import subprocess
import sys
from pathlib import Path

SIGNATURE = ("tick", "ended_by", "refusal", "broke", "state")


def _boot_line(session):
    out = Path(session) / "seat.out"
    if not out.exists():
        return ""
    m = re.search(r"SINKFORGE_BOOT (site=\S+ seed=\S+ start=\S+)", out.read_text())
    return m.group(1) if m else ""


def _signature(o):
    return {k: o.get(k) for k in SIGNATURE}


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("source")
    parser.add_argument("target")
    parser.add_argument("--bursts", type=int, default=0, help="replay only the first N bursts (0 = all)")
    parser.add_argument("--seat", default=str(Path(__file__).with_name("seat.sh")))
    args = parser.parse_args()
    source = Path(args.source)
    target = Path(args.target)
    inputs = sorted(glob.glob(str(source / "input_*.json")))
    if args.bursts:
        inputs = inputs[: args.bursts]
    if not inputs:
        print("replay: no input_*.json in %s" % source, file=sys.stderr)
        return 2
    head = subprocess.run(["git", "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
    manifest = {}
    if (source / "batch.json").exists():
        manifest = json.loads((source / "batch.json").read_text())
        if manifest.get("build") != head:
            print("replay: WARNING the source ran on %s, HEAD is %s -- a divergence may be the build's" % (manifest.get("build", "?")[:8], head[:8]))
    target.mkdir(parents=True, exist_ok=True)
    if subprocess.run(["bash", args.seat, str(target)]).returncode != 0:
        print("replay: HARNESS_INVALID -- the seat did not boot", file=sys.stderr)
        return 2
    src_boot, dst_boot = _boot_line(source), _boot_line(target)
    if src_boot and src_boot != dst_boot:
        print("replay: the boot lines differ: source '%s', target '%s'" % (src_boot, dst_boot))
        return 2
    print("replay: %d bursts, boot '%s', build %s" % (len(inputs), dst_boot, head[:8]))
    command = Path(__file__).with_name("command.py")
    for p in inputs:
        n = int(os.path.basename(p)[6:10])
        c = json.loads(Path(p).read_text())
        for k in ("id", "sent_at"):
            c.pop(k, None)
        r = subprocess.run([sys.executable, str(command), str(target), json.dumps(c), "--timeout", "120", "--note", "replay of input_%04d" % n, "--full"],
                           capture_output=True, text=True)
        lines = [l for l in r.stdout.strip().splitlines() if l.startswith("{")]
        if not lines:
            print("replay: burst %d got no response (%s)" % (n, r.stderr.strip().splitlines()[-1] if r.stderr.strip() else "no stderr"))
            return 1
        got = _signature(json.loads(lines[-1]))
        src_path = source / ("observation_%04d.json" % n)
        if not src_path.exists():
            print("  burst %d: tick %s (the source has no observation to compare)" % (n, got["tick"]))
            continue
        want = _signature(json.loads(src_path.read_text()))
        diff = {k: (want[k], got[k]) for k in SIGNATURE if want.get(k) != got.get(k) and want.get(k) is not None}
        if diff:
            print("DIVERGED at burst %d:" % n)
            for k, (a, b) in diff.items():
                print("  %s: source %s | replay %s" % (k, json.dumps(a), json.dumps(b)))
            subprocess.run([sys.executable, str(command), str(target), '{"quit":true}', "--timeout", "20"], capture_output=True, text=True)
            return 1
        print("  burst %d: tick %s matches" % (n, got["tick"]))
    subprocess.run([sys.executable, str(command), str(target), '{"quit":true}', "--timeout", "20"], capture_output=True, text=True)
    print("IDENTICAL over %d bursts" % len(inputs))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
