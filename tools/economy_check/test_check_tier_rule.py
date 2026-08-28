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

Plus, this round (docs/DECISIONS_LEDGER.md D0093):
  7. Reference integrity -- an unresolved material id at each of the four reference sites, plus
     duplicate demand/recipe ids -- tools/anvil/schema.py's REFERENCE_FIELDS class, applied here.
  8. A witness (not a fixture to fix -- the director's explicit "leave it open"): a concrete,
     executable demonstration of the two-hop decorative gap RESIDUAL_NOTE names in the checker's own
     output. Documents current, accepted behavior; does not assert it should change.

Plus, this round (docs/DECISIONS_LEDGER.md D0094):
  9. The --json output mode -- to_json_report's structure on a broken-reference chain, a chain with
     real check failures, and a clean chain; plus the CLI's --json flag end to end, through main().
"""
import contextlib
import io
import json
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_tier_rule import (check_breach_reachable, check_input_provenance,  # noqa: E402
                              check_output_consequence, check_reference_integrity,
                              check_terminal_products, format_report, check_chain,
                              main as cli_main, to_json_report, RESIDUAL_NOTE,
                              RESIDUAL_ANVIL_FINDING_ID, SCOPE_NOTE)


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

    residual_present = RESIDUAL_NOTE in text and "one hop" in text.lower()
    RESULTS.append(("two-hop residual is stated in the checker's OUTPUT, not just its docstring",
                     residual_present))
    print(f"[{'OBSERVED' if residual_present else 'NOT OBSERVED -- BRANCH UNTESTED'}] residual note in "
          f"output")


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


# --- Fixture 7: reference integrity (the director's follow-up, D0093) ---------------------------------

def _assert_errors(name: str, errors: list[str], expect_substring: str) -> None:
    fired = any(expect_substring in e for e in errors)
    RESULTS.append((name, fired))
    status = "OBSERVED" if fired else "NOT OBSERVED -- BRANCH UNTESTED"
    print(f"[{status}] {name} -- got {errors}")


def fixture_7_reference_integrity() -> None:
    materials = {"ore_iron": mat(1.0), "ingot_iron": mat(0.0)}
    recipes = [recipe("smelt_iron", [req("ore_iron", 1)], [req("ingot_iron", 1)])]

    broken_demand = make_chain(materials, [], [demand("D1", [req("ore_copper", 1)], {})], [])
    _assert_errors("fixture7 BROKEN: demand.requires references an unknown material",
                    check_reference_integrity(broken_demand), "unknown material 'ore_copper'")

    broken_recipe_input = make_chain(materials, [recipe("r", [req("ore_missing", 1)], [], [])], [], [])
    _assert_errors("fixture7 BROKEN: recipe.inputs references an unknown material",
                    check_reference_integrity(broken_recipe_input), "unknown material 'ore_missing'")

    broken_recipe_output = make_chain(materials, [recipe("r", [], [req("ingot_missing", 1)], [])], [], [])
    _assert_errors("fixture7 BROKEN: recipe.outputs references an unknown material",
                    check_reference_integrity(broken_recipe_output), "unknown material 'ingot_missing'")

    broken_breach = make_chain(materials, [], [], [req("unobtainium_typo", 1)])
    _assert_errors("fixture7 BROKEN: breach.requires references an unknown material",
                    check_reference_integrity(broken_breach), "unknown material 'unobtainium_typo'")

    dup_demand = make_chain(materials, [], [
        demand("D1", [req("ore_iron", 1)], {}), demand("D1", [req("ore_iron", 1)], {}),
    ], [])
    _assert_errors("fixture7 BROKEN: duplicate demand id", check_reference_integrity(dup_demand),
                    "demand id 'D1': duplicate")

    dup_recipe = make_chain(materials, [
        recipe("r1", [req("ore_iron", 1)], []), recipe("r1", [req("ore_iron", 1)], []),
    ], [], [])
    _assert_errors("fixture7 BROKEN: duplicate recipe id", check_reference_integrity(dup_recipe),
                    "recipe id 'r1': duplicate")

    fixed = make_chain(materials, recipes, [demand("D1", [req("ore_iron", 1)], {})],
                        [req("ingot_iron", 1)])
    fixed_errors = check_reference_integrity(fixed)
    ok = fixed_errors == []
    RESULTS.append(("fixture7 FIXED: every reference resolves, no duplicates", ok))
    print(f"[{'OBSERVED' if ok else 'NOT OBSERVED -- BRANCH UNTESTED'}] fixture7 FIXED -- got "
          f"{fixed_errors}")

    broken_report = check_chain(broken_demand)
    skipped = ("input_provenance" not in broken_report and broken_report["reference_integrity"])
    RESULTS.append(("check_chain skips the four graph-query checks when references don't resolve",
                     skipped))
    print(f"[{'OBSERVED' if skipped else 'NOT OBSERVED -- BRANCH UNTESTED'}] skip-on-broken-reference -- "
          f"got keys {sorted(broken_report.keys())}")

    fixed_report = check_chain(fixed)
    ran = "input_provenance" in fixed_report and "breach_reachable" in fixed_report
    RESULTS.append(("check_chain runs the four graph-query checks once references resolve", ran))
    print(f"[{'OBSERVED' if ran else 'NOT OBSERVED -- BRANCH UNTESTED'}] runs-on-clean-reference -- got "
          f"keys {sorted(fixed_report.keys())}")

    broken_text, broken_ok = format_report(broken_report)
    reported = (not broken_ok and "unknown material 'ore_copper'" in broken_text
                and "were NOT run" in broken_text)
    RESULTS.append(("format_report names the bad reference and explains the skip, doesn't crash",
                     reported))
    print(f"[{'OBSERVED' if reported else 'NOT OBSERVED -- BRANCH UNTESTED'}] format_report on a broken "
          f"reference")


# --- Fixture 8: the two-hop decorative gap, a witness, not a fix (D0093 #2) ----------------------------

def witness_two_hop_decorative_gap_documented_not_fixed() -> None:
    """Does NOT assert this should change -- the director's explicit instruction is to leave it open.
    This demonstrates, with a real chain, exactly the case docs/DECISIONS_LEDGER.md D0093 and
    RESIDUAL_NOTE both describe: D1 grants a verb referenced by a recipe (a real, structural fact, so
    clause (a) correctly passes it) whose output is required ONLY by D2 -- and D2 itself independently
    FAILS output consequence (grants nothing referenced anywhere). D1's pass is one hop deep; nothing
    here verifies that the second hop (D2) does anything meaningful, and D1 passes regardless.
    """
    materials = {"topsoil": mat(0.0), "copper": mat(2.0), "byproduct": mat(0.0)}
    recipes = [recipe("fake_recipe", [req("copper", 1)], [req("byproduct", 1)], requires_verbs=["assay"])]
    demands = [
        demand("D1", [req("topsoil", 5)], {"cut_hardness": 2.0, "verbs": ["assay"]}),
        demand("D2", [req("byproduct", 1)], {}),
    ]
    chain = make_chain(materials, recipes, demands, [])
    report = check_chain(chain)

    check("witness: D1 passes output consequence via the verb a recipe references (clause a, correctly)",
          report["output_consequence"], {"D1": "pass"})
    check("witness: D2 -- the demand D1's verb actually leads to -- independently fails on its own",
          report["output_consequence"], {"D2": "fail"})
    check("witness: byproduct is NOT flagged terminal, because D2 'requires' it -- even though D2 "
          "itself fails everything", report["terminal_products"], {"byproduct": "pass"})

    text, _ok = format_report(report)
    residual_documented = RESIDUAL_NOTE in text
    RESULTS.append(("the checker's own output names this exact gap alongside the pass that exhibits it",
                     residual_documented))
    print(f"[{'OBSERVED' if residual_documented else 'NOT OBSERVED -- BRANCH UNTESTED'}] residual note "
          f"present alongside the witnessed gap")


# --- Fixture 9: the --json output mode (D0094) ----------------------------------------------------

def fixture_9_json_output() -> None:
    materials = {"ore_iron": mat(1.0)}
    broken = make_chain(materials, [], [demand("D1", [req("ore_copper", 1)], {})], [])
    broken_payload = to_json_report(check_chain(broken))
    ok = (broken_payload["ok"] is False and broken_payload["checks_run"] is False
          and broken_payload["checks"] is None and broken_payload["failures"] is None
          and broken_payload["reference_integrity"]["ok"] is False
          and "unknown material 'ore_copper'" in broken_payload["reference_integrity"]["errors"][0])
    RESULTS.append(("fixture9: broken-reference chain reports checks_run=False, not an empty checks "
                     "dict", ok))
    print(f"[{'OBSERVED' if ok else 'NOT OBSERVED -- BRANCH UNTESTED'}] fixture9 broken-reference JSON "
          f"-- got {broken_payload}")
    ok2 = json.loads(json.dumps(broken_payload)) == broken_payload
    RESULTS.append(("fixture9: broken-reference payload round-trips through json.dumps/loads", ok2))
    print(f"[{'OBSERVED' if ok2 else 'NOT OBSERVED -- BRANCH UNTESTED'}] fixture9 broken-reference "
          f"JSON-serializable")

    decorative_materials = {"topsoil": mat(0.0), "ore_a": mat(1.0), "ore_b": mat(2.0), "ore_c": mat(3.0),
                             "ingot_a": mat(0.0)}
    decorative_recipes = [recipe("refine_ore", [req("ore_a", 2)], [req("ingot_a", 1)],
                                  requires_verbs=["drill"])]
    decorative_demands = [
        demand("D1", [req("topsoil", 1)], {"cut_hardness": 1.0, "verbs": ["drill"]}),
        demand("D2", [req("ore_a", 2)], {"cut_hardness": 2.0}),
        demand("D3", [req("ore_b", 2)], {"cut_hardness": 3.0}),
    ]
    decorative = make_chain(decorative_materials, decorative_recipes, decorative_demands, [])
    decorative_payload = to_json_report(check_chain(decorative))
    ok3 = (decorative_payload["ok"] is False and decorative_payload["checks_run"] is True
           and decorative_payload["failures"]["output_consequence"] == ["D2", "D3"]
           and decorative_payload["failures"]["terminal_products"] == ["ingot_a"])
    RESULTS.append(("fixture9: a chain with real failures names the specific demands/materials "
                     "implicated, per check", ok3))
    print(f"[{'OBSERVED' if ok3 else 'NOT OBSERVED -- BRANCH UNTESTED'}] fixture9 failing-chain "
          f"failures -- got {decorative_payload['failures']}")

    clean = make_chain(_fixture_5_materials(), _fixture_5_recipes(), _fixture_5_demands(),
                        [req("steel_ingot", 1)])
    clean_payload = to_json_report(check_chain(clean))
    ok4 = (clean_payload["ok"] is True and clean_payload["checks_run"] is True
           and all(v == [] for v in clean_payload["failures"].values())
           and clean_payload["reference_integrity"]["ok"] is True
           and clean_payload["reference_integrity"]["errors"] == [])
    RESULTS.append(("fixture9: a clean chain reports ok=True with every per-check failure list empty",
                     ok4))
    print(f"[{'OBSERVED' if ok4 else 'NOT OBSERVED -- BRANCH UNTESTED'}] fixture9 clean-chain JSON")

    residual = clean_payload["residual"]
    ok5 = (residual["id"] == "two_hop_decorative_gap" and residual["decision_ledger"] == "D0093"
           and residual["anvil_finding_id"] == RESIDUAL_ANVIL_FINDING_ID
           and residual["note"] == RESIDUAL_NOTE)
    RESULTS.append(("fixture9: the residual gap is a structured field (id/ledger/finding-id/note), "
                     "not embedded prose", ok5))
    print(f"[{'OBSERVED' if ok5 else 'NOT OBSERVED -- BRANCH UNTESTED'}] fixture9 residual struct -- "
          f"got {residual}")

    scope = clean_payload["scope"]
    ok6 = scope["note"] == SCOPE_NOTE and scope["id"] == "rig_demand_chain_only"
    RESULTS.append(("fixture9: the scope note is present as a structured field too", ok6))
    print(f"[{'OBSERVED' if ok6 else 'NOT OBSERVED -- BRANCH UNTESTED'}] fixture9 scope struct -- got "
          f"{scope}")


def branch_json_cli_flag() -> None:
    with tempfile.TemporaryDirectory() as d:
        clean_path = Path(d) / "clean.json"
        clean = make_chain(_fixture_5_materials(), _fixture_5_recipes(), _fixture_5_demands(),
                            [req("steel_ingot", 1)])
        clean_path.write_text(json.dumps(clean), encoding="utf-8")

        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            exit_code = cli_main(["--json", str(clean_path)])
        parsed = json.loads(buf.getvalue())
        ok = exit_code == 0 and parsed["ok"] is True and parsed["checks_run"] is True
        RESULTS.append(("--json CLI flag on a clean chain: exit 0, stdout is parseable JSON", ok))
        print(f"[{'OBSERVED' if ok else 'NOT OBSERVED -- BRANCH UNTESTED'}] --json clean CLI -- exit="
              f"{exit_code}")

        broken_path = Path(d) / "broken.json"
        broken = make_chain({"ore_iron": mat(1.0)}, [], [demand("D1", [req("ore_copper", 1)], {})], [])
        broken_path.write_text(json.dumps(broken), encoding="utf-8")

        buf2 = io.StringIO()
        with contextlib.redirect_stdout(buf2):
            exit_code2 = cli_main(["--json", str(broken_path)])
        parsed2 = json.loads(buf2.getvalue())
        ok2 = exit_code2 == 1 and parsed2["ok"] is False and parsed2["checks_run"] is False
        RESULTS.append(("--json CLI flag on a broken-reference chain: exit 1, checks_run False in "
                         "the JSON", ok2))
        print(f"[{'OBSERVED' if ok2 else 'NOT OBSERVED -- BRANCH UNTESTED'}] --json broken CLI -- exit="
              f"{exit_code2}")

        buf3 = io.StringIO()
        buf3_err = io.StringIO()
        with contextlib.redirect_stdout(buf3), contextlib.redirect_stderr(buf3_err):
            exit_code3 = cli_main(["--json"])
        ok3 = exit_code3 == 2 and "usage:" in buf3_err.getvalue()
        RESULTS.append(("--json CLI flag alone, no file argument, still reports usage error (exit 2)",
                         ok3))
        print(f"[{'OBSERVED' if ok3 else 'NOT OBSERVED -- BRANCH UNTESTED'}] --json no-file CLI -- "
              f"exit={exit_code3}")

        buf4 = io.StringIO()
        with contextlib.redirect_stdout(buf4):
            exit_code4 = cli_main([str(clean_path)])
        text_out = buf4.getvalue()
        ok4 = exit_code4 == 0 and SCOPE_NOTE in text_out and text_out.strip()[0] != "{"
        RESULTS.append(("plain (non --json) mode is unaffected -- still prints prose, not JSON", ok4))
        print(f"[{'OBSERVED' if ok4 else 'NOT OBSERVED -- BRANCH UNTESTED'}] plain-mode regression "
              f"check -- exit={exit_code4}")


def main() -> int:
    for branch in (fixture_1_input_provenance, branch_d1_reports_na_not_pass,
                   branch_d2_gets_no_exemption, fixture_2_decorative_demand,
                   fixture_3_decorative_chain, fixture_4_terminal_product, fixture_5_valid_chain,
                   fixture_6_breach_unreachable, fixture_7_reference_integrity,
                   witness_two_hop_decorative_gap_documented_not_fixed, fixture_9_json_output,
                   branch_json_cli_flag):
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
