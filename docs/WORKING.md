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

**Open, and expected:** the shaft-replay golden array is stale by construction — the resolver changed, so
200 checkpoint hashes changed with it (first mismatch at checkpoint 30). It must be re-captured from CI's
pinned **Linux** build, not locally: D0167/D0168 measured `ValueNoise` differing across platforms.

## SLICE 1.5, the bite — delivered, still awaiting the director's play verdict

**The brief's premise was false in both halves and the real defect was its opposite** (D0200, full account
in the ledger): mining was already at the 4px resolution and collision already runs on it. What was wrong
is that one blow removed 1/16th of a metre while being charged a full metre's worth of legacy
hardness-seconds — **0.06x legacy per unit volume**, unmeasured because the check was in seconds-per-CELL
and the two codebases' cells are different sizes.

**Delivered:** `Mining.bite_radius`, a Euclidean disc (areas 1/5/13/29 for r=0..3), default **2** (0.81 m²,
the largest disc under legacy's metre). **`--bite=0` is bit-for-bit Slice 1 and is the control.**
Determinism green; `bite=` joins `site=`/`seed=` in the recording header so an old log reconstructs at
radius 0, never at the current default. The same 24-cell shaft takes **991 ticks at bite=0, 242 at bite=2**
(`docs/MILESTONES.md`, `docs/TASTE_QUEUE.md` T004).

**The probe's most useful output was a collision defect, now fixed** — D0202 escalated it, D0203 corrected
its mechanism (the step succeeds and is undone inside its own tick), D0205 fixed that, and D0206 fixed the
criterion flaw underneath it. `fixture_step_up_into_wall_probe` no longer reproduces and can be retired
whenever the director wants; it is left in place as a one-command check.

**D0204 stands as a rule, not an open item:** a build handed over for a feel judgment gets played from a
clean checkout. The director's second session read 8 bad ticks on a clean tree and 268 in the D0139-dirty
one — 33x — and that dirty tree no longer exists (see below).

**Also fixed on the way in:** D0199, the vertical half of D0192. The entry shaft opened row 0, so the body
spawned with its head ON y=0 and the first jump left the world — one bounds violation in the director's own
session. Row 0 stays solid now; 64 seeds × 2 sites hold JUMP for 90 ticks with 0 violations, head stopped
by ROCK at 4.15px, and the pre-fix carve is kept as a live control that still reproduces the director's own
error line byte for byte.

**D0201 — every suite written in Slices 0 and 1 ran nowhere.** `test_material_palette`, `test_mining`,
`test_reveal_scene_dig_edge`, `test_reveal_spawn_bounds`: passing locally, in no CI job, including two
deliberately mutation-tested bounds controls. Gate 31 (`check_suite_coverage.py`) now reconciles the
tracked population against the workflow and reports MEMBERS — its first run printed 26 on each side while
the sets differed.

**WAITING ON THE DIRECTOR:** play it (`godot --path . tests/body/reveal_scene.tscn -- --play`, and sweep
`--bite=0/1/2/3`) and rule. If the bite alone makes it read → Slice 2. If it reads better but the body is
still too massive → Option 1 becomes a deliberate, collision-touching decision. **Note the third
possibility the geometry raises:** the world is 48 cells / 12 m wide and the body is 8.3% of that and 33%
of the screen's HEIGHT at zoom 6. Shrinking the body and widening the world are the same fix from two ends,
and no mining change reaches either.

**GATES.** All 29 suites pass on CI's Linux build (run `33303000919`), `test_shaft_replay_determinism`
included with its re-captured golden. `check_size_limits` and `check_untracked_files` are green for the
first time in weeks — both were red only on D0139's parked work.

**Gate 7 (LOC velocity) is the one red, and D0207 is why that now matters more than a red gate usually
does.** It runs early in the `structural gates` job, a failed step aborts the job, so **ten BLOCKING
checks after it were reported `skipped` — not failed, not passed** — on the final run of this session:

> gate 13 (schema validation) · gates 15-16 (claim references) · gate 22 (generated data freshness) ·
> gate 23 (WORKING.md freshness) · gate 27 (no untracked files) · gate 30 (CORRECTIONS freshness) ·
> `project.godot` load-bearing flags · gate mutation tests (BLOCKING) · duplication (BLOCKING)

**None of those has been enforced by CI for as long as gate 7 has been red.** They pass locally right now —
checked individually this session, not assumed — but "CI is green except gate 7" was never what was
happening. This is a real hole, it is bigger than the duplication that revealed it, and fixing it means
changing the CI topology (one job per gate, or `continue-on-error` plus an aggregation step), which is a
director-level call, not something to slip into a body fix. **Gate 7 itself only falls when GAME LOC grows
— its own message: "the next unit of work is game, not another check."**

`check_claim_references` is VOID (zero scenarios exist to carry a reference), unchanged and by construction.


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

Shelved on branch **`shelf/d0139-full-footprint`** (`f8186fb`, pushed) and reverted from the working tree.
Recover with `git checkout shelf/d0139-full-footprint -- sim/body/vertical_resolve.gd tests/test_vertical_resolve.gd`.
Four measurements against it, three from its own investigation: its acceptance signal failed
(`grounded_no_floor` stayed at 59, attribution flipping `resolve_floor` 55→0 / `grid_floor_backstop` 4→59
— the flaw changing hands, the director's own anticipated "second bug"); it regressed
`test_body_acceptance`'s HARD gate (`depenetration_events` 0→1, `stall_seconds` 0→0.017s); it broke
`check_size_limits`; and it made real play 33x worse.

**Its diagnosis was right and is now closed by D0206 instead** — the criterion really was the bug, but the
fix is to make both paths share ONE full-footprint criterion, not to make `resolve_floor` refuse landings
and leave the backstop holding the same flaw.

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
