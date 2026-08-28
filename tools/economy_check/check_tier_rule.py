#!/usr/bin/env python3
"""The corrected three-part demand-chain tier rule, as a pure graph query over synthetic chain data.
No engine, no sim, no `data/economy/` -- this reads a `chain` dict (schema.py) and reports, it never
executes anything. Built against `tools/economy_check/test_check_tier_rule.py`'s synthetic fixtures only.

    python3 tools/economy_check/check_tier_rule.py [--json] <chain.json|chain.yaml>

`--json` prints `to_json_report`'s structured output instead of `format_report`'s prose -- built so a
future check run can become a `tools/anvil/append.py` `MEASUREMENT` event directly (`docs/DECISIONS_
LEDGER.md` D0094), rather than a number transcribed by hand off this same console. Not wired to Anvil
here: this module writes nothing to `.anvil/log/`, and nothing here calls `append.py`. That wiring is
separate, deferred work, waiting on `data/economy/` to have real rows to measure.

## Two things stated here AND in every report's output (not just this docstring, per the director's
explicit instruction -- a green result that silently excludes something is exactly what an audit catches
later, not something to bury in a comment)

**Scope** (`SCOPE_NOTE`). This checks the RIG-DEMAND chain only. `docs/GDD.md`:135 names a second,
separate verb path -- artifacts found in ruins, unlocking verbs "through a different door." Nothing here
models that path. A PASS from this checker says the rig-demand chain is coherent; it says nothing about
artifact-granted verbs.

**The two-hop residual** (`RESIDUAL_NOTE`). Output consequence (check 2, below) verifies one hop:
"meaningfully referenced" means a Recipe or the Breach uses the thing directly, right now. It does not
verify that THAT recipe's own output, or a demand consuming that material, is itself non-decorative. A
demand granting a verb whose only real consumer is a recipe feeding a second, independently-decorative
demand can still PASS -- because check 3 treats "required by a demand" as consumption regardless of
whether that demand itself passes anything. Director-confirmed, left open on purpose
(`docs/DECISIONS_LEDGER.md` D0093, logged as an Anvil FINDING, `source_class: artifact-instrument`, so
the gap travels with the checker rather than living only in a chat transcript). Demonstrated, not just
asserted, by `test_check_tier_rule.py`'s `witness_two_hop_decorative_gap_documented_not_fixed`.

## The checks

**0. Reference integrity**, run first. Every material id `schema.iter_material_references()` yields must
resolve to a real `chain["materials"]` entry; demand and recipe ids must be unique within their own list.
The untyped-reference class `tools/anvil/schema.py`'s `REFERENCE_FIELDS` closes for the event log
(`docs/DECISIONS_LEDGER.md` D0069), applied here so the same discipline holds in both schemas -- the
director's explicit instruction, since "one architecture at two scales" is only true if the reference
discipline is actually identical, not merely similar. If this fails, the other four checks are NOT run --
a graph query over an id that doesn't resolve would raise, not report, and a raised exception is a worse
failure mode than a named one.

## The three checks

**1. Input provenance.** For demand D_n (n>=2): let `before` = accumulated grants through D_{n-2},
`after` = accumulated grants through D_{n-1}. Passes if some material in D_n.requires is NOT
accessible_for(before) but IS accessible_for(after) -- genuinely, causally unlocked by D_{n-1}
specifically. D_1 has no `before` state to compare against: reported "n/a", never "pass" -- a demand
with nothing before it hasn't demonstrated anything, and treating that as a pass would be exactly the
"vacuous success" this project's own retrospective (see docs/DECISIONS_LEDGER.md) warns about
repeatedly. **D_2 gets no exemption** -- the original brief's "D2 passes vacuously" carve-out is
deliberately NOT implemented. If real D2 data can't pass this check honestly, that is a finding about
the design, which is the checker doing its job, not a bug in the checker.

**2. Output consequence.** For every D_n, including D_1, passes if at least one of:
  (a) D_n.grants includes a verb that appears in some Recipe.requires_verbs, anywhere in the graph.
  (b) D_n's grant makes some material newly material_reachable() AND that material is in
      schema.meaningfully_referenced_materials() -- consumed by a recipe input or required by the
      breach. **Both clauses require the thing granted/opened to be referenced by something ELSE in the
      graph, not merely self-declared or merely "what happens to come next."** For (a): a `kind:
      cosmetic|mechanical` field would ask the author to self-certify the exact thing this check exists
      to catch -- a promise, not a fact. For (b), the discipline is structurally necessary, not just
      consistent: a material becoming newly reachable is *definitionally* true of whatever the very next
      demand in the chain requires (that's what makes its OWN input-provenance check pass) -- so without
      excluding materials that are only ever "the next demand's fodder," every hardness-escalator chain
      would pass clause (b) at every single step by construction, collapsing output consequence back
      into a restatement of input provenance. That is the exact vacuity the three-part rule exists to
      replace. Confirmed by fixture 3 below: without this exclusion, the decorative chain passes; with
      it, it correctly fails.
  (c) D_n is a prerequisite (via the dependency edges input provenance's causal links establish) of some
      later D_m that independently satisfies (a) or (b).

  **Honest residual, stated plainly rather than overclaimed:** clause (a)'s "referenced elsewhere" test
  closes the single-hop decorative dodge. A sufficiently motivated author could still wire a decorative
  verb into a fake recipe whose own output nothing meaningful consumes -- but that recipe's output is
  then itself caught by check 3 (terminal products), or the fake chain has to keep growing to dodge that,
  at which point it is no longer decorative, it is a real (if pointless) subsystem. The three checks
  compose to close the single-hop case; they do not close every possible adversarial multi-hop one, and
  this docstring does not claim they do.

**3. Terminal products.** For every material that is a Recipe OUTPUT: passes if it is consumed by
another recipe's input, required by a demand, or required by the breach. Scoped to manufactured
materials (recipe outputs) -- raw ore sitting unmined is a different, milder problem than a refined
product with no sink, and conflating them would blur the exact failure this check exists to catch (the
legacy game's terminal high-tier products). **This is the exact clause the two-hop residual above lives
in**: "required by a demand" does not ask whether that demand itself passed anything.

**4. Breach reachability (the director's addition).** The breach's own `requires` must be satisfiable BY
THE CHAIN, not merely declared. Checked against the capability state at the END of the demand chain --
capabilities accumulate monotonically (nothing decays), so "reachable at the end" and "reachable at some
point during the chain" are the same question; if it's not reachable with every demand satisfied, it was
never reachable. Without this, check 3's breach exemption could launder an unreachable terminal state --
"the breach consumes it" becoming an excuse for a product nothing in a real game could actually produce.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from schema import (accessible_for, accumulate, iter_material_references, material_reachable,  # noqa: E402
                     meaningfully_referenced_materials)

SCOPE_NOTE = (
    "SCOPE: rig-demand chain only. Artifact-granted verbs from ruins (docs/GDD.md:135) are a second, "
    "separate unlock path this instrument does not model -- a PASS below says nothing about that path."
)

RESIDUAL_NOTE = (
    "RESIDUAL (known, open, not fixed -- docs/DECISIONS_LEDGER.md D0093): output consequence verifies "
    "ONE HOP. A verb/material counts as meaningfully referenced the moment a recipe or the breach uses "
    "it directly -- this checker does NOT verify that recipe's own output, or a demand consuming that "
    "material, is itself non-decorative. A demand granting a verb consumed only by another demand that "
    "itself fails every check can still PASS below."
)

# The Anvil event carrying RESIDUAL_NOTE's evidence (docs/DECISIONS_LEDGER.md D0093). A static pointer,
# not resolved by reading .anvil/log/ at runtime -- this instrument has no reason to depend on Anvil's
# log at check time, only to CITE it in output for whoever later builds a MEASUREMENT event from a run.
# If that FINDING is ever superseded (tools/anvil's own supersedes mechanism), update this constant to
# the superseding event's id -- it is a citation, not a live query, and can go stale exactly like any
# other citation in this codebase.
RESIDUAL_ANVIL_FINDING_ID = "a677726d-8984-4ec6-9e3e-ab44b850d841"


def check_reference_integrity(chain: dict) -> list[str]:
    """Every material id iter_material_references() yields must resolve to a real chain["materials"]
    entry; demand and recipe ids must be unique within their own list. Mirrors
    tools/anvil/check_integrity.py's reference-resolution walk -- the director's explicit instruction
    that the two schemas carry identical reference discipline, not merely analogous ones."""
    errors = []
    materials = chain["materials"]
    for location, material_id in iter_material_references(chain):
        if material_id not in materials:
            errors.append(f"{location}: references unknown material {material_id!r}")

    seen_demand_ids: set[str] = set()
    for demand in chain["demands"]:
        if demand["id"] in seen_demand_ids:
            errors.append(f"demand id {demand['id']!r}: duplicate, appears more than once in this chain")
        seen_demand_ids.add(demand["id"])

    seen_recipe_ids: set[str] = set()
    for recipe in chain["recipes"]:
        if recipe["id"] in seen_recipe_ids:
            errors.append(f"recipe id {recipe['id']!r}: duplicate, appears more than once in this chain")
        seen_recipe_ids.add(recipe["id"])

    return errors


def check_input_provenance(chain: dict) -> list[tuple[str, str, str]]:
    """Returns (demand_id, verdict, detail) per demand, verdict in {"n/a", "pass", "fail"}."""
    demands = chain["demands"]
    materials = chain["materials"]
    results = []
    for i, demand in enumerate(demands):
        if i == 0:
            results.append((demand["id"], "n/a", "no previous unlock exists for the first demand"))
            continue
        before = accumulate(d["grants"] for d in demands[:i - 1])
        after = accumulate(d["grants"] for d in demands[:i])
        satisfying = None
        for entry in demand["requires"]:
            material = materials[entry["material"]]
            if not accessible_for(material, entry["qty"], before) and \
                    accessible_for(material, entry["qty"], after):
                satisfying = entry["material"]
                break
        if satisfying:
            results.append((demand["id"], "pass",
                             f"{satisfying} became accessible via {demands[i - 1]['id']}'s grant"))
        else:
            results.append((demand["id"], "fail",
                             "no required material was newly made accessible by the previous demand's "
                             "grant -- everything it requires was already obtainable before then"))
    return results


def check_output_consequence(chain: dict) -> list[tuple[str, str, str]]:
    demands = chain["demands"]
    materials = chain["materials"]
    recipes = chain["recipes"]
    referenced_verbs: set[str] = set()
    for recipe in recipes:
        referenced_verbs |= set(recipe.get("requires_verbs", []))
    meaningful = meaningfully_referenced_materials(chain)

    def cap_through(k: int) -> dict:
        return accumulate(d["grants"] for d in demands[:k])

    direct: list[bool] = []
    detail_a: list[list[str]] = []
    detail_b: list[list[str]] = []
    for i, demand in enumerate(demands):
        cap_before = cap_through(i)
        cap_after = cap_through(i + 1)
        granted_verbs = set(demand["grants"].get("verbs", []))
        referenced = sorted(granted_verbs & referenced_verbs)
        newly_reachable = sorted(
            mid for mid, mat in materials.items()
            if material_reachable(mat, cap_after) and not material_reachable(mat, cap_before)
            and mid in meaningful
        )
        detail_a.append(referenced)
        detail_b.append(newly_reachable)
        direct.append(bool(referenced) or bool(newly_reachable))

    provenance = check_input_provenance(chain)
    edges: dict[int, set[int]] = {i: set() for i in range(len(demands))}
    for i, (_id, verdict, _detail) in enumerate(provenance):
        if verdict == "pass":
            edges[i - 1].add(i)

    def reaches_direct(i: int, visited: set[int]) -> tuple[bool, int | None]:
        for j in sorted(edges[i]):
            if j in visited:
                continue
            visited.add(j)
            if direct[j]:
                return True, j
            found, via = reaches_direct(j, visited)
            if found:
                return True, via
        return False, None

    results = []
    for i, demand in enumerate(demands):
        if direct[i]:
            reasons = []
            if detail_a[i]:
                reasons.append(f"grants verb(s) {detail_a[i]} referenced by a recipe")
            if detail_b[i]:
                reasons.append(f"opens access to meaningfully-referenced material(s) {detail_b[i]}")
            results.append((demand["id"], "pass", "; ".join(reasons)))
            continue
        found, via = reaches_direct(i, set())
        if found:
            results.append((demand["id"], "pass",
                             f"prerequisite of {demands[via]['id']}, which passes directly"))
        else:
            results.append((demand["id"], "fail",
                             "grants nothing referenced elsewhere in the graph, opens no "
                             "meaningfully-referenced material access, and is not a prerequisite of any "
                             "later demand that does either -- decorative"))
    return results


def check_terminal_products(chain: dict) -> list[tuple[str, str, str]]:
    recipes = chain["recipes"]
    demands = chain["demands"]
    breach = chain["breach"]

    consumed_by_recipe = {entry["material"] for r in recipes for entry in r["inputs"]}
    consumed_by_demand = {entry["material"] for d in demands for entry in d["requires"]}
    consumed_by_breach = {entry["material"] for entry in breach["requires"]}
    produced = {entry["material"] for r in recipes for entry in r["outputs"]}

    results = []
    for material_id in sorted(produced):
        if material_id in consumed_by_recipe:
            results.append((material_id, "pass", "consumed as another recipe's input"))
        elif material_id in consumed_by_demand:
            results.append((material_id, "pass", "required by a demand"))
        elif material_id in consumed_by_breach:
            results.append((material_id, "pass", "required by the breach"))
        else:
            results.append((material_id, "fail", "produced by a recipe, consumed by nothing"))
    return results


def check_breach_reachable(chain: dict) -> list[tuple[str, str, str]]:
    demands = chain["demands"]
    materials = chain["materials"]
    breach = chain["breach"]
    final_capability = accumulate(d["grants"] for d in demands)

    results = []
    for entry in breach["requires"]:
        material = materials[entry["material"]]
        if accessible_for(material, entry["qty"], final_capability):
            results.append((entry["material"], "pass",
                             "accessible with the capability state at the end of the chain"))
        else:
            results.append((entry["material"], "fail",
                             "not accessible (hardness/verb/haul) even with every demand in the chain "
                             "satisfied -- the terminal-products exemption for this material is not "
                             "earned"))
    return results


def check_chain(chain: dict) -> dict:
    reference_errors = check_reference_integrity(chain)
    if reference_errors:
        return {"reference_integrity": reference_errors}
    return {
        "reference_integrity": [],
        "input_provenance": check_input_provenance(chain),
        "output_consequence": check_output_consequence(chain),
        "terminal_products": check_terminal_products(chain),
        "breach_reachable": check_breach_reachable(chain),
    }


def format_report(report: dict) -> tuple[str, bool]:
    ok = True
    lines = [SCOPE_NOTE, RESIDUAL_NOTE, ""]

    if report["reference_integrity"]:
        ok = False
        lines.append("Reference integrity:")
        for error in report["reference_integrity"]:
            lines.append(f"  [FAIL] {error}")
        lines.append("")
        lines.append("Input provenance, output consequence, terminal products, and breach reachability "
                      "were NOT run -- this chain does not resolve, and running graph queries over an "
                      "unresolved reference would raise, not report.")
        return "\n".join(lines), ok

    lines.append("Reference integrity: PASS -- every material id resolves, no duplicate demand/recipe "
                  "ids.")
    lines.append("")

    def section(title: str, rows: list[tuple[str, str, str]], empty_note: str) -> None:
        nonlocal ok
        lines.append(f"{title}:")
        if not rows:
            lines.append(f"  {empty_note}")
            return
        for item_id, verdict, detail in rows:
            if verdict == "fail":
                ok = False
            lines.append(f"  [{verdict.upper():4s}] {item_id}: {detail}")

    section("Input provenance", report["input_provenance"], "(no demands)")
    section("Output consequence", report["output_consequence"], "(no demands)")
    section("Terminal products", report["terminal_products"], "(no recipe outputs in this chain)")
    section("Breach reachability", report["breach_reachable"], "(breach requires nothing)")
    return "\n".join(lines), ok


CHECK_KEYS = ("input_provenance", "output_consequence", "terminal_products", "breach_reachable")


def to_json_report(report: dict) -> dict:
    """Machine-readable form of `report` (check_chain's return value) -- everything format_report prints
    as prose, as structured data instead, so a future MEASUREMENT event (tools/anvil/append.py) can cite
    a check run directly rather than someone reading a console and transcribing a number by hand, exactly
    the failure mode Anvil's provenance discipline exists to prevent. Building this does NOT wire it to
    the log -- no MEASUREMENT event is written here, and no code in this module calls append.py. That
    wiring is separate, deferred work, waiting on data/economy/ to exist (docs/DECISIONS_LEDGER.md D0094).

    `checks_run` is explicit (True/False), never inferred from an empty `checks`/`failures` dict being
    absent or empty -- an empty dict silently reading as "0 checked, clean" is exactly the vacuous-
    success class this project's own retrospective is built around avoiding, so a broken-reference chain
    reports `checks_run: false` plus a reason, never a quietly-empty `checks: {}`.
    """
    payload = {
        "version": 1,
        "scope": {"id": "rig_demand_chain_only", "note": SCOPE_NOTE},
        "residual": {
            "id": "two_hop_decorative_gap",
            "status": "known_open_not_fixed",
            "decision_ledger": "D0093",
            "anvil_finding_id": RESIDUAL_ANVIL_FINDING_ID,
            "note": RESIDUAL_NOTE,
        },
        "reference_integrity": {
            "ok": not report["reference_integrity"],
            "errors": list(report["reference_integrity"]),
        },
    }

    if report["reference_integrity"]:
        payload.update({
            "checks_run": False,
            "checks_not_run_reason": "chain does not resolve -- reference_integrity failed, the four "
                                      "graph-query checks were not run",
            "checks": None,
            "failures": None,
            "ok": False,
        })
        return payload

    def rows(key: str) -> list[dict]:
        return [{"id": item_id, "verdict": verdict, "detail": detail}
                 for item_id, verdict, detail in report[key]]

    def failing_ids(key: str) -> list[str]:
        return [item_id for item_id, verdict, _detail in report[key] if verdict == "fail"]

    failures = {key: failing_ids(key) for key in CHECK_KEYS}
    payload.update({
        "checks_run": True,
        "checks_not_run_reason": None,
        "checks": {key: rows(key) for key in CHECK_KEYS},
        "failures": failures,
        "ok": not any(failures.values()),
    })
    return payload


def load_chain(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    if path.suffix in (".yaml", ".yml"):
        try:
            import yaml
        except ImportError:
            print("check_tier_rule: PyYAML is not installed. `pip install pyyaml`.", file=sys.stderr)
            sys.exit(1)
        return yaml.safe_load(text)
    return json.loads(text)


def main(argv: list[str] | None = None) -> int:
    argv = sys.argv[1:] if argv is None else argv
    json_mode = "--json" in argv
    positional = [a for a in argv if a != "--json"]
    if len(positional) != 1:
        print("usage: check_tier_rule.py [--json] <chain.json|chain.yaml>", file=sys.stderr)
        print("check_tier_rule: no data/economy/ chain file exists yet -- this CLI has no default "
              "target. Point it at a chain once one is authored.", file=sys.stderr)
        return 2
    chain = load_chain(Path(positional[0]))
    report = check_chain(chain)
    if json_mode:
        payload = to_json_report(report)
        print(json.dumps(payload, indent=2, sort_keys=True))
        return 0 if payload["ok"] else 1
    text, ok = format_report(report)
    print(text)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
