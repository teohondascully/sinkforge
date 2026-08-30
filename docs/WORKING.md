# Working state

Not a log. Current stage, what's actually happening, and what would be lost if this session ended
right now. Updated as work happens. Resets when a stage closes — durable content moves to an ADR,
a MODULE.md, or a claim first.

**Last updated: 2026-08-30.** Bump this date whenever this file changes — a CI gate fails if it's
older than `HEAD`'s own commit date, so a session that lands commits without touching this file is
caught mechanically rather than relying on someone noticing later.

**Reset this round:** the Slice 1 section closed and its still-live items moved into STANDING below rather
than being dropped with it; Slice 0's own section compressed to the two findings that outlive it. Nothing
deleted from the record — the detail is in `docs/DECISIONS_LEDGER.md` D0187-D0198 — only relocated, per
this file's own 150-line cap.

## IN FLIGHT — SLICE 1.5, the bite. Probe delivered, STOPPED for the director's play session

**The brief's premise was false and is worth reading before the result.** It asked for sub-cell mining at
SUBDIV-4 with collision kept on a coarse logic grid behind a threshold. This tree has neither thing to
change: `Mining.CELL_PX` is already `Heightfield.TERRAIN_CELL_PX` (4), and `TileGrid` stores only 4px
cells with `Heightfield` reading them directly — its own header says the 16px grid "is a VIEW over this,
not a second array". Building the probe as written would have been a no-op the director then played, felt
nothing from, and reasonably read as "granularity doesn't help — shrink the body" (D0200).

**What the director's own session says** (`tools/measure_play_session.gd` on
`reveal_play_2026-08-30T05-58-03.log`): 29.6 s, MINE held 876 ticks, **504 of them aimed at AIR**, 29 cells
broken, first break **11.4 s in**, **0.50 m** descended, **0.7 of one body-volume** removed. The bite was
never huge — it was so small that half a minute of holding dug a hole smaller than the digger, and a blow
ends on the cell it just cleared, so the cursor is over air the moment it lands. The perception was right;
the mechanism attributed to it was inverted.

**Delivered (D0200):** `Mining.bite_radius`, a Euclidean disc (areas 1/5/13/29 for r=0..3), default **2**.
DERIVED, and it **corrects D0195**: legacy's 32px cell is one square METRE and one charge removes it; this
world's metre is 16 terrain cells and Slice 1 charged a full metre of hardness-seconds to remove one of
them, so it mined at **0.06x legacy per unit volume**. D0195 checked seconds-per-CELL, one paragraph after
establishing that the metre is the portable unit. r=2 is 0.81 m², the largest disc under legacy's metre.
**`--bite=0` is bit-for-bit Slice 1 and is the control**; `--bite=N` sweeps it. Collision untouched
(confirmed by diff) and it needed no threshold rule, because there is only one grid. Determinism green: the
disc is a nested integer `range`, and `bite=` joins `site=`/`seed=` in the recording header so a log
without it reconstructs at radius 0, never at the current default. Milestone artifacts in
`docs/MILESTONES.md`: the same 24-cell shaft takes **991 ticks at bite=0, 242 at bite=2**.

**HARD STOP HIT — D0202/D0203, reported not fixed, and the most useful thing this probe produced.** The
failing tick **excavates nothing**; it reproduces on a clean checkout without D0139's parked change, and
then from a **hand-authored 15-row map with no `Mining` in the script at all**. **Not rare:** the
director's second `--play` session hits it **4 times in 710 ticks on a clean tree, at the shipped bite
radius**. Reproduce: `godot --headless --path . --script res://tests/fixture_step_up_into_wall_probe.gd`.

**The mechanism, corrected (D0203).** D0202 said "the step-up's HEIGHT is checked, the destination's FIT is
not." That is false — `_try_step` calls `_box_blocked` on the body's box translated up by the lift, with
the half-open bounds right. What actually happens: the step succeeds and is **undone inside its own tick**.
`Body.tick` runs `_integrate_horizontal` → `pos_x +=` → `HorizontalResolve.resolve` (the step) →
`_integrate_vertical` → `VerticalResolve`; the vertical pass moves the body again by one tick of gravity
against the `vel_y` the step had just zeroed, and leaves it inside rock without re-grounding it. **The tell
was already on screen:** the tick ends with `floor_source_this_tick = "try_step"` and `on_floor = false`,
which cannot both be true. That pair is a cheap general invariant nobody asserts yet.

**D0204 — do not read the director's second session as a reading of `main`.** Replayed against a clean
checkout it is **8 bad ticks in 4 episodes (1%)**; in the working tree, which carries D0139's parked
`vertical_resolve.gd`, it is **268 in 12 episodes (38%)**. 33x. The clean-tree numbers are the quotable
ones. A build handed over for a feel judgment gets played from a clean checkout, or the dirty-tree
difference gets measured before it is described.

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

**GATES.** All green except two, both D0139's parked work, verified unchanged: `check_size_limits`
(`resolve_floor` at 60 lines) and `check_untracked_files` (`test_vertical_resolve.gd`). Gate 7 (LOC
velocity) still red on its trailing window. Every suite passes on a clean clone carrying this work and not
D0139's — checked, not assumed.


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

## OPEN, MID-INVESTIGATION — D0139's Option-2 `resolve_floor` fix hit a SECOND hard stop, uncommitted,
awaiting the director's ruling

**Do not touch `sim/body/vertical_resolve.gd` or `tests/test_vertical_resolve.gd` without reading the full
account first** — `docs/archive/working/WORKING-2026-08-29.md`'s own "OPEN, MID-INVESTIGATION" section has
the complete detail (tick traces, exact grid dumps). Working tree is dirty on purpose: `vertical_resolve.gd`
carries an uncommitted `_full_footprint_solid` attempt; `tests/test_vertical_resolve.gd`(`.uid`) are new,
untracked, 6 passing unit tests, one mutation-tested.

Two real findings, reported, neither acted on: (1) the full 1000×1500 sweep's `grounded_no_floor` did NOT
drop toward ~4 — it stayed at 59, mechanism flipped entirely to `grid_floor_backstop`, which has the
identical criterion flaw (the director's own anticipated "second bug"). (2) A real regression against
`test_body_acceptance.gd`'s own HARD gate — the golden traverse stalls at tick 133, traced to an authored
1-row rubble notch the new exact-same-row check can't distinguish from a real gap. Also breaks
`check_size_limits` (`resolve_floor` 49→59 lines against the 50-line limit). Not shippable as written even
if both findings resolve. Waiting on the director; nothing here resolves unilaterally.

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
