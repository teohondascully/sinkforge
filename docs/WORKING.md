# Working state

Not a log. Current stage, what's actually happening, and what would be lost if this session ended
right now. Updated as work happens. Resets when a stage closes — durable content moves to an ADR,
a MODULE.md, or a claim first.

**Last updated: 2026-08-30.** Bump this date whenever this file changes — a CI gate fails if it's
older than `HEAD`'s own commit date, so a session that lands commits without touching this file is
caught mechanically rather than relying on someone noticing later.

**Reset this round:** D0206-D0212 compressed to their results in the ledger; this file now carries only
what a future session needs that the ledger does not already say better. New this round:
**`docs/NEEDS_DIRECTOR.md`**, the parked queue — read it FIRST if you are the director picking this up.

## DONE THIS RUN — D0213 to D0222, grouped below into six

Full accounts in `docs/DECISIONS_LEDGER.md`. What a future session needs to know:

**D0213 — the third and last instant translation, closed.** `resolve_ceiling`'s corner nudge took its
direction from `body.facing` whenever `vel_x` was zero, so a body jumping STRAIGHT UP under an overhang
was moved **+6.00px sideways in one tick**, 360 px/s against a 150 px/s run speed. **The gate is MOTION,
not grounding, and that is measured**: `resolve_ceiling` runs only while moving upward, so every corner
correction that has ever fired ran at `on_floor=false, coyote=0` — applying the two climbs'
`recently_grounded` gate takes `corner_correction_success_rate` from **100% to 0**. A ceiling is only
contacted airborne; a grounded gate there is a deletion, not a gate. What the three instances share is
CONSENT: `_try_climb` has required `vel_x != 0` all along.

Proven not to relocate at set level: full 1000x1500 sweeps either side, **one violation removed, zero
added**, all 46 `grounded_no_floor` lines byte-identical. All four director sessions still replay 0 bad
ticks. New instruments: `Invariants.check_translation_consent` (names no path, so a fourth instance trips
it without an edit) and `tests/test_corner_consent.gd`.

**The fuzzer is blind to that class, and the reason generalises.** It reports 0 with the defect present
AND absent, because `HostileChamber` fires `corner_corrected_this_tick` **0 times in 50,000 ticks** —
D0055's hand-placed corner has been unreachable since the bug it was fitted against was fixed. The real
witness is the shaft replay (a shaft is walls, and every wall contact zeroes `vel_x`): **corner_unconsented
2 -> 0**, now asserted per commit. Remedy parked as P004.

**D0214 — L2 exists (ADR 0007).** `Interface.observe(Envelope) -> Observation` / `apply(Command) -> Result`.
The blocker on the whole presentation batch: layer lint gives `view` only `interface` and `core`. **The
one decision everything follows from is that `observe()` COPIES** — handing back the grid would be cheaper
and would silently delete the envelope, so the suite attempts the reach-around and asserts it fails. One
envelope dimension, three deliberately ABSENT. Nothing persists, so its shape is cheap to change.

**D0215/D0216 — the build makes a sound, and mining throws chips.** `view/audio/score.gd` (three beds
mixed by depth; the whole port is one line, a `Settings` global becoming an injected `music_db`) and
`view/fx/particles.gd` (chips on a break, a draught on a breach — the hollow tell's visual half). Both
chosen by measuring rather than by slice order.

**D0217 — a regex read a workflow that could not parse, and said PASS.** Two step names with unquoted
colons made `harness.yml` invalid YAML; **GitHub ran zero jobs** and reported an ordinary red, while gate
31 found every suite it was looking for. It parses first now, with a permanent 5/5 mutation test.

**D0221 — three duplication clusters, three different answers.** The BLOCKING gate surfaced at all only
because gate 7 went GREEN (game LOC 2,362 -> 3,075 against instrument +1,186, 1.66x under a 2x limit), so
the ten checks D0207 found reporting `skipped` behind it finally ran. `Command.move`/`mine` was REAL duplication and is deduplicated (two constructors
differing only in which payload field they set are one constructor with an argument).
`test_score::_built` colliding with `test_replay_determinism::_sorted_ids` was a MISSING TEST — `_built`
gained the `music_db` parameter it should have had, which is the one line that differs from legacy and
had no coverage at all. And `interface::_init` vs `tile_grid::_init` **collide by arithmetic, not by
copying**: a plain constructor of arity N normalises to `ID = ID` repeated N times, so every one collides
with every other. That got a named exclusion, mutation-tested in three failure directions plus a control.

**D0218/D0219/D0220 — three smaller ones with the same shape.** "No automated checks on documents" was
stated in three normative docs while three ran in CI (repaired by stating the LINE: a gate may check that
two artifacts agree, never that prose is true). The `delve` capture fired at tick 940 on a run that now
ends at 228, so it silently wrote no file — and Slice 1's and Slice 2's `delve` shots are **not a
comparable pair**, because the bite default moved and nobody re-derived the tick. And the capture tool
left one recording behind per moment; twelve reached two commits before it started cleaning up after
itself.

**D0222 — the parked items' own numbers were the unmeasured ones.** P007 named two sub-items "cheap, no
ruling needed" from reading rather than measuring; both were wrong, both in the direction that made the
deferred work sound safer. `test_reveal_spawn_bounds` calls `ShaftGenerator.generate` **517 times, 149.3
ms each, 77.2s of its 81.1s** — four passes over the same 128 pairs, and the free half of the saving is a
different half from the one that needs a ruling. And the fuzz probe's seeds are **not** independent by
design: `HostileChamber.build()` runs once above the loop and all seeds share the object. Checking whether
that bites found the real thing: **`dig_pressed` is true on 1,544 of 3,000 ticks and zero cells are ever
excavated** (solid count 1285 at every seed's entry; 63 violations with digging and 63 with `--no-dig`).
So `--no-dig` is currently a control that cannot fail, the fuzz suite has never exercised mining, and seed
independence holds by accident. Recorded in P004; **the mechanism behind `events=0` is deliberately not
diagnosed** — three plausible causes and no evidence between them is a unit of work, not a line in a wrap.

## THE PRESENTATION BATCH IS MOSTLY BLOCKED — read `docs/NEEDS_DIRECTOR.md` P005

Classifying all 21 code files in the 63-file LIFT set by the legacy types they use **in code with
comments stripped**: ~1,540 lines blocked on the `WorldRenderer` coordinator, ~2,700 on legacy's
`FactorySim`, ~2,050 on `MachineDef`/`RecipeDef` entities this build does not have, and **~945 liftable
today**. The run's own "no coordinator rebuilds" non-negotiable is what blocks most of its own queue.

**Of that ~945, only two files had a CONSUMER** — score and particles, both now done. `art.gd` needs
sprites that do not exist, `light_layer.gd` needs light math in the absent coordinator, `seams.gd` needs
a `docs/BITS.md` not in this tree. **"No unsatisfied dependency" and "has a consumer" are different
questions.** P005 carries the three options; option 3 (un-park the coordinator) is the only route to
changing how the game actually looks.

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

## STANDING — carried forward, unchanged by this round

**D0193 — the bounds invariant has no magnitude, and it is the director's call** (gate 24's subject). It
fired at 0.3125px and 3.4px; D0055 built it for 15.85px, and this world is 192px wide, so pressing into a
wall is ordinary play. The discriminator is written up: overshoot against `|vel|/TICK_HZ` separates a
wall-press from an escape without a threshold picked to silence a log.

**The fuzzer still never sets `mine_held`.** Gate 26 is green about cursor-aim mining only because it
never exercises it. Named four times now; still its own unit of work. **Line of sight is not ported**
(D0195) — a player can mine through one tile of rock, a real behaviour difference from legacy.

**Standing instruction — milestone recordings and captures.** Every slice, and any work that changes what
a player sees or does, commits the `--play`/agent `.log`, a screenshot, and the commit SHA it was produced
against, **generated from the commit, never hand-typed**, agent-mode always LABELLED. Fixed 1920x1080,
fixed camera, plus a before/after PAIR. `docs/MILESTONES.md` carries the rows;
`tools/capture_moments.sh <slice-label>` is the driver, with `BITE=` and `TICKS=` pinning the two things a
mining change moves — and D0219 is why both halves of a pair must pin them explicitly.

**Slices 0, 1 and 1.5 closed; Slice 2 closed this round.** The Q1 answer that gates the expensive slices
stands: **the palette reads at 16px; the FLECK does not**, so `terrain_painter.gd` is not portable as
written and needs an art pass rather than a port. **`claims/C004` is still untouched on purpose:** four
real human sessions exist, but deciding whether one qualifies is the director's judgment.

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
