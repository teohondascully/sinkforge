#!/usr/bin/env python3
"""Mutation test for check_ci_suite_count.py (D0317).

    python3 tools/layer_lint/test_check_ci_suite_count.py

Swept by CI's "every tools/**/test_*.py" step, so it needs no workflow entry of its own.

WHAT IT PINS, and why each row is not decoration:

  1. the real workflow passes                 -- the gate is not simply always-fail
  2. label below the truth fails              -- the D0317 defect itself (49 against 62)
  3. label above the truth fails              -- drift has two directions and `!=` is easy to write as `<`
  4. no count in the label fails              -- deleting the number is the edit someone reaches for
                                                 when this gate goes red, and it must not be a way out
  5. the self-test step is NOT the subject    -- `run_suites.sh` is invoked by its own D0272 self-test
                                                 with no suites; a gate that judged that step would be
                                                 unfixable, and one that judged it INSTEAD would pass
                                                 on any label at all
  6. an emptied parallel step fails           -- the population going to zero is a failure, not a skip
  7. an absent `tests` job fails              -- "found no mismatches" and "could not look" must not
                                                 produce the same exit code

Rows 5-7 exist because rows 1-4 are all satisfied by a gate reading the WRONG STEP or NO STEP. That is
this repository's dominant failure class and it does not stop being possible inside the check written to
catch an instance of it.
"""
import pathlib
import subprocess
import sys
import tempfile

import yaml

ROOT = pathlib.Path(__file__).resolve().parents[2]
GATE = ROOT / "tools" / "layer_lint" / "check_ci_suite_count.py"
REAL = ROOT / ".github" / "workflows" / "harness.yml"

fails = 0


def check(ok: bool, label: str) -> None:
    global fails
    if ok:
        print(f"  PASS  {label}")
    else:
        print(f"  FAIL  {label}", file=sys.stderr)
        fails += 1


def run(path: pathlib.Path) -> int:
    return subprocess.run([sys.executable, str(GATE), str(path)],
                          capture_output=True, text=True).returncode


def write(doc: dict) -> pathlib.Path:
    fh = tempfile.NamedTemporaryFile("w", suffix=".yml", delete=False, encoding="utf-8")
    yaml.safe_dump(doc, fh)
    fh.close()
    return pathlib.Path(fh.name)


def load_real() -> dict:
    return yaml.safe_load(REAL.read_text(encoding="utf-8"))


def suite_step(doc: dict) -> dict:
    """The step the gate is about: the one passing res:// suites to the runner."""
    for step in doc["jobs"]["tests"]["steps"]:
        if "run_suites.sh" in (step.get("run") or "") and "res://tests/" in step["run"]:
            return step
    raise SystemExit("test_check_ci_suite_count: the real workflow has no parallel suite step to mutate")


print("test_check_ci_suite_count: mutating the real workflow, one property at a time")

# --- 1. THE CONTROL. Without it every row below is satisfied by a gate that fails on everything. ------
check(run(REAL) == 0, "the real workflow passes (the gate is not always-fail)")

# --- 2-3. Drift in both directions. --------------------------------------------------------------
for wrong, direction in ((49, "below"), (999, "above")):
    doc = load_real()
    step = suite_step(doc)
    actual = step["run"].count("res://tests/")
    step["name"] = f"all {wrong} suites, in parallel"
    check(run(write(doc)) == 1, f"a label {direction} the truth fails ({wrong} against {actual})")

# --- 4. Deleting the count is not a way out. ------------------------------------------------------
doc = load_real()
suite_step(doc)["name"] = "all suites, in parallel"
check(run(write(doc)) == 1, "a label with NO count fails -- removing the number is not an escape")

# --- 5. The D0272 self-test step is not the subject, and mislabelling it changes nothing. ----------
doc = load_real()
for step in doc["jobs"]["tests"]["steps"]:
    if "run_suites.sh" in (step.get("run") or "") and "res://tests/" not in step["run"]:
        step["name"] = "all 7 suites, in parallel"   # a lie, on a step that runs no suites
check(run(write(doc)) == 0,
      "the run_suites.sh self-test step is NOT judged (it passes no suites, so a count on it is not "
      "the gate's subject)")

# --- 6. The population going to zero is a failure, not a skip. ------------------------------------
doc = load_real()
step = suite_step(doc)
step["run"] = "bash tools/run_suites.sh ./godot 4\n"
check(run(write(doc)) == 2, "an EMPTIED parallel step fails rather than passing on an empty population")

# --- 7. "Could not look" must not read as "looked and found nothing". -----------------------------
doc = load_real()
del doc["jobs"]["tests"]
check(run(write(doc)) == 2, "an absent 'tests' job fails (exit 2), never a silent pass")

# --- 8-9. THE ASK, FROM THE OTHER SIDE. Rows 2-3 move the label against a fixed suite list; these move
# the SUITE LIST against a fixed label, which is what actually happens when someone adds a test. A step
# `name:` cannot interpolate shell output, so the label cannot update itself -- what it can do is refuse
# to be wrong, which turns "remember to edit the name" into a red build instead of a silent drift.
for delta, verb in ((1, "adding"), (-1, "removing")):
    doc = load_real()
    step = suite_step(doc)
    actual = step["run"].count("res://tests/")
    if delta > 0:
        step["run"] += "            res://tests/test_newly_added.gd \\\n"
    else:
        step["run"] = step["run"].replace("res://tests/test_fixed_point.gd", "", 1)
    check(run(write(doc)) == 1,
          f"{verb} a suite without touching the label fails ({actual} -> {actual + delta} against a "
          f"label still reading {actual})")

if fails == 0:
    print("test_check_ci_suite_count: PASS.")
    sys.exit(0)
print(f"test_check_ci_suite_count: FAIL -- {fails} case(s).", file=sys.stderr)
sys.exit(1)
