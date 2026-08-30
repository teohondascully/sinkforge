# Working state

Not a log. Current stage, what's actually happening, and what would be lost if this session ended
right now. Updated as work happens. Resets when a stage closes — durable content moves to an ADR,
a MODULE.md, or a claim first.

**Last updated: 2026-08-30.** Bump this date whenever this file changes — a CI gate fails if it's
older than `HEAD`'s own commit date, so a session that lands commits without touching this file is
caught mechanically rather than relying on someone noticing later.

**Reset this round:** the D0206 section compressed to its result (detail in `docs/DECISIONS_LEDGER.md`
D0206-D0212), replaced by D0213 below. New file this round: **`docs/NEEDS_DIRECTOR.md`**, the parked
queue — read it first if you are the director picking this up, it is what is waiting on a ruling.

## DONE THIS RUN — the third and last instant translation, closed (D0213)

**The class D0209 (step-up mid-air) and D0212 (mantle mid-air) opened is now closed at its third
instance.** `VerticalResolve.resolve_ceiling`'s corner nudge took its direction from `body.facing`
whenever `vel_x` was zero, so a body jumping STRAIGHT UP under an overhang, with no horizontal input at
all, was translated **+6.00px sideways in one tick** — 360 px/s against a 150 px/s run speed — in a
direction it had never been asked to move. Found by a Codex audit, not by playing; reproduced before
anything was changed.

**The gate is MOTION, not grounding, and that is measured rather than argued.** `resolve_ceiling` runs
only while moving upward, `move_and_resolve` clears `on_floor` before any substep, and `_handle_jump`
zeroes coyote on launch — so every corner correction that has ever fired ran at `on_floor=false,
coyote=0`. Applying the grounded gate the two climbs use took `test_body_acceptance`'s
`corner_correction_success_rate` **from 100% to 0**. A ceiling is only ever contacted airborne; a
grounded gate there is not a gate, it is a deletion. What the three instances share is the CONSENT half:
`_try_climb` has required `vel_x != 0` all along, and this path had no motion condition at all.

**Did not relocate, proven at set level.** Full 1000x1500 sweeps either side of the gate, diffed line by
line: **one violation removed, zero added** (`type=bounds edge=left seed=0 tick=1487` — the invented
nudge pushing the body out through the world's left edge). All **46** `grounded_no_floor` lines are
byte-identical in seed, tick, position and `floor_source`; the D0206 residual is untouched. All four
director sessions still replay **0 bad ticks, 0 airborne climbs, 0 unconsented nudges**.

**Two new instruments, and one honest null.** `Invariants.check_translation_consent` is a runtime
post-condition that names no path — a tick with no input and no incoming velocity cannot move the body
horizontally, so any displacement on one came from a correction, and only the two RECOVERY paths
(depenetration, bounds clamp) are exempt. `tests/test_corner_consent.gd` witnesses it deterministically
and mutation-tests both directions. But **the per-commit fuzzer is blind to this class**: it reports 0
with the defect present as well as absent, because `HostileChamber` fires `corner_corrected_this_tick`
**0 times in 50,000 ticks** — D0055's hand-placed corner tile has been unreachable since the held-jump
bug it was fitted against was fixed. The real witness is `fixture_shaft_replay_probe.gd` (a generated
shaft is walls, and every wall contact zeroes `vel_x`): **corner_unconsented 2 -> 0, corner_ok 18 -> 11**.
That fixture now asserts it per commit. Remedy for the fuzzer is parked, not applied (P004).

**Golden re-captured and CI green on the fix.** Run 33331589523 on commit c953117 confirms
`corner_ok=11, corner_unconsented=0` on Linux, matching local exactly; the golden array moved because the
scenario really did contain the defect, and all 200 checkpoints are now the CI-captured values (f9216b2).

## DONE THIS RUN — L2 exists (D0214, ADR 0007)

**`interface/` and `sim/commands/` stop being skeletons.** `Interface.observe(Envelope) -> Observation`
and `apply(Command) -> Result`, with `Command.move(InputFrame)` and `Command.mine(cell)`. This was the
literal blocker on the presentation batch: `tools/layer_lint/layer_lint.py` gives `view` access to
`interface` and `core` and nothing else, so every lifted renderer file is a red gate until the door exists.

**The one decision the rest follows from: `observe()` COPIES.** An `Observation` holds a flat byte array
over its window plus a legend, and no reference to `TileGrid`, `Body` or `Mining`. Handing back the grid
would be cheaper and would silently delete the envelope — a consumer holding it reads any cell it likes.
`tests/test_interface.gd` tests that by attempting the reach-around: observe, excavate, assert the
observation still reports the old state. **One envelope dimension, three deliberately absent** — there is
no fog, planner, motor model or priors table, and a `vision` field that never filters reads as a filter
that has been checked. Same reasoning gives `Command` two members, one per verb that exists.

**Safe to land in one unattended pass because nothing persists.** No save schema, no golden, no fixture
depends on an `Observation`'s shape. Changing its fields later costs a recompile of its consumers and
nothing else. **No consumer was migrated** — `reveal_scene`/`play_scene` still drive `sim/` directly.

## DONE THIS RUN — the build makes a sound (D0215)

**`view/audio/score.gd`, lifted from legacy, wired into `reveal_scene`.** Three synthesised beds mixed
and pitched by depth. **The whole port is one line**: legacy read the music slider off a `Settings`
global, and `Settings` is `shell/`, so the level is injected as `music_db`. That substitution is the shape
every remaining lift needs.

**Chosen by measuring, not by slice order.** The map puts it in Slice 4 behind a renderer; its entire
interface with the game turned out to be one float (`set_depth(t, delta)`), so it needed neither.

## THE PRESENTATION BATCH IS MOSTLY BLOCKED — read `docs/NEEDS_DIRECTOR.md` P005

Classifying all 21 code files in the 63-file LIFT set by the legacy types they use **in code with
comments stripped**: ~1,540 lines blocked on the `WorldRenderer` coordinator, ~2,700 on legacy's
`FactorySim`, ~2,050 on `MachineDef`/`RecipeDef` entities this build does not have, and **~945 liftable
today** (`art`, `particles`, `light_layer`, `settings`, `seams`, `score` — the last now done). The run's
own "no coordinator rebuilds" non-negotiable is what blocks most of its own queue. P005 carries the three
options and the numbers; option 1 (finish the unblocked ~900) needs no ruling and is the obvious next step.

## SLICE 1.5, the bite — delivered, still awaiting the director's play verdict

Full account in `docs/DECISIONS_LEDGER.md` D0199-D0205. **Result:** `Mining.bite_radius`, a Euclidean
disc, default 2 (0.81 m^2, the largest disc under legacy's metre); `--bite=0` is bit-for-bit Slice 1 and
is the control. The same 24-cell shaft takes **991 ticks at bite=0, 242 at bite=2**. The brief's premise
was false in both halves and the real defect was its opposite (D0200): mining was already at 4px and
collision already ran on it; what was wrong is that one blow removed a sixteenth of a metre while being
charged a full metre's hardness-seconds, **0.06x legacy per unit volume**, unmeasured because the check
was in seconds-per-CELL and the two codebases' cells are different sizes.

**Two rules that outlived it.** D0204: a build handed over for a feel judgment gets played from a CLEAN
CHECKOUT — the director's second session read 8 bad ticks clean and 268 in a dirty tree, 33x. D0201: four
suites written across Slices 0 and 1 were passing locally and running in no CI job at all, including two
mutation-tested bounds controls; gate 31 now reconciles the sets and prints members.

**WAITING ON THE DIRECTOR:** play it (`godot --path . tests/body/reveal_scene.tscn -- --play`, sweeping
`--bite=0/1/2/3`) and rule. **Note the geometry question underneath it:** the world is 48 cells / 12 m
wide, the body is 8.3% of that and 33% of the screen's height at zoom 6. Shrinking the body and widening
the world are the same fix from two ends, and no mining change reaches either.

## STANDING — carried forward, none of it closed by Slice 1.5

**D0193 — the bounds invariant has no magnitude. The director's call, gate 24's subject.** It fired at
0.3125px (D0192) and 3.4px (D0199); D0055 built it for 15.85px, and this world is 192px wide, so pressing
into a wall is ordinary play. The discriminator is written up: overshoot against `|vel|/TICK_HZ` separates
a wall-press from an escape without a threshold picked to silence a log.

**The fuzzer still never sets `mine_held`, and D0202 raises the price of that.** Gate 26 is green about
cursor-aim mining only because it never exercises it. A bite radius is a shape generator and it found a
real resolver defect in one recorded session; wiring the fuzzer to the verb is now a much better bet than
it looked. Still not done, still its own unit of work.

**Line of sight is not ported.** Legacy gates mining on a float DDA; without it a player can mine through
one tile of rock. Real behaviour change, stated rather than dropped (D0195).

**Standing instructions — milestone recordings and the screenshot set.** Every slice, and any intermediary
work that changes what a player sees or does, commits the `--play`/agent `.log`, a screenshot, and the
commit SHA it was produced against — **generated from the commit, never hand-typed**, never overwritten,
agent-mode always LABELLED. Canonical moments at a FIXED 1920x1080 from a FIXED camera plus a before/after
PAIR at each visual milestone. `docs/MILESTONES.md` carries a row per milestone and the full rationale;
`tools/capture_moments.sh <slice-label>` is the driver, with `BITE=n` and `TICKS=a,b,c` pinning the two
things a mining change moves.

**Slice 0 and Slice 1, both closed.** Evidence: `docs/DECISIONS_LEDGER.md` D0187-D0198 and
`docs/MILESTONES.md`. The Q1 answer that gates the expensive slices still stands — **the palette reads at
16px; the FLECK does not**, so any material whose identity lives in its flecks needs its base retuned for
Slices 3-4, and `terrain_painter.gd` is not portable as written. **`claims/C004` is still untouched on
purpose:** two real human sessions now exist, but deciding whether one qualifies is the director's
judgment, not a session's.

## CLOSED — D0139, reverted on the director's ruling; the diagnosis survived, the remedy did not

Shelved on branch **`shelf/d0139-full-footprint`** (`f8186fb`, pushed), reverted from the tree. Recover
with `git checkout shelf/d0139-full-footprint -- sim/body/vertical_resolve.gd tests/test_vertical_resolve.gd`.
Four measurements against it, three from its own investigation: its acceptance signal failed
(`grounded_no_floor` stayed at 59 while attribution flipped, the flaw changing hands); it regressed
`test_body_acceptance`'s HARD gate; it broke `check_size_limits`; and it made real play 33x worse. **Its
diagnosis was right and is closed by D0206 instead** — the criterion really was the bug, but the fix is
one shared full-footprint criterion, not making `resolve_floor` refuse landings while the backstop keeps
the same flaw.

## OPEN, NOT STARTED — the persistent-world GDD reversal

A director brief reversing the 2026-08-25 run-based-roguelite pivot back to a persistent single shaft +
rig-as-consumer (further than the already-closed 2026-08-27 reversal `docs/GDD.md` §9 already records) —
its full text exists only in prior conversation history, not in any tracked doc. A fresh session needs the
brief re-supplied (asked of the director, not reconstructed from a summary) before touching `docs/GDD.md`.

## Standing, unchanged, all reserved for the director

- **`data/economy/`, D1-D6** — the demand-chain content itself; `tools/economy_check/` (parked, D0153)
  waits for it.
- **`history/`'s pre-pivot image cull** — waits on the director, unchanged.
- **`claims/C004`** — no longer blocked on getting a session at all (4 real ones exist now, see above);
  blocked on one that actually produces a qualifying reveal with real dig events on both sides.
- **A Codex finding on THE CONTROL PLANE** (parked, D0155, but the finding stands regardless of whether
  the slice is in the tree): CONSTRAINED restricts distance, not discovery — Anvil FINDING `ed491e83`
  existed only inside the now-parked `.anvil/log/`; recoverable via `git show 4ec12bb:.anvil/log/2026-08-29T095108.038191Z-ed491e83.json`.
