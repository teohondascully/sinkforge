# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-08-30. This round: Phase 0 of the coordinator rebuild — the painter contract,
measured and stopped for you. NO CODE WAS WRITTEN, deliberately; the brief's Phase 0 says produce the
contract and stop, and this is the stop.** One PR, `git log --oneline main..run/coordinator-contract` for
its commits. `docs/DECISIONS_LEDGER.md` D0234-D0235; the deliverable is `docs/COORDINATOR_CONTRACT.md`;
`docs/NEEDS_DIRECTOR.md` **P011** indexes the five questions.

**Headline: three of the five painters are not blocked on the contract, and no contract shape unblocks
them.** `water_view`, `rope_view` and `falling_items` need `sim/fluid`, `sim/transport` and `sim/items` —
**empty directories holding only a MODULE.md.** Nine of fifteen `sim/` modules are. Lifting them means
writing a fluid simulation, a rope system and an item-flow system first, none of which is view work.
**That resizes Phase 2 to `sky_painter` + `terrain_painter`**, and it is question 4 of five.

---

## What was learned

### The scanner that could not spell its subject's name

The first pass at measuring painter reach-in hardcoded the coordinator's binding as `r`, and reported
**0 private reach-in for `water_view`, `rope_view` and `machine_view`.** All three bind under `_wv`/`_wr`;
the real counts are 2, 2 and 7. A clean zero from three files at once was the tell — the rewrite derives
each binding from the file's own `var x: WorldRenderer` declaration and prints the derived set per file as
its positive control. **This is the house failure arriving inside the measurement written to avoid it**,
which is the second run in a row that has happened (D0233 was the same shape).

### Ten fields were four kinds, and five of them were one argument

The ten private members the painters demand collapse to four kinds once sorted by *what supplies them*:
a cosmetic clock, a camera rect, the palette, and UI-marker positions. That last group — `_guide_targets`,
`_aim`, `_aim_in_reach`, `_ghost_def`, `_ghost_material` — all feed **one local variable** inside
`sky_painter._stars`: `marks`, the positions where stars fade so a UI marker stays legible. The painter
does not need to know a build ghost exists; it needs to know where not to put stars. Passing `marks`
severs its only route to the dead economy, because `_ghost_def` is a `MachineDef`.

**The lesson generalises past this file:** a reach-in count is an upper bound on a contract's width, not
its width. Sort by supplier before designing anything against the raw list.

### A missing door is not a missing capability

`terrain_painter` wants the wall plane and a per-column surface, and neither is in `Observation`. But
`TileGrid.get_wall` already holds the plane the lode migration put ore into, and
`sim/body/heightfield.gd` already derives the surface. Both take a `TileGrid`, which `view/` may not
touch. **So two gaps that looked like two design problems are one ruling about one door.** I had written
them up as separate gaps and corrected it before this reached you rather than after.

### The first painter trips the boundary the lint just learned to see

`sky_painter` calls `Seams.grain` five times, and we put `Seams` in `sim/world/` last round (D0227).
`view` may reference only `{interface, core}`. **P008 predicted the first real outgoing `view/` edge would
be the fixed lint's first genuine test — it arrives on file one**, earlier than that entry expected.
`Seams` is measurably `core/`-shaped: zero project dependencies, and its only consumer is its own test.
Moving it is near-free *right now*, purely because last round's lifts landed unused.

---

## Gates — and PR #6 is parked, blocked on gate 7 alone

**Authorship passes; all 15 structural checks pass locally; the PR is held by `check_loc_ratio` and
nothing else.** Parked per your brief rather than forced, squashed or merged past protection. P012.

**The PR adds zero instrument lines and zero game lines** — `git diff --stat main..HEAD` touches only
`.github/` and five files in `docs/`. It is red because **gate 7's window is ten COMMITS**, and four
docs-only commits evicted last round's `+685` game lift (`33d5109`) out the far end, leaving instrument
growth against **zero** game growth in view. (`python3 tools/layer_lint/check_loc_ratio.py` for the
current pair — amending a single commit moved it from `+344/+2` to `+326/+0` with no code changing
anywhere, which is the same point one level down.)

**The general form matters more than this PR.** A commit-count window means **writing documentation
degrades the LOC ratio** — not by adding instrument, but by pushing game work out of sight. A ledger
entry, a brief regeneration and a `NEEDS_DIRECTOR` update each spend a slot, and this project documents
heavily on purpose. Any run ending in several docs commits tends to close red regardless of what it
built. If you want a remedy, the faithful one is counting only commits that touched *either* population.

**What I did not do:** squash the four commits to move the window. It goes green, the LOC reality is
identical, and that is gaming a measurement rather than answering it.

**And Phase 1 should improve it.** The entire current renderer lives in `tests/body/` — an *instrument*
directory — while `view/` is a *game* directory. Moving `material_look.gd` and `mining_overlay.gd` into
`view/` moves lines off the numerator and onto the denominator at once. Both files already declare that
move in their own headers, written by earlier sessions anticipating this rebuild.

**And one gate was genuinely broken, in a way that would have bitten you and not me.** All 15 gates
passed locally; CI failed gate 23. The `gates` job checks out GitHub's synthetic merge commit, **which is
committed at the moment CI runs** — so `check_working_freshness` compared a `WORKING.md` written this
evening against a HEAD dated the next day, the run having crossed midnight UTC. The midnight case is the
mild one: because that commit is re-dated on every run, **an open PR's gates job goes red with nobody
having touched it.** Pinned to the PR head, exactly as `authorship` already was — D0231's root cause
found in a second gate (D0235). I did not bump the date to go green; that would have left the defect and
written a date wrong in the frame every other doc in the tree uses.

**One thing that felt wrong even though it passed.** `tools/check_trailers.sh` fails *locally* on
`refs/t3/checkpoints/*` — session-checkpoint refs the background-job harness writes under a `t3code@`
identity. They are local-only, on no branch, never pushed, and **CI's authorship check passed**, verified
on this PR rather than assumed. But it is D0231's shape again: the gate reads `git log --all`, which
includes refs that are not the project's history. Left untouched — deleting refs the tooling created is
not mine to do — and worth a ruling before a future session sees authorship red and "fixes" it.

## The decisions this round is waiting on

**`docs/NEEDS_DIRECTOR.md`, 7 items. P011 is the one blocking live work** — everything else is parked by
choice, this one has a run stopped behind it.

- **P011 · the contract, five questions.** (1) the `Frame` shape and the explicit-`CanvasItem`
  convention; (2) the two L2 doors; (3) `Seams` to `core/`; (4) **Phase 2's real scope — the one that
  resizes the run**; (5) whether a game starting underground wants a day/night clock at all.
- **P010 — still read this before your next merge.** Rebase only.
- **P008/P009, P001/P004/P007** unchanged: the sibling-reach-in convention, `light_layer`'s contradiction,
  the fuzz ratchet, the fuzzer's world, the determinism running hash.

Carried, unchanged: **`grounded_no_floor`'s residual** (46); **Slice 1.5's bite radius**,
`docs/TASTE_QUEUE.md` T004; **the body/world proportion**; the **persistent-world GDD reversal** whose
text exists only in pre-compaction history.

## Blocked, and what it's waiting on

- **The coordinator rebuild is stopped at its first gate, by design.** Phases 1-3 are ready to start the
  moment P011 is ruled on. This is still the keystone and still the only route to changing how the game
  looks — but the reachable half of it is smaller than the brief assumed, and that is question 4.
- **`data/economy/` D1-D6**, **line of sight**, the **`ValueNoise` float gap** (D0171/D0172), **three GDD
  contradictions** (D0177), **`history/`'s 168-image cull** — all unchanged, all yours.

## Taste queue

**4 open**, unchanged. T001 (`ore_copper` reads silver), T002 (band tint at 0.10), T003 (mining times),
T004 (the bite radius).
