# Working state

Not a log. Current stage, what's actually happening, and what would be lost if this session ended
right now. Updated as work happens. Resets when a stage closes — durable content moves to an ADR,
a MODULE.md, or a claim first.

**Last updated: 2026-08-29.** Bump this date whenever this file changes — a CI gate fails if it's
older than `HEAD`'s own commit date, so a session that lands commits without touching this file is
caught mechanically rather than relying on someone noticing later.

**Reset this round:** the fix queue's own CLOSED section moved to
`docs/archive/working/WORKING-2026-08-29.md` alongside queues #2 and #3. Nothing deleted, only relocated,
per this file's own 150-line cap.

## IN FLIGHT — SLICE 1, the director's brief, written down before item 1 (CONTEXT.md's own rule)

Slice 0 is ACCEPTED: Q1 passed, the palette reads as material at 16px, the 16px world stays. Order is
playable-first, pretty-later — the legacy *look* (light pools, shaders, molded rock) is Slice 3 and must
NOT be pulled forward.

1. ~~**STEP ONE, gating: diagnose the bounds error**~~ **DONE — scene setup, fixed (D0192).** It is the
   world's **LEFT edge**, not the floor: `pos_x=503808` is x=7.6875px, left edge −0.3125px (one accel
   step). The trace is `_enforce_grid_bounds ← tick` with `on_floor` true throughout — `resolve_floor`
   and `grid_floor_backstop` are **not in it**, so the escalation fork did not fire. Cause:
   `find_spawn` returned spawn column **0** (pocket at column 6 minus the offset 6), putting the body's
   left edge exactly on x=0, and `carve_entry_shaft` then removed the column-0 rock that would have
   stopped it. Not a tail case — **53.2% of dense seeds / 14.0% of sparse** over 400. Deterministic:
   two independent replays are byte-identical. Fixed by clamping the spawn to `MIN_SPAWN_COL = 1`; the
   director's own log now replays **0 violations**, furthest-left 4.0px (stopped by terrain, not the
   clamp). **Escalated separately (D0193): the invariant itself cannot tell a wall-press from an
   escape** — it fired at −0.3125px, D0055 built it for −15.85px, and this world is 192px wide, so wall
   contact is ordinary play. Not fixed unilaterally; the discriminator is written up for the director.
2. ~~Cursor-aim + reach + hold-to-charge~~ **DONE** (D0195) — `sim/mining/`, integer-only. Reach is 3.2
   METRES (legacy's 3.2 of a 32px cell; both are one metre), Euclidean, compared squared. Collision
   resolver untouched, confirmed by diff.
3. ~~Downward by construction~~ **DONE** — D0110's deferral superseded and documented (D0195).
4. ~~Lift `controls.gd`~~ **DONE** (D0194) — `view/controls.gd`, posable pointer + deafness switch +
   4 actions. The other 22 (craft/research/bazaar/tech) are the dead economy and were NOT lifted.
5. ~~`Command.Mine(target_cell)` seam~~ **DONE** — `Mining.mine()` is the payload shape, marked in code.
   `interface/` not built.
6. ~~Extract the charge loop~~ **DONE** — re-derived, not lifted; legacy's is float + `delta` + a
   `time_scale`-sensitive accumulator.
7. ~~Hollow/breach tell~~ **DONE** (D0196) — `sim/mining/hollow_tell.gd`, reads LOGIC TILES (at 4px cells
   the probe box would be 1056 samples, not 20). **No audio** — Slice 1 has no sound layer; the tell is
   surfaced visually in `tests/body/mining_overlay.gd`.

**Acceptance:** a human mines downward in `--play` and descends into what they mined, no bounds error,
correct dig semantics, proven with a recorded session. Do NOT populate `claims/C004` — the director rules
on which sessions qualify.

**ACCEPTANCE STATUS — half met, and the missing half is not mine to run.** The verb is proven
mechanically: `--mine-down` agent mode sinks a shaft and the body DESCENDS 24 cells (6.0 m), 85 cells
broken, **0 bounds violations**, verified by replaying the recording rather than by trusting the run's own
exit condition. That is an AGENT trace and is labelled as one. **A human `--play` session cannot be
produced from this session — there is no keyboard or mouse here.** The director's own run is the missing
evidence; the command is in the report. Two things to watch for in it that the agent cannot test: whether
the reach radius *feels* right at 3.2 m, and whether the crack bank reads as progress at a 4px cell.

**Open risk, named because no gate covers it (D0195):** single-cell mining can produce the straddle-able
geometry D0113/D0125 exist to prevent and D0122/D0123 found as a fuzzer `discontinuity`. The fuzzer drives
`InputFrame` and never sets `mine_held`, so **gate 26 is green about this verb only because it never
exercises it.** Wiring the fuzzer to cursor-aim is its own unit of work and was not done here.

**HARD STOPS — report and hold:** the bounds error tracing into `resolve_floor`/`grid_floor_backstop`;
any change to the collision resolver; the determinism gate going red; `interface/` ballooning; the
economy (no `craft_cost`, no research, no demands, do not touch `data/economy/`); pulling Slice 3 visual
work forward.

**Standing, from this slice onward — milestone recordings.** Every slice, and any intermediary work that
changes what a player sees or does, commits: (1) the `--play` or agent trace `.log` in
`tests/body/recordings/`, named by slice + timestamp; (2) a screenshot of the resulting state; (3) the
commit SHA it was produced against, recorded IN the artifact or a sibling note — generated from the
commit, never hand-typed. Re-recordings name the new SHA and never overwrite: the sequence IS the
migration's visual history. Agent-mode captures are fine but must be LABELLED agent-mode. Keep
`docs/MILESTONES.md` — one line per milestone: slice, SHA, recording path, screenshot path, one sentence.

**Standing — the screenshot set.** Beyond the single state shot: canonical moments at a FIXED resolution
(1920x1080) from a FIXED camera so milestone-to-milestone shots are directly comparable, plus a
before/after PAIR at each visual milestone. Re-derive legacy's `tools/capture_moments.gd` APPROACH
(scripted fixed-frame moment capture) once, minus its dead economy references; every milestone then runs
it. Shots are keyed to their SHA, named by slice + moment + SHA.

## GATED — LEGACY REVIVAL, Slice 0 done, STOPPED for the director's look before Slice 1

The Phase 1 map is approved and committed. Slice 0 landed in 4 commits (`b8e9b59..`); evidence
`docs/DECISIONS_LEDGER.md` D0187-D0191. **Slice 1 is NOT started and must not be — Slice 0 is the gate.**

- **Map committed** (D0187) as `docs/LEGACY_MIGRATION_MAP_2026-08-29.md`, pinned at legacy `666e551` /
  current `0be151f`. It carries 265 legacy-side verdicts, not 432: the current-side 167 were behind a
  second tab and are not in the text handed over. Said so in the file rather than implying coverage.
- **Defect B fixed** (D0188) — `dig_pressed` is edge-triggered again. 9 assertions, mutation-tested; the
  mutant reproduces the director's own recorded number (a 30-tick hold reading as 30 events, not 1).
  Corrects the map's wording: that session was UNCOMMITTED, a 7th recording. It is committed now.
- **Slice 0 shipped** (D0189) — 8 band records in `data/bands/`, appearance on all 7 materials, painted
  in the reveal scene. Screenshots: `$CLAUDE_JOB_DIR/tmp/shots/slice0_reveal_test_{dense,sparse}.png`.
- **Screenshot tool was lying** (D0190) — it saved BLACK PNGs and printed "saved". Fixed, plus a
  distinct-colour check so a recurrence is loud. Every prior low-tick capture from it is suspect.
- **The map's coverage gap closed** (D0191) — five full reads of the files it admits it never read.
  Eleven corrections, one of which points a whole future slice at the wrong file (the lighting is in
  `world_renderer.gd`, not `main.gd`; the map inherited a stale docstring).

**THE Q1 ANSWER, which is what gates the expensive slices: the palette reads at 16px; the FLECK does not.**
Legacy distinguishes every ore by bright crystals scattered inside a dull host. Its nugget is 6.4px; this
world's whole terrain cell is 4px, so a cell is either host or fleck and ~81% are bare host. Measured, not
predicted — glimmer authored in the strict legacy idiom came out **0.028** from deepstone against a
**0.087** rock-vs-rock noise floor, i.e. less distinct than two rocks are from each other, and broke a
colour-distance claim the scene already had. Retuned per the Q1 ruling (art adapts, world does not):
**0.286**. Six of seven records lift verbatim. **For Slices 3-4: any material whose identity lives in its
flecks needs its base retuned.** Separately, `terrain_painter.gd` is not portable as written — its
`h % int(CELL - 12.0)` collapses to a 4px band at CELL=16 and is a division by zero at CELL=12.

**Waiting on the director:** approve Slice 0 → Slice 1 (cursor-aim mining, supersedes D0110). Two taste
calls in `docs/TASTE_QUEUE.md` (T001 copper reads silver, T002 band tint). And a Slice 1 candidate found
in passing: legacy's `STRIDE_GAIN = 0.55` takes top speed 150 → 232 px/s. The feel constants were ported;
the stride mechanic was not, which is a concrete answer to "it feels barebones."

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
