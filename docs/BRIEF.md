# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-08-30. This round: your Phase-0 rulings applied, and the coordinator skeleton
built. STOPPED at the Phase-1 ◆ — Phase 2 does not start until you look.** `docs/DECISIONS_LEDGER.md`
D0237, D0238, D0240. Two PRs open and stacked: **#6** (Phase 0's contract, parked on gate 7 alone) and
**#7** (prerequisites + skeleton), branched off #6 so the ledger stays sequential.

**Headline: it is 101 lines against a 400 cap, and that is the whole point.** The brief warned the
skeleton would be born at the size gate. `tests/body/reveal_scene.gd` — the closest thing this tree had
to a coordinator — sits at **398/400** with `_physics_process` at **49/50**, one line from firing on
both. So nothing was ported from it. Its argument parsing, agent-drive modes and recording flush are
~120 of those 398 lines and **none is coordinator work**; they stayed in the debug scene where they
belong. A renderer does not parse `--seed`.

---

## What landed

**P0a · `Seams` → `core/`** (D0237). `test_seams` passes unchanged — `class_name` is path-independent.

**P0b · two doors through L2** (D0238). `Observation` now carries `walls`/`wall_legend` and a per-column
`Fx` `surface_y`. Each is derived **per window**, so a window sitting above the floor reports `NO_FLOOR`
rather than scanning past its own edge — the envelope is preserved by construction, not by promise. ADR
0007 Decision 1 amended in place.

**Phase 1 · the coordinator** (D0240). `world_view.gd` (101), `frame.gd` (57), `paint_layer.gd` (45),
plus `MaterialLook` moved out of `tests/body/` into `view/visuals/`.

**Evidence:** 39/39 suites pass, determinism included. **Gate 7 green and strongly positive —
instrument +60 against game +464** (3,762 → 4,226 game LOC), exactly the direction you asked me to
report. The layer lint was **mutation-tested on `world_view.gd` itself**, not trusted from last run's
plant: a planted `TileGrid` reference fails with the precise message, removing it passes.

## What was learned

### A dependency scan is not an architecture argument

I recommended `Seams` for `core/` on the evidence that it references only `RefCounted`, `Vector2i` and
its own constants. That is true, and it answers a different question. It describes what the file
**imports**, not what it **means**: `at()`, `aligned()` and `RUN_CAP` talk about swings, grain and the
Wedge bit, and `core/MODULE.md` describes its residents as primitives "with no domain concept of their
own". **Only `grain()` is domain-free — and `grain()` is the only function `view/` calls.** The clean
split is named in D0237 and deliberately not taken: the integer conversion is proven exact as a
whole-file unit over 196,608 inputs, and splitting the file splits the proof for a mechanic nothing
calls yet.

### Right by coincidence is still wrong

My first draft of the coordinator had a `view → sim` edge — `Heightfield.TERRAIN_CELL_PX`, to convert
pixels to cells. The obvious repair was to re-declare the cell size in `view/`, and
`view/visuals/material_look.gd` **already carries `CELLS_PER_METRE = 4`** — a *different* quantity
(cells per metre, not pixels per cell) that happens to share the value at 16px/m. Copying it would have
worked, forever, until the world scale changed. The real fix put the conversion in
`Interface.Envelope.covering()`, where the constant legitimately lives and `view/` never learns it.

### The gate cannot see a `view/ → tests/` dependency

`Frame.look` is typed `MaterialLook`, which lived in `tests/body/`. Because `class_name` is
path-independent, a shipped renderer could have depended on a test file **forever** with the layer lint
silent throughout — `tests` is in its `UNPOLICED` set and its class map is built "from the policed tree
only". That is why the file was physically moved rather than merely referenced. Same shape as the
`view → data` edge now flagged in P013: the lint is silent in *both* directions, which is the worst
place for a rule to live.

### My own new test asserted something vacuous, and passed

`test_world_view` first checked that the observation window was "non-empty". It **passed** — over a 4×4
window that was *entirely* `WINDOW_MARGIN_CELLS`, because a Godot node is not really in the tree until a
process frame has passed, so `get_viewport()` returned null and the camera rect was zero. An assertion
about having seen a viewport, passing on having seen no viewport. Now it asserts the window is wider
than its own margin (324×184 over a real 1280×720), with the camera rect as a control.

## The decisions this round is waiting on

**`docs/NEEDS_DIRECTOR.md`, 9 items.** P011 is closed and deleted — your five rulings are applied.

- **The Phase-1 ◆ itself.** Review the skeleton and the split boundaries; Phase 2 (`sky_painter`) is
  ready to start on your word.
- **P013 — `view/` reads `data/`** for the palette. §3's table grants that only to `shell`, and the lint
  cannot see the edge either way. One sentence, and it arrives twice more in Phase 2.
- **P014 — `core/MODULE.md` is at exactly its 100-line cap.** Two of your rulings collided: P006 set the
  cap when the file was at 98, and Q3 put a fifth class in `core/`. Resolved by writing less, with no
  duplication left to reclaim — the next class added to `core/` forces the number open.
- **P012 — PR #6 still parked on gate 7.** Unchanged.
- **P001, P004, P007, P008, P009, P010** unchanged.

## Anything that felt wrong even though it passed

**A ledger-number collision happened and nothing detected it.** A second session committed **D0239** to
this branch mid-run — the trailer gate counting identities over a wider ref set than it scanned, which
also fixes the local-red flagged in the previous brief. **The director confirms this was deliberate and
a one-off, so it is not a standing hazard and needs no protocol change.** Earlier claim keeps the
address; the Phase-1 entry is **D0240**, with every citation moved.

The mechanical lesson is the part that outlives the incident: **two entries can hold one number and no
gate says so.** `docs/DECISIONS_LEDGER.md` is append-only prose, the commit-msg hook checks that an
entry *exists* rather than that its number is unused, and both commits were green. It was caught by
reading `git log` after committing, which is luck rather than method. A duplicate-number check is a
handful of lines if a second writer is ever expected again.

## Blocked, and what it's waiting on

- **Phase 2 is `sky_painter` then `terrain_painter`, and then dry.** `water_view`, `rope_view` and
  `falling_items` need `sim/fluid`, `sim/transport` and `sim/items` — still zero lines of code.
- **`data/economy/` D1-D6**, **line of sight**, the **`ValueNoise` float gap**, **three GDD
  contradictions**, **`history/`'s 168-image cull** — all unchanged, all yours.

## Taste queue

**4 open**, unchanged. T001, T002, T003, T004.
