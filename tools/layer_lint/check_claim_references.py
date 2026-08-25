#!/usr/bin/env python3
"""Every scenario and every harness layer names a claim. docs/QUALITY.md gate 15-16.

    python3 tools/layer_lint/check_claim_references.py

"The single most important process gate in this document" (docs/QUALITY.md
§1) — the direct fix for the prior codebase's 108 registered check layers
accumulating with no claim behind a large fraction of them. This is a
mechanical existence check, not a taste check: it does not judge whether the
claim reference is the RIGHT claim, only that one is present and the ID it
names exists in claims/.

Scope:
  - scenarios/*.yaml — must carry a top-level `claim: C###` key
    (docs/ARCHITECTURE.md §6 scenario format).
  - harness/**/*.gd — every file that registers a check/layer (heuristic:
    contains a top-level `func run(` or a `# claim:` marker comment — see
    below) must carry a `# claim: C###` comment. Marker-comment convention,
    not a language feature, so it is stated here rather than assumed.

Exemption: docs/adr/0001 records that report/visualization tooling under
harness/aggregate/ is exempt — it serves the whole corpus and defends no
single claim. A file exempted this way must say so explicitly with
`# claim: EXEMPT (ADR-0001)` — an unmarked file is a gap, not a pass, so
exemption cannot be silent.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CLAIM_RE = re.compile(r'\bC\d{3}\b')
SCENARIO_CLAIM_RE = re.compile(r'^\s*claim:\s*(C\d{3})\b', re.MULTILINE)
GD_CLAIM_RE = re.compile(r'^\s*#\s*claim:\s*(C\d{3}|EXEMPT \(ADR-\d{4}\))', re.MULTILINE)


def known_claim_ids() -> set[str]:
    claims_dir = ROOT / "claims"
    if not claims_dir.is_dir():
        return set()
    return {p.stem.split("-")[0] for p in claims_dir.glob("C*.md")}


def check_scenarios(known: set[str]) -> list[str]:
    scenarios_dir = ROOT / "scenarios"
    errors = []
    if not scenarios_dir.is_dir():
        return errors
    for path in sorted(scenarios_dir.glob("*.yaml")):
        text = path.read_text(encoding="utf-8", errors="replace")
        m = SCENARIO_CLAIM_RE.search(text)
        rel = path.relative_to(ROOT)
        if not m:
            errors.append(f"{rel}: no top-level `claim: C###` key")
            continue
        if m.group(1) not in known:
            errors.append(f"{rel}: claims unknown id {m.group(1)} (not in claims/)")
    return errors


def check_harness_layers(known: set[str]) -> list[str]:
    harness_dir = ROOT / "harness"
    errors = []
    if not harness_dir.is_dir():
        return errors
    for path in sorted(harness_dir.rglob("*.gd")):
        text = path.read_text(encoding="utf-8", errors="replace")
        registers_a_check = bool(re.search(r'^\s*func run\s*\(', text, re.MULTILINE))
        if not registers_a_check:
            continue  # a support file, not a registered check layer itself
        rel = path.relative_to(ROOT)
        m = GD_CLAIM_RE.search(text)
        if not m:
            errors.append(f"{rel}: registers a check (func run()) but has no `# claim: C###` comment")
            continue
        claimed = m.group(1)
        if claimed.startswith("EXEMPT"):
            continue
        if claimed not in known:
            errors.append(f"{rel}: claims unknown id {claimed} (not in claims/)")
    return errors


def main() -> int:
    known = known_claim_ids()
    scenarios_dir_exists = (ROOT / "scenarios").is_dir()
    harness_dir_exists = (ROOT / "harness").is_dir()

    if not scenarios_dir_exists and not harness_dir_exists:
        print("check_claim_references: neither scenarios/ nor harness/ exist yet — nothing to check.")
        print("check_claim_references: PASS (vacuously)")
        return 0

    errors = check_scenarios(known) + check_harness_layers(known)

    print(f"check_claim_references: {len(known)} known claim id(s) in claims/")
    if errors:
        print(f"check_claim_references: FAIL — {len(errors)} violation(s)")
        for e in errors:
            print(f"  FAIL  {e}")
        return 1

    print("check_claim_references: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
