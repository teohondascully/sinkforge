#!/usr/bin/env python3
"""Pick one random commit for a ledger spot-audit. Run by the director, never by the session being
audited -- the point is checking whether the session under-reported, so it cannot select its own sample.
`CONTEXT.md`, "Review bandwidth."

    python3 tools/spot_audit.py

Samples uniformly from commits made AFTER docs/DECISIONS_LEDGER.md itself was created (found by walking
its own git history, not a hardcoded hash -- the ledger could in principle be renamed or recreated, and a
hardcoded commit would then silently audit the wrong range). Prints the chosen commit's short hash and
subject; the reviewer pastes its full diff (`git show <hash>`) alongside the ledger entries that claim to
cover it.

The first version of this idea (`git log --oneline | shuf -n 1`) sampled the ENTIRE history, including
commits from before the ledger existed -- one draw landed on a pre-ledger commit and tested nothing. This
script exists specifically to not repeat that mistake. `shuf`/`gshuf` also isn't available on every
platform (not on stock macOS); this uses Python's own `random`, which is.
"""
import subprocess
import sys


def ledger_creation_commit() -> str:
    out = subprocess.run(
        ["git", "log", "--follow", "--diff-filter=A", "--format=%H", "--", "docs/DECISIONS_LEDGER.md"],
        capture_output=True, text=True, check=True,
    ).stdout.strip().splitlines()
    if not out:
        print("spot_audit: docs/DECISIONS_LEDGER.md has no creation commit in history -- nothing to "
              "sample from.", file=sys.stderr)
        sys.exit(1)
    return out[-1]  # git log is newest-first; the last line is the oldest, i.e. the creation commit.


def main() -> int:
    creation = ledger_creation_commit()
    out = subprocess.run(
        ["git", "log", "--oneline", f"{creation}..HEAD"],
        capture_output=True, text=True, check=True,
    ).stdout.strip().splitlines()
    if not out:
        print(f"spot_audit: no commits after the ledger's creation ({creation[:7]}) -- nothing to audit "
              f"yet.")
        return 0

    import random
    chosen = random.choice(out)
    print(f"spot_audit: sampled from {len(out)} commit(s) after the ledger's creation ({creation[:7]})")
    print(f"spot_audit: chosen commit -- {chosen}")
    print(f"spot_audit: run `git show {chosen.split()[0]}` for its full diff, then compare against the "
          f"ledger entries that claim to cover it.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
