#!/usr/bin/env python3
"""tools/check_corrections_freshness.py -- freshness gate for docs/CORRECTIONS.md (queue #3 Part L2).

`docs/CORRECTIONS.md` is a curated projection over `docs/DECISIONS_LEDGER.md`'s own correction links
(D0170): grep the ledger's own header lines for entries whose text says a prior entry was corrected,
wrong, superseded, or falsified, then read each one in full and write it up -- a judgment call this
script does NOT attempt to replace. D0170's own account: several grep hits need a human read to tell a
real correction (names an earlier entry as wrong) from an entry merely ABOUT the concept of correction.
Because of that judgment step, this is NOT a full regenerate-and-diff gate like
`tools/data_codegen/generate.py --check` -- there is no mechanical way to produce CORRECTIONS.md's own
prose from the ledger alone, so building one would mean faking the judgment, not skipping it.

What this script DOES check, mechanically, every run: every ledger entry whose header matches the same
keyword pattern D0170 used has its own D-number appearing somewhere in CORRECTIONS.md's text. A match not
found there is drift -- a candidate correction the page has not yet caught up to -- reported explicitly,
not silently absorbed. This is the narrower, honest half of "regenerate with a --check gate": it notices
when the candidate set has grown, so a future session doesn't have to remember to re-run D0170's own grep
by hand.

    python3 tools/check_corrections_freshness.py          # prints the candidate set and any drift
    python3 tools/check_corrections_freshness.py --check  # gate mode: exit 1 if any candidate is missing

Known blind spot, stated plainly (D0170's own limit, unchanged by this script): a future correction whose
header line doesn't use one of these keywords is invisible to this gate too, same as it was to the grep
that first built the page.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LEDGER = ROOT / "docs" / "DECISIONS_LEDGER.md"
CORRECTIONS = ROOT / "docs" / "CORRECTIONS.md"

HEADER_ID_RE = re.compile(r"^## (D\d{4}) ·")
KEYWORD_RE = re.compile(
    r"correct|supersed|falsif|corrective|reversed|wrong|mistake|error found|retract",
    re.IGNORECASE,
)


FILENAME_RE = re.compile(r"(docs/)?CORRECTIONS\.md", re.IGNORECASE)


def candidate_ids(ledger_text: str) -> list[str]:
    ids = []
    for line in ledger_text.splitlines():
        m = HEADER_ID_RE.match(line)
        if not m:
            continue
        # A header naming the file "CORRECTIONS.md" itself false-positives on the
        # keyword regex (the filename contains the substring "correct") -- strip
        # that literal reference before matching, so citing the page by name isn't
        # mistaken for the page correcting something. Found by dogfooding this gate
        # against a real ledger: it flagged D0170/D0174, the two entries that only
        # ever MENTION CORRECTIONS.md, as drift.
        stripped = FILENAME_RE.sub("", line)
        if KEYWORD_RE.search(stripped):
            ids.append(m.group(1))
    return ids


def main() -> int:
    check_mode = "--check" in sys.argv[1:]
    ledger_text = LEDGER.read_text(encoding="utf-8")
    corrections_text = CORRECTIONS.read_text(encoding="utf-8")

    candidates = candidate_ids(ledger_text)
    missing = [d for d in candidates if d not in corrections_text]

    print(f"check_corrections_freshness: {len(candidates)} candidate entries in the ledger "
          f"matching the correction-keyword pattern")
    if missing:
        print(f"DRIFT: {len(missing)} candidate(s) not yet mentioned in docs/CORRECTIONS.md: "
              f"{', '.join(missing)}")
    else:
        print("clean: every candidate entry's D-number appears somewhere in docs/CORRECTIONS.md")

    if check_mode and missing:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
