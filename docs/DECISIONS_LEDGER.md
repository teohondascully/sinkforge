# Decisions ledger

Append-only. Every judgment call not dictated by a normative doc, logged when made, not at session
end. Four lines: decided, alternative, why, reverse cost. Test: would a competent engineer with these
documents have plausibly chosen differently? If yes, it belongs here. `CONTEXT.md`, "Review bandwidth."

---

## D0001 · 2026-08-26 · docs/GDD.md §8
Decided: Draft A's run curve is 2, 3, 5, 8, 12, 18, 25, 35, 42 minutes across 9 runs (~2.5h total).
Alternative: any other escalating shape landing in the stated 8-12 runs / 2-3h envelope — this exact
sequence is one plausible fit among many.
Why: preserves the original curve's escalating shape and front-loaded-cadence argument while landing
inside the revised total. Not derived from anything more principled than "a plausible compression";
flagging in case the director wants a different specific shape.
Reverse: CHEAP — prose numbers, nothing built against them yet.

## D0002 · 2026-08-26 · docs/GDD.md §5, §10
Decided: extended the run-curve revision beyond §8 into the worked examples in §5 ("Run 12"/"Run 30" →
"Run 5"/"Run 9") and §10 ("Run 25" → "Run 9"), which the instruction to update the curve didn't name
explicitly.
Alternative: leave those examples untouched and let them go stale against the new 9-run arc.
Why: leaving them would put two irreconcilable claims about total run count in the same document —
exactly the kind of internal contradiction this project treats as a defect, not a style choice.
Reverse: CHEAP — prose only.

## D0003 · 2026-08-26 · sim/commands/MODULE.md, sim/run/MODULE.md
Decided: the Freight Winch gate note goes in both MODULE.md files, not just one.
Alternative: `sim/commands` only, the closer analog to the pre-pivot entry point where the mechanic
regrew ad hoc.
Why: haul mechanics plausibly touch both the command vocabulary and run lifecycle; a reader consulting
only one module shouldn't miss the gate.
Reverse: CHEAP — delete a paragraph from either file.

## D0004 · 2026-08-26 · core/ — NOT DECIDED, stopped per instruction
Not decided: fixed-point representation for state-affecting positions and velocities.
Existing spec: `core/MODULE.md` and `docs/ARCHITECTURE.md` §4 both already say i32, 16 fractional bits —
written during Task 0 skeleton scaffolding, before this specific range question was checked. i32 (not
i64) is well-motivated independent of range: it makes fixed-point multiply safe using GDScript's native
64-bit int as the intermediate (i32 × i32 always fits in 64 bits; i64 × i64 would need 128-bit
intermediates GDScript doesn't have). That part looks right and isn't in question.
What's actually unresolved: 16 fractional bits leaves 15 magnitude bits, so position range is ±32,767 in
whatever unit "position" is stored in. Two facts needed to validate that range are not written down
anywhere I can find: (1) the pixels-per-meter (or equivalent) conversion between GDD's narrative depth
in meters and the position unit body/world actually use — `docs/ARCHITECTURE.md` §9 names 1px/2-4px/16px
as resolution levels but never states a scale constant, and legacy's old `CELL: int = 32` doesn't carry
over as a stated decision; (2) a maximum playable depth — `docs/GDD.md` §11 states depth is "continuous
and always increasing" with no ceiling, by design. Without both, ±32,767 units cannot be checked against
the depth range "we need," which is exactly the check requested. A chunked/relative coordinate scheme
(position relative to a region origin, sidestepping global range entirely) is a plausible alternative
that would change what "range" even means here, and isn't something to adopt unilaterally either.
Reverse: N/A — nothing implemented. `core/fixed_point.gd` (or equivalent) is not written this session.
Blocks: `sim/body`, `sim/transport`, and any other position/velocity state, but not RNG or generational
IDs, which don't depend on it — proceeding with those instead.

## D0005 · 2026-08-26 · core/split_rng.gd
Decided: SplitMix64 (Vigna) as the RNG algorithm, verified bit-exact in GDScript against a from-scratch
Python reference before writing any test around it (golden vectors regenerated, not remembered).
Alternative: xorshift128+, PCG32, or a Godot-builtin-seeded `RandomNumberGenerator` wrapper.
Why: four operations, no internal array/table state (the entire state is one int, trivial to serialize
per `docs/ARCHITECTURE.md` §4's "streams are serialized state"), and its structure makes advancing the
stream and deriving a child stream the same primitive operation, which is what `split()` needed. Not
cryptographically secure and nothing here needs that. Godot's built-in RNG was rejected specifically
because its algorithm isn't part of the engine's documented determinism contract — this project pins
the engine version for reproducibility and shouldn't also depend on an internal implementation detail
that could change between patch releases without notice.
Reverse: EXPENSIVE once anything depends on specific drawn values (a recorded replay log, a scenario
fixture) — cheap right now, before either exists.

## D0006 · 2026-08-26 · core/split_rng.gd
Decided: `split(label)` derives from the stream's ROOT seed, not its current draw position, and passes
the result through one extra SplitMix64 step rather than using the raw XOR of root-seed and label-hash
directly.
Alternative: derive from current mutable state (simpler, but makes split() results depend on call order
and how many draws happened first — a stream saved/restored mid-run could then produce different children
than the same stream that never paused, which would be a determinism trap of exactly the kind this
project exists to avoid); or skip the extra mixing step (cheaper, but a family of labels differing by one
bit would produce correlated children).
Why: order-independence is worth one extra operation. Verified in the same test suite that split() gives
identical results regardless of how many draws preceded the call.
Reverse: CHEAP — nothing consumes split() output for real yet.

## D0007 · 2026-08-26 · core/entity_id_pool.gd
Decided: an entity id is one packed 64-bit int, `(generation << 32) | index`, not a two-field object.
Alternative: a small `RefCounted`-based `EntityId` class with `index`/`generation` fields and an
`equals()` method.
Why: GDScript objects compare by reference, not value, so two `EntityId` instances representing "the
same" id would need a custom equals() everywhere instead of plain `==`, and couldn't be used as
dictionary keys directly. A packed int sidesteps both for free and serializes as one integer, which
matches "generational-index entity IDs... Never pointers, never bare array positions"
(`docs/ARCHITECTURE.md` §4) more literally than an object would. 32 bits per field is not a limit this
project will hit.
Reverse: EXPENSIVE once any sim/ module stores ids in serialized state or as struct fields — cheap now,
nothing does yet. The release operation is named `release()`, not `free()` — `Object.free()` is inherited
by every GDScript class and the collision is a parse error, not a silent shadow, but the name is worth
getting right the first time rather than colliding with it in a dozen call sites later.

## D0008 · 2026-08-26 · HARD STOP — gate red, not fixable in one attempt within scope
Not decided: nothing. `SplitRng` and `EntityIdPool` (152 lines, `core/`) plus their tests (249 lines,
`tests/`) are complete, mutation-tested, and staged, but NOT committed — `check_loc_ratio.py` FAILs
(instrument 1112 > game 152) and this is the hard stop the autonomous-session grant named explicitly:
"any gate red you cannot make green in one attempt — revert, log, stop."
This is not a bug in the new code or a miscalibrated gate. `tools/` alone is 863 lines, built in Task 0
before any game code existed, specifically because `docs/ONBOARDING.md` Task 0.6 required the gates to
exist before core/ or sim/ did. 863 already exceeds any plausible size for `core/` on its own — "small,
pure," per this module's own MODULE.md — so this gate was arithmetically guaranteed to flip from its
bootstrap WARN to a real FAIL the moment ANY code landed in `core/` without `sim/` also landing enough
LOC alongside it. That is exactly what this autonomous grant's stage boundary does: stop before stage 3
(`sim/world`, `sim/terrain_gen`), which is where most real "game" LOC would come from. The gate's own
source comment anticipated this precisely: "This WARN must stop being silent the moment Task 1 lands
core/... it should be treated as a FAIL by hand until then" — it did exactly what it was built to do.
The two ways to make it green — shrink `tests/` to reduce instrument LOC, or write `sim/` code to grow
game LOC — are both worse than leaving it red: the first trades away real correctness assurance on
bit-manipulation code specifically chosen because it's easy to get subtly wrong, to satisfy a proxy
metric (exactly the "claim-as-paperwork" failure class this project's culture exists to avoid); the
second crosses the stage-3 boundary the grant drew on purpose ("stage 3 starts making judgment calls...
I want to be present for those").
Reverse: N/A — nothing committed, nothing reverted. The 152+249 lines exist on disk, staged, for review;
git history is untouched past commit `b45510f`.
Blocks: this session's remaining commit budget. Stage 2 (`replay_determinism_test`) is not attempted —
it would only add more `tests/` LOC against the same still-tiny `core/`, worsening the same red rather
than working around it.

## D0004 — RESOLVED, 2026-08-26
The director supplied both missing constants directly: world scale 16px = 1m (= the machine/logic
cell), terrain grid 4px, max playable depth 4096px (256m). i32/16-fractional-bits checked against them
in `docs/adr/0003-fixed-point-representation.md` and confirmed far from binding (8x range headroom,
precision several orders finer than anything that consumes it). `core/fixed_point.gd` implements
exactly this format. This entry is not edited above — D0004 is left as the honest record of what was
unknown at the time; this is the follow-up, not a correction of it.

## D0009 · 2026-08-26 · core/fixed_point.gd
Decided: `Fx.isqrt()` uses Newton's method (Heron's method) on plain non-negative integers, verified
against Python's `math.isqrt` for 27 values including 0, 1, perfect squares, and random values up to
2^47 before being trusted.
Alternative: a bit-by-bit binary digit-extraction integer sqrt (the classic hardware-style algorithm),
or a fixed iteration count instead of convergence-based termination.
Why: Newton's method for integer sqrt converges monotonically and terminates in a handful of iterations
for any input in this project's actual range; it's fewer lines and easier to verify by hand than the
bit-by-bit form, and termination-by-convergence (rather than a fixed iteration count) means it's
correct rather than "correct enough after N steps" — no separate argument needed for why N is enough.
Reverse: CHEAP — nothing outside `core/` calls it yet, and both algorithms produce the same output for
the same input by construction (floor(sqrt(x))), so swapping is a drop-in replacement if a performance
reason ever justifies it.

## D0010 · 2026-08-26 · core/fixed_point.gd
Decided: `Fx.div(a, b)` with `b == 0` returns 0 and logs via `push_error()`, rather than letting
GDScript's `/` raise.
Alternative: return a saturated sentinel (max/min i32 depending on the sign of `a`), or let it raise and
require every caller to pre-check `b != 0` themselves.
Why: an unguarded `/` by zero doesn't crash the process in a bare `--headless --script` run — it HANGS,
because the runtime script error aborts execution before `quit()` is ever reached, and nothing catches
it (GDScript has no try/catch). Verified empirically before writing this entry, not assumed; see
`core/MODULE.md`'s Gotchas for the general statement. A hang is strictly worse than a wrong-but-visible
return value for a test suite or CI job, so returning 0 (loud in the log, not fatal to the run) was
chosen over both letting it raise and over a saturating sentinel, which would be quieter about a real
bug than an explicit error log is.
Reverse: CHEAP — one function, no caller depends on the specific sentinel value yet.

## D0011 · 2026-08-26 · core/fixed_point.gd
Decided: `Fx.length()`/`Fx.length_sq()` are scoped explicitly as LOCAL-neighborhood primitives (safe to
~181px per axis, documented and demonstrated by a test that shows the exact wraparound point), not
extended to handle arbitrary world-scale distances.
Alternative: widen the intermediate (accumulate the squared terms in a wider format before reducing) so
the function is safe across the full ~2048m depth budget.
Why: named need was "distance" for `sim/body`/`sim/transport`, which is collision-adjacent and
inherently local (nearest-neighbor checks, per-tick movement deltas) — never a distance query spanning
a meaningful fraction of the world. Building a world-scale-safe version now would be exactly the
"square roots beyond what collision needs" the autonomous grant named as a stop condition, for a need
nothing currently has. Documented precisely instead of built defensively.
Reverse: EXPENSIVE once something calls `length()` on a delta anywhere near 181px and gets silently
wrong output — this is the specific risk the doc comment and the boundary test exist to prevent, but a
reverse (widening the intermediate) would still just be adding to the same file, not restructuring it.

## D0012 · 2026-08-26 · tests/test_replay_determinism.gd
Decided: Stage 2's stub sim and its replay test live entirely in `tests/`, not in a new `sim/` or
`harness/` file.
Alternative: create minimal placeholder `sim/` and `harness/` modules now, so the stub "lives where the
real thing eventually will."
Why: `sim/` and `harness/` are stage 3+, gated on judgment calls (worldgen porting, scenario format) the
director explicitly wants to be present for. A placeholder module under either name risks reading as
those layers having started for real. `tests/` is the one place touching this doesn't imply anything
about layer boundaries not yet decided.
Reverse: CHEAP — this file is explicitly documented as throwaway scaffolding, superseded rather than
extended once a real sim exists.

## D0013 · 2026-08-26 · tests/test_replay_determinism.gd
Decided: the "recorded input log" is a fixed deterministic pattern (spawn every 37 ticks, despawn every
53) generated once, independent of the stub's own `SplitRng` stream.
Alternative: derive the input log from RNG too, or skip the input-log concept entirely and just tick
20,000 times with no per-tick events.
Why: keeps "recorded external input" and "sim-internal randomness" as two separate concepts even in a
stub this small, matching what `docs/ARCHITECTURE.md` §6 will actually need (a real `input.log` distinct
from any RNG stream) — a stub that already respects that boundary is a small head start on the real
harness's shape.
Reverse: CHEAP — the pattern's specific numbers are arbitrary and nothing depends on them.

## D0014 · 2026-08-26 · tests/test_replay_determinism.gd
Decided: checkpoint hashing uses GDScript's built-in `String.hash()`, not a hand-rolled hash function.
Alternative: implement a deterministic hash (e.g. FNV-1a, already written once for `core/split_rng.gd`)
to avoid depending on an engine-internal algorithm.
Why: unlike `SplitRng.split()`'s label hashing (which needed to be independently specified and stable so
it could be tested against an external Python reference), this hash only ever compares two values
computed in the same process, in the same run, against each other — it's never persisted, replayed
across engine versions, or checked against anything outside this one test. Whatever `String.hash()`
does, it does identically both times it's called in the same process, which is the only property this
use needs.
Reverse: CHEAP — swapping the hash function changes nothing about what the test asserts.

## D0015 · 2026-08-26 · tests/test_replay_determinism.gd
Decided: kept the full 20,000-tick count and 100-tick hash interval from `docs/ARCHITECTURE.md` §4's
`replay_determinism_test` spec, even though the stub's own state and logic are deliberately trivial.
Alternative: reduce the tick count too, on the theory that a trivial stub deserves a trivial test.
Why: "the stub can be almost nothing" (director) is about what the stub simulates, not about whether the
replay-and-hash mechanism itself gets exercised at the scale the real requirement states. Running the
actual specified tick count now is what proves the mechanism holds up at that scale before anything
real depends on it — the whole point of building this stage before there's a sim worth testing.
Reverse: CHEAP — two constants.

## D0016 · 2026-08-26 · data/strata/shallow_clay.yaml
Decided: every ported generation constant (cave thresholds, strata banding, ore/coal/iron attempts and
sizing) lives in one per-site YAML file that `sim/terrain_gen`'s `generate()` takes as an explicit
parameter, rather than as constants inside the generator's own code.
Alternative: keep the constants as GDScript consts (as legacy did) and add per-shaft modifier support
as a later refactor once the modifier system is actually designed.
Why: `docs/GDD.md` §2's per-shaft modifiers ("floods fast", "hard rock starts early") are stated as data
requirements now, and `docs/QUALITY.md`/`data/README.md` both treat "a generation parameter that can
only vary by code branch" as the specific failure this project polices. Parameterizing now, before the
modifier system exists, is the same pattern as ADR-0002's R1 scope decision: the option a later modifier
needs is preserved by construction rather than retrofitted.
Reverse: CHEAP — the parameter object's shape, not this.

## D0017 · 2026-08-26 · sim/terrain_gen — scope cut, not silently dropped
Decided: `legacy/src/core/layered_world_gen.gd`'s big caverns, tunnels, rifts, ledges, spires, rubble,
lodes, aquifers, aquifer-treasure, surface trees, the bazaar-ruin stamp, the research-gated "seal", and
`_restore_turf` are NOT ported this stage. Only strata banding, cave carving, and ore/coal/iron vein
scattering are.
Alternative: port everything for structural completeness, deferring only the genuinely dead-mechanic
passes (bazaar ruin, the seal).
Why: several of the cut passes are themselves tied to dead pre-pivot mechanics (the seal gates a
research tier that no longer exists; aquifers were a different, superseded water-risk concept from R3's
clock-driven flood; rifts assumed a persistent explorable world the player finds structure in, where the
new design has the player's own dig AS the vertical structure). Porting these faithfully would mean
re-deciding pre-pivot design questions this stage isn't scoped to touch. What's kept (strata, caves,
ore/coal/iron) is what `docs/ARCHITECTURE.md` §9's determinism/resolution goals and `docs/GDD.md` §11's
three-layer structure actually need to be provable this stage.
One specific regression risk carried forward, not silently: legacy's `STRATA_SHELF_EVERY` comment
documents a real defect at value 2 (shelf bands collapse into one contiguous slab), held by a legacy
test not ported here. `data/strata/shallow_clay.yaml`'s value (3) matches legacy's, but nothing in this
port's own test suite would catch a future edit reintroducing that defect the way legacy's test did.
Reverse: CHEAP to add any cut pass later — each was additive in legacy's own `generate()` pipeline.
EXPENSIVE if the strata-shelf regression is ever silently reintroduced without a test to catch it —
flagged here specifically so it isn't rediscovered by feel.

## D0018 · 2026-08-26 · sim/terrain_gen — ruin placement, minimal scope
Decided: one guaranteed empty chamber per generated shaft, past a minimum depth, marked with a distinct
material/flag and nothing else. No artifact, no schematic, no loot table.
Alternative: wait until `sim/items` exists and skip ruin placement entirely this stage, since
`terrain_gen`'s own MODULE.md names "ruin placement" as in scope.
Why: `docs/GDD.md` §5's ruins ("artifacts found in deep ruins... skip extraction entirely, sprint, grab
the schematic") describe a mechanic whose exact generation parameters (frequency, size, content rules)
are undesigned — inventing them now would be deciding unstated design, not porting a stated one. Placing
an empty, marked chamber satisfies the MODULE.md's literal scope (terrain_gen decides WHERE, not WHAT)
without inventing artifact semantics that belong to a module that doesn't exist yet.
Reverse: CHEAP — one function, no consumer depends on ruin content yet.

## D0019 · 2026-08-26 · EXPENSIVE, analyzed not decided — chunk size
Not decided: fixed chunk array size for `sim/world`'s tile storage.
`sim/world/tile_grid.gd` uses a sparse `Dictionary` (`terrain_cell: Vector2i -> material: StringName`),
matching legacy's own `WorldData` representation, which sidesteps needing a chunk size at all for
correctness — "chunk" in this stage means only "the bounded region one shaft's generation touches,"
addressed sparsely, not a fixed-size backing array.
The actual chunk-size question (what size for a packed array optimization later) interacts with three
things this stage has no data on: dirty-rect rebuild cost for the fine-terrain remold (`legacy/src/core/
fine_terrain.gd`'s `SYNC_BAND`/`SUBDIV` pattern is the closest precedent — a coarse-cell edit remolds a
`SUBDIV × (1 + 2×SYNC_BAND)` fine-cell block, so a bigger chunk means a bigger minimum remold even for a
one-cell edit), the fluid active-cell set's iteration cost once `sim/fluid` exists, and the size of
whatever gets sent to `view/` as a render packet. A size aligned to the 16px logic grid (so a chunk
boundary lines up with a machine-placement cell — e.g. 16×16 or 32×32 terrain cells) is the natural
family to pick from, but which one trades those three costs correctly is not knowable without measuring
any of them, which nothing built yet can do.
Reverse: N/A — nothing implemented depends on a chunk size. Revisit once `sim/fluid` and `view/` exist
enough to measure against.

## D0020 · 2026-08-26 · EXPENSIVE, proposed not committed — coordinate type scheme
Not committed: how the 4px terrain grid and the 16px machine/logic grid are distinguished in the API.
Working choice for this stage, explicitly reversible: naming convention only — every `sim/world`/
`sim/terrain_gen` function signature and parameter is named `terrain_cell: Vector2i` (never a bare
`cell`), reserving `logic_cell: Vector2i` for whichever future module (`sim/machines`, most likely)
needs the 16px grid. Both grids share GDScript's `Vector2i`; nothing at the type level stops a caller
from passing a `logic_cell` where a `terrain_cell` is expected.
Two stronger alternatives, proposed, not adopted:
  (a) Distinct lightweight wrapper classes (`TerrainCell`, `LogicCell`, each holding one `Vector2i`) —
      a type-level guarantee, a real GDScript class per coordinate, so a mismatch is a compile-time
      type error rather than a naming-discipline lapse. Cost: every coordinate becomes a `RefCounted`
      allocation, and terrain-grid coordinates are queried at collision/rendering frequency — the
      allocation cost is unmeasured, not assumed acceptable.
  (b) A single coordinate type carrying its own grid tag (e.g. an int enum field alongside x/y), checked
      at the API boundary with an explicit assert. Weaker than (a) at compile time, cheaper at runtime,
      catches a mismatch at the first call rather than never.
Why naming-only for now: it's the only option with zero performance cost and zero speculative
structure, and per the director's instruction this is a propose-don't-commit question — adopting (a) or
(b) now would foreclose the other without the measurement needed to choose between them.
Reverse: EXPENSIVE if a real cross-grid coordinate bug ships before this is revisited — the risk this
naming-only choice accepts, stated plainly rather than assumed away.

## D0021 · 2026-08-26 · data/ has no GDScript-side runtime loader yet — flagged, not solved
Finding, not really a choice: Godot ships no YAML parser, so nothing in `sim/` can read
`data/strata/shallow_clay.yaml` or `data/materials/*.yaml` directly at runtime. `sim/terrain_gen`'s
`site_shallow_clay.gd` and `sim/world`'s `materials.gd` are GDScript dictionaries hand-mirroring the
YAML files' values, kept in sync by hand for now — not a data-loading pipeline.
Alternative considered and rejected for this stage: write a minimal YAML-subset parser (flat and
one-level-nested scalars only, which is all this stage's files use). Rejected as scope creep: a parser,
however minimal, is infrastructure for all of `data/`, not something `sim/world`/`sim/terrain_gen`
should own or that this stage's budget should absorb.
This is closer to EXPENSIVE than CHEAP and is flagged as such rather than decided: how `data/` gets from
YAML to a running GDScript value touches every future data-driven module (`sim/machines`,
`sim/economy`, `sim/meta`), not just this stage's two. Options for whoever picks this up: a small
hand-written parser scoped to the actual subset in use, a build-time codegen step (YAML -> a generated
.gd file, checked in), or switching `data/`'s on-disk format to something Godot's `JSON` singleton reads
natively while keeping `.yaml` review copies. Not chosen here.
Reverse: EXPENSIVE — every hand-mirrored file is a place the two copies can silently drift; the mirrors
this stage adds are named exactly for the file they mirror so drift is at least easy to search for.

## D0022 · 2026-08-26 · tests/, not scenarios/, for the shaft-determinism check
Decided: "generates a shaft from a seed and asserts determinism across two generations" is a
`tests/` suite, not a `scenarios/*.yaml` fixture with a claim reference.
Alternative: create a real `scenarios/*.yaml` file matching `docs/ARCHITECTURE.md` §6's declarative
format, naming a new claim (C003 or similar).
Why: `docs/CLAIMS.md` §10d draws the claim/test boundary explicitly — "a correctness assertion is a
test... no design choice makes it acceptable for [it] to [fail]." Nothing about Draft A vs. C, R1's
scope, or any other design decision changes whether the same seed must produce the same terrain twice;
that's an architectural invariant, the same category as conservation of matter, not a design claim.
Filing it as a claim would also immediately fail `check_claim_references.py`'s scenario check, which
requires a cited claim's `first_failed_at` to be populated before the gate passes — unsatisfiable for a
brand-new claim with no harness yet to observe it failing for real. Same pattern as stage 2's stub
living in `tests/`, not `harness/`.
Reverse: CHEAP — nothing stops a future `scenarios/*.yaml` fixture from covering shaft generation for an
actual design claim (e.g. "a generated shaft always has a completable ore-to-surface route") once such a
claim exists; this entry is about the determinism check specifically, not about scenarios never
existing for terrain_gen.

## D0023 · 2026-08-26 · no_engine_imports gap: FastNoiseLite and RandomNumberGenerator
Decided: added both classes to `tools/layer_lint/no_engine_imports.py`'s pattern list, ahead of writing
`sim/terrain_gen`'s cave-carving pass.
Why: legacy's cave carving uses `FastNoiseLite` and a plain `RandomNumberGenerator`, both real Godot
engine classes. The gate's own docstring says it encodes only "something docs/ARCHITECTURE.md states
outright as forbidden," scoped to categories that had come up before this stage (scene-tree, resource
paths, file IO, wall clock, unseeded global RNG, autoloads) — noise/RNG *classes* were never enumerated,
so both would have passed the gate cleanly while quietly reintroducing engine coupling into L1, exactly
the failure mode the file's own comment warns about from the other direction ("loosening a pattern here
is exactly how the sim quietly regains engine coupling" — a category nobody added yet is the same gap by
omission). Caught by reading the gate before writing the code that would have tripped it, not by a red.
Reverse: CHEAP to relax per-file if a real exception ever needs one (the gate has no allowlist mechanism
yet, but none of L1 has needed an exception so far).

## D0024 · 2026-08-26 · integration test missed a floor a unit test caught
Found while mutation-checking `ShaftGenerator._grow_vein`'s `min_row` floor (the guard stopping an
iron vein from accreting upward into hardrock): removing the floor did NOT fail the full-scale
generation test (`_test_iron_only_appears_at_or_below_stonereach`, seed 20260826, real
`StrataData.SHALLOW_CLAY` dimensions).
Why it didn't catch it: an accretion blob is compact (radius roughly sqrt(size/pi) for a 2D fill), and
iron's size range (10-40 cells) gives a radius of about 2-4 cells. Iron's seed depth is uniform over a
464-row band, so only a small fraction of the ~307 attempts per run seed within a few rows of the
`stonereach_end` floor at all, and among those, whether the blob's random walk happens to reach upward
across the line is a further coin flip. The floor is real and load-bearing; the seed this test happened
to use just didn't expose it.
Fix: added a second, targeted test that isolates `_grow_vein` directly -- an all-host-rock grid, a seed
sitting exactly on the floor, size large enough (60, against a 20x10 available band) that the frontier
is forced to repeatedly offer cells one row above the floor. Mutation-confirmed this one catches it.
Same pattern for the "never fills a carved cave" half of the host-rock check: an integration-scale test
never confirmed it either (caves are sparse enough that a random vein rarely lands next to one); a
direct unit test seeding a vein beside a pre-carved cell does.
General lesson, matches [[correct-instrument-wrong-scale]]/[[instrument-cannot-register-subject]] in
spirit: a full-generation integration test asks "does the finished world look right," which is the wrong
scale to ask "does this one guard ever fire." A guard needs a test built to force it, not a test that
merely runs code that happens to contain it.
