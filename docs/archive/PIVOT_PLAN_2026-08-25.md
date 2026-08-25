> **SUPERSEDED 2026-08-25.** The other of the two read-only audits/plans that established the ground truth for the pivot. Note: this document's own closing section lists itself and `COMPAT_AUDIT_2026-08-25.md` as documents that should stay live/normative rather than move to `docs/archive/` — that recommendation was superseded by a later decision (recorded in `docs/README.md` and `CONTEXT.md`, both of which place both audits in `docs/archive/`); flagging here so the discrepancy is documented rather than silently overridden.
> Kept for provenance: `legacy/` may still contain code that implements what this document describes,
> and an agent reading that code needs to be able to find out why. See `docs/GDD.md` for current design.

---

# SINKFORGE Pivot Plan

**Date:** 2026-08-25. **Pinned commit:** `666e551`. **Input documents:** the Pivot Handoff (design/reasoning
state, no repository access) and `docs/COMPAT_AUDIT_2026-08-25.md` (20-agent measurement pass). **This
document:** a 10-agent research pass (full triage of all 31 `docs/*.md` files, a full read of `scenes/main.gd`,
and targeted investigation of R1's cost model and every item in the Handoff's §3.3 dead-content list) plus the
synthesis answering the Handoff's seven questions. Read-only research; nothing in the repository was changed to
produce this document.

**Disagreement check (Handoff §1's instruction — stop if you disagree with the pivot before planning anything):**
No disagreement. The design reasoning holds up against what the code actually contains: `docs/MATERIAL_SPINE.md`
independently concluded, from source, that gear/plate are dead-end products with no ongoing demand and ingot is
a de facto currency — the same diagnosis the Handoff makes from the design side. Proceeding.

---

## Executive summary

The compatibility audit found the *architecture* compatible. This research pass finds the *game* — in the
specific sense of a bounded, run-based expedition with a persistent surface rig — genuinely does not exist yet,
not even as a mislabeled or partially-built analog. Confirmed by exhaustive grep and full-file reads: no
`shaft`/`expedition`/`run_start`/`run_end`/`flood_level`/`pump_capacity` concept anywhere; the closest thing to a
"run boundary," the Descent Engine's L1→L2 quota gate, is a *permanent* one-time wall inside one persistent
world, not a repeatable timed session; `water_flow.gd` forbids a rising flood by explicit design contract ("no
source or drain, so total_water() is invariant across a tick"); and R1's fuel-per-unit-per-meter transport cost
has zero precedent — every existing upward-transport mechanism (Lift, Pump, Winch) is a power-gated rate/cap,
never a per-unit or per-distance charge.

Two things run counter to what the Handoff's §8 expected to find:

1. **The Bazaar is not a gate to excise — it is a subsystem woven through `main.gd`'s input handling, verb
   layer, and per-frame HUD push** (3 dedicated keys, a 3-tab panel dispatcher, a whole cosmetic module, 3 of 11
   verbs hard-gated, one guide-target case). Removing it is real work, not a radius-check deletion.
2. **The fastest unblock is smaller than it looks.** The Bazaar's proximity gate and the research-tree's unlock
   gate are two independent, separable checks (three `_near_bazaar()` calls in `main.gd`; one `craft_unlocked()`
   predicate in `factory_sim.gd`) sitting *in front of* an already-portable, already-compatible crafting UI (the
   Hud's PACK/WORKS/BENCH tabs, scored PORT/compat-4 in the audit as generic shop infrastructure). Loosening
   those two checks — not rebuilding the UI — is enough to make a fresh world craftable without a Bazaar
   structure, and is a good first step regardless of how the rest of this plan sequences.

---

## 1. Document triage

31 files in `docs/*.md`, individually read in full. **12 KEEP, 8 ARCHIVE, 11 REWRITE.** Two of the eleven —
`DECISIONS.md` and `ARCHITECTURE.md` — need a correction to the Handoff's own framing (below); the other nine
genuinely mix durable and dead content and need editing, not wholesale supersession.

### KEEP as-is (12) — process/engineering docs with no game-design content the pivot touches

`A_PLUS_PROGRAM.md`, `A_PLUS_STATUS.md`, `BRANCHING.md`, `CAPTURE_MANIFEST.md`, `DIRECTOR_BUS.md`,
`ENGINEERING.md`, `HARNESS_LAYERS.md`, `PEER_SESSIONS.md`, `RELEASE_HARDENING.md`, `REPO_PORTFOLIO_AUDIT.md`,
`SANDBOX.md`, `VISUAL_TRIAGE.md` (its game-content references are almost entirely rendering/HUD/terrain/grapple
presentation quality, orthogonal to persistent-vs-run structure).

**Correction to the Handoff's own list:** §1's "Supersedes... the A+ program docs" is imprecise.
`A_PLUS_PROGRAM.md`/`A_PLUS_STATUS.md` contain essentially zero game-design content — every Bazaar/Generator/
Splitter mention inside them is an incidental machine name inside a code-quality bug writeup (e.g. "a tree could
grow inside your bazaar" is a cache-invalidation defect, not a design statement). They should be **kept
untouched** as the historical record of a completed engineering programme, not treated as design docs needing a
superseded header.

### ARCHIVE with a superseded header (8) — dead design, code still reflects it

`BAZAAR.md`, `DIRECTOR_BRIEF.md`, `DRIFT.md`, `GDD.md`, `LODE_PLAN.md`, `MATERIAL_SPINE.md`, `PRIORITY.md`,
`PROGRESSION.md`. Two are worth a specific note:

- **`DIRECTOR_BRIEF.md`** is the approved Freight Winch/Skipway design — the document your memory already flags
  as `director-brief-freight-winch.md`. It's entirely built on "no unique mandatory mechanism may exist only at
  spawn" and "the coordinate-independent campaign invariant," both replaced outright by a bounded shaft +
  persistent surface rig. Its §4.1-4.3 evaluation methodology (evidence tiers, blind-evaluator protocol, 0-4
  anchored rubric) is generic enough to be worth extracting into a standalone methodology doc before the rest of
  the file is archived — the machine and campaign premise it was written for are dead, the way of *judging*
  machines is not.
- **`MATERIAL_SPINE.md`** independently reaches the Handoff's own diagnosis from source (gear/plate are
  production dead-ends, ingot is a de facto currency, the Descent Engine is the only bulk sink) — archive it,
  but it's the single strongest piece of evidence in this repository that the pivot's read of the old design was
  correct, and worth citing for that reason alone.

### REWRITE (11) — genuinely mixed content

**Two of these need a correction to the Handoff's explicit "does not supersede" list**, not a full rewrite:

- **`docs/ARCHITECTURE.md`** — the Handoff says this is not superseded. It shouldn't be archived, but it *does*
  need targeted edits: the FactorySim/`_BEHAVIORS`/Resource-schema sections (lines 8-10, 35-46, 61-68, 181-192)
  are exactly what this plan builds on and must stay untouched, but the Descent Engine (lines 69-77), Research
  as "the PULL" (135-141), the Bazaar as a world-detected structure (142-146), and the Lode extraction plane
  (147-167) describe systems this plan kills or replaces. Recommendation: edit those four sections in place with
  the doc's existing conventions rather than archiving the file.
- **`docs/DECISIONS.md`** — same correction. Its Engineering/Harness/Process entries (node-free sim, static
  typing as a compile error, never lower a harness floor, no commit trailer) are untouched by the pivot. Its
  Design section's campaign-spine/"Sinkforge is a lighthouse"/"validate the loop before building the campaign"
  entries describe the superseded single-continuous-campaign framing — and the doc already has a `SUPERSEDED`
  status tag built for exactly this (line 20). Recommendation: add new `SUPERSEDED`-tagged entries pointing at
  this plan, using the file's own convention, rather than rewriting or archiving it.

The remaining nine split cleanly into a durable half and a dead half — each should be edited to keep the
durable half in place:

| Doc | Durable half (keep) | Dead half (cut or archive separately) |
|---|---|---|
| `AGENT_PLAY_EVALUATION_PROTOCOL.md` | The 6-layer eval portfolio, actor-validity taxonomy, assistance ladder, judging protocol (~2/3 of the file) | The specific opening-loop content and Freight Winch tie-in (explicit: "forbids mentioning... Freight Winch") |
| `BITS.md` | The five bits (cutting geometry) and SEAMS (grain-direction mining) — moment-to-moment digging feel | "Where they come from" — Drive=Bench-research, Bit=Rack-purchase acquisition model |
| `CONTENT_CATALOG_PLAN.md` | The `Catalog`-derives-from-`.tres` architecture and its `validate()` schema | Validation rules V13-V14 (research-tree fields) and the Bazaar-row staging step |
| `FEEL_GAP.md` | ~26 of 39 "strikes" — rendering perf, movement physics, audio QA methodology | Strikes 33-34 (Bazaar/research UI) and 35-36 (Drift Rig/Crusher) |
| `LODE.md` | The vein-as-wall-plane resource model and hand-vs-machine extraction rates (§4-5) | §6 (re-sources the Drift Rig and Borer, both killed) |
| `MENU_MATRIX.md` | Settings/accessibility/keybinding methodology (MNU-26 through MNU-32: contrast audit, focus-visible traversal, conflict detection) | Bazaar counter findings 1-8 and MNU-06/11/12/18/20/25 |
| `ORCHESTRATOR.md` | Harness commands, non-vacuity philosophy, agent-play-eval model, orchestration playbook, hard commit/destruction rules (§1,3,5-9) | The five-pillars/Seal/seven-band content (§2), proposed lore (§11), and the entire stale session-snapshot (§12-14) |
| `VISUAL_DESIGN_SYSTEM_AND_THREE_WAY_EVALS.md` | The A/B/C evaluation protocol and 50-item atomic-finding table | "The Bazaar especially should become a physical character" and the Settings/Pack/Works/Bench menu-language section |
| `VISUAL_RECOMMENDATIONS_SURFACE.md` | Sections A-F (tutorial occlusion, world labels, grapple readability, terrain grammar) — ~40% | Section G (~60%, MNU-01 through MNU-35, the Bazaar's four tabs) |

### What the minimal normative doc set should be going forward

`ARCHITECTURE.md` (edited), `DECISIONS.md` (edited, new SUPERSEDED entries), `COMPAT_AUDIT_2026-08-25.md`, this
document, plus the twelve KEEP docs above. **A new `GDD.md`** should be authored by promoting Handoff §§2-6
(the design state) directly — that content is already well-organized and the Handoff explicitly frames itself
as *not* a permanent document, so don't leave the design's canonical source sitting in a "handoff" file. **A new
`PRIORITY.md`** needs to be authored from scratch once this plan is approved; the old one is 3,447 lines of
work-log for a superseded queue and isn't line-editable into relevance.

---

## 2. Ordered sequence of work, to a playable two-minute bounded run

**What needs no change** (stated first, because it's most of the codebase): FactorySim's tick/item/machine
chassis, the Resource-based machine/material/recipe data model, movement (`player.gd`/`grapple.gd`), the
rendering pipeline, and most of the harness. The audit already scored these compatible; nothing below touches
them except where explicitly noted.

**What genuinely does not exist and blocks a bounded run** (confirmed this pass, not assumed): a session
lifecycle distinct from "the `MainView` node exists," a run/meta save split, a surface/shaft mode distinction, a
flood clock, a haul-to-surface mechanic, and R1's transport cost model. `main.gd`'s `_ready()` (lines 253-399)
constructs the *entire* live game object graph — sim, player, camera, renderer, HUD — unconditionally, before
even checking whether a title screen should show; the only "reset" primitive in the whole file is
`get_tree().reload_current_scene()`. A run-lifecycle extraction has to insert a real state machine *before*
`sim = FactorySim.new()` at line 268, which today runs exactly once per process with no notion of "begin
expedition" versus "return to hub."

### Stage 0 (do this first, before anything else in this plan): loosen the two gates blocking iteration

Three `_near_bazaar()` checks (`main.gd:2166,2215,2228`, guarding `try_craft`/`try_craft_tool`/`try_research`)
and one research predicate (`FactorySim.craft_unlocked()`, `factory_sim.gd:1646-1648`, which currently blocks
*everything* behind researching Power — itself required transitively for the Descent gate, and therefore for
every later tech). Loosen both. This does **not** require rebuilding the crafting UI — the Hud's PACK/WORKS/BENCH
tabs sit behind these gates but are themselves generic, already-portable shop infrastructure (audit compat
score 4). The payoff is disproportionate to the size of the change: every later stage in this plan gets easier
to test once a fresh world is craftable without walking to a structure and researching Power first.

### Stage 1: run/meta save split

`SaveGame.capture(sim)` plus `main.gd`'s own bolt-ons (`_save_game()`, lines 2390-2400) write exactly one
envelope. This pass found precisely two fields that are meta-scoped rather than run-scoped:
`lamp_tint` (main.gd:2393, an identity/cosmetic fact) and `hints_taught` (2396-2397, tutorial progress). Split
them into a second file now, before more state accumulates on either side of the boundary — the audit already
scored `save_game.gd`'s underlying mechanism (versioned migration, transactional staging, atomic write) as
directly reusable (compat 2, REWRITE only for the envelope shape, not the machinery). Small, well-scoped, low
risk, and every later stage benefits from writing into the correct envelope from the start instead of a second
cleanup pass.

### Stage 2: the session state machine

Insert `MetaIdle → RunActive → RunResolved → MetaIdle` ahead of `main.gd:268`. This is genuinely new
construction — nothing today distinguishes "starting a session" from "the node existing" — but it's the single
piece every other stage attaches to, so it has to land before shaft generation, the flood clock, or the haul
mechanic can mean anything. Reuse `reload_current_scene()`'s existing seed/skip-title static-var pattern
(`main.gd:421-428`) as the mechanism for "begin a fresh shaft," rather than inventing a second one.

### Stage 3: excise the Bazaar's physical-structure wiring

Not a radius check — per the full `main.gd` read, this is 58 Bazaar-matching lines across 3 dedicated input
keys, a 3-tab panel dispatcher (`_bazaar_enter`, 1891-1910), one cosmetic detection/animation module (`Bazaars`,
wired at `main.gd:192,382`), and a guide-target case. Stage 0 already removed the *functional* gate; this stage
removes the *physical* one — the wood-frame detection, the walk-to-a-structure requirement, `bazaars.gd` itself
(audit verdict: DELETE, the one file that *is* the mechanic with no generic-infra reading possible). The
PACK/WORKS/BENCH tab UI survives unchanged; only its proximity/structure requirement goes.

### Stage 4: remove the Descent Engine and the research tree's gating role

Descent Engine (`factory_sim.gd:2339-2391`, 72 total LOC): a permanent, one-time throughput-quota wall that
breaches sealrock and deepens a single persistent world. No bounded-run analog fits this shape — remove it.
Research tree (`research_rules.gd` + `bazaar_bench.gd`, 320 LOC named, but 12 more files reference
`ResearchRules` and the actual gate — `craft_unlocked`/`is_researched`/`research_tech`,
`factory_sim.gd:1646-1678` — is load-bearing beyond either named file): decide explicitly what replaces "what's
craftable when," since Stage 0 already loosened the gate for testing but didn't design its replacement. Per the
Handoff's two-currency model (material buys capacity, artifacts unlock verbs), the natural replacement is a
rig-driven predicate with the same shape as `craft_unlocked` — not research state, but rig-unlock state.

### Stage 5: shaft generation per run

`LayeredWorldGen`/`WorldSeeder` are already scored PORT (compat 4) and already produce a deterministic, seeded
world from a fixed pipeline. What's new is calling that pipeline *per run* instead of once at boot, and scoping
it to a bounded shaft region rather than the persistent 128×128 grid. This is the stage where "same game, new
architecture" earns its keep — the generation algorithm doesn't change, only when and how often it runs.

### Stage 6: the flood clock

Genuinely new. `water_flow.gd`'s own design contract — "no source or drain, so `total_water()` is invariant
across a tick" (factory_sim.gd:292) — currently *forbids* what a flood clock needs: a controlled water-add over
time. Scope this as a new function gated by the run state machine (Stage 2), tied to the rig's `pump_capacity`
stat (R3), rather than touching `WaterFlow.step()`'s existing invariant-preserving passes. Keep the violation of
"no source" contained to one clearly-named function, not threaded through the existing algorithm.

### Stage 7: the haul-to-surface / extraction mechanic

Nothing like this exists today under any name (confirmed: zero hits for `extraction`-as-player-verb,
`run_end`, `game_over`, `session_end`). This is where the Freight Winch's underlying mechanism — a
power-throttled per-trip capacity plus a fixed transit duration, linking two arbitrary cells
(`factory_sim.gd:2178-2244`) — is the best existing analog, and the audit's own research agent independently
suggested repurposing it for exactly this boundary. Recommendation: don't delete the Winch outright (§4); retarget
it (or a renamed successor) at the shaft↔surface boundary specifically, as the mechanism `RunActive → RunResolved`
routes through.

### Stage 8: R1's transport cost model

Confirmed zero precedent (§3, below) — every existing upward mechanism uses `power_throttle()`, a spatial
rate/cap gate, never a per-unit or per-meter charge. This is new economic plumbing on the scale of Stage 6 or 7,
not a constant-tuning task. Natural sequencing: build it *into* Stage 7's retargeted haul mechanic, since that's
the one transport path a bounded run actually needs R1 to govern end-to-end (in-shaft Lift/Pump routing can stay
on the existing power-throttle model if the design doesn't need R1 enforced at every internal machine — confirm
with the director whether R1 applies only to the shaft→surface boundary or to every upward movement in the
shaft; the Handoff's own text ("all upward movement... forever") reads as the latter, which is a larger scope
than Stage 7 alone covers).

### Stage 9: the persistent surface rig and between-run upgrade UI

Replaces the Bazaar's shop role for the meta-progression loop. Can reuse `BazaarPage`'s tabbed-shop
infrastructure *pattern* (audit compat 4, generic shop UI) even though the Bazaar *concept* is dead — the shape
survives, the structure doesn't. Spends banked material on rig stats (`pump_capacity` for R3, fuel efficiency,
artifact-gated verb unlocks per the two-currency model).

### Stage 10: close the loop, validate

At this point a genuinely bounded two-minute run should exist end to end. Validate primarily by play, not by
harness — per §5 below, most of the existing `check_*.gd` layers that would validate this test dead systems
(`check_progression_payable.gd`, `check_craftable_registry.gd`, `check_rules_registry.gd`,
`check_pack_layout.gd`'s Bazaar-layout assertions) and need retiring alongside their subjects, not extending.
Write the harness coverage for stages 1-9 as each lands, not as a batch at the end.

---

## 3. Where the four rules conflict with what exists

**R1 (down free, up powered per meter) — CONFLICTS, zero precedent.** Every upward mechanism today (Lift, Pump,
Winch) shares one cost mechanism: `power_throttle(cell, demand) = clamp(power_at(cell)/demand, 0, 1)`
(`factory_sim.gd:2059-2066`) — a binary/proportional throughput-rate gate keyed to the *consumer's own cell* in
a spatially-decaying power field. A Lift moving material 1 cell up and a Lift moving material 20 cells up (there
is, in fact, no multi-cell "lift span" concept at all — a Lift is a single-cell machine) cost identically.
Winch's fixed `WINCH_TRANSIT_TICKS=40` is a bare constant, not derived from the head-to-station distance
anywhere in `link_winch()`. The only thing genuinely *consumed* in the whole power chain is generator coal, at a
fixed rate independent of what or how much is being lifted. **This is new construction, not a migration** — see
Stage 8.

**R2 (deep material required, not more valuable) — no conflict, because no current value system exists to
conflict with.** `MaterialDef` has no price/value field at all; `MATERIAL_SPINE.md`'s own source-derived finding
(F1/F2) already concludes ingot functions as a de facto universal currency with no exponential depth-value
curve anywhere in the recipe graph. R2 is greenfield recipe-quantity design, not a code fight.

**R3 (run length is a purchased resource, derived from rig state) — CONFLICTS, zero precedent.** No
`pump_capacity`, no run-duration constant, no rig stat driving any timer anywhere (confirmed by exhaustive
grep). New construction — Stage 6/9.

**R4 (every tool tier removes one skill, introduces another) — the one rule with real, already-shipped
precedent.** `BITS.md` (REWRITE, not ARCHIVE, per §1) already documents exactly this shape, already built:
DRIVE (pick tier, gates what rock you can bite at all, monotonic) versus BIT (interchangeable cutting head,
changes what one swing *does* — Point/Broad/Lance/Sinker/Wedge), plus SEAMS (grain-direction mining, a hard
bite/no-bite wall with legible refusal tells replacing a "punishingly slow" soft gate). The mechanic doesn't need
redesigning — only its *acquisition* model (currently Drive=Bench-research, Bit=Rack-purchase, both dead
delivery mechanisms) needs to move to rig-upgrade unlocks. **Push back on this one specifically if the design
review didn't already know it**: R4 is closer to done than any other rule in this document.

---

## 4. What should be deleted outright, and the risk

None of the six items named in Handoff §3.3 are stubs — every one is live, wired, tested code, confirmed by
full reads this pass. That changes the risk calculus for several of them.

| Item | LOC | Risk of outright deletion | Recommendation |
|---|---:|---|---|
| Descent Engine | 72 | **Low.** Narrowly scoped (3 functions + consts), nothing else calls `_seal_below`. | Delete (Stage 4). |
| Research tree as menu | 320 named, but the real gate (`craft_unlocked`) is load-bearing across 12 more files | **Medium-high.** Deleting the menu alone orphans the gate; every locked craftable needs a replacement predicate decided *before* deletion, not after. | Delete the menu; replace the gate's *predicate* with rig-unlock state, keep its *shape* (Stage 4). |
| Waste/tailings | 0 | **None.** Zero occurrences anywhere in `src/`/`scenes/` — it was designed, never implemented. | Nothing to delete. |
| Plates and gears | 93, pure `.tres` data, zero bespoke sim code (runs through the generic `_run_recipe` fallback) | **Low.** Their only consumers (Drift Rig, H-Drill, Blast Furnace, Crusher, 3 research rungs) are themselves being cut in the same pass — no orphaned dependents. | Delete alongside the L2/L3 tier. |
| Splitter | ~49 | **Worth a second look before deleting.** It is today's *only* branching item-router and is explicitly documented in-repo as intentionally-ungated "core loop" infrastructure (`research_rules.gd:9`). Under §6's own "a hole is a conveyor" philosophy, a bounded run may not need a *machine* for branching at all — two free-carved chutes are a splitter — which would make deletion a deliberate simplification, not a gap. | Confirm with the director this is intentional before deleting; if geometry replaces it, say so explicitly rather than silently losing branching capability. |
| Conduit / Generator | ~88 / ~60 | **Medium — a quiet-failure risk, not a hard blocker.** Generator is the *only* `power_source:true` entry in `_BEHAVIORS`; Lift/Pump/Winch's entire cost mechanism depends on `power_throttle()` reading a nonzero `power_at(cell)`. Delete Generator/Conduit without deciding what replaces power-gating, and Lift/Pump/Winch don't break — they silently freeze at their *unpowered floor* (`LIFT_THROUGHPUT=2` forever, never `LIFT_POWERED_THROUGHPUT=6`) with no error, exactly the "quiet green" failure class this project's own harness culture is built to catch. | Delete only as part of the same decision that defines R1's replacement cost model (Stage 8) — not independently. |
| Freight Winch (as currently conceived) | ~224 | **Low if repurposed, medium if deleted outright** (loses the closest existing analog to the shaft↔surface haul mechanic — see Stage 7). | Repurpose, don't delete; retarget at the run boundary. |
| Horizontal boring (H-Drill/"Borer") | ~123 | **Low.** Self-contained, gated behind 'machining' (also cut), nothing else depends on it. | Delete. |
| Seven-layer depth plan | mostly design, minimal code | **Low.** Only L1/L2 are actually worldgen-implemented (`DEEPSLATE_ROW`/`SEAL_TOP`/`SEAL_ROWS` in `layered_world_gen.gd`); L3-L6 were "DESIGNED, not built" per `PROGRESSION.md`'s own status note. Also: **it isn't seven anywhere in the code** — `strata.gd`'s `BANDS` has 8 entries including a non-depth "OPEN SKY," `PROGRESSION.md`'s ladder has 6 rows. | Mostly a worldgen-tuning task (`strata.gd`, `layered_world_gen.gd` constants), not a deletion — there's little built to remove. |

---

## 5. The harness-freeze question

**Recommendation: freeze new harness surface for the systems §3.3 kills, effective now — but do not freeze
harness work for the new run/shaft/flood/save-split construction, which needs coverage as it lands, not after.**

The evidence supports the Handoff's instinct more strongly than the Handoff itself states it. `tools/` grew 90%
in the 5 days since the last portfolio audit (33,773→64,319 GDScript lines, 232 commits) against `src/`'s 9%,
already a 2.6:1 instrumentation-to-game ratio. This pass adds a sharper point: a real, non-trivial fraction of
*that existing harness* directly tests systems this plan kills — `check_progression_payable.gd`,
`check_craftable_registry.gd`, and `check_rules_registry.gd` test the research tree; `check_pack_layout.gd`
asserts Bazaar-pack layout geometry; roughly 40 of `VISUAL_RECOMMENDATIONS_SURFACE.md`'s ~90 tickets and most of
`MENU_MATRIX.md`'s findings are Bazaar-UI-specific. Continuing to write new checks against the Bazaar or research
tree between now and their removal is measurable waste — tests written against code with a known deletion date.
When Stage 3/4 land, these existing layers need retiring alongside their subjects, not indefinite maintenance as
false-positive dead weight (a green check for a deleted mechanic is a worse failure mode than a missing one).

---

## 6. The language question, re-argued from measurement

**Recommendation: do not migrate to Rust now.** The original brief's case rested on three gaps — engine
coupling, unverified determinism, and weak static typing — and this project has already closed or substantially
narrowed all three without a language change:

- **Engine coupling:** the audit's strictest possible P1 test (16 grep patterns plus 11 supplementary
  engine-lifecycle patterns, across all 5,399 lines of `src/core/`) found zero violations. The sim is genuinely
  node-free, not aspirationally so.
- **Determinism:** proven live, not assumed — `tests/test_stress.gd` run headless this session produced a
  byte-identical replay of a 364-op seeded sequence including a mid-sequence save/load round-trip.
- **Static typing:** already enforced as a *compile error*, not a lint warning —
  `project.godot`'s `gdscript/warnings/untyped_declaration=2` (confirmed at the very start of the compatibility
  audit) makes an untyped declaration a build failure today, in GDScript, with no migration required.

What's left of the original case is pure runtime performance headroom at a scale nothing in this repository has
been measured against yet. The audit's real evidence — ~2× frame-budget headroom at *current* (not late-game)
scale, packed `Dictionary`/`Array` item and machine representation rather than the Node-per-item anti-pattern —
points toward "probably fine," but the audit itself named the honest gap: no harness layer exercises the
brief's target load (2,000 machines / 20,000 items), so "probably fine" is an extrapolation, not a measurement.
**The correct trigger for revisiting this isn't a deadline or a brief — it's a specific benchmark scenario at
that scale returning a number GDScript can't hit**, which doesn't exist yet and is a real, separately-worth-doing
piece of work. Migrating now would also discard the compat audit's strongest finding — 72% of subsystems already
score ≥3 compatible, zero dependency cycles — for a performance problem that hasn't been shown to exist.

---

## 7. Where this document — and the Handoff it's built on — is likely wrong

- **`MATERIALS.md` doesn't exist**; the Handoff's §1 header means `docs/MATERIAL_SPINE.md`. Minor, but worth
  fixing before either document is cited again.
- **The Handoff's "does not supersede: DECISIONS.md, ARCHITECTURE.md" is too strong**, corrected in §1: both need
  targeted section-level edits, not zero changes. Neither should be archived, but treating them as fully
  untouched leaves four dead-design sections in `ARCHITECTURE.md` and several dead-design entries in
  `DECISIONS.md`'s Design section standing as if current.
- **"The A+ program docs" are not design content and don't need a superseded header** — corrected in §1;
  they're pure engineering-process records with zero game-design dependency.
- **The seven-layer depth plan isn't seven anywhere in the actual repository** — 8 band entries in `strata.gd`
  (including a non-depth "OPEN SKY") or 6 ladder rows in `PROGRESSION.md`, never a clean 7. Worth using a precise
  number in whatever document replaces `PROGRESSION.md`.
- **Splitter's inclusion on the kill list deserves a second look, not automatic deletion** — see §4. It's the
  only current branching mechanism and is explicitly documented as intentionally-ungated core infrastructure;
  the Handoff's own §6 philosophy (a hole is a conveyor) may make it redundant by design, but that should be a
  stated decision, not a silent capability loss.
- **The Freight Winch is worth repurposing, not deleting** — its underlying trip-capacity/transit-tick mechanism
  linking two arbitrary cells is the closest existing analog to the shaft↔surface haul boundary the pivot
  actually needs (§2 Stage 7), and the "as currently conceived" qualifier in the Handoff's own §3.3 already
  leaves room for this reading.
- **Deleting Generator/Conduit is entangled with R1's design, not independent of it** — see §4's Conduit/
  Generator row. This wasn't obvious from the Handoff alone and only surfaced from reading how `power_throttle()`
  is shared across every upward-transport mechanism.
- **The Handoff's own §8 estimate that "condition 4's result is provisional" and "a batching pass is likely real
  uncosted work" is confirmed, not just plausible** — this pass's `main.gd` read found the per-frame juice/HUD
  push (lines 681-816) already scans `sim.machines` and `sim.water` multiple times per frame for cosmetic
  purposes (factory-hum SFX, pump SFX, breach-stinger detection) independent of the draw-call count the audit
  measured; at 2,000 machines this cosmetic scanning cost is additional to the draw-call finding and wasn't
  separately budgeted anywhere.
- **This document itself should be read skeptically on effort/scope for Stages 6-9** — none of them have a
  measured cost the way §1-§5 of this document do; they're reasoned from what exists, not sized from a prototype.
  Treat the ordering as more load-bearing than any implied timeline.
