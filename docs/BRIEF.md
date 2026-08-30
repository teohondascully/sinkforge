# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-08-29. This round: LEGACY REVIVAL Slice 1 — the mining verb. 3 commits
(`caf0d99`, `427b3e0`, `c7a137f`). `docs/DECISIONS_LEDGER.md` D0192-D0198.**

**Headline: a body can now mine downward and descend into what it mined — the core verb D0110
deliberately never built. And the bounds error that was gating this slice was not the collision arc at
all: the reveal scene was spawning the body flush against the world's left wall on 53% of dense seeds.**

---

## What was learned

Findings from this round, written while they're fresh — not the ledger's judgment-call record (that's
`docs/DECISIONS_LEDGER.md`), and not a work log.

### The bounds error was a spawn bug, and the invariant that caught it cannot do its job

`pos=(503808, ...)` decodes to x = 7.6875px, so the body's left edge was **−0.3125px** — exactly one
acceleration step, at the world's LEFT edge. Not the floor. The trace is `_enforce_grid_bounds ← tick`
with `on_floor` true throughout; `resolve_floor` and `grid_floor_backstop` are nowhere in it. `find_spawn`
returned spawn column 0 whenever the target pocket sat at column 6, and `carve_entry_shaft` then
excavated the column-0 rock that would have stopped the walk. **53.2% of dense seeds, 14.0% of sparse** —
the guard that skips columns 0..5 piles every shallow pocket onto column 6, so this is the mode of the
distribution, not a tail (D0192).

The deeper finding is the one to rule on (D0193): `Invariants.check_bounds` has **no magnitude**. It fired
here at 0.3125px; D0055 built it for a chained step-up that launched the body **15.85px** out. This world
is 192px wide — twelve body-widths — so pressing into the outer wall is ordinary play, not an edge case,
and an invariant that fires during ordinary play trains everyone to ignore it. That defeats exactly what
D0055's own comment says it exists for. **It is gate 24's subject, so loosening it is a gate change and
yours, not mine.** A principled discriminator exists and is written up: the body can only ever be outside
by one tick of legal motion unless something teleported it, so overshoot measured against `|vel|/TICK_HZ`
separates a wall-press from an escape without a threshold picked to silence a log.

### Two codebases can share a constant's name and not its units

Legacy's hardness numbers **are seconds to break** (earth 0.28, stone 0.85). This project's are unitless
(clay 1.0, hardrock 3.0). No single factor maps one onto the other — the scales genuinely differ in shape
at the deep end. Porting "the same" hardness would have silently changed every mining time. The one dial
relating them (`TICKS_PER_HARDNESS = 17`) is derived from the shallow end and reproduces legacy's two
shallowest materials at 0.283s vs 0.28s and 0.850s vs 0.850s — the second exact, and not fitted to. The
deep end lands ~2x faster than legacy, which is a tuning question and is printed as a table in seconds so
it stays visible instead of buried in a constant (D0195).

Same class, different axis: legacy's `REACH_CELLS = 3.2` is 102.4px there and **51.2px here** — because
legacy's 32px cell and this world's 16px logic tile are both **one metre**. The portable quantity was
metres; copying the pixel count would have doubled the reach.

### "Not blank" and "shows its subject" are different claims

D0190's blank-frame guard is real and it could not catch this: the first milestone capture derived its zoom
from the **output** resolution (1920) when the project renders 2D at **1280×720** and scales up. Every
moment was framed 1.5x tighter than intended and the `delve` shot had the shaft and the body **both
entirely outside the frame** — while reporting 159 distinct colours, because a wall of textured clay is not
blank. Found by looking at the image and then printing the camera and body position; not by re-reading the
arithmetic (D0197). The scene now prints camera, zoom and body cell alongside every capture.

### An artifact made over a dirty tree names a commit that cannot reproduce it

Measured, not theorised: the same scripted `--mine-down` run gives **954 ticks in the working tree and 1019
on a clean checkout**, because the tree carries D0139's uncommitted `vertical_resolve.gd`. Every Slice 1
milestone artifact was therefore re-made on a clean clone. A recording that names a commit producing a
different recording is declared state wearing a reproducible label (D0198).

### Legacy's breach camera-settle has never once fired

`_note_breach` sets `_shake = max(_shake, 1.4 * hollow)`, but `try_mine` has already set it to 2.0 or 2.6
on every successful break, and `1.4 * hollow ≤ 1.4 < 2.0`. Found while extracting the tell; not ported. A
faithful port would have carried a dead line forward as if it were behaviour.

### A green gate that is green because it never runs the subject

`tests/test_body_fuzz_fast.gd` (gate 26) drives `InputFrame` and never sets `mine_held`. So it says nothing
about cursor-aim mining — and single-cell mining is exactly the shape that can produce the straddle-able
geometry D0113/D0125 exist to prevent and D0122/D0123 found as a real `discontinuity`. **Named rather than
assumed away; wiring the fuzzer to the new verb is its own unit of work and was not done.**

## Gates

Run `python3 tools/gate_status.py`. Its live output is the current gate table — this section does not copy
it (`docs/DECISIONS_LEDGER.md` D0143, D0146: a copied number here is exactly the drift an external audit
found, twice). **Two locally-red suites (`test_shaft_replay_determinism`, `test_body_acceptance`) and one
size FAIL (`resolve_floor` at 60 lines) are D0139's parked uncommitted work, not this round's** —
re-confirmed by running Slice 1's files on a clean clone at `caf0d99`, where all three pass.

## Ratio

Run `python3 tools/layer_lint/check_loc_ratio.py`. **Still red, and for the last time on this cause**: its
trailing 10-commit window still reaches back over Slice 0, which was instrument-heavy by design (+588
instrument, +28 game). **Slice 1's own ratio is 1.12x against the 2.00x limit** (game +546, instrument
+609) — the first slice in a while to add real game LOC. It clears as the window rolls forward.

## Claims

Aggregate: `python3 tools/layer_lint/check_claim_references.py`. Per-claim status: `claims/*.md`
frontmatter directly. **`claims/C004` is untouched on purpose** — this round produced a clean recording,
and deciding whether a session qualifies is your judgment, not the session's.

## Blocked, and what it's waiting on

- **The human `--play` acceptance run** — Slice 1's own acceptance bar, half met. The verb is proven
  mechanically (agent trace: 24 cells / 6.0m descent, 91 breaks, 0 bounds violations). **A human session
  cannot be produced from a session with no keyboard**; the command is in the report.
- **D0193 / the bounds invariant's missing magnitude** — new, yours, gate 24's subject.
- **D0139 / `resolve_floor`** — unchanged, untouched, still dirty on purpose. Now also known to change the
  mine-down trace by 65 ticks (D0198).
- **Line of sight** — legacy gates mining on a float DDA; not ported, so a player can currently mine
  through one tile of rock. Real behaviour change, stated rather than dropped.
- **The `ValueNoise` cross-platform float gap** (D0171/D0172) — unchanged.
- **Three GDD contradictions** (D0177) — unchanged, yours.
- **The persistent-world GDD reversal** — unchanged; text exists only in pre-compaction history.
- **`data/economy/` D1-D6**, **`history/`'s 168-image cull**, **the parked Anvil CONSTRAINED finding** —
  all unchanged, all yours.

## Taste queue

**3 open.** T001 (`ore_copper` reads silver) and T002 (band tint at 0.10 nearly invisible) carry over
unanswered from Slice 0. **T003 is new**: mining times. Clay breaks in 0.28s and deepstone in 1.42s against
legacy's 2.80s — the shallow end is legacy's exactly, the deep end is twice as fast, and only playing it
answers whether that is right.
