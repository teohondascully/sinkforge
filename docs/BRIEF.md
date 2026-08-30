# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-08-30. This round: the collision resolver's grounding criterion, authorized overnight.
5 commits — `3ea7c87` (the fix), `db05f00` (milestone), `f784aac` (golden re-capture), `ec1acfa` (D0207),
`bae9565` — plus this wrap, and one shelf branch `shelf/d0139-full-footprint` (`f8186fb`).
`docs/DECISIONS_LEDGER.md` D0206 and D0207.**

**Headline: bad ticks on the director's own two recorded sessions go 6 → 0 and 171 → 0, the step-up probe
no longer reproduces, and the golden traverse is 225 — identical, not merely within tolerance. The one
acceptance number that did NOT move is `grounded_no_floor`, still exactly 59, and proving that is not a
relocation took the violation SET rather than its count.**

---

## What was learned

### A bug report that names a direction is still a hypothesis about direction

The brief described both grounding paths sinking the body into rock, and said so with justified
confidence — the previous session had traced exactly that. Classifying all 184 bad ticks first
(`tools/scratch/classify_bad_ticks.gd`) instead of designing to that description: **153 of them are the
body thrown ABOVE the world**, `grid_floor_backstop` placing the feet on the world ceiling's top face
(y=0). Sinking was 13. Both are the same interpolation error with opposite signs, and the expensive one
was the sign nobody had looked for. **Cost of classifying first: one 90-line scratch script.** Cost of not
having: a fix aimed at 7% of the population.

### A count cannot tell a fix from a relocation. The set can

`grounded_no_floor` came out of the 1000×1500 sweep at **exactly 59** — the same number D0139 failed with,
and the brief's own stated stop condition ("if it stays at 59 again, the flaw moved again"). The count is
genuinely unable to distinguish the two cases, so it was the wrong instrument to answer with. Diffing all
**805,456** violation lines: byte-identical before and after in seed, tick and **position**; exactly **4**
lines differ, in attribution only, and in the direction opposite to a relocation — `grid_floor_backstop`'s
share went **4 → 0**, where D0139's went **4 → 59**. The bodies land in the identical pixels. This is the
ledger's own "equal counts, different sets" law, arriving as *equal counts, equal sets, and a stop
condition that would have been tripped by the wrong evidence*.

### Two invariants the project holds simultaneously are mutually exclusive

`PropertyChecks.grounded_implies_solid_beneath` wants every column under the feet solid — full support,
which means resting at the **deepest** column's surface. Zero overlap means resting at the **highest**. A
flat-bottomed box cannot do both on uneven ground; this is a proof, not a tuning problem. So
`grounded_no_floor` cannot reach zero alongside the bad-tick count, and D0061 already weighed the
alternative and rejected it on feel. **The residual is a design fork, not an unfinished fix.**

### Sub-pixel ground following and a zero-overlap flat-bottomed collider cannot coexist

`Heightfield.surface_y_at_x` interpolates between two columns' faces, so wherever the footprint spans
columns of different heights it returns a height *below* the taller one's face. It also anchors on column
CENTRES, so a foot sample near the box's edge blends in a column **outside** the footprint — ground the
body isn't standing on — which is what lifted the head 1px into the ceiling and started the 153-tick
cascade. Three samples also cannot cover a four-column footprint. `surface_y_at_x` still exists and is
still tested; nothing in `sim/` calls it now.

### A test was pinning the defect, and only an A/B of the OLD code licensed changing it

`test_cave_geometry` asserted a body falls through the cave gap to the lower floor. The gap is 4 columns
and the body is 4 columns wide, and the test placed it offset by one — so its box included a shelf column,
and it reached the lower floor **by clipping through the shelf's 6-row slab** (`worst_overlap=1` at tick 11).
Correcting a test to match new behaviour is how a real regression ships, so the correction is backed by
measuring the OLD resolver either side of a `git stash` (`tools/scratch/cave_gap_ab.gd`), never by the new
code's say-so.

### The determinism golden came back identical on both platforms

Re-captured from CI's Linux build per D0167. All 200 checkpoints matched the local macOS run exactly. That
doesn't make local capture correct — it means this one scenario is insensitive to the D0171/D0172
`ValueNoise` float gap, which is a real datum about where that gap reaches.

## Gates

**All 29 suites pass on CI's Linux build** (run `33303000919`), golden array re-captured. Two gates were
red only on D0139's parked work and are now green. **Gate 7 (LOC velocity) is the one red** — and this
round made it worse, honestly: instrument +1185 against game +169 over the trailing 10 commits.

**D0207, and it is the more serious finding of the two:** gate 7 runs early in the `structural gates` job,
a failed step aborts the job, so **ten BLOCKING checks after it come back `skipped` — not failed, not
passed.** Gate 13, gates 15-16, 22, 23 (WORKING freshness), **27 (untracked files)**, 30, the
`project.godot` tripwire, the gate mutation tests, and duplication. **None has been enforced by CI for as
long as gate 7 has been red.** All pass locally, checked individually this session. Found only because
`gate_status.py` prints `local=` beside the CI conclusion — reading CI alone shows silence, not an error.

## Claims

`python3 tools/layer_lint/check_claim_references.py`. **`claims/C004` still untouched on purpose** — whether
a session qualifies is your judgment, not a session's.

## The decisions this round is waiting on

1. **`grounded_no_floor`'s 59 — full support vs. perching.** Driving it to zero means refusing to ground on
   a partial footprint, so a body at any narrow ledge edge must walk fully onto it before resting. That is a
   feel call. It is the only part of the acceptance signal not met, and it is not a bug.
2. **Slice 1.5's bite radius, unchanged from last round.** Play it and sweep `--bite=0/1/2/3`
   (`godot --path . tests/body/reveal_scene.tscn -- --play --bite=N`). `docs/TASTE_QUEUE.md` T004.
3. **The body/world proportion.** The world is 12 m wide, the body is 8.3% of that and 33% of the screen's
   height at zoom 6. Shrinking the body and widening the world are the same fix from two ends.

## Blocked, and what it's waiting on

- **D0193 / the bounds invariant's magnitude** — unchanged, yours, gate 24's subject. Worth pairing with the
  fuzz sweep's `bounds` count, which is **805,397 of 1.5M ticks** and not gated by anything.
- **The fuzzer still never sets `mine_held`** — named three times now, still its own unit of work.
- **Line of sight** — still not ported; a player can mine through one tile of rock.
- **The `ValueNoise` cross-platform float gap** (D0171/D0172), **three GDD contradictions** (D0177), **the
  persistent-world GDD reversal** (text exists only in pre-compaction history), **`data/economy/` D1-D6**,
  **`history/`'s 168-image cull**, **the parked Anvil CONSTRAINED finding** — all unchanged, all yours.

## Taste queue

**4 open**, unchanged. T001 (`ore_copper` reads silver), T002 (band tint at 0.10), T003 (mining times,
partly re-framed by T004), **T004 (the bite radius) is the one that gates Slice 2.**
