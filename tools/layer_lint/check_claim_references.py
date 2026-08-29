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

VOID, not PASS, on an empty corpus (added 2026-08-29, `docs/DECISIONS_LEDGER.md` D0146, the audit
queue's own A4): `scenarios/` has held only a README since before this gate existed and `harness/**/*.gd`
has zero files matching `func run(` right now, so `check_scenarios`/`check_harness_layers` both iterate
zero files and return zero errors -- vacuously, not because a real corpus was checked and found clean.
The old `main()` read that as an unqualified PASS, the exact "instrument cannot register its subject"
shape this project's own memory names as its dominant failure class: a bare "0 errors" cannot be told
apart from "0 things existed to error." Population (scenario files + qualifying harness files) is now
counted and printed explicitly; PASS is reported only when that population is nonzero AND clean. The
active-claim cap still gates unconditionally either way, since it does not depend on this corpus at all.
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


def load_claims(root: Path = ROOT) -> dict[str, dict[str, str]]:
    """claim id -> its frontmatter fields, for every file in claims/."""
    claims_dir = root / "claims"
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


def find_scenario_files(root: Path = ROOT) -> list[Path]:
    scenarios_dir = root / "scenarios"
    if not scenarios_dir.is_dir():
        return []
    return sorted(scenarios_dir.glob("*.yaml"))


def find_harness_layer_files(root: Path = ROOT) -> list[Path]:
    """Every harness/**/*.gd file that registers a check layer (contains a top-level `func run(`) --
    the same population check_harness_layers() below walks, extracted so main()/run() can COUNT it
    without duplicating the registration heuristic."""
    harness_dir = root / "harness"
    if not harness_dir.is_dir():
        return []
    out = []
    for path in sorted(harness_dir.rglob("*.gd")):
        text = path.read_text(encoding="utf-8", errors="replace")
        if re.search(r'^\s*func run\s*\(', text, re.MULTILINE):
            out.append(path)
    return out


def check_scenarios(proven: set[str], all_ids: set[str], root: Path = ROOT) -> list[str]:
    errors = []
    for path in find_scenario_files(root):
        text = path.read_text(encoding="utf-8", errors="replace")
        m = SCENARIO_CLAIM_RE.search(text)
        rel = path.relative_to(root)
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


def check_harness_layers(proven: set[str], all_ids: set[str], root: Path = ROOT) -> list[str]:
    errors = []
    for path in find_harness_layer_files(root):
        text = path.read_text(encoding="utf-8", errors="replace")
        rel = path.relative_to(root)
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


def run(root: Path = ROOT) -> int:
    claims = load_claims(root)
    all_ids = set(claims)
    proven = proven_claim_ids(claims)
    cap_errors = check_active_claim_cap(claims)
    errors = cap_errors + check_scenarios(proven, all_ids, root) + check_harness_layers(proven, all_ids, root)

    scenario_files = find_scenario_files(root)
    harness_layer_files = find_harness_layer_files(root)
    population = len(scenario_files) + len(harness_layer_files)

    print(f"check_claim_references: {len(all_ids)} known claim id(s) in claims/, "
          f"{len(proven)} proven (first_failed_at populated)")
    print(f"check_claim_references: population = {len(scenario_files)} scenarios/*.yaml + "
          f"{len(harness_layer_files)} harness/**/*.gd check-registering file(s) = {population}")

    if errors:
        print(f"check_claim_references: FAIL — {len(errors)} violation(s)")
        for e in errors:
            print(f"  FAIL  {e}")
        return 1

    if population == 0:
        print("check_claim_references: VOID — zero scenarios and zero harness check-layers exist to "
              "carry a claim reference right now; a PASS would assert a corpus was checked and found "
              "clean, when nothing was checked at all. The active-claim cap is still enforced above, "
              "unconditionally.")
        return 0

    print("check_claim_references: PASS")
    return 0


def main() -> int:
    return run(ROOT)


if __name__ == "__main__":
    sys.exit(main())
