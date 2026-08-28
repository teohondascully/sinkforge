# tools/economy_check

## Purpose

Validates the corrected, three-part rig-demand tier rule against synthetic fixtures, before
`data/economy/` has a single real row. A pure graph query — no engine, no sim, no game state — over a
`chain` of demands/materials/recipes/a breach. Schema and the three checks are `schema.py` /
`check_tier_rule.py`; both module docstrings carry the full reasoning, not repeated here.

Built ahead of `data/economy/` on purpose (`docs/DECISIONS_LEDGER.md` D0092): the checker exists so the
first real chain the director authors gets checked against a rule that has already been mutation-tested
against its own failure modes, rather than discovering gaps by re-deriving the same failure the legacy
game shipped.

## The three checks, plus one addition

1. **Input provenance** — every demand (after D1) must require at least one material genuinely,
   causally unlocked by the immediately preceding demand's grant. **D1 is reported `n/a`, never
   `pass`** — there is no prior demand to compare against, and treating "nothing to compare against" as
   a pass would itself be a vacuous-success case. **D2 gets no exemption.** The original design brief's
   own "D2 passes vacuously" carve-out is deliberately not implemented — if the real D2 can't pass this
   honestly, that's a finding about the design, which is the checker doing its job.
2. **Output consequence** — every demand must grant a verb some recipe requires, open access to a
   material something else in the graph consumes, or be a prerequisite of a later demand that does
   either. Both sub-clauses require the thing granted to be **referenced by something else in the
   graph**, never self-declared and never merely "what the next demand in the chain happens to need" —
   see `check_tier_rule.py`'s docstring for why the second exclusion is structurally necessary, not just
   consistent with the first, and for the honest residual gap this doesn't close.
3. **Terminal products** — no recipe output may go unconsumed, except what the breach itself requires.
4. **Breach reachability** (the director's addition) — the breach's own requirement must be reachable BY
   THE CHAIN, checked against the capability state at the end of it, not merely declared. Without this,
   check 3's breach exemption could launder a terminal product nothing can actually reach.

## Scope boundary

This checks the rig-demand chain only. `docs/GDD.md`:135 names a second, separate verb path — artifacts
found in ruins. This instrument doesn't model it. **A PASS here says nothing about that path** — stated
in the checker's own output (`SCOPE_NOTE`, printed first in every report), not only in this file, so a
reader of a passing result isn't relying on having read the docstring too.

## Haul-mass is proven, not yet load-bearing

`Material.mass_per_unit` and the `haul_mass` capability axis are real, checked fields — the "extractable
but not transportable in the required quantity" input-provenance sub-clause, and the breach-reachability
addition, both exercise them directly (fixture 5's D3, fixture 6). But nothing in the real repository
populates `mass_per_unit` or grants `haul_mass` yet — `BASELINE_CAPABILITY.haul_mass` in `schema.py` is a
placeholder with no data behind it. **This clause is dormant against real data, not absent.** Its
silence on a real chain today means "not yet exercised," never "verified." It starts enforcing the
moment `data/economy/` populates those fields.

## Consumers

None yet. `data/economy/` doesn't exist. Intended consumer, once it does: whoever authors that content
runs `python3 tools/economy_check/check_tier_rule.py <chain file>` against it directly, or a future gate
wires this into CI the way `tools/schema_validator` is wired for `data/`'s other kinds — not decided,
not this session's call.

## Public API

- `schema.py` — `accumulate`, `material_reachable`, `accessible_for`, `meaningfully_referenced_materials`,
  `BASELINE_CAPABILITY`.
- `check_tier_rule.py` — `check_input_provenance`, `check_output_consequence`, `check_terminal_products`,
  `check_breach_reachable`, `check_chain`, `format_report`, and a CLI (`python3 check_tier_rule.py
  <chain.json|chain.yaml>` — no default target, since no real chain file exists to point it at yet).

## Mutation testing

`test_check_tier_rule.py`, run directly (`python3 tools/economy_check/test_check_tier_rule.py`) — 19
cases across the 6 fixtures (the director's 5 plus the breach-reachability addition), every BROKEN case
observed actually failing before its FIXED counterpart is trusted to pass, `tools/anvil/
test_check_integrity.py`'s own discipline. All 19 OBSERVED as of this writing.

## LOC

Counts toward `tools/`'s instrument total (`docs/QUALITY.md` gate 7 / `check_loc_ratio.py`) — it is
instrument code with no game-code counterpart, and stays that way until real chain data exists to check.
Does **not** count against the Anvil budget (`incoming/ANVIL_ARCHITECTURE.md`'s 1,000/2,000-line cap) —
a separate instrument, no shared code or cap.

## Gotchas

- Capability state is monotonic (max/union, never decays) — matches the persistent-world premise, but
  means the checker has no way to model a capability being lost (e.g. a flooded, scrapped machine). Not
  needed by the three checks as stated; would need a real design decision if that ever changes.
- Clause (b)'s "meaningfully referenced" gate reads `Recipe.inputs` and `Breach.requires` only — a
  material referenced only by *another demand's* `requires` does not count (see `schema.py`'s
  `meaningfully_referenced_materials` docstring for why that specific exclusion is load-bearing, not an
  oversight).
- No referential-integrity validation (unknown material ids in a chain raise a plain `KeyError`, not a
  named error). Deliberately out of scope — this checks the tier rule, not chain well-formedness; add a
  real validator only if malformed real data actually shows up needing one.
