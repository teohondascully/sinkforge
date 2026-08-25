#!/usr/bin/env python3
"""Every scenario and every harness layer names a claim. docs/QUALITY.md gate 15-16.

    python3 tools/layer_lint/check_claim_references.py

"The single most important process gate in this document" (docs/QUALITY.md
§1) — the direct fix for the prior codebase's 108 registered check layers
accumulating with no claim behind a large fraction of them. This is a
mechanical existence check, not a taste check: it does not judge whether the
claim reference is the RIGHT claim, only that one is present, the ID it
names exists in claims/, and (docs/CLAIMS.md §10a) that claim has actually
been observed failing at least once.

Scope:
  - scenarios/*.yaml — must carry a top-level `claim: C###` key
    (docs/ARCHITECTURE.md §6 scenario format).
  - harness/**/*.gd — every file that registers a check/layer (heuristic:
    contains a top-level `func run(` or a `# claim:` marker comment — see
    below) must carry a `# claim: C###` comment. Marker-comment convention,
    not a language feature, so it is stated here rather than assumed.

A claim ID only counts as known if the claim file's frontmatter has a
`first_failed_at` other than `never` (docs/CLAIMS.md §10a: "a claim born
PASSING was written to describe existing behavior... until first_failed_at
is populated, the claim is provisional and does not satisfy the
claim-reference gate for any harness layer"). Citing an unproven claim is
the same violation as citing no claim at all.

Also enforces the 40-active-claim cap (docs/CLAIMS.md §10c): counts claims
whose `status` is not `RETIRED`.

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
SCENARIO_CLAIM_RE = re.compile(r'^\s*claim:\s*(C\d{3})\b', re.MULTILINE)
GD_CLAIM_RE = re.compile(r'^\s*#\s*claim:\s*(C\d{3}|EXEMPT \(ADR-\d{4}\))', re.MULTILINE)
FRONTMATTER_RE = re.compile(r'\A---\n(.*?)\n---', re.DOTALL)
ACTIVE_CLAIM_CAP = 40


def parse_frontmatter(text: str) -> dict[str, str]:
    """Minimal `key: value` frontmatter parser — no YAML dependency for a flat block."""
    m = FRONTMATTER_RE.match(text)
    if not m:
        return {}
    fields = {}
    for line in m.group(1).splitlines():
        if ":" not in line or line.strip().startswith("#"):
            continue
        key, _, value = line.partition(":")
        value = value.split("#", 1)[0].strip()  # strip inline comments
        fields[key.strip()] = value
    return fields


def load_claims() -> dict[str, dict[str, str]]:
    """claim id -> its frontmatter fields, for every file in claims/."""
    claims_dir = ROOT / "claims"
    if not claims_dir.is_dir():
        return {}
    out = {}
    for path in claims_dir.glob("C*.md"):
        cid = path.stem.split("-")[0]
        out[cid] = parse_frontmatter(path.read_text(encoding="utf-8", errors="replace"))
    return out


def proven_claim_ids(claims: dict[str, dict[str, str]]) -> set[str]:
    return {cid for cid, fields in claims.items() if fields.get("first_failed_at", "never") != "never"}


def check_active_claim_cap(claims: dict[str, dict[str, str]]) -> list[str]:
    active = [cid for cid, fields in claims.items() if fields.get("status") != "RETIRED"]
    if len(active) > ACTIVE_CLAIM_CAP:
        return [
            f"{len(active)} active (non-RETIRED) claims exceeds the cap of {ACTIVE_CLAIM_CAP} "
            f"(docs/CLAIMS.md §10c) — retire one before adding another"
        ]
    return []


def check_scenarios(proven: set[str], all_ids: set[str]) -> list[str]:
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
        claimed = m.group(1)
        if claimed not in all_ids:
            errors.append(f"{rel}: claims unknown id {claimed} (not in claims/)")
        elif claimed not in proven:
            errors.append(f"{rel}: claims {claimed}, which has never been observed FAILING "
                           f"(first_failed_at: never) — provisional, does not satisfy this gate")
    return errors


def check_harness_layers(proven: set[str], all_ids: set[str]) -> list[str]:
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
        if claimed not in all_ids:
            errors.append(f"{rel}: claims unknown id {claimed} (not in claims/)")
        elif claimed not in proven:
            errors.append(f"{rel}: claims {claimed}, which has never been observed FAILING "
                           f"(first_failed_at: never) — provisional, does not satisfy this gate")
    return errors


def main() -> int:
    claims = load_claims()
    all_ids = set(claims)
    proven = proven_claim_ids(claims)
    scenarios_dir_exists = (ROOT / "scenarios").is_dir()
    harness_dir_exists = (ROOT / "harness").is_dir()

    cap_errors = check_active_claim_cap(claims)

    if not scenarios_dir_exists and not harness_dir_exists:
        print("check_claim_references: neither scenarios/ nor harness/ exist yet — nothing to check "
              "for claim references, but the corpus cap still applies.")
        if cap_errors:
            print(f"check_claim_references: FAIL — {len(cap_errors)} violation(s)")
            for e in cap_errors:
                print(f"  FAIL  {e}")
            return 1
        print("check_claim_references: PASS (vacuously on references — nothing to check yet)")
        return 0

    errors = cap_errors + check_scenarios(proven, all_ids) + check_harness_layers(proven, all_ids)

    print(f"check_claim_references: {len(all_ids)} known claim id(s) in claims/, "
          f"{len(proven)} proven (first_failed_at populated)")
    if errors:
        print(f"check_claim_references: FAIL — {len(errors)} violation(s)")
        for e in errors:
            print(f"  FAIL  {e}")
        return 1

    print("check_claim_references: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
