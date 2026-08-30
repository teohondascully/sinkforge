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

## Slice 2 — the L2 door, and the first cosmetic feedback

| | |
|---|---|
| **Slice** | 2 — `interface/` exists; the score; chips and the draught |
| **Commit** | `5f40ac1` |
| **Recording** | [`tests/body/recordings/slice2_minedown_agent_2026-08-30.log`](../tests/body/recordings/slice2_minedown_agent_2026-08-30.log) — **AGENT-MODE**, scripted `--mine-down`, 228 ticks |
| **Shows** | The same scripted shaft as Slice 1, now throwing chips of the broken material's own colour on every break. The two changes that carry this slice are not visible at all: `interface/` renders nothing, and `view/audio/score.gd` is sound. |
| **Screenshots** | [surface](milestones/slice2_surface_5f40ac1.png) · [delve](milestones/slice2_delve_5f40ac1.png) · [aim](milestones/slice2_aim_5f40ac1.png) |

**This slice's honest visual delta is `aim`, and only `aim`.** At zoom 13 the scattered dark flecks
around the reticle are D0216's chips — the first cosmetic feedback this build has ever produced. Nothing
else in the frame changed, which is the correct reading rather than a disappointing one: Slice 2's
subject is a layer boundary, and a layer boundary that changed a pixel would be a bug.

**The cross-milestone `delve` pair does NOT exist yet, and putting these two side by side would be
wrong** (`docs/DECISIONS_LEDGER.md` D0219). Slice 1's `delve` is bite radius 0 at tick 940; this one is
bite 2 at tick 216, because D0200 moved the bite default and the scripted run now reaches its target in
228 ticks instead of 991. Those are two different worlds at two different moments, and every difference
between the images would be attributed to whatever this slice changed. To build the real pair, re-capture
**both** commits with the knobs pinned — `BITE=0 TICKS=2,940,40 tools/capture_moments.sh <label>` — which
is what the SHA in every filename exists to make possible. Left undone deliberately rather than papered
over with a caption.

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

## Slice 1.5 — the bite (a probe, revertible in one commit)

| | |
|---|---|
| **Slice** | 1.5 — how much of the world one charged blow removes |
| **Commit** | `ea33549` |
| **Recording** | [`tests/body/recordings/slice15_minedown_bite2_agent_2026-08-30.log`](../tests/body/recordings/slice15_minedown_bite2_agent_2026-08-30.log) — **AGENT-MODE**, scripted `--mine-down --bite=2`, **242 ticks** |
| **Shows** | The same 24-cell / 6.0 m shaft the Slice 1 recording sinks in **991** ticks, sunk in **242** — 4.1x. 20 blows, **144 cells removed** (3.6 body-volumes), 0 bounds violations. |
| **Screenshots** | [surface](milestones/slice15_surface_b0_ea33549.png) · delve [b0](milestones/slice15_delve_b0_ea33549.png) → [b2](milestones/slice15_delve_b2_ea33549.png) · aim [b0](milestones/slice15_aim_b0_ea33549.png) → [b2](milestones/slice15_aim_b2_ea33549.png) |

**The before/after pair is the `_b0` → `_b2` half of each moment**, and it is a stricter pair than Slice
1's: same commit, same seed, same site, same camera, same zoom **and the same tick** — the only difference
between the two frames is the bite radius, because `--bite=0` is bit-for-bit the Slice 1 blow. The capture
tick (200) is one both radii reach; a larger bite sinks the shaft faster, and shooting each half at its own
completion tick would compare two different moments and call it a before/after.

**`surface` has no pair, and that is a result rather than an omission.** Nothing is mined at tick 2, so the
frame cannot depend on the bite — captured at both radii it came back **byte-identical** (same SHA-256),
which is also a free check that the fixed-camera capture is deterministic. One frame is kept.

**What the pair actually shows.** At tick 200 the `b0` body is still near the surface with a shaft barely
its own length; the `b2` body is most of the way down an open column that runs the full height of the
frame. The `aim` pair is the closer look: the reach ring, the reticle, the crack bars on a part-charged
cell, and the shape of the hole each radius leaves.

**Read this against the frames, not instead of them.** The removed shape is still built out of 4px cells,
so the wall stays finely divided — but a disc is a regular shape, so a swept column's sides come out
straighter than Noita's, whose raggedness comes from irregular material rather than from a small bite. What
these frames can settle is throughput and hole size. Whether the *edge* reads as rock is a Slice 3 question
and these frames are not evidence about it: still no lighting, no shaders, no molded rock, no sprites, no
HUD, and the body is a rectangle.

**Cost:** the five frames total **0.17 MB**, consistent with Slice 1's 0.11 MB for three. Re-measure when
Slice 3 adds lighting; do not carry this number past it.

---

## D0206 — the collision resolver's grounding criterion

| | |
|---|---|
| **Slice** | 1.5 (out-of-band) — authorized collision-resolver work, the exception to the standing hard stop |
| **Commit** | `3ea7c87` |
| **Recording** | [`tests/body/recordings/d0206_minedown_bite2_agent_2026-08-30.log`](../tests/body/recordings/d0206_minedown_bite2_agent_2026-08-30.log) — **AGENT-MODE**, scripted `--mine-down --bite=2`, **228 ticks** |
| **Shows** | The same shaft the Slice 1.5 milestone row records, run again on the fixed resolver: **228 ticks against the parent commit's 242**, measured on this machine by checking out the parent's `vertical_resolve.gd` alone and re-running — not quoted from the older row, which predates D0205. Same seed, same site, same 24-cell target depth. **0 bad ticks** replayed through `tools/scratch/classify_bad_ticks.gd`. |
| **Screenshots** | none — this milestone changes where the body RESTS, not what a frame looks like. A still cannot show it; the two replays below can. |

**The evidence that matters here is not a picture.** The director's own two recorded sessions, replayed on
a clean tree: **6 → 0** bad ticks (710-tick session) and **171 → 0** (767-tick session), where a "bad tick"
is the body's own box overlapping solid rock or leaving the world. `fixture_step_up_into_wall_probe`
reports NOT REPRODUCED. `test_body_acceptance`'s golden traverse is **225, identical to golden**, so the
one scripted route this project has pinned since D0038 is bit-for-bit unchanged by the fix.

**Why the shaft got 14 ticks faster.** The body now rests on the highest solid face under its whole
footprint rather than on a blend of three sample points, so each layer it opens drops it a slightly
different amount. It reaches the same depth; it is not a throughput change and should not be read as one.
