# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-08-29. This round: two consecutive 5-hour autonomous queues (director away), 19
commits total, everything pending Codex re-verification on return — nothing here is self-certified.**
`docs/DECISIONS_LEDGER.md` D0162-D0178.
**Headline: an architecture rule the project wrote for itself — "no float math on state-affecting
paths" — was quietly broken by the one noise function nobody had cross-platform-tested until this round
built the test.**

---

## What was learned

Findings from this round, written while they're fresh — not the ledger's judgment-call record (that's
`docs/DECISIONS_LEDGER.md`), and not a work log.

### The one that matters most: determinism was claimed unconditional in ~19 places; it's real only within one platform

`docs/ARCHITECTURE.md`'s own "### Determinism" section states the rule plainly: fixed-point for every
state-affecting position and velocity, no floats on those paths. `sim/terrain_gen/value_noise.gd`'s cave-
carving noise — baked into the committed `TileGrid`, read by every tick after generation, unambiguously
state — uses real `float` arithmetic throughout. Nobody had ever run the same seed on two different
platforms to find out whether that mattered.

Building gate 8's real determinism test (D0165) found out. A live `ShaftGenerator`+`TileGrid`+`Body` sim,
20,000 ticks, replayed across two OS processes — first attempt's "proof" was itself invalid (an in-tree
`sim/` rename let Godot's importer silently rediscover the same code; caught before being reported, not
after) — then corrected and run for real: CI (Linux/x86_64) and local (macOS/arm64) produce IDENTICAL
hashes for the first two checkpoints, then diverge at checkpoint 3, the moment the body's path reaches
real generated terrain. CI's own same-platform, two-independent-process check still passes bit-identical
— determinism holds perfectly WITHIN a platform. It has simply never been proven ACROSS platforms for
anything touching terrain generation, and now it's proven NOT to be, specifically because of this one
function's float math.

The fix (converting `ValueNoise` to `Fx` fixed-point) is not in this round — it would re-tune a calibration
constant, regenerate every committed golden hash, and break any pre-existing recorded session against
current seeds, including whatever your own `--play` session produces if it lands first. `docs/DECISIONS_
LEDGER.md` D0172 has the full diagnosis, ready for your own scoping. What this round did instead: corrected
every doc that overclaimed unconditional determinism — `ARCHITECTURE.md`, `README.md`, `claims/C003`,
`sim/terrain_gen/MODULE.md`, `CONTEXT.md` (twice) — to state the real, narrower, still-true claim, each
pointing at one canonical ledger entry (D0171) instead of re-explaining the crack five different ways.

### What landed

**Queue #2** (Parts F/G/H/I, D0162-D0170):
1. Self-audit found two real, previously-undiscovered gaps in this project's own tooling: `gate_status.py`
   never resolved `${{ env.KEY }}` expressions before matching CI step names (permanent UNKNOWN, never a
   false PASS, for the Godot-download step); the D1 mutation-tests CI step only globbed one directory
   level deep. Both fixed, mutation-tested.
2. Gate 8 (the determinism gate) got a real subject for the first time — see above.
3. A drift-count sweep found its OWN premises were undercounts: "capped at 12" had 2 more stale instances
   than believed; `MODULE.md`'s "60 lines maximum" is violated by 7 files, not 4. Both corrected, several
   hand-typed counts replaced with pointers so they can't re-drift the same way.
4. `docs/CORRECTIONS.md` built — a projection over the ledger tracing every entry that names an earlier
   one as wrong, including the deepest chain in the ledger (D0059 → D0137, six weeks, five corrections)
   traced to its true origin, closing a citation gap an external audit specifically flagged.

**Queue #3** (Parts J/K/L/M, D0171-D0178):
5. The determinism honesty sweep above (Part J).
6. A real, if currently latent, two-dialect risk in the reveal-metric replay pipeline fixed:
   `RevealReplayDriver.parse_log` validated column count, not column names, so a differently-shaped log
   with the same field count could silently replay wrong data. Fixed, mutation-tested twice. Then the
   capture path was proven end-to-end against a REAL run of `reveal_scene.gd` (not synthesized data) —
   `claims/C004` is still correctly BLOCKED, but the pipeline underneath it is now proven, not assumed.
7. `docs/CORRECTIONS.md` re-verified complete (no gap found — a checked, clean result, reported as a
   finding in its own right) and given a `--check` freshness gate (QUALITY gate 30) — dogfooding it found
   a real bug in the gate itself (its own filename false-positived against its keyword pattern) before it
   was trusted.
8. The size-gate ruling from queue #2 written into `QUALITY.md` itself, and a fresh sweep of the cold-read
   audit's own measured-FALSE table: 8 real drifts fixed (stale CI-wiring claims, a stale root-file list,
   a drifting line-count claim, `project.godot`'s pre-pivot description, a fictional test-directory
   structure, an orphaned normative doc, a stale function-location citation), 3 design contradictions
   flagged for you rather than resolved, the rest already moot.

### Anything that felt wrong even though it passed

- **A mutation-testing script almost destroyed real work, silently.** Testing the reveal-replay fix, a
  script meant to mutate a scratch copy instead overwrote the real tracked `reveal_replay_driver.gd` with
  reverted behavior. Caught only because a system reminder flagged the file had changed on disk
  unexpectedly — not because anything in the process itself would have noticed. Recovered by re-reading
  the mutated state and reapplying the missing code by hand; the second mutation test of the round
  explicitly backed the file up first, learned from the first one's near-miss.
- **An external audit's own citation was off by one entry, and only checking caught it.** The cold-read
  audit says `resolve_floor` "moved to `vertical_resolve.gd` at D0060" — the actual split is inside D0059's
  own text. A citation this project would have otherwise repeated as fact, in a ledger entry meant to model
  verifying claims before writing them down.
- **A freshness gate false-positived against its own filename the first time it ran.** `check_corrections_
  freshness.py`'s keyword regex matches the substring "correct" — which is also inside "CORRECTIONS.md."
  It flagged the two entries that only ever *mention* the page as if they were corrections needing
  inclusion. Dogfooded before trusting it, per standing discipline; not caught by writing the gate, only by
  running it against the real tree.
- **Adding gate 30 broke `gate_status.py` immediately, and its own test suite didn't catch it.** Two
  separate hardcoded `range(1, 30)` literals assumed the gate count would always be 29 — one FATALed
  loudly the moment the tool was actually run at wrap time; the other, found only by grepping the whole
  file rather than stopping at the first hit, would have silently under-counted gate 30 forever instead of
  erroring. `tools/test_gate_status.py`'s 11 cases all exercise per-gate classification, none exercise the
  gate-count itself — a real gap in what "mutation-tested" had actually covered. Fixed (D0178).
- **`docs/BRIEF.md` itself was stale across two full queues.** This file's last real update predates queue
  #2 entirely (D0140/D0141, the control-plane ruling round). "Regenerate this last, every session" is the
  file's own stated rule; it wasn't followed for two consecutive 5-hour queues until this wrap. No process
  currently catches that mechanically — `check_working_freshness.py` gates `WORKING.md`'s date, nothing
  gates this file's own.

## Gates

Run `python3 tools/gate_status.py`. Its live output is the current gate table — this section does not
copy it (`docs/DECISIONS_LEDGER.md` D0143, D0146: a copied number here is exactly the drift an external
audit found, twice).

## Ratio

Run `python3 tools/layer_lint/check_loc_ratio.py`. Its live output is the current velocity gate result
and the absolute instrument/game ratio metric — the latter is reported, not gated
(`docs/DECISIONS_LEDGER.md` D0147). **Currently red** (instrument grew far more than game over the last 10
commits) — expected and unavoidable given two consecutive tooling/docs-heavy queues under a hard stop that
forbade touching `data/economy/`; not a regression, a direct consequence of scope.

## Claims

Aggregate population/proven-count/cap: `python3 tools/layer_lint/check_claim_references.py`. Per-claim
status (BLOCKED/PASSING/RETIRED): `claims/*.md` frontmatter, directly — no tool summarizes that across
claims yet, so this section does not invent one. **`claims/C004` gained a History row** this round: its
capture path is now proven working end-to-end, still correctly BLOCKED pending an actual human session.

## Blocked, and what it's waiting on

- **D0139 / `resolve_floor`** — unchanged, untouched this round per explicit hard stop. Working tree still
  dirty on purpose (`sim/body/vertical_resolve.gd` modified, `tests/test_vertical_resolve.gd`(`.uid`)
  untracked). Two hard-stop findings still un-ruled: the acceptance signal didn't drop (59→59, mechanism
  flipped entirely to `grid_floor_backstop`, same criterion flaw); a real regression against
  `test_body_acceptance.gd`'s hard gate. Also breaks `check_size_limits` as written.
- **The `ValueNoise` cross-platform float gap** — new this round (D0171/D0172). Real, diagnosed, not
  fixed: a director-scoped design cycle (re-tune a calibration constant, regenerate every golden hash,
  breaks pre-existing recorded sessions against current seeds).
- **Three design contradictions surfaced this round, none resolved** (D0177): `docs/GDD.md` §5 vs §7's two
  different currency models; §13 vs `docs/adr/0002`'s fuel-cost contradiction; iron's placement stated
  three incompatible ways across the GDD, the generator, and its own data file (and hardness has no
  consumer in `sim/` at all — digging ignores it entirely). All three are yours to rule on, not fixable by
  re-reading the code harder.
- **The collider-shape table** (`ARCHITECTURE.md` §9: "capsule or rounded AABB") vs. the actual flat AABB
  in code — deliberately left alone this round. The code already discloses and explains the divergence in
  its own docstring; whether the doc's table should change or a formal ADR should exist is your call, and
  collision-shape changes are out of scope regardless.
- **The dropped Codex finding — CONSTRAINED restricts distance, not discovery.** Unchanged. Anvil FINDING
  `ed491e83`, recoverable via `git show 4ec12bb:.anvil/log/2026-08-29T095108.038191Z-ed491e83.json`.
- **Where a public position-to-cell conversion lives** — unchanged, the actual liftability decision behind
  D0141.
- **The persistent-world GDD reversal** — unchanged. Its text exists only in pre-compaction history and
  must be re-supplied before `docs/GDD.md` is touched.
- **The hands-on-keyboard `--play` session** — unchanged, still the sole remaining blocker on `claims/
  C004`, and now the one thing this round's own capture-path proof could not produce on purpose (faking
  one was explicitly out of scope).
- **`history/`'s 168-image pre-pivot cull** — unchanged, waits on you.
- **`data/economy/`, D1-D6** — unchanged, yours.

## Taste queue

0 fixtures. Unchanged.
