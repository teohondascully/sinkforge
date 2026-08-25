#!/usr/bin/env python3
"""Instrument LOC may not exceed game LOC. docs/QUALITY.md gate 7, docs/CLAIMS.md §2.

    python3 tools/layer_lint/check_loc_ratio.py

    instrument = harness/ + experiment/ + tools/ + tests/
    game       = core/ + sim/ + interface/ + view/ + shell/

This is the single check that failed hardest in the prior codebase: tools/
grew 90% in five days against src/'s 9% (docs/archive/COMPAT_AUDIT... and
docs/archive/PIVOT_PLAN...), and no individual commit that produced that
looked wrong on its own. This gate exists to make the trend visible on every
PR instead of discoverable only in retrospect.

legacy/ is excluded from both sides — it is frozen, pre-pivot code and
counting it would make this gate meaningless in both directions.

`tools/scratch/` is excluded from the instrument side: it is gitignored
precisely so throwaway exploration doesn't count against anything, per
docs/ONBOARDING.md's scratch-work rule.

Counts `.gd`, `.py`, and `.sh` — not `.gd` alone. The gates in this very
directory are Python, and counting only GDScript would make them invisible
to the ratio they're supposed to be part of: exactly the "instrument cannot
register its subject" failure this project's own culture watches for.
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

INSTRUMENT_DIRS = ["harness", "experiment", "tools", "tests"]
GAME_DIRS = ["core", "sim", "interface", "view", "shell"]
SCRATCH_PREFIX = "tools/scratch"
CODE_EXTENSIONS = ("*.gd", "*.py", "*.sh")


def loc_under(dirname: str) -> int:
    base = ROOT / dirname
    if not base.is_dir():
        return 0
    total = 0
    paths = (p for ext in CODE_EXTENSIONS for p in base.rglob(ext))
    for p in paths:
        rel = p.relative_to(ROOT).as_posix()
        if rel.startswith(SCRATCH_PREFIX + "/"):
            continue
        total += len(p.read_text(encoding="utf-8", errors="replace").splitlines())
    return total


def main() -> int:
    instrument = {d: loc_under(d) for d in INSTRUMENT_DIRS}
    game = {d: loc_under(d) for d in GAME_DIRS}
    instrument_total = sum(instrument.values())
    game_total = sum(game.values())

    print("check_loc_ratio: instrument (harness+experiment+tools+tests):")
    for d, n in instrument.items():
        print(f"    {d:12s} {n:6d}")
    print(f"    {'total':12s} {instrument_total:6d}")
    print("check_loc_ratio: game (core+sim+interface+view+shell):")
    for d, n in game.items():
        print(f"    {d:12s} {n:6d}")
    print(f"    {'total':12s} {game_total:6d}")

    if game_total == 0:
        # Bootstrap exception, not a loophole: the gate scripts under tools/ MUST exist
        # before core/ and sim/ do (docs/ONBOARDING.md Task 0.6, "build the gates before
        # the code"), so a nonzero instrument total here is expected, not drift. The ratio
        # this gate exists to police ("instrument outpacing game") is meaningless with no
        # game to compare against — see docs/ARCHITECTURE.md discussion in this project's
        # memory of "expected null carries no conclusion": a zero-game state is a different
        # condition than "instrument exceeds game," not a degenerate case of it.
        # This WARN must stop being silent the moment Task 1 lands core/ — if this line is
        # still printing once game_total has been nonzero in a prior run, that is the drift
        # this gate exists to catch, and it should be treated as a FAIL by hand until then.
        print(
            f"check_loc_ratio: WARN — {instrument_total} lines of instrument exist with zero "
            "lines of game. Expected before Task 1 lands core/; the ratio is unenforceable "
            "until then. PASS on this bootstrap exception, not because the ratio holds."
        )
        return 0

    ratio = instrument_total / game_total
    print(f"check_loc_ratio: ratio = {ratio:.3f} (instrument / game)")
    if instrument_total > game_total:
        print(
            f"check_loc_ratio: FAIL — instrument ({instrument_total}) exceeds game ({game_total}). "
            "Per docs/CLAIMS.md, the next unit of work is game, not another check."
        )
        return 1

    print("check_loc_ratio: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
