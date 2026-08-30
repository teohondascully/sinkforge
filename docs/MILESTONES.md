# Milestones — the migration's visual history

One row per milestone artifact. **The row is keyed to a commit, not to a date**: a recording or a
screenshot that does not name the tree that produced it is declared state, and declared state drifts.
SHAs here are generated from `git rev-parse`, never typed.

Produced by `tools/capture_moments.sh <slice-label>` (`docs/DECISIONS_LEDGER.md` D0197), which holds the
resolution, the camera and the seed constant so that only the CONTENT differs between milestones. That is
the only property that makes a before/after pair mean anything.

**Agent-mode and human `--play` traces are different evidence and are labelled as such.** An agent trace
is mechanically reproducible; a human session is not, and only a human session can answer a question about
feel. `claims/C004` is populated by the director's judgment, never from this table.

## Slice 1 — the mining verb

| | |
|---|---|
| **Slice** | 1 — cursor-aim, reach, hold-to-charge, hollow tell |
| **Commit** | `427b3e0` |
| **Recording** | [`tests/body/recordings/slice1_minedown_agent_2026-08-30.log`](../tests/body/recordings/slice1_minedown_agent_2026-08-30.log) — **AGENT-MODE**, scripted `--mine-down`, 1019 ticks |
| **Shows** | The body sinks a shaft through its own footprint and descends 24 terrain cells (6.0 m) into what it mined — 91 cells broken, **0 bounds violations**. |
| **Screenshots** | [surface](milestones/slice1_surface_427b3e0.png) · [delve](milestones/slice1_delve_427b3e0.png) · [aim](milestones/slice1_aim_427b3e0.png) |

**The before/after pair for this slice is `surface` → `delve`**: the same seed, the same site, the same
camera and zoom, at tick 2 and tick 940. What differs between them is only the shaft. There is no
cross-milestone pair yet, and there cannot be one until Slice 2 — the fixed-camera capture mechanism is
itself a Slice 1 deliverable, so Slice 0 has no comparable frame to pair against. Slice 2's pair will be
the first true milestone-to-milestone comparison.

**What each moment is for:**

- **surface** — the world as a player first meets it, untouched. The "before" half of the pair, and the
  only frame that shows the entry pocket the session actually starts in.
- **delve** — the same world after the scripted shaft. Framed on the whole world width (zoom 6.5, camera
  column 24) rather than on the body, because the shaft sits one cell from the world's left wall and any
  tighter frame either clips it or fills a third of the image with off-world background.
- **aim** — Slice 1's own subject, and the only frame where the new verb is visible at all: the reach ring,
  the reticle on the aimed cell, and the crack bars of a cell caught part-charged. Deliberately tighter
  (zoom 13) so a 4px terrain cell reaches ~78 output pixels and reads as a reticle rather than a dot.

**What these frames do NOT show, so they are not read as a verdict on the look:** no lighting, no shadow
veil, no shaders, no molded rock, no sprites, no HUD. The body is a rectangle. That is Slice 3, and pulling
it forward was an explicit hard stop for this slice. What is legible here is Slice 0's palette and Slice
1's verb, and nothing else.

**Cost, measured rather than assumed.** The three Slice 1 frames total **0.11 MB**, not the ~1.5 MB each
that `.gitignore`'s own long note about `history/` (171 MB) and the legacy moment set (66 MB) would lead
you to expect. Flat-colour 1920x1080 PNGs of a 4px grid compress roughly forty times better than legacy's
shaded, lit, noise-textured frames. At this rate the whole six-slice migration record costs well under a
megabyte, so the repo-size argument that made the legacy captures a hard decision does not apply here —
**and it will stop applying the moment Slice 3 adds lighting and shaders.** Re-measure then; do not carry
this number forward as if it were a property of the format.

**A trap this table exists to prevent, found while building it.** The same `--mine-down` run produced
**954 ticks** in the working tree and **1019 ticks** on a clean checkout of `427b3e0` — because the tree
carried D0139's uncommitted `sim/body/vertical_resolve.gd`. Every artifact above was therefore re-made on
a clean clone. An artifact produced over a dirty tree names a commit that cannot reproduce it, which is
exactly the failure this file's commit column exists to catch; `capture_moments.sh` now suffixes such a
capture `-dirty` rather than letting it pass as reproducible.
