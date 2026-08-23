#!/usr/bin/env python3
"""DOES THIS LAYER GIVE THE SAME ANSWER TWICE?

Not a harness layer, and named so it cannot be taken for one: it compares two FINISHED sweeps, which no
layer can see. Point it at two retained sweep directories taken on trees where the layers themselves did
not change, and it reports, per layer, what fraction of the numbers inside its PASS/FAIL lines moved.

Diagnostic numbers are deliberately excluded. A layer may print a duration, a frame count or a seed and be
perfectly sound; what matters is whether the numbers its VERDICT rests on reproduce. Those are the numbers
a threshold is compared against, and a threshold compared against a number that moves is deciding partly
at random.

    python3 tools/sweep_drift.py <sweep-dir-a> <sweep-dir-b>

Reading the output: a layer whose subject IS time (frametime, dig_hitch, lock, pacing) is expected here and
is not a defect. A layer that judges PIXELS and appears here has a verdict with a random component. A layer
whose INPUT changed between the two sweeps (trailers reads commits, prose reads files) is a control that
the comparison is alive rather than a finding.
"""
import glob
import io
import os
import re
import sys

NUM = re.compile(r"-?\d+\.?\d*")
ASSERTION = re.compile(r"^\s*(?:PASS|FAIL)\b.*$", re.M)


def judged(text):
    """The numbers inside a layer's PASS/FAIL lines, in order."""
    return NUM.findall("\n".join(ASSERTION.findall(text)))


def read_layers(d):
    out = {}
    for f in glob.glob(os.path.join(d, "*.log")):
        name = re.sub(r"^[0-9]+-", "", os.path.basename(f)[:-4])
        out[name] = io.open(f, encoding="utf-8", errors="replace").read()
    return out


def compare(a, b):
    """[(layer, moved, total)] for every layer in both, movers only. ONE implementation, so the controls
    below and the real census cannot disagree about what a difference is."""
    rows = []
    for n in sorted(set(a) & set(b)):
        na, nb = judged(a[n]), judged(b[n])
        if not na and not nb:
            continue
        if len(na) != len(nb):
            rows.append((n, -1, len(na)))
            continue
        moved = sum(1 for x, y in zip(na, nb) if x != y)
        if moved:
            rows.append((n, moved, len(na)))
    return rows


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    da, db = sys.argv[1], sys.argv[2]
    a, b = read_layers(da), read_layers(db)
    if not a or not b:
        print("sweep_drift: REFUSED - one of the directories holds no *.log files", file=sys.stderr)
        return 1

    # THE COMPARISON HAS TO BE ABLE TO SAY BOTH THINGS, shown on this data and not argued. A census that
    # reports "nothing moved" is the same output a dead comparison produces, and a census that reports
    # everything moved is what a mismatched parse produces. Both directions are checked against the very
    # logs being censused.
    self_rows = compare(a, a)
    victim = sorted(a)[0]
    planted = dict(a)
    planted[victim] = re.sub(r"^(\s*PASS\b.*?)(\d)", r"\g<1>9\g<2>", a[victim], count=1, flags=re.M)
    plant_rows = compare(a, planted)
    if self_rows:
        print("sweep_drift: REFUSED - a sweep compared against ITSELF reported %d mover(s). The comparison"
              % len(self_rows), file=sys.stderr)
        print("  is broken, so a clean census below would mean nothing.", file=sys.stderr)
        return 1
    if [r[0] for r in plant_rows] != [victim]:
        print("sweep_drift: REFUSED - a digit changed inside one PASS line of %s produced %r, not [%r]."
              % (victim, [r[0] for r in plant_rows], victim), file=sys.stderr)
        print("  The comparison cannot register a moved number, so it cannot report that none moved.",
              file=sys.stderr)
        return 1

    rows = compare(a, b)
    both = len([n for n in sorted(set(a) & set(b)) if judged(a[n]) or judged(b[n])])
    print("sweep_drift: %d layers carry judged numbers in both sweeps" % both)
    print("             %d reproduce EXACTLY, %d moved" % (both - len(rows), len(rows)))
    print("             controls: self-comparison 0 movers, planted digit caught in %s" % victim)
    for n, moved, total in sorted(rows, key=lambda r: -(r[1] / max(r[2], 1))):
        if moved < 0:
            print("  %-26s SHAPE CHANGED - %d judged numbers on one side" % (n, total))
        else:
            print("  %-26s %5.1f%%  (%d of %d judged numbers moved)"
                  % (n, 100.0 * moved / total, moved, total))
    return 0


if __name__ == "__main__":
    sys.exit(main())
