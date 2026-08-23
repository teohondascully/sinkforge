#!/usr/bin/env python3
"""DOES THIS LAYER GIVE THE SAME ANSWER TWICE?

Not a harness layer, and named so it cannot be taken for one: it compares two FINISHED sweeps, which no
layer can see. Point it at two retained sweep directories and it reports, per layer, what fraction of the
numbers inside its PASS/FAIL lines moved.

**THE TWO SWEEPS MUST HAVE RUN ON THE SAME TREE, AND THIS TOOL NOW CHECKS IT RATHER THAN ASKING.** That
used to be a sentence here telling the operator to guarantee it, which protects nothing. The census exists
to rank layers by how unstable their numbers are, and a layer whose source was REPAIRED between the two
sweeps moves every number it prints -- so run across a repair, it ranks the layers that were just fixed as
the least reproducible in the run. That is not a hypothetical: four layers were repaired in a single day
here, and the obvious next step was to re-run the census over the sweeps either side of them.

Every sweep records what it ran on in its own `summary.txt`: a head commit, and for a modified worktree a
`delta` that content-addresses the uncommitted diff. Same head and same delta is the same tree, whether or
not it was clean -- the three sweeps this tool was first run against were all taken on the same 3-file
delta over `fc8d22f`, and refusing them for being dirty would have been a false refusal.

    THE DELTA IS BLIND TO UNTRACKED FILES. It comes from `git diff HEAD`, which reports nothing for a file
    git has never seen, so two trees agreeing on head and delta can still differ by an untracked one. No
    registered layer can be added that way (the registry is tracked), but an untracked asset can change
    pixels. This check makes the precondition testable, not certain.

Diagnostic numbers are deliberately excluded. A layer may print a duration, a frame count or a seed and be
perfectly sound; what matters is whether the numbers its VERDICT rests on reproduce. Those are the numbers
a threshold is compared against, and a threshold compared against a number that moves is deciding partly
at random.

    python3 tools/sweep_drift.py <sweep-dir-a> <sweep-dir-b>
    python3 tools/sweep_drift.py --cross-tree <a> <b>    # different trees, on purpose; says what differs

Reading the output: a layer whose subject IS time (frametime, dig_hitch, lock, pacing) is expected here and
is not a defect. A layer that judges PIXELS and appears here has a verdict with a random component. A layer
whose INPUT changed between the two sweeps (trailers reads commits, prose reads files) is a control that
the comparison is alive rather than a finding.

THIS IS A SCREEN, NOT A RISK RANKING, and the first version of it was quoted as one. Two columns are
printed because neither is enough on its own, and both were caught over-reporting on real data here:

    COUNT of numbers that moved over-reports last-digit wobble. `check_rock_reads` scored 50% because
    four of its eight judged numbers moved -- and the biggest of those was a cue reading 87.68% against
    a floor of 75.00% on one run and 87.55% on the next. Twelve points of headroom, nothing at risk.

    RELATIVE MAGNITUDE over-reports small integers. `check_snap_frame` scored 100% because a control
    line went from "198193 changed against 0" to "197995 changed against 1". A count of 0 to 1 is a
    100% move and the control needs a factor of four.

The quantity that would actually rank risk is headroom consumed: the movement as a fraction of the
distance to the assertion's own bound. It is not computed, and deliberately: only 159 of 3266 assertion
lines state a bound at all, and pairing the stated bound with the right value inside a free-text line is a
guess that would be silently wrong on some of them. **So this tool says WHERE TO LOOK and refuses to say
HOW BAD.** Read the layer's own PASS lines before concluding anything from a row here.
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


def provenance(d):
    """(tree, why) from a sweep's own summary.txt, where `tree` is head+delta. A sweep that does not
    record what it ran on cannot be paired with anything, so an unreadable header is a refusal."""
    f = os.path.join(d, "summary.txt")
    if not os.path.exists(f):
        return None, "no summary.txt, so the tree it ran on is unrecorded"
    head = None
    delta = "clean"
    for line in io.open(f, encoding="utf-8", errors="replace"):
        m = re.search(r"\bhead:\s*([0-9a-f]{7,40})\b", line)
        if not m:
            continue
        head = m.group(1)[:7]
        d2 = re.search(r"\bdelta\s+([0-9a-f]+)", line)
        if d2:
            delta = d2.group(1)
        elif "worktree: clean" not in line:
            return None, "summary.txt records a modified worktree with no delta to identify it"
        break
    if head is None:
        return None, "summary.txt records no head commit"
    return (head, delta), ""


def changed_under_tools(head_a, head_b):
    """Which files under tools/ differ between two commits. None means git could not say."""
    import subprocess
    try:
        out = subprocess.run(["git", "diff", "--name-only", head_a, head_b, "--", "tools/"],
                             capture_output=True, text=True, timeout=30)
    except Exception:
        return None
    if out.returncode != 0:
        return None
    return [ln for ln in out.stdout.split("\n") if ln.strip()]


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
            rows.append((n, -1, len(na), 0.0))
            continue
        moved = 0
        worst = 0.0
        for x, y in zip(na, nb):
            if x == y:
                continue
            moved += 1
            try:
                fx, fy = float(x), float(y)
            except ValueError:
                continue
            worst = max(worst, abs(fx - fy) / max(abs(fx), abs(fy), 1e-9))
        if moved:
            rows.append((n, moved, len(na), worst))
    return rows


def main():
    argv = [x for x in sys.argv[1:] if x != "--cross-tree"]
    cross = len(argv) != len(sys.argv) - 1
    if len(argv) != 2:
        print(__doc__)
        return 2
    da, db = argv[0], argv[1]
    a, b = read_layers(da), read_layers(db)
    if not a or not b:
        print("sweep_drift: REFUSED - one of the directories holds no *.log files", file=sys.stderr)
        return 1

    # THE PRECONDITION, CHECKED. Reproducibility is only what this measures if the thing measured was the
    # same both times, and neither way that fails is visible anywhere in the logs being compared.
    ta, wa = provenance(da)
    tb, wb = provenance(db)
    if ta is None or tb is None:
        print("sweep_drift: REFUSED - %s: %s" % (os.path.basename((da if ta is None else db).rstrip("/")),
                                                 wa or wb), file=sys.stderr)
        print("  Without both trees this cannot tell reproducibility from a code change.", file=sys.stderr)
        return 1
    if ta != tb:
        print("sweep_drift: the two sweeps ran on DIFFERENT trees.", file=sys.stderr)
        print("    %-34s %s" % (os.path.basename(da.rstrip("/")), "%s + %s" % ta), file=sys.stderr)
        print("    %-34s %s" % (os.path.basename(db.rstrip("/")), "%s + %s" % tb), file=sys.stderr)
        if ta[0] != tb[0]:
            touched = changed_under_tools(ta[0], tb[0])
            if touched is None:
                print("  git could not diff the two commits, so which layers changed is unknown.",
                      file=sys.stderr)
            elif touched:
                print("  %d file(s) under tools/ differ between the commits:" % len(touched),
                      file=sys.stderr)
                for t in touched[:12]:
                    print("      %s" % t, file=sys.stderr)
                if len(touched) > 12:
                    print("      ... and %d more" % (len(touched) - 12), file=sys.stderr)
            else:
                print("  No file under tools/ differs; any movement below would be the game's, not the",
                      file=sys.stderr)
                print("  layers'.", file=sys.stderr)
        else:
            print("  Same commit, different uncommitted delta.", file=sys.stderr)
        if not cross:
            print("sweep_drift: REFUSED. A layer repaired between these two sweeps moves every number it",
                  file=sys.stderr)
            print("  prints and would rank as the least reproducible layer here. Pass --cross-tree if you",
                  file=sys.stderr)
            print("  have a reason to compare them anyway.", file=sys.stderr)
            return 1
        print("sweep_drift: --cross-tree given. ANY ROW BELOW MAY BE A CODE CHANGE.", file=sys.stderr)
        print(file=sys.stderr)

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
    print()
    print("  %-26s %8s  %9s   %s" % ("layer", "moved", "widest", "judged numbers"))
    for n, moved, total, worst in sorted(rows, key=lambda r: -r[3]):
        if moved < 0:
            print("  %-26s SHAPE CHANGED - %d judged numbers on one side" % (n, total))
        else:
            print("  %-26s %6d/%-3d %8.1f%%   %d" % (n, moved, total, 100.0 * worst, total))
    print()
    print("  moved  = how many judged numbers differ.  widest = the largest single move, relative.")
    print("  Neither ranks risk. See the header of this file for the two ways each one lies.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
