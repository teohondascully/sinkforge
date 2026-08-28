#!/usr/bin/env python3
"""Mutation tests for the tier-rule checker. One function per fixture, `tools/anvil/test_check_integrity.py`'s
own style: write a BROKEN chain, OBSERVE the target check actually flag it, then (where the fixture has
one) write the FIXED chain and observe it clean. A branch that never gets a broken fixture to fail on is
not tested, it is decorated -- the discipline this project applies everywhere a checker gets built.

    python3 tools/economy_check/test_check_tier_rule.py

The six fixtures, matching the director's list exactly (docs/DECISIONS_LEDGER.md D0092):
  1. Input provenance violation -- a demand requiring only already-baseline-accessible material.
  2. Codex's decorative-demand case -- passes provenance, grants nothing referenced elsewhere.
  3. THE most important one -- a chain of three demands, each individually passing input provenance,
     none granting a referenced verb or opening a meaningfully-referenced material. The legacy failure
     at the scale it actually occurred (docs/DECISIONS_LEDGER.md D0092, the director's own framing).
  4. A terminal product -- a recipe output nothing consumes.
  5. A valid chain -- every check clean, the positive control proving this isn't just an always-fail.
  6. The addition -- a breach requiring a material no demand in the chain ever makes accessible.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_tier_rule import (check_breach_reachable, check_input_provenance,  # noqa: E402
                              check_output_consequence, check_terminal_products, format_report,
                              check_chain, SCOPE_NOTE)


def mat(hardness=0.0, mass=1.0, verbs=None):
    return {"hardness": hardness, "mass_per_unit": mass, "requires_verbs": list(verbs or [])}


def req(material, qty):
    return {"material": material, "qty": qty}


def demand(id_, requires, grants):
    return {"id": id_, "requires": requires, "grants": dict(grants)}


def recipe(id_, inputs, outputs, requires_verbs=None):
    return {"id": id_, "inputs": inputs, "outputs": outputs, "requires_verbs": list(requires_verbs or [])}


def make_chain(materials, recipes, demands, breach_requires):
    return {"materials": materials, "recipes": recipes, "demands": demands,
            "breach": {"requires": breach_requires}}


RESULTS: list[tuple[str, bool]] = []


def check(name: str, rows: list[tuple[str, str, str]], expected: dict[str, str]) -> None:
    actual = {row[0]: row[1] for row in rows}
    got = {k: actual.get(k) for k in expected}
    ok = got == expected
    RESULTS.append((name, ok))
    status = "OBSERVED" if ok else "NOT OBSERVED -- BRANCH UNTESTED"
    print(f"[{status}] {name} -- expected {expected}, got {got}")


# --- Fixture 1: input provenance ------------------------------------------------------------------

def fixture_1_input_provenance() -> None:
    materials = {"topsoil": mat(hardness=0.0), "copper": mat(hardness=2.0)}

    broken = make_chain(materials, [], [
        demand("D1", [req("topsoil", 5)], {"cut_hardness": 2.0}),
        demand("D2", [req("topsoil", 5)], {}),
    ], [])
    check("fixture1 BROKEN: D2 requires only already-accessible material", check_input_provenance(broken),
          {"D1": "n/a", "D2": "fail"})

    fixed = make_chain(materials, [], [
        demand("D1", [req("topsoil", 5)], {"cut_hardness": 2.0}),
        demand("D2", [req("copper", 5)], {}),
    ], [])
    check("fixture1 FIXED: D2 requires newly-accessible copper", check_input_provenance(fixed),
          {"D1": "n/a", "D2": "pass"})


def branch_d1_reports_na_not_pass() -> None:
    materials = {"topsoil": mat(hardness=0.0)}
    chain = make_chain(materials, [], [demand("D1", [req("topsoil", 1)], {})], [])
    rows = check_input_provenance(chain)
    ok = rows[0] == ("D1", "n/a", rows[0][2])
    RESULTS.append(("D1 with no previous unlock reports n/a, never pass", ok))
    print(f"[{'OBSERVED' if ok else 'NOT OBSERVED -- BRANCH UNTESTED'}] D1 n/a -- got {rows[0]}")


def branch_d2_gets_no_exemption() -> None:
    # Same chain as fixture 1's BROKEN case. D2 requiring only already-accessible material must FAIL --
    # the director's explicit correction: the original brief's "D2 passes vacuously" carve-out is not
    # implemented. If this ever reports "n/a" or "pass" for D2, the exemption crept back in.
    materials = {"topsoil": mat(hardness=0.0)}
    chain = make_chain(materials, [], [
        demand("D1", [req("topsoil", 5)], {"cut_hardness": 2.0}),
        demand("D2", [req("topsoil", 5)], {}),
    ], [])
    check("D2 has no bootstrap exemption -- fails like any other demand", check_input_provenance(chain),
          {"D2": "fail"})


# --- Fixture 2: Codex's decorative-demand case ------------------------------------------------------

def fixture_2_decorative_demand() -> None:
    materials = {"topsoil": mat(0.0), "copper": mat(2.0), "iron": mat(3.0), "ore_hardrock": mat(4.0)}
    recipes = [recipe("assay_ore", [req("iron", 1)], [req("refined_sample", 1)], requires_verbs=["assay"])]

    def chain_with_breach(breach_requires):
        return make_chain(materials, recipes, [
            demand("D1", [req("topsoil", 5)], {"cut_hardness": 2.0}),
            demand("D2", [req("copper", 1)], {"cut_hardness": 3.0, "verbs": ["assay"]}),
            demand("D3", [req("copper", 1), req("iron", 5)], {"verbs": ["iron_convenience"]}),
        ], breach_requires)

    broken = chain_with_breach([])
    check("fixture2 BROKEN: passes provenance, grants an unreferenced verb", check_output_consequence(broken),
          {"D2": "pass", "D3": "fail"})

    fixed = make_chain(materials, recipes, [
        demand("D1", [req("topsoil", 5)], {"cut_hardness": 2.0}),
        demand("D2", [req("copper", 1)], {"cut_hardness": 3.0, "verbs": ["assay"]}),
        demand("D3", [req("copper", 1), req("iron", 5)], {"cut_hardness": 4.0}),
    ], [req("ore_hardrock", 1)])
    check("fixture2 FIXED: D3 opens a breach-required material instead", check_output_consequence(fixed),
          {"D3": "pass"})


# --- Fixture 3: the chain of three decorative demands (most important) ------------------------------

def fixture_3_decorative_chain() -> None:
    materials = {"topsoil": mat(0.0), "ore_a": mat(1.0), "ore_b": mat(2.0), "ore_c": mat(3.0),
                 "ore_d": mat(4.0)}
    recipes = [recipe("refine_ore", [req("ore_a", 2)], [req("ingot_a", 1)], requires_verbs=["drill"])]
    demands = [
        demand("D1", [req("topsoil", 1)], {"cut_hardness": 1.0, "verbs": ["drill"]}),
        demand("D2", [req("ore_a", 2)], {"cut_hardness": 2.0}),
        demand("D3", [req("ore_b", 2)], {"cut_hardness": 3.0}),
        demand("D4", [req("ore_c", 2)], {"cut_hardness": 4.0}),
    ]

    broken = make_chain(materials, recipes, demands, [])
    broken_provenance = check_input_provenance(broken)
    check("fixture3 BROKEN: all three still pass input provenance individually", broken_provenance,
          {"D2": "pass", "D3": "pass", "D4": "pass"})
    check("fixture3 BROKEN: none grants a referenced verb or opens a meaningfully-referenced material "
          "-- the legacy failure, at scale", check_output_consequence(broken),
          {"D1": "pass", "D2": "fail", "D3": "fail", "D4": "fail"})

    fixed = make_chain(materials, recipes, demands, [req("ore_d", 1)])  # breach needs ore_d
    check("fixture3 FIXED: making the tail meaningful retroactively passes the whole chain via (c)",
          check_output_consequence(fixed),
          {"D1": "pass", "D2": "pass", "D3": "pass", "D4": "pass"})


# --- Fixture 4: terminal product ---------------------------------------------------------------------

def fixture_4_terminal_product() -> None:
    recipes = [recipe("smelt_iron", [req("ore_iron", 2)], [req("ingot_iron", 1)])]

    broken = make_chain({}, recipes, [], [])
    check("fixture4 BROKEN: ingot_iron produced, consumed by nothing", check_terminal_products(broken),
          {"ingot_iron": "fail"})

    fixed = make_chain({}, recipes, [demand("Dx", [req("ingot_iron", 1)], {})], [])
    check("fixture4 FIXED: a demand now requires ingot_iron", check_terminal_products(fixed),
          {"ingot_iron": "pass"})


# --- Fixture 5: a valid chain -- the positive control -------------------------------------------------

def _fixture_5_materials() -> dict:
    return {
        "topsoil": mat(0.0), "ore_iron": mat(1.0), "ingot_iron": mat(0.0),
        "ore_hardrock": mat(2.0), "steel_ingot": mat(0.0),
    }


def _fixture_5_recipes() -> list:
    return [
        recipe("smelt_iron", [req("ore_iron", 2)], [req("ingot_iron", 1)], requires_verbs=["forge"]),
        recipe("temper_steel", [req("ore_hardrock", 1), req("ingot_iron", 1)], [req("steel_ingot", 1)]),
    ]


def _fixture_5_demands() -> list:
    return [
        demand("D1", [req("topsoil", 5)], {"cut_hardness": 1.0, "verbs": ["forge"]}),
        demand("D2", [req("ore_iron", 2)], {"haul_mass": 100.0}),
        demand("D3", [req("ingot_iron", 60)], {"cut_hardness": 2.0}),
    ]


def fixture_5_valid_chain() -> None:
    chain = make_chain(_fixture_5_materials(), _fixture_5_recipes(), _fixture_5_demands(),
                        [req("steel_ingot", 1)])
    report = check_chain(chain)
    check("fixture5: input provenance clean (D3 passes via the haul-mass sub-clause specifically)",
          report["input_provenance"], {"D1": "n/a", "D2": "pass", "D3": "pass"})
    check("fixture5: output consequence clean (a, then c-via-D3, then b)", report["output_consequence"],
          {"D1": "pass", "D2": "pass", "D3": "pass"})
    check("fixture5: terminal products clean", report["terminal_products"],
          {"ingot_iron": "pass", "steel_ingot": "pass"})
    check("fixture5: breach reachable", report["breach_reachable"], {"steel_ingot": "pass"})

    text, ok = format_report(report)
    all_clean = ok and "FAIL" not in text
    RESULTS.append(("fixture5: checker stays silent on a clean chain (no FAIL anywhere)", all_clean))
    print(f"[{'OBSERVED' if all_clean else 'NOT OBSERVED -- BRANCH UNTESTED'}] fixture5 fully clean")

    scope_present = SCOPE_NOTE in text and "ruin" in text.lower()
    RESULTS.append(("scope boundary is stated in the checker's OUTPUT, not just its docstring",
                     scope_present))
    print(f"[{'OBSERVED' if scope_present else 'NOT OBSERVED -- BRANCH UNTESTED'}] scope note in output")


# --- Fixture 6 (addition): breach requires an unreachable material ------------------------------------

def fixture_6_breach_unreachable() -> None:
    materials = _fixture_5_materials()
    materials["unobtainium"] = mat(hardness=99.0, verbs=["never_granted"])

    unreachable = make_chain(materials, _fixture_5_recipes(), _fixture_5_demands(),
                              [req("unobtainium", 1)])
    check("fixture6 BROKEN: breach requires a material the chain never makes accessible",
          check_breach_reachable(unreachable), {"unobtainium": "fail"})

    reachable = make_chain(materials, _fixture_5_recipes(), _fixture_5_demands(),
                            [req("steel_ingot", 1)])
    check("fixture6 FIXED: breach requires steel_ingot, reachable by the end of the chain",
          check_breach_reachable(reachable), {"steel_ingot": "pass"})


def main() -> int:
    for branch in (fixture_1_input_provenance, branch_d1_reports_na_not_pass,
                   branch_d2_gets_no_exemption, fixture_2_decorative_demand,
                   fixture_3_decorative_chain, fixture_4_terminal_product, fixture_5_valid_chain,
                   fixture_6_breach_unreachable):
        branch()

    failed = [name for name, ok in RESULTS if not ok]
    print()
    print(f"test_check_tier_rule: {len(RESULTS) - len(failed)}/{len(RESULTS)} cases observed correctly.")
    if failed:
        print("test_check_tier_rule: FAIL -- these branches did not fire as expected:")
        for name in failed:
            print(f"  {name}")
        return 1

    print("test_check_tier_rule: PASS.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
