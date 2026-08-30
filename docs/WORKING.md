# Working state

Not a log. Current stage, what's actually happening, and what would be lost if this session ended
right now. Updated as work happens. Resets when a stage closes — durable content moves to an ADR,
a MODULE.md, or a claim first.

**Last updated: 2026-08-30.** Bump this date whenever this file changes — a CI gate fails if it's
older than `HEAD`'s own commit date, so a session that lands commits without touching this file is
caught mechanically rather than relying on someone noticing later.

**Reset this round:** the Slice 1.5 section compressed to its result (the detail is `docs/DECISIONS_LEDGER.md`
D0199-D0205), and the D0139 "OPEN, MID-INVESTIGATION" section is CLOSED — it was the last thing keeping
the working tree dirty. Nothing deleted from the record, only relocated, per this file's own 150-line cap.

## DONE THIS RUN — the criterion flaw, fixed on both grounding paths (D0206)

**Authorized overnight collision work, the exception to the standing hard stop.** Both defects the
director's own sessions produced are gone: bad ticks (body inside rock or outside the world) on clean-tree
replays go **6 → 0** (710-tick session) and **171 → 0** (767-tick session), and
`fixture_step_up_into_wall_probe` reports NOT REPRODUCED. `test_body_acceptance`'s golden traverse is
**225, byte-identical to golden**, not merely inside ±12.

**The brief's direction was inverted, and classifying beat theorising.** It described both paths sinking
the body into rock. `tools/scratch/classify_bad_ticks.gd` over all 184 bad ticks found **153 of them are
the body thrown ABOVE the world** — `grid_floor_backstop` placing the feet on the world CEILING's top
face (y=0) — caused by `resolve_floor` first lifting the head 1px into row 0. Sinking was 13 ticks.

**The fix is one shared criterion, which is what stops it relocating.** `VerticalResolve.footprint_surface_y`
— the highest solid face across EVERY column the box occupies — is now the only height either path grounds
at, and `grid_floor_backstop` must pass `_landing_is_clear` (destination in-bounds AND unblocked) before
committing. The interpolated sub-pixel ground plane is gone from `sim/`, by proof not preference: a blend
between two columns of different heights is BELOW the taller one's face, so sub-pixel following and a
zero-overlap flat-bottomed box are mutually exclusive, and D0032 already chose the box.

**`grounded_no_floor` stayed at exactly 59 — and it is NOT D0139's relocation.** The count cannot tell
the two apart, so the SET was diffed: all **805,456** sweep violations are byte-identical before and after
in seed, tick and POSITION; **4 lines** differ, in attribution only, `grid_floor_backstop` → `resolve_floor`
(the backstop's share went 4 → **0**; D0139's went 4 → **59**). It cannot go to zero alongside the bad-tick
count: full support means resting at the DEEPEST column, zero overlap means the HIGHEST, and a flat-bottomed
box cannot do both on uneven ground. **A design fork for the director, not a bug** — D0061 already weighed
and rejected the alternative on feel.

**A test was pinning the defect.** `test_cave_geometry`'s lower-floor case dropped a 4-column-wide body into
a 4-column gap offset by one column, so its box included a shelf column; it reached the lower floor by
clipping THROUGH the shelf's 6-row slab (`worst_overlap=1`, measured against the OLD resolver via
`tools/scratch/cave_gap_ab.gd` either side of a `git stash`). Corrected, with the catching case added
separately — and the correction is backed by an A/B of the old code, never by the new code's say-so.

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

**GATES.** `check_size_limits` and `check_untracked_files` are GREEN for the first time in weeks — both
were red only on D0139's parked work. **Gate 7 (LOC velocity) is the one red**, and this run made it
worse, honestly: instrument +1185 against game +169 over the trailing 10 commits. Its own message is the
signal — "the next unit of work is game, not another check." `check_claim_references` is VOID (zero
scenarios exist to carry a reference), unchanged and by construction.


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
