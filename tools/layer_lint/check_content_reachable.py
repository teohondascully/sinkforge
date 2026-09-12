#!/usr/bin/env python3
"""QUALITY gate 37 (D0591): every recipe, machine and demand tier is reachable by ordinary play.

The failure this exists for is `docs/CORRECTIONS.md`'s "one ruling would reach all of it" -- a claim
written into `docs/NEEDS_DIRECTOR.md` P042, quoted forward twice, and false. Two counts were made and
both were right: six machines no start places and no demand names, four recipes stranded behind them.
The JOIN between them was never computed, and it is the whole answer: `iron` and `rich_ore` are consumed
by recipes and produced by nothing anywhere, so the same four recipes are unreachable TWICE over and
neither half of the obvious fix does anything alone.

A hand count in this area has now been wrong twice -- the queue also quoted seven orphan machines when
there are six. That is `docs/DECISIONS_LEDGER.md`'s "count without membership": the number cannot be
re-measured by reading it, so this reports MEMBERS and the rule that produced them, never a total.

WHAT IT MODELS, and the limit is stated in its own output rather than only here. `Machines.machine_eats`
is a union of FOUR rules -- the coal-burner set, `winch_head` plus bulk, `rig` plus the live demand, and
`recipe.inputs`. Only the last is in `data/`. So this gate answers "can this recipe ever run", not "is
this item ever wanted", and a machine that burns fuel is reachable here on its recipe alone.

AND SPARE FIELDS ARE ITS OWN TRAP. `data/strata/shallow_clay.yaml` has a top-level `iron:` key that is
terrain-gen tuning, not an item. Anything scanning `data/` for item-shaped strings "finds" iron and
declares `smelt_iron` fed. This reads named fields out of named record kinds and never scans.

THE SHIPPED START IS READ FROM THE CODE, not guessed and not listed here. `data/starts/` holds four
records and nothing in the data says which is the game: `beacon_probe` and `lighting_bench` both say in
their own first line that they are scenario records rather than starts of play, and `site:` splits
"stamps world geometry" from "stamps a pack", which is the wrong axis. The one machine-readable
discriminator is `shell/main.gd`'s `const START`, so that is what this parses -- and it FAILS if that
constant names no record, because a partition that silently falls back to everything would count a
lighting bench's placed forge as shipped progression.

--report-only prints the same findings and exits 0. It ran report-only while P042 was open; the d3-d7
ladder extension wired every orphan machine a source, the bare check exits 0, and CI invokes it
without the flag. The flag stays for the next open design question this gate cannot answer.

Exit 0 clean, 1 on unreachable content -- or on a population it could not load, which is the same
refusal every gate here makes rather than passing vacuously.
"""

import pathlib
import re
import sys

import yaml

ROOT = pathlib.Path(__file__).resolve().parents[2]


def _records(root: pathlib.Path, kind: str) -> dict:
    """Every record of one kind, keyed by id. SCHEMA.yaml is the schema, not a record."""
    out = {}
    folder = root / "data" / kind
    if not folder.is_dir():
        return out
    for path in sorted(folder.glob("*.yaml")):
        if path.name == "SCHEMA.yaml":
            continue
        try:
            doc = yaml.safe_load(path.read_text(encoding="utf-8"))
        except yaml.YAMLError:
            return {}
        if isinstance(doc, dict) and doc.get("id"):
            out[str(doc["id"])] = doc
    return out


def shipped_start(root: pathlib.Path) -> str:
    """The start `shell/main.gd` actually boots. See the module docstring for why it is read from code."""
    main = root / "shell" / "main.gd"
    if not main.is_file():
        return ""
    hit = re.search(r'^const\s+START\s*:\s*StringName\s*=\s*&"([^"]+)"',
                    main.read_text(encoding="utf-8"), re.MULTILINE)
    return hit.group(1) if hit else ""


def seeds(start: dict) -> tuple[set, set]:
    """What a new game begins with: items in the pack or on the floor, and machines already placed."""
    items, machines = set(), set()
    for fix in start.get("fixtures") or []:
        if not isinstance(fix, dict):
            continue
        kind = fix.get("kind")
        if kind == "machine" and fix.get("id"):
            machines.add(str(fix["id"]))
        elif kind in ("pack", "pile") and fix.get("item"):
            items.add(str(fix["item"]))
    return items, machines


def check(root: pathlib.Path) -> int:
    materials = _records(root, "materials")
    recipes = _records(root, "recipes")
    machines = _records(root, "machines")
    starts = _records(root, "starts")
    tiers = _records(root, "progression")

    # THE POPULATION CONTROLS. An empty set makes every "unreachable" list empty too, and this gate
    # would pass forever while checking nothing.
    for name, pop in (("materials", materials), ("recipes", recipes),
                      ("machines", machines), ("starts", starts), ("progression", tiers)):
        if not pop:
            print(f"check_content_reachable: FAIL - loaded no {name} records at all; "
                  f"the scan is broken, not the tree")
            return 1

    named = shipped_start(root)
    if named not in starts:
        print(f"check_content_reachable: FAIL - shell/main.gd's START is {named!r}, which names no "
              f"record in data/starts/; refusing to guess which start is the shipped game")
        return 1

    # `yield_of` (sim/world/materials.gd): an absent `yields` means the material's OWN id, so coal
    # drops coal. Reading this rule wrong is what made the first hand count wrong.
    minable = {str(m.get("yields") or m["id"]) for m in materials.values()}
    start_items, have_machines = seeds(starts[named])
    have = set(minable) | set(start_items)

    runs = {str(m["recipe"]): mid for mid, m in machines.items() if m.get("recipe")}
    fired, unlocked = set(), set()
    order = sorted(tiers.values(), key=lambda t: int(t.get("order", 0)))

    # ONE JOINT FIXPOINT over recipes and demand tiers, because they gate each other: a tier's grants
    # pay for the machine that makes what the NEXT tier wants. Running them separately is what lets a
    # tier award the very machine its own `wants` needed -- the bootstrap-order defect.
    changed = True
    while changed:
        changed = False
        for rid, rec in recipes.items():
            if rid in fired:
                continue
            machine = runs.get(rid)
            if machine is not None and machine not in have_machines:
                continue
            if not all(i in have for i in (rec.get("inputs") or {})):
                continue
            fired.add(rid)
            have |= set(rec.get("outputs") or {})
            changed = True
        for tier in order:
            tid = str(tier["id"])
            if tid in unlocked or not all(w in have for w in (tier.get("wants") or {})):
                continue
            unlocked.add(tid)
            have_machines |= set(tier.get("grants") or {})
            changed = True

    producible = set(minable) | set(start_items) | {
        o for r in recipes.values() for o in (r.get("outputs") or {})}
    consumed = {i for r in recipes.values() for i in (r.get("inputs") or {})}
    every_source = set(have_machines) | {
        g for t in tiers.values() for g in (t.get("grants") or {})} | set(start_items)

    print(f"check_content_reachable: shipped start {named!r} (shell/main.gd); "
          f"{len(materials)} materials, {len(recipes)} recipes, {len(machines)} machines, "
          f"{len(tiers)} demand tiers")
    print(f"check_content_reachable: models recipe inputs only -- Machines.machine_eats has three more "
          f"rules that live in code (fuel, bulk, the live demand)")

    bad = 0
    for rid in sorted(set(recipes) - fired):
        machine = runs.get(rid)
        missing = sorted(i for i in (recipes[rid].get("inputs") or {}) if i not in have)
        why = []
        if machine is not None and machine not in every_source:
            why.append(f"no route to its machine {machine!r}")
        if missing:
            orphan = [i for i in missing if i not in producible]
            why.append(f"inputs not producible {missing}"
                       + (f", of which NOTHING PRODUCES {orphan}" if orphan else ""))
        print(f"  UNREACHABLE recipe {rid}: {'; and '.join(why) or 'blocked upstream'}")
        bad += 1
    for tid in sorted({str(t['id']) for t in tiers.values()} - unlocked):
        print(f"  UNREACHABLE tier {tid}: wants {sorted(tiers[tid].get('wants') or {})}, not all producible")
        bad += 1
    for mid in sorted(set(machines) - every_source):
        print(f"  ORPHAN machine {mid}: no start places it and no demand grants it")
        bad += 1
    for item in sorted(consumed - producible):
        print(f"  ORPHAN item {item}: consumed by a recipe, produced by nothing")
        bad += 1

    if bad:
        print(f"check_content_reachable: FAIL — {bad} unreachable item(s)")
        return 1
    print("check_content_reachable: PASS — every recipe, tier and machine is reachable from a new game")
    return 0


def main(argv: list[str]) -> int:
    root = ROOT
    if "--root" in argv:
        root = pathlib.Path(argv[argv.index("--root") + 1]).resolve()
    code = check(root)
    if "--report-only" in argv and code == 1:
        print("check_content_reachable: reported-only (P042 is open); not failing the build")
        return 0
    return code


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
