#!/usr/bin/env python3
"""Mutation tests for `tools/perf_fixture.py`'s refusal rules and its line parser.

    python3 tools/test_perf_fixture.py

Exit 0 if every rule both FIRES on its own failure and STAYS QUIET on a clean set, 1 otherwise.

## Why each rule is tested with a passing control beside it

A refusal rule that can never pass is as useless as one that can never fire, and both look identical
from a green run. Every case below is a pair: the window set that must be refused, and a window set
differing only in the thing the rule is about, which must be accepted. That is the same discipline the
repository's other gate tests hold to, and it is what `docs/CLAIMS.md` calls reaching a check versus the
check firing.

The rules exist because each of them caught something real while the fixture was being built, on
2026-09-08:

* the work rule caught a `dig` workload that mined air for four consecutive windows -- the hand held one
  point, cut a notch narrower than the miner, and the runner would have averaged a standstill into the
  numbers under the heading "dig";
* the movement rule caught the same class in the workload the bake cannot see: a one-way walk crossed
  this 256-cell world in a single window and then stood against the east edge for the rest of the run;
* the control rule is the one D0527 needed and did not have, when the host ran the main thread ~3x
  slower and every painter, every HUD chip and `observe` slowed by the same factor;
* the pacing rule is legacy's own warning, which D0527 walked into anyway: under display pacing every
  frame inside a refresh interval measures as exactly one refresh interval.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import perf_fixture as pf  # noqa: E402

FAILURES: list[str] = []


def check(name: str, got: str, want_prefix: str) -> None:
    if not got.startswith(want_prefix):
        FAILURES.append("%s: wanted %s, got %r" % (name, want_prefix, got))


def win(cal: float = 60.0, fps: float = 400.0, chunks: int = 5, body: tuple = (10, 20)) -> dict:
    return {"cal_p50": cal, "fps_wall": fps, "prep_chunks": chunks, "body": body}


def test_work_rule() -> None:
    """A digging workload that baked nothing is refused; one that baked is not."""
    check("dig idle", pf.verdict("dig", [win(chunks=5), win(chunks=0)]), "VOID")
    check("fall idle", pf.verdict("fall", [win(chunks=0), win(chunks=4)]), "VOID")
    check("dig working", pf.verdict("dig", [win(chunks=5), win(chunks=4)]), "VALID")
    # The rule is scoped, and the scope is the mutation that matters: `still` and `walk` bake nothing by
    # design in this world, so applying the bake rule to them would refuse every honest run they produce.
    check("still exempt", pf.verdict("still", [win(chunks=0), win(chunks=0)]), "VALID")
    check("walk exempt", pf.verdict("walk", [win(chunks=0), win(chunks=0, body=(90, 20))]), "VALID")


def test_movement_rule() -> None:
    """The walk must move and the standstill must not; each is the other's mutation."""
    check("walk stuck", pf.verdict("walk", [win(chunks=0), win(chunks=0)]), "VOID")
    check("walk moving", pf.verdict("walk", [win(chunks=0), win(chunks=0, body=(90, 20))]), "VALID")
    check("still moved", pf.verdict("still", [win(chunks=0), win(chunks=0, body=(90, 20))]), "VOID")
    check("still still", pf.verdict("still", [win(chunks=0), win(chunks=0)]), "VALID")


def test_control_rule() -> None:
    """Host drift: quiet below SUSPECT, described between, refused above MAX."""
    steady = pf.CAL_DRIFT_SUSPECT * 0.9
    middle = (pf.CAL_DRIFT_SUSPECT + pf.CAL_DRIFT_MAX) / 2.0
    check("control steady", pf.verdict("dig", [win(cal=60.0), win(cal=60.0 * steady)]), "VALID")
    check("control drifting", pf.verdict("dig", [win(cal=60.0), win(cal=60.0 * middle)]), "SUSPECT")
    check("control broken", pf.verdict("dig", [win(cal=60.0), win(cal=60.0 * pf.CAL_DRIFT_MAX * 1.1)]), "VOID")
    check("control zero", pf.verdict("dig", [win(cal=0.0), win(cal=0.0)]), "VOID")


def test_one_window_rule() -> None:
    """A single warm window carries no spread, so it carries no control either."""
    check("one window", pf.verdict("dig", [win()]), "VOID")


def test_pacing_rule() -> None:
    """Pacing disqualifies the frame statistics and nothing else."""
    paced = [win(fps=120.0), win(fps=119.0)]
    check("all paced", pf.frame_note(paced), "WITHHELD")
    check("some paced", pf.frame_note([win(fps=120.0), win(fps=400.0)]), "WITHHELD")
    check("none paced", pf.frame_note([win(fps=400.0), win(fps=520.0)]), "VALID")
    # AND THE SEPARATION ITSELF: a fully paced set still has usable phase clocks, because a timer inside
    # the frame does not care what the display did with the finished picture. Refusing them here would
    # throw away good measurements of exactly what the performance passes move.
    check("paced phases survive", pf.verdict("dig", paced), "VALID")


def test_parser() -> None:
    """The three report lines parse into the fields the verdicts read."""
    lines = [
        "WINDOW tick=600 workload=dig body=(130,147)",
        "PERF frames=600 fps_wall=114.6 frame p50=6.10ms p99=40.17ms max=62.71ms over8.3ms=300 "
        "over16.7ms=25 | draw p50=4.40ms p99=9.91ms | physics hub p50=0.74ms p99=1.13ms n=100 | "
        "quiet p50=0.67ms p99=1.05ms n=200 | cal p50=58us p99=79us max=91us spread=1.36 n=150",
        "painters total=3.44ms (budget 8.33ms at 120Hz) -- sky_painter.paint=1.51ms | refresh=0.26ms "
        "(observe=0.18ms) queued=10824/12000 drawn=2.430ms/tick plane_rebuilds=105 hub_rebuilds=418 /600 ticks",
        "bake prep=0.554ms/tick chunks=120 cells=13892 12.30us/cell | upload=0.002ms/tick n=30 "
        "cells=8478720 0.000us/cell",
    ]
    w = pf.parse_windows("\n".join(lines))
    if len(w) != 1:
        FAILURES.append("parser: wanted 1 window, got %d" % len(w))
        return
    got = w[0]
    for key, want in (("workload", "dig"), ("body", (130, 147)), ("fps_wall", 114.6), ("p50", 6.10),
                      ("draw_p50", 4.40), ("quiet_p50", 0.67), ("cal_p50", 58.0), ("over16", 25.0),
                      ("drawn_per_tick", 2.430), ("prep_ms", 0.554), ("prep_chunks", 120.0),
                      ("prep_us_cell", 12.30), ("upload_ms", 0.002), ("uploads", 30.0)):
        if got.get(key) != want:
            FAILURES.append("parser %s: wanted %r, got %r" % (key, want, got.get(key)))
    # A WINDOW WITH NO PERF LINE IS DROPPED, not carried with holes in it. A seat that died mid-window
    # leaves exactly that, and a half-parsed window would reach `verdict` and be read for fields it does
    # not have -- which is how a crashed run turns into a quiet number.
    if pf.parse_windows("WINDOW tick=300 workload=dig body=(1,2)"):
        FAILURES.append("parser: kept a window that carried no PERF line")


def main() -> int:
    for fn in (test_work_rule, test_movement_rule, test_control_rule, test_one_window_rule,
               test_pacing_rule, test_parser):
        fn()
    if FAILURES:
        print("test_perf_fixture: %d FAILED" % len(FAILURES))
        for f in FAILURES:
            print("  " + f)
        return 1
    print("test_perf_fixture: all rules fire and all controls pass")
    return 0


if __name__ == "__main__":
    sys.exit(main())
