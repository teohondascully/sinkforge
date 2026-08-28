"""Data shapes for the tier-rule checker (tools/economy_check/). Pure graph-query inputs -- no engine,
no sim, no data/economy/ content. The director's schema review approved this shape (chat, 2026-08-27,
`docs/DECISIONS_LEDGER.md` D0092); this module implements that approval, it is not a new design pass.

Four entities, one shared currency:

- Capability: the thing demands GRANT and materials/recipes REQUIRE. Three axes -- `cut_hardness`
  (float, compared directly against Material.hardness, reusing the existing `data/materials/SCHEMA.yaml`
  field rather than inventing a "tool tier"), `haul_mass` (float, max transportable mass, gates the
  "transportable in required quantity" input-provenance sub-clause), `verbs` (open string namespace,
  matching `docs/GDD.md`:118-135's own "verb"/"capability" vocabulary -- pump, winch, feeder, drill...).
  Capability state accumulates monotonically across the demand chain: componentwise max on the numeric
  axes, set union on verbs. Nothing decays -- matches the persistent-world premise, there is no run
  boundary to reset it at.

- Material: extends `data/materials/SCHEMA.yaml` with two fields the real schema doesn't have yet --
  `mass_per_unit` and `requires_verbs`. `hardness` and the rest are the existing fields, reused as-is.
  A manufactured material (a recipe output nothing mines directly) conventionally gets `hardness=0.0,
  requires_verbs=[]` -- it isn't gated by extraction, it's gated by whether the RECIPE that makes it can
  run, which is `Recipe.requires_verbs`'s job, not the material's own.

- Recipe: `inputs`/`outputs` as material+qty pairs (`data/recipes/README.md`'s own informal sketch),
  plus `requires_verbs` -- the field that makes output-consequence clause (a) computable rather than
  vacuous (see check_tier_rule.py's module docstring for why).

- Demand: `requires` (= `data/progression`'s "cost") and `grants` (= `data/progression`'s "what the
  unlock actually changes"). Order is chain position -- demands are a plain ordered list, D1 first.

- Breach: a singleton, `requires` only -- the one thing check_terminal_products exempts from "nothing
  consumes it," and the thing check_breach_reachable additionally requires to be REACHABLE (director's
  addition, not merely declared) rather than merely present.

Two axes were considered and dropped: a separate "layer" reachability gate (folded into `hardness`;
nothing in the three checks needs layer as anything but an informational tag, and `layer` isn't part of
this module at all -- it would be carried on the real `data/materials` record, not this synthetic one)
and an OR-combinator for accessibility predicates (kept AND-only; every fixture here needs only
conjunction, and adding OR before something actually needs it is exactly the "designing for hypothetical
future requirements" this project's conventions warn against).

`BASELINE_CAPABILITY.haul_mass` is a placeholder (bare-hands carry capacity) with no real-data backing --
see `tools/economy_check/README.md`'s "haul-mass is dormant" note. Its exact value is arbitrary; it only
needs to be large enough that fixtures not specifically testing the haul sub-clause aren't accidentally
gated by it.
"""
from __future__ import annotations

BASELINE_CAPABILITY = {"cut_hardness": 0.0, "haul_mass": 50.0, "verbs": frozenset()}


def accumulate(grants_iterable, baseline: dict | None = None) -> dict:
    """Fold a sequence of Demand.grants dicts into one capability state -- max on the numeric axes,
    union on verbs, starting from `baseline` (default BASELINE_CAPABILITY). accumulate([]) is exactly
    the baseline: what a cold start can do before any demand is satisfied."""
    base = baseline if baseline is not None else BASELINE_CAPABILITY
    cut_hardness = base["cut_hardness"]
    haul_mass = base["haul_mass"]
    verbs: set[str] = set(base["verbs"])
    for grants in grants_iterable:
        cut_hardness = max(cut_hardness, grants.get("cut_hardness", 0.0))
        haul_mass = max(haul_mass, grants.get("haul_mass", 0.0))
        verbs |= set(grants.get("verbs", []))
    return {"cut_hardness": cut_hardness, "haul_mass": haul_mass, "verbs": verbs}


def material_reachable(material: dict, capability: dict) -> bool:
    """Can this material be extracted at all under this capability state -- hardness and verb gates
    only. Deliberately excludes haul-mass: reachability is a property of the material, haul feasibility
    is a property of a specific demanded QUANTITY, which this function has no quantity to check against.
    Used by output-consequence clause (b) (see meaningfully_referenced_materials for the second gate
    clause (b) applies on top of this one) and by check_breach_reachable's material_reachable half.
    Quantity-aware accessibility for a specific demand lives in accessible_for, below."""
    if capability["cut_hardness"] < material["hardness"]:
        return False
    return set(material.get("requires_verbs", [])) <= capability["verbs"]


def accessible_for(material: dict, qty: float, capability: dict) -> bool:
    """Full accessibility for a specific demanded quantity: reachable AND haulable at that quantity in
    the current haul_mass capability. This is input provenance's sense of "accessible" -- the rule's
    third sub-clause ("extractable but not transportable in the required quantity") only makes sense
    next to an actual quantity, which is why it lives here and not in material_reachable."""
    if not material_reachable(material, capability):
        return False
    return capability["haul_mass"] >= material["mass_per_unit"] * qty


def meaningfully_referenced_materials(chain: dict) -> set[str]:
    """Materials referenced by something beyond being a raw demand requirement -- a recipe INPUT, or the
    breach. Used to gate output-consequence clause (b); see check_tier_rule.py's module docstring,
    'Why clause (b) needs the same discipline as clause (a),' for the reasoning: being what the very
    next demand in the chain happens to need is exactly the input-provenance relationship (already
    checked separately), and doesn't on its own make opening a material MEANINGFUL in the
    output-consequence sense -- every hardness-escalator chain would otherwise pass this clause by
    construction, which is the exact vacuity the three-part rule replaced the old one to avoid."""
    referenced = {entry["material"] for recipe in chain["recipes"] for entry in recipe["inputs"]}
    referenced |= {entry["material"] for entry in chain["breach"]["requires"]}
    return referenced


# Typed-reference table, mirroring tools/anvil/schema.py's REFERENCE_FIELDS -- the director's explicit
# instruction (docs/DECISIONS_LEDGER.md D0093) that the two schemas carry the SAME reference discipline,
# not merely an analogous one. Every entry maps (entity_kind, field_name) -> the registry a reference in
# that field must resolve against. Materials are the only referenceable registry today (demands and
# recipes have no id-references to each other) -- kept in this shape rather than a bare "always check
# materials" so a future reference type (a demand naming a prerequisite demand, say) slots into the same
# table instead of forcing a redesign, the same reasoning tools/anvil/schema.py gives for keeping its own
# table even where a field's legal-target set has just one member.
REFERENCE_FIELDS = {
    ("demand", "requires"): "materials",
    ("recipe", "inputs"): "materials",
    ("recipe", "outputs"): "materials",
    ("breach", "requires"): "materials",
}


def iter_material_references(chain: dict):
    """Yield (location, material_id) for every material-id reference REFERENCE_FIELDS names, walked
    against the chain's actual data -- tools/anvil/schema.py's iter_reference_targets, for this schema."""
    for demand in chain["demands"]:
        for entry in demand["requires"]:
            yield f"demand {demand['id']!r}.requires", entry["material"]
    for recipe in chain["recipes"]:
        for entry in recipe["inputs"]:
            yield f"recipe {recipe['id']!r}.inputs", entry["material"]
        for entry in recipe["outputs"]:
            yield f"recipe {recipe['id']!r}.outputs", entry["material"]
    for entry in chain["breach"]["requires"]:
        yield "breach.requires", entry["material"]
