#!/usr/bin/env python3
"""Every ledger entry number is declared exactly once, and every back-reference points at a real entry.

    python3 tools/layer_lint/check_ledger_integrity.py

WHY THIS EXISTS (`docs/DECISIONS_LEDGER.md` D0298). Ledger numbers are ADDRESSES: `CLAUDE.md` forbids
editing or reusing one, and dozens of commit messages, docs and code comments cite them. That makes the
ledger append-only, which makes it conflict on **every** rebase in a batched-branch run -- the same
conflict, resolved by hand, several times an hour. The remedy is `.gitattributes`' `merge=union`, which
concatenates both sides' appended blocks with no markers and no human in the loop.

Union merge is the right resolver for an append-only file and the wrong one for everything else: it will
happily produce a file containing an entry twice if the append-only rule is ever actually broken, and it
does so SILENTLY, which is this project's dominant failure shape. This gate is the other half of that
trade -- the check that makes an automatic resolver safe to enable.

**Two heading FORMS, and conflating them is how the first version of this got it wrong.** A scan for
`^## D0\\d{3}` reported D0004 and D0019 as duplicated, and they are not:

    ## D0004 · 2026-08-26 · core/ -- NOT DECIDED, stopped per instruction   <- a DECLARATION
    ## D0004 -- RESOLVED, 2026-08-26                                        <- a continuation
    ## D0019/D0020 · 2026-08-26 · addendum -- the wrapper-type cost         <- a joint addendum

Only the first form opens a new address. The other two revisit addresses that already exist, which is a
thing the ledger does deliberately and must keep being allowed to do. Told apart by the separator: a
declaration is one number followed by ` · `. Enumerating the forms first turned a two-entry grandfather
list into no grandfather list at all -- there are zero duplicate declarations in this file and there
never were (memory: *declaration forms a scan omits*).

The `--` rules below are each here because a merge can produce them and nothing else would notice.
"""

import re
import sys
from pathlib import Path

LEDGER = Path("docs/DECISIONS_LEDGER.md")

# One heading, any depth, opening with one or more slash-joined entry numbers. `rest` decides the form.
HEADING = re.compile(r"^(#+) +(D0\d{3}(?:/D0\d{3})*)(.*)$", re.M)

CONFLICT_MARKERS = ("<<<<<<< ", "=======\n", ">>>>>>> ")

# A ledger that parses to zero entries is indistinguishable from a clean one, and that is precisely the
# green-by-absence shape this project keeps finding. Any real ledger is far above this; the number only
# has to be high enough that an empty or truncated file cannot slip past as "no violations".
MIN_DECLARATIONS = 50


def find_violations(root: Path) -> list[str]:
    """Return one string per problem. Empty means the ledger is well-formed."""
    path = root / LEDGER
    if not path.exists():
        return [f"{LEDGER} does not exist -- this gate cannot check a file that is not there"]
    text = path.read_text(encoding="utf-8")

    violations: list[str] = []

    # A conflict marker committed into the ledger is silent: the file still renders, still greps, and
    # the surrounding entries still read correctly. Only a scan like this one sees it.
    for marker in CONFLICT_MARKERS:
        if marker in text:
            line = text[: text.index(marker)].count("\n") + 1
            violations.append(f"{LEDGER}:{line}: an unresolved conflict marker "
                              f"{marker.strip()!r} was committed into the ledger")

    declarations: dict[str, int] = {}
    duplicate_of: list[str] = []
    references: list[tuple[str, int, str]] = []
    for match in HEADING.finditer(text):
        numbers, rest = match.group(2), match.group(3)
        line = text[: match.start()].count("\n") + 1
        is_declaration = "/" not in numbers and rest.lstrip().startswith("·")
        if not is_declaration:
            for number in numbers.split("/"):
                references.append((number, line, match.group(0).strip()))
            continue
        if numbers in declarations:
            duplicate_of.append(f"{LEDGER}:{line}: entry {numbers} is declared a second time "
                                f"(first at line {declarations[numbers]}) -- a ledger number is an "
                                f"address and two entries cannot share one")
        else:
            declarations[numbers] = line
    violations.extend(duplicate_of)

    if len(declarations) < MIN_DECLARATIONS:
        violations.append(f"{LEDGER}: parsed only {len(declarations)} entry declarations, below the "
                          f"floor of {MIN_DECLARATIONS} -- a ledger that parses to almost nothing "
                          f"would otherwise pass this gate by having no entries to fault")

    # An addendum or a RESOLVED continuation pointing at an entry that is not in the file is exactly what
    # a merge that dropped a block looks like from the inside.
    for number, line, heading in references:
        if number not in declarations:
            violations.append(f"{LEDGER}:{line}: {heading!r} revisits entry {number}, which is never "
                              f"declared in this file -- either the entry was lost by a merge, or the "
                              f"heading names the wrong number")

    return violations


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    violations = find_violations(root)
    if violations:
        print(f"check_ledger_integrity: FAIL -- {len(violations)} problem(s) in {LEDGER}:")
        for violation in violations:
            print(f"  {violation}")
        return 1
    declarations = len(HEADING.findall((root / LEDGER).read_text(encoding="utf-8")))
    print(f"check_ledger_integrity: PASS -- {declarations} headings, every entry number declared once, "
          f"every back-reference resolves.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
