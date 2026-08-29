# Working state

Not a log. Current stage, what's actually happening, and what would be lost if this session ended
right now. Updated as work happens. Resets when a stage closes — durable content moves to an ADR,
a MODULE.md, or a claim first.

**Last updated: 2026-08-29.** Bump this date whenever this file changes — a CI gate fails if it's
older than `HEAD`'s own commit date, so a session that lands commits without touching this file is
caught mechanically rather than relying on someone noticing later.

## PRE-COMPACTION CHECKPOINT — external audit response, Phase 1 (Tier 1) COMPLETE, awaiting the director's ruling on item 3, 2026-08-29

**Context a fresh session needs:** an independent cold-read audit (fresh model, no project history) found
the enforcement layer itself was lying — `BRIEF.md` said all gates passed at a commit where CI was
actually red, and the LOC-ratio gate had never once been able to fail. The director issued a three-item
Phase 1 ("stop the lie"), each its own commit, each verified against tool output before being reported.
All three are DONE and PUSHED. Do not redo any of them. Do not start Phase 2/Tier 2 — the director's
closing instruction was explicit: "Then stop and wait for the director's ruling on item 3 before Phase 2."

**Commits this round, in order** (`b71d6e9..c82c269`, all pushed to `origin/main`):
- `c9457f5` — `tools/gate_status.py` built (D0143): enumerates `docs/QUALITY.md`'s 29 gates and
  `.github/workflows/harness.yml`'s steps programmatically (no hand list), three link tiers, reproduces
  an independent audit's own hand-derived split exactly (18/29 gates have code, 11 do not:
  `5, 6, 9, 10, 12, 14, 17, 18, 19, 20, 21`). Mutation-tested against the real historical red run at
  `8f6d540`, not a synthetic break.
- `d9b3020` — `wrap.md` step 7, `QUALITY.md`'s gate-list intro, and `BRIEF.md`'s Gates section all point at
  `tools/gate_status.py` now instead of hand-enumerating.
- `6734e21` — the LOC-ratio gate armed (D0144): `check_loc_ratio.py`'s `GAME_LOC_ADVISORY_FLOOR=2000` (a
  permanent off switch — game LOC has never exceeded 1665) deleted, not raised or narrowed. Runs red
  immediately: instrument +560 lines vs game's +28 over 10 commits. **This is the CURRENT, LIVE, INTENDED
  CI state — `origin/main`'s `gates` job is red on gate 7 alone, on purpose, per the director's own
  explicit instruction not to suppress this.** A fresh session must not "fix" this without a ruling.
- `c82c269` — `gate_status.py` fixed (D0145): it was conflating GitHub's `"skipped"` step conclusion
  (every step after gate 7 in the same CI job never ran) with `"failed"`, which would have shown 7 gates
  broken instead of 1. Found by running the tool against the real red it exists to report, before ever
  reporting its output.

**Verified final state, via `gh run view` on `c82c269` (the pushed HEAD), not from memory:** CI conclusion
`failure`, and the *only* failing step in the whole workflow is "Instrument LOC must not exceed game LOC
(QUALITY gate 7)." `authorship` and `godot test suites` jobs are both green. `tools/gate_status.py`'s own
table at this commit: `FAIL gate numbers: [1, 7, 27]` — gates 1 and 27 are NOT a new regression; they
report via a correctly-labeled DISAGREE (CI passes them at the committed tree; only THIS session's local,
uncommitted D0139 files fail them locally) rather than a false CI failure.

**What the director is waiting to rule on:** item 3's own open question, stated precisely so it isn't lost
— arming the gate proved the *velocity* check (instrument growth vs game growth over 10 commits) is
violated, which is NOT the same claim `docs/QUALITY.md` gate 7's own words make ("Instrument LOC ≤ game
LOC" — an ABSOLUTE ratio, currently 6.4:1, never gated by this script at any point in its history). The
director must decide: accept the currently-red velocity gate as honest and correct, or set a justified
floor with a documented diagnosis. Do not decide this and do not touch `check_loc_ratio.py` again without
that ruling landing first.

**`AUDIT_RESPONSE_BRIEF.md` does not exist anywhere in this tree** (checked: full repo search, git log,
`docs/`) — the director pasted its content and the underlying audit's content directly into chat mid-turn.
A fresh session will not find either document on disk; if it needs the exact audit findings again, they
are not recoverable from the repository, only from this conversation's own history.

**D0139 remains completely untouched, exactly as the last checkpoint left it — still not this round's
business.** `sim/body/vertical_resolve.gd` still carries D0139's uncommitted `_full_footprint_solid` fix
attempt; `tests/test_vertical_resolve.gd`/`.uid` are still new and untracked. Two hard-stop findings from
that investigation are still un-ruled (the mechanism-flip to `grid_floor_backstop`, and the rubble-notch
regression). See the OVERNIGHT QUEUE section immediately below for that investigation's own full detail —
it predates this round and nothing in this round changed it.

## OVERNIGHT QUEUE, 2026-08-29 — STOPPED ON A FALSE PREMISE. 4 of 5 items rest on state that does not exist.

The queue's own context line: "the bound-diagnosis mechanism, the 4-case diagnosis, and the two
control-plane fixes are already done." **None of the first two is true, and the third is half true.**
Verified against the tree, not from memory:

| Premise | Actual state | Evidence |
|---|---|---|
| bound-diagnosis mechanism built | **does not exist** | `git grep -liE "bound.?diagnos\|diagnos.?bound\|bound_diag"` over `tools/ tests/ sim/ core/` → zero files. `tools/` has no such entry. |
| `grounded_no_floor` fixed to 4 | **is 59** | `tests/test_body_fuzz.gd:68`: `const DESIGN_TRADEOFF: Dictionary = {"grounded_no_floor": 59}` |
| resolve_floor fix applied | **uncommitted, un-ruled** | `git status`: `M sim/body/vertical_resolve.gd` still dirty, unchanged since the checkpoint |
| two control-plane fixes done | **one landed, one reported blocked** | D0140 landed (ADR 0006); D0141 reported item 2 as not executable |

**Disposition, item by item:**

1. **STOPPED — no retrofit exists to have surfaced anything.** Cannot report an all-clear (there is no
   scan) and cannot report an undiagnosed bound (nothing ran). Reporting "all bounds diagnosed" here
   would be a green with no instrument behind it.
2. **STOPPED — cannot confirm what did not happen.** `grounded_no_floor` is 59, not 4; the fix that was
   to move it is uncommitted and sitting on two un-ruled hard-stop findings. A full 1000×1500 sweep would
   re-measure a baseline nothing has changed since (this session has touched only docs and `tests/`), at
   ~an hour of compute, to confirm a number already measured. Declined as waste, not as difficulty.
3. **STOPPED — would require fabricating a measurement.** The specified entry narrates "bound 32 pre-dig,
   59 wrongly attributed, **4 correctly fixed**." The third stage never occurred. Writing it into the
   append-only ledger would put an invented number into the permanent record, against the standing rule
   that a numeric claim is verified against tool output before it is written. The arc close-out is
   writable the moment D0139 is ruled on and a real post-fix number exists.
4. **DONE, and it found a live CI failure.** See D0142 below.
5. **ANSWERED as far as it can be.** No mechanism exists to audit, so the useful deliverable is the
   population one would have to cover — see below.

**Item 5's answer without the mechanism: the fuzz suite holds 2 of roughly 8 non-zero bounds.**
In the fuzz suite: `RESIDUAL = {"embedded": 1}` and `DESIGN_TRADEOFF = {"grounded_no_floor": 59}`
(`tests/test_body_fuzz.gd:67-68`). Outside it, and invisible to anything fuzz-scoped:
`GOLDEN_TRAVERSE_TICKS = 225` plus its ±5% tolerance (`tests/test_body_acceptance.gd:14,129`),
`MAX_TICKS = 3000` at three sites (`test_body_acceptance.gd:8`, `body/play_scene.gd:38`,
`body/reveal_scene.gd:18`), `Body.FLOOR_SCAN_ROWS = 48` (ADR 0005, a measured window width), and
`tools/economy_check/check_tier_rule.py`'s `RESIDUAL_NOTE`/`RESIDUAL_ANVIL_FINDING_ID`. So a mechanism
scoped to the fuzzer would cover ~25% of its stated subject — the exact "check that covers less than its
subject" shape the queue named. **Worth noting for whoever builds it:** `check_tier_rule.py` already
carries a residual bound with an Anvil FINDING id attached to it. That is a working precedent for
"a bound that names what it admits," already in the tree, and it is not in the fuzz suite either.

## CLOSED THIS ROUND — CI's duplication gate was red, from this session's own commit (D0142)

`tools/quality_check/duplication.py` is a **blocking** CI step (`.github/workflows/harness.yml:141`) and
was exiting 1 with two clusters, both introduced by `tests/diag_resolve_floor.gd` (D0137, committed this
session as `aba9793`). Red since `aba9793`; found by this queue's sweep, not by anyone reading CI.
Extracted `_spawn_body`/`_random_input` to `tests/body/fuzz_driver_common.gd`, the same response this same
gate already produced once (`DebugSceneCommon`, D0116). Behavior proven byte-identical by a before/after
diff of `test_body_fuzz_fast.gd` (`violations=868`, every gated category 0), with the dirty
`vertical_resolve.gd` held constant across both arms. `duplication.py` now exits 0.

## CLOSED THIS ROUND — the control-plane ruling's two items, one landed and one reported as a blocked premise (D0140/D0141)

The director's ruling on the Codex control-plane audit gave two items. Both are answered; neither changed
`tests/control_plane/`, which the audit found sound and the ruling did not ask to alter.

- **Item 1 (episode-log fork context) — LANDED.** `docs/adr/0006-episode-log-replayable-prefix.md`, D0140.
  The constraint is written down before the format sets, as instructed; no episode log was built and
  nothing forks. Two things the investigation turned up that the ruling did not anticipate: the required
  format already exists (`reveal_replay_driver.gd`'s `(site, seed)` + input-prefix lineage, which
  `docs/ARCHITECTURE.md` §5 already makes mandatory by forbidding "a second, incompatible input-replay
  format"), and that format is already not a complete prefix — its two dialects each drop a different
  `InputFrame` field into positionally identical columns, guarded only by an unrelated header check.
- **Item 2 (lift the `tests/` coupling) — REPORTED, NOT DONE, on the branch the ruling itself
  pre-authorized.** D0141. The prescribed fix is not executable: the coupling is to `Body._px_to_cell`
  (a `sim/` private, not a test helper), it is a coordinate conversion (not grid access — grid access is
  already through `TileGrid`'s real public API), and there is no "real world interface the sim already
  exposes" to route through, because `interface/` contains only a `MODULE.md` that says "no code has been
  written." Reaching around it by re-typing the conversion inline was available and was rejected.

**Two things need the director and are not decided here.** (1) A Codex finding the ruling did not address —
CONSTRAINED restricts distance but not discovery, so it currently cannot measure the discoverability
`docs/ARCHITECTURE.md` §5 says it exists to measure; disclosed in the slice's own comment as a deferral,
but a ruling declaring the contract sound did not weigh it. Filed as an Anvil FINDING
(`ed491e83`). (2) Where a *public* position-to-cell conversion should live, which is the actual liftability
decision and is a `sim/` change to the highest-risk module.

## OPEN, MID-INVESTIGATION — D0139's Option-2 fix hit a SECOND hard stop; uncommitted, awaiting the director's ruling, 2026-08-29

Working tree is DIRTY on purpose, not cleaned up: `sim/body/vertical_resolve.gd` carries an uncommitted
attempt (28 lines added: a new `_full_footprint_solid` static func plus its call site inside
`resolve_floor`), and `tests/test_vertical_resolve.gd` (new, untracked, 6 passing unit tests, one of them
mutation-tested and confirmed load-bearing) sits alongside it. **Do not discard these without reading this
section first — they are mid-investigation evidence, not abandoned scratch work.**

**The ruling this responds to (D0138's own follow-up):** the director correctly re-diagnosed D0138's dead
end as a criterion problem, not a tie-break problem, and ruled Option 2 — `resolve_floor` must check
full-footprint grid-solidity at the chosen landing row, the IDENTICAL condition
`tests/property_checks.gd::grounded_implies_solid_beneath` verifies, before succeeding. Acceptance signal:
`grounded_no_floor` should drop toward the ~4 that were `grid_floor_backstop`-sourced. Explicit hard stop
if it doesn't. Explicit guard: golden traverse time MAY change this round (unlike D0138's), but any change
must be manually verified tick-by-tick as a legitimate correction, not a broken grounding.

**Implemented exactly as ruled.** `VerticalResolve._full_footprint_solid(body, grid, surface)`: computes
`landing_row = Body._px_to_cell(surface)`, checks every column across the body's own current footprint
width is `grid.is_solid()` at that row — duplicated from (not calling) `PropertyChecks
.grounded_implies_solid_beneath`, since `sim/` cannot depend on `tests/`. Wired into `resolve_floor` right
after the existing NO_FLOOR/too-far check. Mutation-tested (disabling the new check via `if false and ...`
broke exactly the new partial-footprint-landing test, once that test's own grid setup was itself corrected
— an earlier version of the test had the LEFT foot sample's own straddle poison itself to NO_FLOOR by
accident, masking the mutation; fixed by widening the solid region so the sample always finds real ground,
confirmed the mutation is now caught).

**Two real findings, both reported to the director, neither acted on yet:**

1. **The full 1000x1500 sweep's acceptance signal did NOT drop — this is the explicit hard stop.**
   `grounded_no_floor` stayed at EXACTLY 59 (not toward ~4). Every other metric identical to baseline
   (`bounds=805397`, `embedded=0`, `overflow=0`, `discontinuity=0`, `deadlock=0`). But the floor_source
   attribution completely FLIPPED: 0/59 now `resolve_floor` (down from 55 pre-fix), 59/59 now
   `grid_floor_backstop` (up from 4 pre-fix). `resolve_floor` correctly stopped grounding on partial
   support every time; every one of those cases now falls through to `grid_floor_backstop`, which grounds
   them the SAME wrong way via a different code path (`_topmost_solid_row` finds the shallowest solid cell
   ANYWHERE across the footprint's columns and snaps the whole box there — the identical criterion flaw,
   not a fix for it). This is the director's own explicitly anticipated "second bug" scenario, verbatim.

2. **A separate real regression against `test_body_acceptance.gd`'s own HARD gate** (not an allowlisted
   fuzzer metric): the scripted golden traverse now stalls at tick 133 (`stall_seconds` 0 -> 0.017s,
   `traverse_time` 225 -> 237 ticks). Traced by hand, not assumed: `HostileChamber`'s RUBBLE zone (columns
   80-88) has a real, AUTHORED 1-row/4px notch at columns 85-86 (solid at row 57, open at row 56 --
   confirmed by direct grid dump) -- exactly the "1-3px sub-pixel rubble slopes" the heightfield's own
   interpolation is documented to exist for smoothing over, NOT a real multi-column gap like D0137's
   diagnosed pit-lip cases. The new exact-same-row full-footprint check cannot tell "legitimate small
   terrain roughness" from "a real gap," so it now rejects a landing that should succeed. This is a real,
   verified "legitimate grounding broken" case per the director's own stated verification protocol, not a
   false alarm — genuinely ambiguous whether `grounded_implies_solid_beneath`'s own single-exact-row
   definition is too strict for authored-rough terrain, a question for the director, not something to
   silently loosen on this session's own authority.

**Explicitly NOT done, per instruction: no attempt to loosen the check, add a tolerance band, revert, or
otherwise resolve either finding unilaterally.** Both were reported to the director in full technical
detail (tick traces, exact grid dumps, the mechanism in both cases) and the session is now waiting on a
ruling. **A fresh session picking this up must read this section before touching `sim/body/
vertical_resolve.gd` or `tests/test_vertical_resolve.gd` — the working tree's own dirty state is the
investigation's own evidence, not something to clean up by reverting or committing without direction.**

## CLOSED — the director's own NO_FLOOR fix was PROVEN a mathematical no-op, reverted, hard stop honored, D0138, 2026-08-29

Working tree clean; HEAD `dc322f6`, everything pushed. Director's ruling on D0137's diagnosis: fix the
sentinel at its source (exclude `Heightfield.NO_FLOOR` from `resolve_floor`'s own `mini()`), with the bound
DROPPING as the acceptance signal, and an explicit hard stop if it didn't: "something is wrong with my
reasoning or yours — stop and report."

**Implemented exactly as specified, mutation-tested BEFORE the full sweep — and the mutation test is what
caught it.** `VerticalResolve._min_real_surface`: exclude `NO_FLOOR` samples, take min of the remainder,
`NO_FLOOR` only if all three were. Reverting it back to a bare `mini(mini(a,b),c)` and re-running its own
four unit tests: **all four still passed — no test can distinguish the two formulations, because none
exists.** `NO_FLOOR` (i32 max) already loses every `mini()` comparison it's ever part of; excluding an
already-guaranteed loser changes nothing, for any input, provably — not an empirical sample, a mathematical
certainty confirmed by trying to break it and failing.

**Confirmed against the real sweep anyway, per instruction not to skip the empirical step.** Golden
traverse unchanged (225 ticks), determinism unchanged, D0122 fixture's own violation count unchanged
(67,119). **The full 1000x1500 sweep: every single metric byte-identical to the pre-fix baseline**
(`grounded_no_floor=59`, `bounds=805397`, `embedded=0`, `overflow=0`, `discontinuity=0`, `deadlock=0`) —
not "didn't drop enough," literally unchanged.

**Hard stop honored: reverted, nothing shipped.** `sim/body/vertical_resolve.gd` back to its exact
pre-attempt state; the new unit test file deleted; nothing was committed before the revert, so the tree is
clean against `HEAD`, not just clean now. Full explanation plus real candidates for what WOULD change
behavior (require all-three-real before `resolve_floor` succeeds; check full-footprint solidity inline) —
offered for the director's own ruling, not decided or built here. D0138.

**Control-plane thread: still holds, still waiting on the director's review of D0134.** This round did not
touch it, per the standing ordering.

## CLOSED — the bound-raise justification was falsified, resolve_floor diagnosed to one mechanism, D0135-D0137, 2026-08-29

Working tree clean; HEAD `aba9793`, everything pushed. The director's own follow-up to the round below:
D0132's telemetry didn't just refine an attribution, it FALSIFIED the reasoning D0128 used to justify
raising the bound (32→59) — "we know what the excess is, it's the accepted D0059 case" was asserted, then
disproven. Ordered response, all three parts done:

**1. D0135 — Anvil FINDING + ledger entry, filed at HIGH severity, stated plainly, not softened.**
`.anvil/log/2026-08-29T084009.244046Z-b497565f.json`. The bound-raise decision's own stated justification
was wrong, caught by the instrument built to check it — not a subsequent audit, not new information. Bound
stays 59; its status moved from "known mechanism" to "measured, mechanism under active diagnosis."

**Prerequisite, its own commit before the diagnosis touched anything near it: `sim/body/body.gd` extracted
(D0136).** It was at 399/400 lines. `_resolve_horizontal`/`_resolve_horizontal_cell`/`_try_climb`/
`_try_step` moved to a new `sim/body/horizontal_resolve.gd` (`HorizontalResolve`, mirroring the existing
`VerticalResolve` split), pure Extract Class, mutation-tested (forcing the new call site into a no-op broke
real tests for real reasons). `body.gd`: 399 → 313 lines.

**2. D0137 — `resolve_floor` diagnosed to ONE exact, fully-characterized mechanism, not fixed.** Built
`tests/diag_resolve_floor.gd` (a one-off diagnostic, not CI-run, mirroring D0123's own instrumented-replay
method) that independently recomputes `resolve_floor`'s own three heightfield samples from OUTSIDE —
`resolve_floor`/`vertical_resolve.gd` untouched throughout, per explicit instruction. Result: `resolve_floor`'s
`mini(s_left, s_right, s_center)` treats `Heightfield.NO_FLOOR` as a large-but-valid height rather than "this
sample cannot vote" — one real-ground sample wins over the others' correctly-reported `NO_FLOOR`, resting
the body's whole footprint on partial support and short-circuiting `grid_floor_backstop` (the documented
backstop for exactly this geometry) via the `or` in `move_and_resolve`. Measured across all 84 occurrences
(55 dig-on + 29 dig-off): 100% show `transition=false` (my own interpolation hypothesis, refuted directly)
and a NO_FLOOR sample alongside a real one, every time. Confirmed pre-existing (29 occurrences with dig
fully disabled) — dig only amplifies frequency by carving more flat-to-open transitions, not a new kind.

**3. Bound status, restated per the director's own explicit framing: 59/32 are measurements, not yet a
justified ceiling.** No fix made or proposed to `resolve_floor`/`grid_floor_backstop`/`_resolve_horizontal`
— this was diagnose-and-report only, per explicit instruction, since this is the highest-risk code in the
module. Whether/how to fix the NO_FLOOR-vs-real-height asymmetry in `mini()` is a real, separate, still-open
future decision, now against a precise description instead of a guess.

**Control-plane thread: still holds, unchanged.** The director is reviewing D0134's canonical types before
any policy wiring — this round did not touch that thread at all, per the explicit "a dominant undiagnosed
grounding path in the highest-risk module outranks new instrument architecture" ordering.

## CLOSED — Codex audit response: D0115 sweep, grounding-path telemetry, ledger corrections, control-plane canonical types, 2026-08-29

Working tree clean; HEAD `abc2eae`, everything through it pushed to `origin/main`. This round answered an
external (Codex) audit of the D0122 dig fix plus the director's own ruling on THE CONTROL PLANE §9, in the
director's stated order — D0115 sweep first, then telemetry, then ledger corrections, then the
control-plane slice — and stopped exactly where each explicit gate said to stop.

**1. D0115 masking-pattern sweep (D0131, commit `16a5621`).** Codex found the D0115/D0117 masking gap
(`exit_code==0` + a passing check without ever grepping the probe's own output for `SCRIPT ERROR:`) still
live in `test_bounds_invariant.gd` and `test_cave_geometry.gd`; grepping every `OS.execute`/
`OS.create_process` site in `tests/*.gd` (the only CI-exercised scope — `legacy/tools/*.gd` matches too but
is confirmed dead pre-pivot code) found a third instance Codex didn't name, `test_fixed_point.gd`'s
div-by-zero probe test. Fixed identically in all three; mutation-tested by injecting a called-function
crash AFTER each probe's own expected behavior (so the pre-existing occurrence-count check alone would
still have passed) and confirming only the new guard caught it, then reverting each probe clean.

**2. Grounding-path telemetry (D0132, commit `db09326`).** Codex's real, unfixed gap: the fuzz harness
recorded a `grounded_no_floor` violation's position but never which of `resolve_floor`/
`grid_floor_backstop`/`try_step` last set `on_floor=true`, so D0127/D0128's "one shared mechanism" claim
rested on shared HEIGHT alone. Added `Body.floor_source_this_tick`, purely additive (no bound or grounding
logic touched), mutation-tested (stripping all three assignments broke exactly the three real assertions
in the new `test_floor_source_telemetry.gd`, nothing else). First real run already mattered: the 498-seed
dig-on population split 55 `resolve_floor` / 4 `grid_floor_backstop`; the full dig-off population split 29/3
— 84/91 combined is `resolve_floor`, the OPPOSITE of "one shared mechanism." `sim/body/body.gd` is now at
399/400 lines (`FILE_LIMIT`) — one line of headroom; the next change there needs to extract something
before adding.

**3. Ledger corrections (D0133, commit `ea506de`) — D0127/D0128 left untouched, corrections appended, per
explicit instruction.** Two Anvil FINDINGs filed
(`.anvil/log/2026-08-29T082101.373601Z-1b569c4f.json`, `.anvil/log/2026-08-29T082115.567359Z-b9f39d55.json`)
plus a ledger entry: (a) the "all 91 violations share one mechanism" claim was not merely unproven as Codex
found, D0132's own telemetry shows it is actively wrong for 84/91 of the population — restated as measured
bounds (59/32, unchanged) plus "same height, not same code path, now measured and mostly NOT the named
mechanism"; (b) D0128 silently hardened D0127's own explicit "plausible, not yet independently verified"
hedge on the water-mark fix's own bounds contribution into an unqualified "accepted... attributed
consequence" — hedge restored, `bounds` still reported-not-gated, no decision reopened.

**4. THE CONTROL PLANE canonical obs/action types (D0134, commit `abc2eae`) — stopped exactly at the
explicit gate.** Director's ruling on the foundation gap this session's own §9 response flagged: build the
minimal slice on `tests/` ground (not a real, not-yet-built `interface/`), label it explicitly as SIMULATING
Boundary A. `tests/control_plane/`: `CanonicalObservation`, `CanonicalAction` (Raw level only — Semantic
`goto`/`mine`/`place`/`haul_to` deferred), `ObservationSpec` (Oracle/Constrained envelopes — Language
deferred, ARCHITECTURE §5's own "never in CI"), and a pure `ObservationBuilder` (no policy argument, per
S4). Anti-cheat property (CONSTRAINED never reads a cell outside its own radius) proven directly and
mutation-tested (forcing CONSTRAINED to take ORACLE's own full-grid branch broke both relevant assertions).
**Zero Policy/Adapter/Episode-Log/Goal/Scorer code written — this round's own explicit instruction was "show
me the canonical types before the policies are wired," and this is exactly where it stops.** Next action on
this thread: awaiting the director's review of these types before any policy gets wired against them.

**Incident from the prior round, status unchanged — still the standing rule.** The fork-completion
reconciliation tool (`tools/check_fork_completion.py`, D0130) exists but nothing calls it automatically; no
forks were spawned this round (everything done directly), so it was not exercised again. Still: serial
forks only in a shared tree until the reconciliation step is a reflex, not a novelty.

**Thread 2, OPEN, not started, untouched this round: the persistent-world design reversal.** A large
director brief (full text only in this conversation's own history, not yet in any tracked doc) reversing
the 2026-08-25 run-based roguelite pivot back to a persistent single shaft + rig-as-consumer — not the same
as the already-closed 2026-08-27 reversal `docs/GDD.md` §9 already records. `docs/GDD.md` (343 lines) was
read in full in an earlier round; **zero edits made to it or any other doc.** A fresh session picking this
up needs the brief's own full text re-supplied (re-read from the transcript, or ask the director to
re-paste it) before touching `docs/GDD.md` — do not attempt its edit list from memory or a summary.

**Thread 2, OPEN, not started, mid-read when interrupted: the persistent-world design reversal.** A second
large director brief (also only in conversation history, not yet in any tracked doc) reversing the
2026-08-25 run-based roguelite pivot back to a persistent single shaft + rig-as-consumer — NOT the same as
the already-closed 2026-08-27 reversal `docs/GDD.md` §9 already records; this is a newer, further one on
top of it, with its own full §0-§8: a new §1 premise paragraph, locked decisions replacing/amending §7, a
new §3 water-equilibrium section, an economy spine (D1-D6 verbs, two tier-2 materials, a heat-not-hardness
tier-3 gate) for `tools/economy_check/`, honestly-stated open gaps, a full mechanical §6 edit list for
`docs/GDD.md` (verbatim-keep / edit / retire per section, plus a full inlined §10 worked curve), and §7's
four engineer-agent prompts to WRITE (not build) in priority order, sequenced so prompt 1 (a 10-minute
Anvil-episode play test of the fuel/forge/hole-trick loop) ships before 2-4 consume real effort. This
session read the current `docs/GDD.md` (343 lines) in full in preparation and made **zero edits to it or
any other doc** before being interrupted by the fork-coordination incident, then the Control Plane brief.
**Nothing from this thread has landed anywhere. A fresh session picking this up needs the brief's own full
text (only in this conversation's history) before touching `docs/GDD.md` — re-read it from the transcript
or ask the director to re-paste it; do not attempt the edit list from memory or a summary.**


## CLOSED — D0122 fully closed (D0128), D0129 replay driver built against a synthetic trace, 2026-08-29

Two director rulings executed, then the replay driver built (all three explicitly sequenced by the
director as one continuous cycle).

**D0128 — both D0122 residuals resolved on the director's own terms:**
1. `grounded_no_floor`'s `DESIGN_TRADEOFF` bound raised 32→59 in `test_body_fuzz.gd`, WITH the cause
   documented in the same commit — explicitly not the patch instinct, since D0127 already named every
   admitted violation (the same D0059f pit-lip mechanism, now reachable at more player-carved locations).
   Full 1000×1500 sweep re-run: `test_body_fuzz.gd` now ALL PASS.
2. `bounds`'s water-mark-fix-specific +11.4% accepted as a real, attributed cost (dig-off A/B already
   proved the attribution in D0127); noted in the ledger as the place a future investigation starts if it
   ever moves again without a corresponding dig change.
3. D0122 closed end to end in the ledger (D0128): root-caused, fixed at the input, regression fixture
   permanent, both residuals resolved — nothing about the arc left open.
4. Also corrected a stale "seed>=98" overclaim in `test_body_fuzz_fast.gd`'s own docstring, falsified
   directly by D0127's data.

**D0129 — the replay driver, built against a synthetic trace, real-human validation still owed:**
Connects a recorded `reveal_scene.gd` session to `RevealMetric.compute`. `reveal_scene.gd`'s grid/spawn
construction extracted to `tests/body/reveal_session_setup.gd` (`RevealSessionSetup`) so the live scene
and an offline replay build the IDENTICAL session from `(site, seed)` — added to the recording's own
header, previously absent and load-bearing. `tests/body/reveal_replay_driver.gd`
(`RevealReplayDriver.parse_log`/`.replay`/`.compute_from_log`) rebuilds a session and replays its recorded
inputs through the real `Body.tick()`, collecting only `dig_event_this_tick`/`dug_material_this_tick` per
tick — honoring the anti-cheat property (no feature location, ever) by construction. `tests/body/
replay_reveal_scene.gd` is the CLI front end.

Proven, not assumed: a live session and its own replay match EXACTLY, 0/713 ticks mismatched. Explicitly
NOT proven: claims/C004 itself — the trace used is agent-generated (scripted, deterministic), not real
unscripted human play, which C004's own anti-cheat design specifically requires. The hands-on-keyboard
`--play` session remains the open, owed next step.

Built via two parallel forks (disjoint file ownership, both in the single shared working tree — no
worktree isolation used, nothing to merge). A real gate failure (a 54-line function against the 50-line
function-length fence) that neither fork's own narrower run surfaced was caught by this session's own
full local gate sweep and fixed via a real extraction, not a suppression.

Full detail, exact numbers, and reversal cost: `docs/DECISIONS_LEDGER.md` D0128/D0129.

## CLOSED — D0127: diagnosing (not fixing) `grounded_no_floor`'s residual and `bounds`'s rise, 2026-08-28

Director's follow-up on D0125's own two "felt wrong even though it passed" items. Both isolated by a
controlled dig-off A/B (new `--no-dig` flag on `fixture_body_fuzz_probe.gd`, D0127), neither fixed, per
explicit instruction (both are rulings, not fixes).

1. **`grounded_no_floor`: dig-off = 32, an exact match to the pre-dig baseline.** Rules out a
   pre-existing bug predating this session. The 27-violation excess under dig-on is NOT a new,
   distinct dig-created defect either — every one of 91 violations (32 dig-off + 59 dig-on) rests at the
   exact same height, `HostileChamber.FLOOR_ROW`, the signature of the already-accepted D0059f/D0061
   pit-lip trade-off, not a varying-height staircase fragment. Dig simply adds more reachable lips at
   that same height (carving new holes into previously-flat floor) on top of the chamber's own several
   built-in transitions. Not the same thread as the untraced dy=0 discontinuity (seed=497) — that seed
   appears in neither the dig-on nor dig-off `grounded_no_floor` seed lists.
2. **`bounds`: dig-off = 18,157, essentially the pre-dig baseline (18,218).** Confirms dig itself (not
   something else this session touched) drives the increase. This session's own water-mark fix adds a
   further +82,742 (+11.4%) on top of D0124's dig-on-only 722,655 — plausible (more excavated per dig
   removes more supporting ground near the map edges) but not independently proven this cycle.

Full reasoning, exact seed lists, and the `pos_y=14417920` arithmetic: `docs/DECISIONS_LEDGER.md` D0127.
Open for the director: whether to re-baseline the D0061 bound now that its growth is understood, and
whether the water-mark fix's own `bounds` contribution is an acceptable known cost.

## CLOSED — D0122/D0123's dig-mechanic fix, D0125/D0126, 2026-08-28, budget 1hr/12 commits

Director's ruling on the `_handle_dig` design question (three alternatives rejected — whole-column dig
destroys the core mechanic, refuse-if-would-strand is an invisible rule, fragment cleanup is a
resolver-patch — per-column high/low-water mark chosen) executed per the one-hour, ordered cycle. No
hard stop hit. 2 commits (the fix itself, plus a same-cycle follow-up rename forced by a CI gate the
local run hadn't checked).

1. DONE (D0125). `TileGrid.extend_terrain_dig_extent` (renamed from `extend_dig_extent` mid-cycle —
   `check_coordinate_naming.py`, D0020, correctly caught the un-prefixed public Vector2i-returning
   function name; CI-only gate, not run locally before the first push) merges a dig touch into its
   column's own historical [min,max] and returns the union; `Body._handle_dig` now excavates that
   merged range instead of just its own current touch. `_resolve_horizontal` untouched, per the ruling.
   New unit tests (`test_tile_grid.gd`) and one integration test (`test_body.gd`,
   `_test_dig_gap_between_two_touches_in_the_same_column_is_closed`) mutation-tested twice (the merge
   logic's `mini`/`maxi`, and `_handle_dig`'s own wiring) — both mutants caught, both reverted clean.
2. ACCEPTANCE GATE MET. Full 1000×1500 sweep: `discontinuity` 3→**0**. `embedded` 187→**0**,
   `grounded_no_floor` 95→**59** — both moved substantially, confirming the shared staircase root cause
   per the director's explicit "do not declare victory on discontinuity alone." `bounds` (reported, not
   gated) 722,655→805,397 — an unexplained 11% rise, not traced this cycle.
3. DONE (D0126). First nightly-escape-to-per-commit regression fixture,
   `tests/test_body_fuzz_regression_d0122.gd` (QUALITY gate 29): replays the minimal known-reproducing
   prefix (seeds 0-497 on one shared grid, matching the fuzzer's own accumulation structure — a
   fresh-grid replay of seed=497 alone reproduces nothing) and asserts `discontinuity==0`. ~53s. Passes
   clean against the fix; mutation-tested against the pre-fix behavior (`discontinuity=3`, matching
   D0124's own count exactly).
4. Both commits pushed, CI green on both (the second push fixed the coordinate-naming gate the first
   one tripped).

**Two things reported, not smoothed over (the director's own ask for "anything that felt wrong even
though it passed"):** `grounded_no_floor` (59) sits above the pre-dig D0061 `DESIGN_TRADEOFF` bound (32)
in `test_body_fuzz.gd` — real, unexplained, ~2x the old baseline. The bound was deliberately NOT edited
this cycle (would repeat the resolver-patch instinct the ruling rejected for `_handle_dig`); this is an
open question for the director, not resolved here. `bounds`'s own rise (722,655→805,397) is similarly
unexplained and untraced. Neither blocks anything currently gated (`test_body_fuzz.gd` is nightly-only).

Still open, unchanged from before this cycle: the replay driver (real session → `RevealMetric`), the
`history/` 165-image pre-pivot cull, and the hands-on-keyboard `--play` test — none blocking, all owed.

## CLOSED — director's execution-dense queue, 2026-08-28, budget 1hr/12 commits

Autonomous, execution-dense (specs settled, not judgment-dense). All four items closed, no hard stop
hit, within budget (4 commits).

1. DONE (D0099). Wire the four quality instruments into CI at decided tiers — CI confirmed green.
2. DONE (D0100). `_resolve_horizontal` refactor: complexity 24 → 13 worst-case, two Extract Methods,
   behavior verified byte-identical (full fuzzer + fast fuzzer + 5 other suites, before/after diffed).
3. DONE (D0101). `resolve_ceiling` (6, exactly at the fence) and `resolve_floor` (7, no D0059 defect)
   left alone, stated why. `move_and_resolve` 11→9 (partial, real — remaining complexity is the substep
   loop's own control flow). `grid_floor_backstop` 10→3, fully resolved. Behavior byte-identical again
   (full fuzzer + 8 suites). A small correction to D0098's FINDING recorded (which function held which
   defect, one level more precise — doesn't change the FINDING's core claim).
4. DONE (D0102). Full-tree sweep required fixing a real scope gap first: `scan.find_gd_files()` was
   `GAME_DIRS`-only, missing `tests/` entirely despite its own docstring claiming parity with
   `check_size_limits.py`. Fixed (now genuinely the same scope, proven by a set-equality mutation test),
   then swept: one real cluster (`_flat_grid`, `test_body.gd`/`test_heightfield.gd`), unambiguous, fixed
   by moving it into the shared `test_base.gd` both already extend. 0 clusters now, both languages,
   across the actually-whole tree.

## Micro-loop finding + reveal-layer test, 2026-08-28 — CLOSED

Director's design finding, landed via brief: the rig-as-consumer macro-loop has no micro-loop underneath
it (three want-layers: Reveal, Flow, Pressure — `docs/GDD.md` §12). Reveal is the only one in scope this
round; Flow and Pressure are named, confidence-marked, and unbuilt. No hard stop hit. Budget: one hour /
24 commits; closed at ~50 minutes, 6 commits.

1. DONE (D0107). `docs/GDD.md` §12 landed (inserted, old §12/§13 renumbered to §13/§14 — zero external
   cross-reference risk, verified by grep before deciding). Pointers added at §3, §8, §10. `CONTEXT.md`
   updated.
2. DONE (D0108/D0109). `claims/C004-reveal-raises-dig-persistence.md` filed BLOCKED — metric corrected
   per the director's own reframe (dig-rate lift after a reveal, never feature location) after my
   original read flagged the brief's first formulation as circular against
   `docs/EXPERIENCE_EVALUATION.md`'s own Readiness Gate 6.
3. DONE (D0110/D0111/D0112/D0113). Dig mechanic built (horizontal-only, edge-triggered, whole-column,
   no hardness gate — D0110); legacy `layered_world_gen.gd` checked first per the director's explicit
   ask, its vein/pocket placement reused via `ShaftGenerator`'s existing `_grow_vein`, its persistent-
   world-tied structure correctly NOT ported wholesale (D0111); two real bugs found only by actually
   running `tests/body/reveal_scene.gd` end to end, neither caught by that commit's own first-draft unit
   tests — a right-facing target-cell off-by-one (D0112) and a single-row dig that couldn't be walked
   through a 10-cell body (D0113), both fixed, both tests rewritten to stop deriving their own expected
   values from the function under test.
4. DONE (D0114/D0115). `tests/body/reveal_metric.gd`'s `RevealMetric.compute` (dig-events-per-session +
   before/after dig-rate window around a qualifying reveal, explicit anti-cheat docstring per D0109) —
   its own first-draft test suite had 2 test-authoring bugs (a strict inequality at an exact boundary, an
   under-sized array denying the second reveal a full window), both fixed, both root-caused as test bugs
   before touching `compute()` (D0114). The window-boundary guard mutation-tested clean (D0114) — which
   surfaced a real, unrelated FINDING about the shared test harness itself: a mid-test `SCRIPT ERROR`
   crash still exits 0 and still prints `ALL PASS` (D0115), flagged for the director rather than fixed
   here (touches `tests/test_base.gd`, shared by every suite in the project — a real design decision
   about shared infrastructure, not a parameter this round owns).
5. DONE. Three screenshots captured (`history/153-the-glimmer-in-the-wall.png`,
   `154-reveal-density-sparse.png`, `154-reveal-density-dense.png`) via `reveal_scene.gd`'s agent mode,
   not literal `--play` — no human keyboard was available to this session, flagged plainly in
   `history/README.md` rather than glossed over. `history/`'s unapplied cap-of-12 policy (set 2026-08-25)
   is still unapplied as of this round (168 images total); the 3 additions were made without a swap-one-
   out, flagged in `history/README.md` rather than either silently violating the policy or unilaterally
   executing the 165-image pre-pivot cull, which is not this session's call.
6. NOT BUILT, honestly scoped out rather than rushed: a replay-driver reading a real recorded
   `tests/body/recordings/*.log` session into a `RevealMetric.TickEvent` array (the piece that would let
   `claims/C004` run against a real session instead of only synthetic test data). Stopped here at ~50
   minutes with a complete, tested, mutation-tested instrument rather than starting a second chunk of
   work with its own bug-discovery risk this late in the budget. Clear next step, not a gap glossed over.
7. DONE, incidental. `tools/quality_check/duplication.py` (blocking gate) caught a real exact-shape
   duplicate cluster between `reveal_scene.gd` and the pre-existing `play_scene.gd` it was modeled on
   (`_record_tick`, `_notification`) — fixed by extracting the shared logic into a new
   `tests/body/debug_scene_common.gd`, not by excluding or loosening the gate. Full non-nightly test
   suite (17 suites, fast fuzzer included) re-confirmed green after the refactor.

HARD STOPS (director's, unchanged): determinism regression, gate red not clearable in one attempt, a
design decision surfacing rather than a parameter, touching `data/economy/` or the flow/pressure layers.
None hit. D0115 (test-harness finding) is exactly the "design decision surfacing" case — recorded and
left for the director rather than resolved under this round's authorization.

## Director's response to the reveal-layer report — D0115 fix, sweep-blindness hunt, density fix, 2026-08-28 — CLOSED

Director prioritized, in order: (1) fix D0115, the harness's own trustworthiness, before anything else —
"the most important thing in this report"; (2) a deliberate hunt across the whole repo for the same
exit-code/pass-fail masking pattern, not just the two incidental catches; (3) the density-contrast
screenshots read too weak — confirm the range is real, widen if not, report actual counts; (4) the
replay driver, downstream of a trustworthy harness; (5) the `history/` 165-image cull, as its own pass,
whenever. The hands-on-keyboard `--play` test stays explicitly open/owed, not closed by any of this.

1. DONE (D0116). `tools/run_gd_test.sh` — wraps every suite invocation, fails on a `SCRIPT ERROR:` line
   regardless of exit code. Root cause precisely determined (not assumed): a crash directly in
   `_initialize()` hangs; a crash in any function it calls (every real suite's own shape) silently
   continues past it instead. `tests/fixture_harness_crash_probe.gd` + `tools/test_run_gd_test.sh` prove
   the pre-fix bug, then the fix, then a negative control — the director's own explicit TDD bar, met.
   Wired into `.github/workflows/harness.yml` (18 suite invocations); `test_reveal_metric.gd` was also
   found never wired into CI at all and fixed in the same pass. `core/MODULE.md`'s stale hang-only claim
   corrected. `docs/QUALITY.md` gate 28 added.
2. DONE (D0117/D0119/D0120). The hunt: audited every `.sh`/hook/Python-subprocess/GDScript-`OS.execute`
   call site. Two more real instances found and FIXED, not just noted: `.githooks/pre-commit`'s
   base-namespace gate had silently no-op'd for 119 commits since the pivot moved its target file to
   `legacy/` (re-ported to `tests/test_base.gd`, a real bug found and fixed while porting, wired into CI
   too); the fuzz probes' own crash-detection couldn't see a non-hanging crash in `_check_tick()` — fixed
   with the same `SCRIPT ERROR:` guard, confirmed by actual injection (every pre-existing check stayed
   green; only the new one caught it). D0118 separately consolidated the tautological-test-oracle class
   (D0112/D0113/D0114) as its own named failure, distinct from sweep-blindness.
3. DONE (D0121). Density screenshots re-diagnosed: the real counts were already a strong ~4x contrast
   (dense=312/sparse=78, `test_shaft_generator.gd`) — the CAPTURE was the bug (a body-following zoom-6
   camera shows ~28% of the topsoil band, a noisy local sample). Fixed with a new `--wide-view` capture
   mode, not a parameter change; `history/154-reveal-density-*.png` replaced in place with the corrected
   pair (same-round first draft superseded, not kept alongside it — 168 images, unchanged count).
4. FINDING, DIAGNOSED, FIXED — see "CLOSED — D0122/D0123's dig-mechanic fix, D0125/D0126" at the top of
   this file. (D0122/D0123) — surfaced by this round's own gate diligence, not sought: running the FULL
   (nightly-only) fuzzer for the first time since dig existed found a real,
   confirmed (A/B-verified) regression — `embedded` 187 vs. a bound of 1, `grounded_no_floor` 95 vs. 32, a
   brand-new `discontinuity` class at 4 (should be hard zero), all four returning to their EXACT
   established baselines with dig disabled in a controlled re-run. Already on `main` (dig landed at
   `3181c30`), invisible to the fast per-commit fuzzer, invisible to every gate CI actually runs.
   `discontinuity` root-caused by instrumented replay (D0123): dig is confirmed NOT mid-tick (it's the
   tick's own last step); the real interaction is cross-tick — dig can leave jagged, sub-cell-scale solid
   fragments a generated chamber never produces, later straddled by the body's own shifting footprint,
   triggering a `_resolve_horizontal_cell` depenetration correction the fuzz probe's own
   `_max_legit_displacement` never accounted for (a real, separate, non-design test-harness gap) on top of
   a genuine `sim/body` design question (whether/how to bound depenetration distance or change what dig
   leaves behind) — flagged for the director per their own instruction to stop rather than pick a fix.
5. NOT STARTED. The replay driver (real recorded session → `RevealMetric`) — correctly sequenced after
   D0115/D0117, which is now closed, but this round's time went to the harness fix, the hunt, and (once
   discovered) triaging D0122 instead.
6. NOT STARTED. The `history/` 165-image pre-pivot cull — explicitly the director's own call, whenever.

HARD STOPS: none of the ORIGINAL four hit. D0122 is a new, different thing — not a stop this round
crossed, a live defect this round's own diligence uncovered on a round already closed and pushed.

## Director's follow-up round on the execution-dense queue, 2026-08-28 — CLOSED

Four items from the director's response to the queue above. No hard stop.

1. DONE (D0103). `move_and_resolve` at complexity 9 (against a 6.0 fence) — left alone, per instruction:
   the remainder is the substep `while` loop's own control-flow shape, not reducible by pure mechanical
   extraction without turning `break`-based loop control into a return-value contract, which is a design
   decision. Recorded as a known, accepted outlier directly in the function's own docstring, with an
   explicit acceptance condition (complexity comes down when the function is next touched for any other
   reason) — not reopened now, since chasing the number itself is the thing these instruments exist to
   prevent.
2. DONE (D0105). The `tests/`-unscanned bug named as one consolidated Anvil `FINDING`
   (`.anvil/log/2026-08-28T233251.702582Z-d3f72a5f.json`), citing three prior instances (D0026, D0091,
   D0075) as the same law: a sweep bounded by its own author's model of the corpus cannot see outside
   that model, and a green result from it is evidence only about the covered subset. Concrete
   follow-through: every `quality_check` instrument's scan scope audited and tabulated
   (`tools/quality_check/README.md`, "Scope, instrument by instrument") — `duplication.py`/
   `function_length.py`/`complexity.py` all share `scan.all_functions()` so D0102's fix already closed
   the gap for all three; `coupling.py`'s narrower `sim/`+`tools/` scope is a stated design decision, not
   a hidden gap, with one latent (not live) non-recursive-glob gap named for the record.
3. DONE (D0104). The D0098 FINDING's inaccuracy (it attributed D0059 defects #2 AND #3 to
   `resolve_ceiling`; #2's actual fix lives in `move_and_resolve`, the caller) corrected via a real
   superseding Anvil `FINDING` event (`.anvil/log/2026-08-28T233126.646482Z-23f40fb0.json`,
   `--supersedes=` the original) — original event untouched, per the project's append-only discipline.
4. DONE (D0106). Test code's place in the quality instruments, decided once: same self-calibrating IQR
   methodology as production code, computed against test code's OWN population, reported as its own
   labeled section — never pooled (would distort the fence for both), never a looser a priori number
   (would be "a guess wearing a decision's clothes"), never exempted (would recreate a blind spot right
   after D0102/D0105 closed one). `scan.is_test_func` classifies by this repo's own existing `tests/`/
   `test_*.py` conventions. `function_length.py`/`complexity.py` restructured into four buckets each
   (GDScript production/tests, Python production/test_*.py); frozen advisory guardrails stay
   whole-Python-population, unsplit, since they're an absolute drift tripwire, not a distributional read.
   Verified against the live tree: test code's own fences sit measurably above production code's on both
   instruments (GDScript production length fence 19.5 vs. tests/ 25.0; complexity 6.0 vs. 6.0; Python
   production length fence 50.0 vs. test_*.py 42.5; complexity 14.5 vs. 8.5) — confirms the pooling
   concern was real. `test_quality_check.py` needed six lines of reference repair (the guardrail's result
   key moved), not new cases — 41/41 OBSERVED, count unchanged by this restructure.

Ratio (`check_loc_ratio.py`, re-measured, not recalled): absolute 5.430 (instrument 8,063 / game 1,485),
still ADVISORY (game LOC under the 2,000-line floor). Game LOC moved (+61 over the trailing 10 commits)
but only from refactor signature extraction (`_resolve_horizontal_cell`/`_try_climb`/
`_resolve_substep_collision`/etc.), not economy content — stated plainly, not read as progress toward the
target; the number comes down only once `data/economy/` produces machines, which is the director's next
work, not this session's.

## tools/quality_check/ — four code-quality instruments, 2026-08-28 — CLOSED

Director-requested, unrelated to `data/economy/`. Correctness gates existed; nothing measured modularity
or duplication ("the previous project carried six near-identical copies of one function across fifty
layers and nothing flagged it, because nothing was looking"). Built four instruments — function length,
duplication (weighted as most important per instruction), complexity, module coupling — as a DASHBOARD
(no gate, no exit-code reaction to a finding), self-calibrating IQR outlier fences, not a priori
thresholds. Full reasoning and design decisions: `docs/DECISIONS_LEDGER.md` D0096.

**Follow-up round, same day, CLOSED (D0097):** all four of D0096's own findings acted on. `core/_ushr`
extracted to `core/bit_ops.gd` (a test-file reference the original grep missed was caught by actually
running the Godot suite, not anticipated — fixed, both suites re-run, ALL PASS). The two `tools/
layer_lint/find_gd_files` duplications extracted to `tools/layer_lint/gd_scan.py` (two genuinely
different filter styles kept as two named functions, not forced behind one flag). The `main()` cluster
calibrated as a named, length-bounded, mutation-tested exclusion (`duplication.
MAIN_BOILERPLATE_MAX_LINES=8`) — its risk (a future short-and-duplicated `main()` would be hidden)
logged as a real Anvil `DECISION` event, not only ledger prose, matching D0074's own precedent. A shared
CLI harness (`scan.run_cli`) extracted so the fix is real, not just excluded from the report.
`duplication.py` confirms 0 clusters where it found 4 at D0096.

**LOC went up, not down — stated plainly, same as D0096's own overrun.** 847 implementation / 265 test /
1,112 total (was 794/217/1,011). The `main()` boilerplate that came out was only 16 lines; the named
exclusion + its risk statement (+29) and the harness's new home (+18) — both explicitly required this
round — added more back. Full accounting in D0097 and `tools/quality_check/README.md`'s LOC section.
21/21 mutation cases OBSERVED (17 → 21, four new cases for the exclusion). All gates re-run and PASS.

**Third round, same day, CLOSED (D0098).** Four follow-ups on D0097's report, plus one incidental fix.
`FUNC_LIMIT=50` reconciled with the IQR fence as a documented ceiling, not lowered — lowering it would
force an immediate split of several working, tested functions with no defect driving the change. A
FINDING filed for the `_resolve_horizontal`/D0059 complexity correlation — checked against the real
source first, found narrower than the director's own initial framing (1 of 4 defects directly in that
function, not all 4), filed with the corrected scope rather than the stronger claim. Python advisory
guardrails set (`PY_LENGTH_GUARDRAIL=42.5`, `PY_COMPLEXITY_GUARDRAIL=13.5`), frozen and independent of
the self-calibrating fence — proven decoupled by mutation test, and the decoupling showed up for real
within the same round when later edits moved the live fence to 47.5. Stub modules excluded from
`coupling.py`'s corpus (named in the report, not hidden) — confirmed as the actual cause of `sim/`'s
false "4 outliers": re-run with the exclusion drops it to 0. Incidental: `docs/archive/session-exhaust/`
never had a `.gdignore` (unlike `history/`), so its 88 tracked `.import` sidecars drifted stale every
`--import` run — fixed the same way as `history/`, sidecars untracked (files stay on disk).

`tools/quality_check/` now 929 implementation / 353 test / 1,282 total (was 847/265/1,112), reported
plainly, all real content. Still not wired into CI — the director's stated condition (thresholds decided,
stub question settled) is now met, but wiring itself is a separate instruction not yet given.

## tools/economy_check/ — the tier-rule checker, 2026-08-28 — CLOSED

Director-requested design instrument, built ahead of `data/economy/` (which the director authors
separately). Two rounds: a schema proposal (chat, stopped for review per explicit "propose the schema
first and stop" instruction), then this round's build, after the director approved the schema and
issued four decisions plus one addition — clause (a) decided by structural reference not author
self-classification, D2's provenance exemption removed, the scope boundary stated in the checker's own
output not just its docstring, and breach reachability added as a fourth check. Full reasoning and a
fifth decision found during implementation (clause (b) needed the same "referenced elsewhere" discipline
as clause (a), or every hardness-escalator chain passes it trivially) — `docs/DECISIONS_LEDGER.md`
D0092.

Built: `tools/economy_check/schema.py`, `check_tier_rule.py`, `README.md`, `test_check_tier_rule.py` —
19 mutation cases across the director's 5 fixtures plus the breach-reachability addition, all OBSERVED.
CLI verified directly against two hand-built chain files. 376 implementation / 255 test / 631 total LOC.
No `data/economy/` content, no `core/`/`sim/` code touched. All gates re-run and pass.

**Follow-up round, same day, three items, `docs/DECISIONS_LEDGER.md` D0093:**
1. Reference integrity — `check_reference_integrity` + `schema.REFERENCE_FIELDS`, mirroring
   `tools/anvil/schema.py`'s typed-reference discipline exactly (director's explicit "the two schemas
   stay consistent" instruction). `check_chain` skips the four graph-query checks on a broken reference
   rather than crashing. 12 new mutation cases, one of which caught a bug in its own fixture.
2. The two-hop decorative gap named in the checker's output (`RESIDUAL_NOTE`, printed every run), not
   just its docstring — demonstrated with a concrete witness, not just asserted. Left open, per
   instruction — not fixed.
3. Logged as an Anvil `FINDING` (`source_class: artifact-instrument`), `.anvil/log/2026-08-28T165338
   .936688Z-a677726d.json` — `check_integrity.py` re-run, 5 events, referentially sound.

`test_check_tier_rule.py` now 34/34 OBSERVED. LOC: 484 implementation / 375 test / 859 total.

Stopped, as instructed — "I author the real rows against it," now with the director present next.
Director's close on the checker: "done, mutation-proven, and CI-green before any real economy exists to
launder it." Confirmed, this session: authoring `data/economy/` D1-D6 is design work reserved for the
director; this instrument does not author content and does not resolve open design questions.

**Pulled forward the same day, `docs/DECISIONS_LEDGER.md` D0094:** the `--json` output mode above was
parked as "build when there is data," then un-parked — director's reversal: it should exist BEFORE the
real rows land, not after, same ordering as the checker itself preceding the economy. Built:
`check_tier_rule.to_json_report`, structured per-check pass/fail + the specific demands/materials
implicated in any failure + the residual gap and scope note as structured fields (not prose) +
`--json` CLI flag. Explicitly NOT wired to `.anvil/log/` — no `append.py` call anywhere in this round's
code, that wiring waits for real data to measure. `test_check_tier_rule.py` now 44/44 OBSERVED (two more
self-caught fixture bugs, same class as D0093's). LOC: 566 implementation / 500 test / 1,066 total.

**Baseline snapshot, `docs/DECISIONS_LEDGER.md` D0095**, director-requested before `data/economy/`
content starts landing: `tools/economy_check/` 566/500/1,066. Instrument/game absolute ratio 4.652
(6,625/1,424), game LOC unchanged at 1,424 all session. Anvil implementation 513/1,000 cap (51.3% used).
`.anvil/log/` 5 events. Full detail and per-figure verification in the ledger entry, not repeated here.

Stopped again, as instructed — "the next substantial thing is D1 through D6... comes to you as authored
data with the checker already green on it, not as a design task."

## External audit response — surviving run-structure specifications, 2026-08-27 — CLOSED

An external (Codex) audit read the documentation corpus cold, independent of both prior sweeps, and
found live run-structure specifications neither sweep caught: `CLAUDE.md`'s auto-loaded reading order
still pointed at retired `C001`; `docs/CLAIMS.md` and `docs/ARCHITECTURE.md` §5/§6 (the methodology and
scenario-format documents) used `C001`/Draft A as live worked examples; eight `sim/*/MODULE.md` files
still specified the run-based flood clock, per-run terrain generation, or run-ending termination events;
several `harness/*`/`shell/`/`data/progression/` files used "run" ambiguously; `docs/GDD.md`'s own §9
dead-list collided in wording with its own §1 premise; `C003` carried a citation error of its own.

Verified every claim independently before acting — two of the audit's own findings were downgraded
(CONTEXT.md/README.md's "a run must complete with no renderer" is the harness-execution sense, not a
contradiction; the tier-rule "decorative demand" attack is real but out of scope since `data/economy/`
doesn't exist yet, held for the director per their own instruction) and one pre-existing, reversal-
unrelated gap (`docs/README.md`'s normative table missing three documents `CLAUDE.md` already calls
normative) was fixed anyway per explicit instruction, since it's document governance itself.

**New standing rule adopted this round:** "run" is reserved for evaluation/harness executions
(`sinkforge run`, a scenario execution, "an agent run"); "a session" or "a playthrough" for the
sim-execution/game sense. Removes the need to disambiguate by context. Checked, not assumed, across
every touched file — several "run" instances turned out to already be correct under this rule and were
left alone (verified individually, not pattern-matched).

Eight commits, grouped by surface per the director's explicit ordering:

- [x] a. `CLAUDE.md` alone, first — `54dbe60`, D0084.
- [x] (governance) `docs/README.md`'s normative table — `caaa19f`, D0085.
- [x] b. `docs/CLAIMS.md` + `docs/ARCHITECTURE.md` §5/§6 — `aa3ca85`, D0086.
- [x] c. `sim/*/MODULE.md`, the eight with real content — `eaade2a`, D0087.
- [x] d. `harness/*`/`shell/`/`data/progression/` wording standardization — `ee68508`, D0088.
- [x] e. `docs/GDD.md`:7 + the persistent-world disambiguation (`docs/GDD.md`:219, `docs/DECISIONS.md`) —
      `94fcd2e`, D0089.
- [x] f. `C003`'s citation fix — `1f07a0d`, D0090.
- [x] meta-finding: the bounded-sweep pattern, second instance after D0026 — `84a21de`, D0091.

Stopped, as instructed. `data/economy/` waits for the director — the corrected reachability rule and the
tier-rule "decorative demand" critique both wait for that session, not before.

## Design reversal — run-based roguelite to persistent single shaft, 2026-08-27 — CLOSED

All six commits landed (`ebf17e1`, `23118e8`, `f415b5e`, `fc03219`, `31b1f84`, `87f127b`), each with its
own ledger entry (D0076-D0081), no code touched (confirmed via `git diff --stat -- '*.gd'` across the
full range — zero results). Stopped before `data/economy/`, as instructed. Full detail below is kept as
the record of what was decided and why, not trimmed, matching how the ANVIL and stage-4 queues above are
kept in this file after closing rather than deleted.

**Two follow-ups, director-ordered after this round's report, both landed:**

1. The two stale spans D0076 flagged (`docs/GDD.md` §2, R2) fixed, plus one more found by a full sweep
   for the same class (§6's opening line) — the director's own point: "the edit list marked sections, not
   sentences," so run-relative prose survived inside spans marked keep-verbatim at the section level.
   D0082. One residual surfaced, not swept: §5's "run cadence"/"mid-run," left alone since it's a
   relationship, not a duration/count/consequence, and sits inside the exact span the director separately
   ruled "keep verbatim."
2. A successor to D0075 (D0083) records the director's own framing: this is the second time an edit list
   authored from a summary rather than the source document introduced errors caught only by reading the
   file, after an earlier incident with an audit brief. Named as a pattern, not just this incident.

`sim/run`/`sim/meta`'s shape: confirmed still open, not resolved — the director's own framing this round
("meta-state is just state... two candidate futures, neither obvious yet") matches what D0081 already
left open. Nothing to change; noted here so it isn't mistaken for new scope.

Stopped, as instructed. `data/economy/` waits for the director.

Director-authored, verbatim scope. The run-based structure is retired; the rig becomes the
continuous consumer, fed by a permanent single shaft that never resets. Full reasoning in the
director's brief (this session's transcript) and the review that preceded it. `data/economy/`
(the actual demand content) is explicitly next session's work — **stop before it**.

Six corrections from the director's reply to the review, all to apply during the GDD edit:

1. D2-anti-vacuity rule restated in reachability terms (not layer terms) — verbatim wording from
   the director, goes in `data/economy/README.md` *when that file is written*, not this round.
2. "The terrain is the factory" moves to §1 as a standalone, run-independent claim; only the
   run-dependent clause ("fresh geology every run") dies. New honest open question in §8: lateral
   variety now comes from the un-mined extent of one world, not re-rolled geology — unverified.
3. §5 idle-loop subsection: drop "between every run [including the two-minute ones]" only, keep
   the rest verbatim.
4. §6 depreciation and §7's "fresh shaft into a different part" bullet are full rewrites, not
   one-line patches — both were run-minutes/runs-plural end to end.
5. Machine retrieval is NOT retired — reworded as a local question (pull a machine from a section
   about to flood, before the water reaches it) rather than deleted with run termination.
6. `claims/C001-two-minute-run.md` is RETIRED, not edited in place — its title, falsifiable form,
   metric, and threshold are bounded-run constructs. Replacement is an episode claim per the
   checkpoint-lineage idea (§4 of the brief): cold start, does a scripted bot reach D1 within N
   sim-minutes. File BLOCKED, `blocked_on` naming everything that doesn't exist yet (no save/load
   code anywhere, no `interface/`, no `harness/`, no `sim/commands`, no `data/economy/`,
   determinism proven only against `core/` + a stub sim, never a real session).

Queue, one commit per document group so the diff stays reviewable (director's explicit ask):

- [x] 1. `docs/GDD.md` — the full edit (§1 through §11, per the reviewed-and-corrected §6 list),
      plus ledger entries for judgment calls made executing it (exact wording choices, not
      whether to make the change). D0076. Two spots left deliberately stale (§2 "forty-minute
      run", R2's "every run that fails") — inside explicit "keep verbatim" spans, flagged not
      fixed.
- [x] 2. `claims/C001-two-minute-run.md` RETIRED + `C003-cold-start-reaches-d1.md` filed BLOCKED,
      plus the two narrow "C001 is the definition of done" lines in `CONTEXT.md` and
      `ONBOARDING.md` — same commit, per explicit instruction. D0077.
- [x] 3. `CONTEXT.md` + `README.md` broader cleanup (roguelite language, R3 restated, "current
      state" section) — excludes the lines already touched by commit 2. D0078. `CONTEXT.md` is
      274 lines against its own stated 250 budget — already 266 before this commit, flagged not
      fully fixed.
- [x] 4. `ONBOARDING.md` broader cleanup (stages 6/9/10, the deferred run-console section, Draft
      A/C references in "things I specifically do not want") — excludes the lines touched by
      commit 2. D0079. Task 0's two historical `C001` mentions left untouched on purpose.
- [x] 5. `docs/ARCHITECTURE.md` §11 (save/run lifecycle state machine), the `run` module table
      row, §8's "Draft A versus Draft C is a data file" line, `docs/QUALITY.md`'s "a corrupt run
      save never takes down the meta save" line. D0080. §11 kept, retitled "pre-reversal design,
      not current spec" rather than deleted.
- [x] 6. `sim/run`/`sim/meta`/`sim/commands` `MODULE.md` — the run/meta split assumed multiple
      discrete sessions. Zero lines of code exist under any of the three, confirmed. Marked the
      split explicitly open/TBD rather than inventing a replacement architecture. D0081. Queue
      complete — all six commits landed. Stopped before `data/economy/`, as instructed.

**Explicitly not touched this round, flagged not fixed:** `docs/DECISIONS_LEDGER.md` D0017's
reasoning (aquifers/rifts cut partly because they "assumed a persistent explorable world")
partially inverts now — the director did not ask for this to be revisited and reviving cut
content is a real design call, not mine to make unprompted. The 11 non-normative `docs/*.md`
files with "edited for the run-based pivot" headers (`LODE.md`, `BITS.md`,
`CONTENT_CATALOG_PLAN.md`, `EXPERIENCE_EVALUATION.md` among them) likely need a second pass —
already deferred to step 6's manifest gate, not new scope.

**Dating note:** the director's own dictated §9 text is stamped 2026-08-28; `date` confirms today
is actually 2026-08-27. Using the director's exact string verbatim in §9 (it was given as exact
text to insert), the verified date everywhere else this session writes in its own voice — same
off-by-one-day pattern already flagged elsewhere in this file, not a new problem.

## Overnight queue — ANVIL steps 1-2, 2026-08-27

Fixed by the director verbatim, mid-session, per the "multi-item task lands in WORKING.md before work
starts" rule. Mini overnight session, steps 1 and 2 only. STOP before step 3 (economy authoring —
design work, director wants to be present).

- [x] 1a. bucket 1 and 2 moves, per the confirmed triage — `74c397d`, D0062
- [x] 1b. read `CONVERGENCE_LEDGER.md` and the `FREIGHT_WINCH_*` files specifically, before archiving
      session-exhaust; report anything not present in the tracked syntheses — done, see session report;
      surfaced the director_bus.sh/test_director_bus.sh correction (D0062)
- [x] 1c. archive `docs/tracelog/` and `docs/handoff/` to `docs/archive/session-exhaust/` with its
      README. Track, do not delete. — `74c397d`
- [x] 1d. clean `.git/info/exclude` of everything the project depends on — `14646fb`, D0063
- [x] 1e. the untracked-files gate: fails on untracked AND not covered by the shipped `.gitignore`.
      Mutation-test against a real gap and a legitimately ignored file before trusting it. — `14646fb`,
      D0063, 3/3 mutation branches observed
- [x] 1f. correct the FEEL_GAP / MENU_MATRIX memory pointers — done directly in memory files (outside
      this repo, no commit)
- [x] 2a. event schema: 7 types, universal fields, required fields per type — `tools/anvil/schema.py`, D0064
- [x] 2b. append tool — `tools/anvil/append.py`, D0064
- [x] 2c. referential integrity checker — `tools/anvil/check_integrity.py`, D0064
- [x] 2d. mutation-test the integrity checker per branch — `tools/anvil/test_check_integrity.py`,
      16/16 cases observed, D0064

STOPPED after 2d, as instructed. Step 3 (economy authoring) NOT started — design work, director wants
to be present.

## Codex audit follow-up, 2026-08-27 — items 1-5, director-ordered

External audit of ANVIL itself. Director's order: items 1-5 land, report, step 3 still waits.

- [x] 1. Typed-reference table (schema.py REFERENCE_FIELDS/SUPERSEDES_LEGAL_TARGETS), check_integrity.py
      enforcement, serves_claims traversal. D0069.
- [x] 2. Language correction: "contradictions unrepresentable" → "contradictions become explicit event
      history; resolution becomes deterministic projection behavior" (Codex's framing, adopted verbatim).
      Six occurrences in incoming/ANVIL_ARCHITECTURE.md corrected; CONTEXT.md and .anvil/README.md
      checked, already clean. Logged as a FINDING (source_class: external-audit). D0070.
- [x] 3. Empty-log vacuous PASS fixed — reports "0 events", never PASS, over an empty log. D0072.
- [x] 4. Semantic gaps: fixed (empty required arrays — evidence only, not independent_of; self-reference,
      generalized beyond supersedes; malformed UUID). Deferred with a stated reason in check_integrity.py's
      own docstring (supersedes-cycle detection, commit-SHA existence, timestamp ordering). D0072.
- [x] 5. Untracked-gate checked-in mutation harness — tools/layer_lint/test_check_untracked_files.py,
      5/5 cases, disposable scratch git repos. D0071.
- [x] 6. Seven-types sufficiency judgment logged as a FINDING (three named gaps), NOT resolved, no
      eighth type added, per instruction. D0073.
- [x] 7. Stale brief numbers — left alone, per instruction (step 6's generated brief is the real fix).

**HARD STOP crossed, flagged, then resolved by the director as scope growth against a stale cap, not an
overrun — D0074.** Cap raised 800 → 1,000 for steps 1-2, now counts IMPLEMENTATION LOC only (test LOC
reported separately, uncapped, since mutation coverage is exactly the code this project should not
discourage). Current measured split: implementation 513 / test 420 / total 933 (corrected 2026-08-27: the D0074
count predated .anvil/README.md's own D0075 paragraph landing in the same commit). 2,000 total budget
unchanged, 1,067 lines of headroom for steps 3-9.

- [x] Item 1 (D0074 policy part 1): cap raised, `DECISION` event logged.
- [x] Item 2 (D0074 policy part 2): implementation/test split adopted as the standing report shape.
- [x] Item 3 (D0075): the self-referencing test-fixture finding logged as a `FINDING` event against the
      schema's own history — the strongest evidence yet that D0069's typed-reference fix closed a real
      gap, not a precautionary one. Pattern noted (second self-referential finding in three days, after
      D0004): flagged as a candidate opening line for `.anvil/README.md`'s eventual full composition.

**Cohesion note, director's own instruction — for step 4, NOT now, preserved here so it isn't lost by
then:** when projections land, mirror the sim deliberately. `replay_determinism_test` (hash state every
100 ticks, assert identity) is the template `sim/invariants`-shaped projection tests should copy in shape
and naming. Anvil's event log ↔ the sim's input log; Anvil's projections ↔ the sim's tick phases (both
pure functions of prior state); Anvil's integrity checker ↔ `sim/invariants` (both continuous truth
assertions). "One architecture, two scales" has to be visible in the code, not just asserted in prose —
if `sim/invariants` and `tools/anvil/check_integrity` read as siblings, a reviewer notices the symmetry
without being told. Build for that when step 4 actually starts.

Step 3 still waits for the director, unchanged.

**Schema constraints, verbatim:** seven types is a constraint, not a starting point — an eighth seeming
necessary while writing 2a means stop and log the case, don't add it. `MEASUREMENT.source` (measured |
inherited | asserted) and `FINDING.independent_of` are non-defaulting — unstated must be an error, not a
permissive fallback. `DECISION` and `FINDING` both get an optional `narrative` field (1-2 sentences of
why-this-then-that).

**2d mutation coverage required, each branch observed failing before trusted:** dangling `supersedes`,
dangling `invalidates`, dangling `assumes`, dangling `CONTENT_LINK` path, duplicate id, missing required
field per type, unstated `source` or `independent_of`.

**EXPENSIVE — stop, do not decide:** an eighth event type; any change to the seven types' required
fields beyond what's specified above; anything about how projections consume events (step 4); deleting
anything untracked.

**HARD STOPS:** any gate red not clearable in one attempt; three consecutive commits with no test going
red to green; Anvil line count crossing 800 during steps 1-2 (total budget 2,000).

**Budget: twelve commits.**

---

## Overnight queue — stage 4 (a)-(g), earlier round, CLOSED

One line each, in order, from the stage-4 scope. Not extensible by whoever runs the loop — that
constraint is what makes an unattended run of it safe. Rope (step e) is deliberately NOT on this list;
checking anything off that isn't already here, or adding a step, is itself a HARD STOP.

- [x] (a) The hostile chamber — 1-tile ledges/pits, ~3-cell narrow shafts, machine-footprint clusters,
      sub-tile rubble slopes at 1/2/3px, jagged fresh-dig surfaces generated by actually digging (not
      hand-authored), a ceiling-corner case, a mantle section. `tests/body/hostile_chamber.gd`, D0036.
- [x] (b) Per-column heightfield derivation from the 4px terrain grid, sub-pixel, linearly interpolated.
      `sim/body/heightfield.gd`, D0033.
- [x] (c) The capsule sweep and the forgiveness set (step-up, corner correction, depenetration, coyote,
      jump buffer, variable jump, apex float), ARCHITECTURE §9 constants as given. `sim/body/body.gd`,
      D0032/D0034/D0035 — collider is a flat AABB not a capsule, flagged EXPENSIVE not decided (D0032).
- [x] (d) The acceptance suite, headless, against the chamber. All thresholds measured and reported.
      STOP HERE and report the numbers before continuing to (f). `tests/test_body_acceptance.gd`, D0038/D0039.
      ALL 9 THRESHOLDS PASS with `body.gd` and every ARCHITECTURE §9 constant unchanged since D0035 — every
      fix that got the suite green was in this session's own fixture/test code (the chamber, the scripted
      driving policy, the acceptance driver's own span math), never in the controller. Zero of the two
      permitted constant-adjustment rounds spent. STOPPING HERE per this item's own instruction and the
      director's "report at (d) before starting (e)" — (f)/(g) are NOT started; this is the checkpoint.
- [x] (f) Minimal debug renderer: terrain grid, capsule, camera. Flat colors only, explicitly not art.
      `tests/body/play_scene.gd`/`.tscn`.
- [x] (g) `--play` flag + recorded-input plumbing on the scenario driver; one fixture, the hostile
      chamber traverse. Same file. D0053.

**Dating note, found while wiring the gate above:** every commit in this repository's actual git log is
dated 2026-08-25, but "2026-08-26" appears as the stated date across ~15+ tracked files — `ONBOARDING.md`,
`docs/ARCHITECTURE.md` §9, `docs/GDD.md`, ADRs 0002-0004, `docs/EXPERIENCE_EVALUATION.md`,
`docs/archive/*`, `sim/commands/MODULE.md`, and several `tools/` docstrings — plus every entry in this
session's own `docs/DECISIONS_LEDGER.md` and, until this edit, this file and `README.md`. That is a
systemic off-by-one-day error predating this session, not something introduced by it (confirmed via
`git log`, the system clock, and the session's own `currentDate` context all agreeing on 2026-08-25).
Not corrected wholesale here — a 15+-file historical sweep is a real, separate task with its own
verification cost, not a two-minute fix to fold into unrelated work, and none of it affects any actual
git history or code logic, only prose-stated dates. Flagged for the director to decide when it's worth
doing. Every date this session wrote between the finding above and 2026-08-26 used the then-correct
2026-08-25; the real calendar has since rolled over, so 2026-08-26 is now correct going forward and is
no longer part of the ~15+-file discrepancy this note describes.

## Codex audit follow-up queue (commit 489e728), director-ordered

Logged here 2026-08-26, verbatim from the director's chat message, per the new "multi-item task lands
in WORKING.md before work starts" rule (`CONTEXT.md`, "Review bandwidth") — this exact list existed only
in chat for one round of work and never reached the session that needed items 3-7, which is the failure
that rule now exists to prevent. Independent Codex audit of commit `489e728`. Order is the director's.

1. **[CLOSED]** Heightfield rewrite. Superseded by `docs/adr/0005-heightfield-local-window.md` — measured
   and accepted as a documented limitation rather than rewritten. D0042/D0043.
2. **[CLOSED]** Cave geometry in the chamber, proving the local-window query's behavior against the
   limitation above. `tests/test_cave_geometry.gd`.
3. **[CLOSED, D0045]** `ValueNoise` distribution mismatch against the legacy-configured `FastNoiseLite` it
   was ported from — independently reproduced Codex's finding (SD 0.4336 vs 0.2487 pooled, 20 seeds).
   Recommended and built option (a): `ValueNoise.FASTNOISELITE_SD_CALIBRATION = 0.574`, applied at the
   one real call site (`shaft_generator.gd`), not baked into `sample()` itself (would break its own
   golden-vector tests). `tests/test_value_noise.gd` gained a distribution test re-measuring both noises
   live each run. **Follow-on finding (D0046), not part of item 3's own scope but surfaced by it:** this
   fix shares a generator with item 1's own 0.85%/12% multi-level-floor figure — re-measured post-fix,
   genuinely-reachable columns dropped to 0/4,800 (0/100 shafts), down from 41/4,800. D0042's own record
   is left as written (it accurately describes what was measured against the pre-fix code); ADR-0005 and
   `docs/ARCHITECTURE.md` §9 both now point to D0046 so the 0.85%/12% figure isn't read as current.
4. **[CLOSED, D0047]** CI does not run the tests. Added a `tests` job to `.github/workflows/harness.yml`:
   downloads and SHA-512-verifies the exact pinned Godot build, imports the project (fresh checkout has
   no `.godot/` cache), runs all 13 suites as individual steps. `docs/QUALITY.md` gates 8/9/11 are now
   actually CI-enforced, not locally-verified-only.
5. **[CLOSED, D0050]** `split()` order-independence was untested despite D0006 claiming it was. Added
   `_test_split_is_order_independent_of_prior_draws` (varies prior draw count 0/1/3/17, checks the
   child sequence is unaffected). Mutation-tested against the exact `_root_seed`→`_state` mutation the
   audit used: new test fails on the mutant (3 failures), old suite stayed fully green on the same
   mutant. `core/split_rng.gd` itself is unmodified — it was already correct; only the "verified" claim
   in D0006 was wrong. D0006 left as written; D0050 is the append-only correction.
6. **[CLOSED, D0048/D0049]** Batch of four smaller findings:
   - README said 57 test functions (actual 59 as of the audited commit, now 96 across 13 suites — even
     the audit's own "actual" number had gone stale by the time it was quoted); seven gates (CI now runs
     nine, two more than the README's own table listed). Fixed all three, plus a bigger staleness found
     alongside it: the README still called `sim/body`/`sim/invariants` "scaffolded, zero lines of code."
   - `EntityIdPool` generation-masking: measured before fixing, and the audit's framing turned out not
     to be real — GDScript's `<<` on a 64-bit int already discards bits at position 32+ on a shift-by-32,
     so masking changes no actual output. The aliasing itself (generation 0 == generation 2^32) is real
     but is the field's own already-documented 32-bit wraparound, same as `index` already has. Added the
     mask anyway (defensive symmetry), corrected the framing in the code comment and the test.
   - `tools/data_codegen/generate.py` now reports a malformed YAML file (syntax error, or an unquoted
     date auto-parsed to `datetime.date`) via its own controlled `FAIL --` format instead of an uncaught
     Python traceback. Reproduced both crashes before fixing, confirmed the real `data/` tree unaffected.
   - `tests/test_fixed_point.gd`'s div-by-zero test now spawns a real subprocess
     (`tests/fixture_div_by_zero_probe.gd`) and greps its stderr for `Fx.div`'s exact `push_error`
     message, rather than only checking the return value. Mutation-tested: removing `push_error()` from
     `Fx.div` makes the new test fail; the old test didn't notice.
7. **[CLOSED]** LOC ratio (current, measured: 2.896 — the audit's own 3.564 was already stale by the
   time it was quoted) — `check_loc_ratio.py` is advisory below the 2,000-line game-LOC floor, reports
   the state accurately, then permits it. Director is not changing the floor (reasoning is right); see
   the dedicated note under "LOC ratio target" above — the gate's non-enforcement is now a stated fact
   in this file, not something inferred from console output.

**Also from this round, not part of the numbered list:** the invariants guard shipped for item 1 had its
own real coverage gap (its window could not see the case it was built to catch). **[CLOSED, D0044]**
— widened and measured, see the "Landed and closed" bullet above. Addressed before 3-7 as instructed.

## Current stage

**Post-(g), director-directed round: "fix 1" (root-cause the out-of-bounds glitch, add a bounds
invariant, sweep the chamber's full reachable extent) is CLOSED — D0055 above. Next per the director's
explicit "fix 1 first, then 2" ordering: item 2, legibility from the screenshots** — distinct flat
colors for solid rock / excavated space / out-of-grid, a toggleable 4px grid overlay, camera zoom so the
chamber fills more of the frame with the body kept centered, and resolving whether the stray up-left
cell in three of the four screenshots is an intentional marker or a stray tile. Items 3 (document the
red/yellow airborne-vs-grounded body-state color in `play_scene.gd`'s own docstring) and 4 (one gotchas
line about the `Input.parse_input_event`/`flush_buffered_events` quirk) follow. Rope (step e) remains
explicitly not started — "rope still not started" was restated in the same message that assigned this
round.

**Stage 4, steps (a)-(g), CLOSED and reported earlier this session.** Holding at (g) per the director's
explicit "stop after (g)" instruction — rope (step e) is deliberately not started; it has no acceptance
criteria yet and the director wants to play the bare controller first, in a session they're present for.
To play it:
`godot --path . tests/body/play_scene.tscn -- --play`. Controls: Left/Right or A/D to move, Space to
jump (hold for full height, tap for a short hop), Up/W held while moving toward a ledge for
`mantle_hold`. The session ends and writes its recording to `tests/body/recordings/play_<timestamp>.log`
when the window is closed. The acceptance
suite (D0038) is fully green against `HostileChamber` + `ScriptedTraverse` with `sim/body/body.gd`
unchanged since D0035: every one of the ~7 bugs found while getting there was in this session's own
fixture code (the chamber's geometry, the scripted driving policy, or the acceptance driver's own span
math) — never the controller, never an ARCHITECTURE §9 constant. D0038/D0039 carry the full chain.
Stage 3 closed earlier this session: the full pre-stage-4 punch list (four prioritized items, two
smaller items, a README correction) closed this session, plus a separate director-directed
process/tooling round making the session rituals mechanical (D0031). Two findings from the punch list
closed the loop cleanly: `Fx.length()`'s real 181px overflow (fixed, D0029) and `data/`'s hand-mirrored
YAML dual-source problem (fixed via codegen + an ADR, D0021→D0030). A separate finding, unrelated to the
punch list, surfaced while wiring gate 23: a pre-existing, systemic one-day dating error across ~15+
files (see below) — disclosed, not corrected wholesale.

**LOC ratio target, set 2026-08-25 (director's ask, item 3 of the post-audit list):** absolute ratio
under 1.5 by the time `C001` passes. Current absolute ratio is 3.399 (instrument 2,328 / game 685,
measured after `bbc18fe`) — well above target, and the trailing-10-commit window shows the wrong
direction (instrument +363, game −39: the YAML-codegen refactor net-shrank hand-written game code, which
is real and good, but the same window's `tools/` growth outpaced it). This is a finding stated plainly,
not smoothed: at stage 3's close, absolute ratio is more than double the target it needs to hit by
`C001`, and `check_loc_ratio.py` is still ADVISORY (game LOC under its 2,000-line floor) so nothing
gates on it yet. Every `docs/BRIEF.md` from now on reports absolute ratio plus trailing velocity, whether
or not the gate is advisory that session — this is a standing reporting obligation, not a one-time note.
If the ratio is still above 2 when stage 7 lands, that has to be stated as a finding in that session's
brief, not narrated around.

**Item 7 of the Codex-audit follow-up queue, closed 2026-08-26 — no code change, a stated fact.**
The audit's own snapshot (commit `489e728`) reported absolute ratio 3.564; that number is now stale too
(stage 4's `sim/body`/`sim/invariants` landed since, growing game LOC faster than instrument LOC in
relative terms). Current, measured just now via `check_loc_ratio.py` rather than recalled: **2.896**
(instrument 3,553 = tools 1,529 + tests 2,024; game 1,227 = core 296 + sim 931). Still ADVISORY — game
LOC (1,227) remains under the 2,000-line floor where this gate starts actually blocking anything — and
the director has explicitly decided NOT to change that floor; the reasoning for it (below 2,000 lines of
real game code, a ratio number is mostly measuring how much scaffolding a young project needed, not
whether it's earning its instrumentation) is correct and stands. This note is what makes the gate's
current non-enforcement a stated, known fact rather than something a reader has to infer from the gate
script's own console output — the same "invisible unless something reports it" failure class as the
unpushed-commit-count and LOC-velocity rules above, closed the same way: report it every time, whether
or not there's a gate actively acting on it.

**Unpushed commit count, added as a standing rule 2026-08-26 (director's ask, item A of the Codex-audit
follow-up):** every `docs/BRIEF.md` reports `git log origin/main..HEAD --oneline | wc -l` — actually run,
not recalled — regardless of whether it's zero. Same failure class as the LOC ratio: 31 commits (an
entire stage, plus this session's own audit-response work) accumulated unpushed across one session
without either the director or the session noticing, because nothing was reporting the count. It is
visible only if something reports it, every time, whether or not there's anything to say. `docs/DECISIONS_LEDGER.md`
D0040 has the discovery this rule came from (the same unpushed gap made an external audit's correct
report of an older commit read as a contradiction of a correct report of the current one).

`docs/DECISIONS_LEDGER.md` D0016-D0030 carry every judgment call's full reasoning; this section is the
pointer, not the record.

## Landed and closed, with commit references

- Stages 1 and 2 (`core/`'s `Fx`/`SplitRng`/`EntityIdPool`, `tests/test_replay_determinism.gd`) —
  `560ee78`, `f51d722`. Detail in `docs/DECISIONS_LEDGER.md` D0005-D0015.
- **Stage 3 landed and reviewed**: `sim/world` (`TileGrid`, sparse and not chunked on purpose — D0019 —
  plus `WorldMaterials`) and `sim/terrain_gen` (`ShaftGenerator`, `StrataData`, `ValueNoise`) —
  depth-banded base rock into the three `docs/GDD.md` §11 layers, cave carving, ore/coal/iron vein
  scattering, one empty ruin chamber. Port scope is a real subset of legacy (D0017): 29 of the cited 118
  tuning constants carried over by value, 22 consumed by the generator today, the other 7 marked
  structurally pending rather than left as an unread comment (D0025, D0025-followup this round). Two
  real architectural gaps were found and closed, not worked around: `no_engine_imports.py` never checked
  for entire categories of engine coupling — first patched ad hoc for `FastNoiseLite`/
  `RandomNumberGenerator` (D0023), then rewritten wholesale from Godot's actual `ClassDB` (D0026) after
  the director asked "what else is it missing." A pre-stage-4 resolution-split test found one real gap
  in `sim/world`'s API (`occupied_cells`'s untyped return) and it's now fixed (D0027). Mutation-testing
  this stage surfaced its own finding (D0024, now a `docs/QUALITY.md` rule): a full-generation
  integration test can pass even with a real safety guard removed, if the guard's own trigger condition
  is rare at generation scale.
- **`Fx.length()`/`Fx.length_sq()`'s real 181px overflow, fixed** (`297b6aa`, D0029, supersedes D0011's
  scope decision): the director found D0011's "local-neighborhood only" scope was wrong, not just
  narrow — `sim/body`'s grapple, rope, and camera-relative queries have no reason to stay under 11.3m,
  and the failure mode is a silently wrong distance, not an error. Cause: squared terms were reduced
  through `mul()`'s i32 wrap before summing. Fix: accumulate raw `dx*dx+dy*dy` in a native i64, `isqrt()`
  directly — verified in Python that the absolute worst case across `Fx`'s entire range stays under i64
  max with room to spare. Mutation-tested against D0011's exact old formula (12 assertions failed on it,
  confirming the new tests catch the regression) before trusting the fix.
- **`data/materials`/`data/strata`'s hand-mirrored YAML dual-source problem, resolved** (`348a79c` ADR
  0004, `bbc18fe` D0021→D0030): `tools/data_codegen/generate.py` reads `data/<kind>/*.yaml` and emits a
  checked-in `data/<kind>/generated.gd`; `--check` mode is the new staleness gate (`docs/QUALITY.md` gate
  22), mutation-tested in both directions (source edited without regenerating; generated file hand-edited
  directly) before trusting it. `sim/world/materials.gd` and `sim/terrain_gen/strata_data.gd` now read
  from the generated records; their public APIs are unchanged. `data/` is the actual source of truth now.
- **Multi-level-floor limitation (Codex's `sim/body/heightfield.gd` finding) measured and accepted, not
  rewritten** (`docs/adr/0005-heightfield-local-window.md`, D0042/D0043): three separated findings — the
  §9 spec's per-column heightfield genuinely cannot represent a floor under a reachable overhang (Codex
  was right); the actual implementation had already diverged from that spec toward a bounded local
  window before anyone noticed either fact; measured against real `ShaftGenerator` output (100 seeds,
  4,800 columns), the residual gap is 0.85% of columns / 12% of shafts, mostly scattered single columns
  — accepted as documented rather than closed with stateful floor-selection tracking. `sim/invariants`
  gained its first real code (`check_floor_selection`/`report_floor_selection`, `push_error` not
  `assert()` — the hang hazard `core/MODULE.md` documents applies to a failed `assert()` too) and its
  first sim-internal caller, wired diagnostically into `_resolve_floor` (reads nothing back, changes no
  behavior — confirmed via full re-run: `test_body.gd` 17/17, `test_body_acceptance.gd` 9/9 unchanged).
  `tests/body/hostile_chamber.gd` gained a cave-geometry section outside the scripted traversal span, and
  `tests/test_cave_geometry.gd` mutation-tests the new guard directly. `docs/ARCHITECTURE.md` §9 now
  describes the local windowed query as the actual design. This replaces the item-1 rewrite the
  post-audit list originally scoped.
  **Corrected same round (D0044):** the guard's first version shared `_resolve_floor`'s original 6-row
  window and, per the director's review, "reported zero not because the case doesn't happen, but
  because it structurally could not see it." `sim/body/body.gd`'s window is now a named constant,
  `Body.FLOOR_SCAN_ROWS = 48`, sized from re-measuring the real row-gap distribution between
  genuinely-reachable stacked floors (min 11, p50 16, p99 36, max 36) rather than guessed — verified
  safe for ordinary falling (`_bottom_y() < surface` gates every candidate regardless of window width,
  confirmed by the acceptance suite staying byte-identical at both widths) and its perf cost measured
  directly (37.2µs/tick → 55.3µs/tick, negligible against the §10 sim-tick budget). `tests/test_cave_geometry.gd`
  now proves the guard genuinely fires on the fixture it was built to catch. One finding flagged, not
  fixed at the time: the guard logged on nearly every call, not once per episode — since **closed
  (D0052)**, see below.
- **The 0.85%/12% multi-level-floor figure was substantially an artifact, not a property of the terrain
  design — ADR-0005 reframed accordingly (D0051, resolves D0042).** Per the director's review: "we
  accepted a documented limitation" and "the limitation was a bug in an adjacent module, and the residual
  rate after fixing it is zero across 4,800 columns" are different findings. `ValueNoise`'s cave density
  was over-carving relative to legacy's own threshold tuning (D0045); the corrected generator measures
  0/4,800 reachable multi-level columns (D0046), not a smaller version of the same phenomenon. Stated
  explicitly per instruction: 0/4,800 is a null result below this sample's resolution (~0.06% upper
  bound), not proof the case cannot occur. The guard stays — its purpose changes from measuring a known
  cost to watching for this case to reappear after a future generator change.
- **The guard's per-tick logging, rate-limited at the caller (D0052).** `sim/body/body.gd::_resolve_floor()`
  now suppresses a repeat `Invariants.report_floor_selection` call while the resolved (column, floor)
  pair is unchanged, via two new instance fields (`_last_violation_col`/`_last_violation_row`), cleared
  when the violation clears so a later recurrence reads as a fresh episode — per the director's explicit
  instruction, the state lives at the caller, not inside `sim/invariants` (stays stateless by design).
  Measured, not assumed: mutation-testing the new gate (temporarily reverting it) showed the real
  multiplicity is 778 push_errors from one ~400-tick settle, not the ~390 originally guessed —
  `_move_and_resolve_vertical` calls `_resolve_floor` twice on most resting ticks. With the fix: exactly
  1. New test `_test_a_real_settle_rate_limits_the_guard_to_one_report` (`tests/test_cave_geometry.gd`,
  spawning `tests/fixture_settle_violation_probe.gd` as a subprocess, same pattern as
  `fixture_div_by_zero_probe.gd`) proves it and fails on the reverted mutant. Full 13-suite regression
  green before and after, at both the mutant and the real fix.
- **(f)/(g): minimal debug renderer + `--play` mode + recorded-input plumbing
  (`tests/body/play_scene.gd`/`.tscn`, D0053).** Flat-color terrain/body/camera, no shaders or sprites,
  on the director's own instruction to resist polish. Two run modes off one `--play` cmdline flag:
  `agent` (driven by the already-trusted `ScriptedTraverse`, for self-verification without a human) and
  `play` (real physical-key input, no project input map — D0053, a real reversible choice, not an
  oversight). Both write a tick-by-tick input log to `tests/body/recordings/` (`tick,move_dir,
  jump_pressed,jump_held,mantle_hold`), the precursor of `docs/ARCHITECTURE.md` §6's real `input.log` —
  kept deliberately (not gitignored) as the seed of a future golden corpus, per the director's own
  instruction. Verified: parses clean; a real windowed run (screenshot capture) shows the terrain,
  body, and camera rendering correctly against the actual hostile-chamber geometry; a headless agent-mode
  run reaches the chamber's end column and writes a correctly-formatted 226-tick log; a `--play`-mode
  smoke run (no human input available to this session) initializes, renders, and records without
  crashing. `tests/body/recordings/README.md` documents the format and retention policy (`agent_*.log`
  disposable, `play_*.log` requires director confirmation before deletion).
- Task 0 (repository restructuring), context-compaction protocol, claim-rot mechanisms, movement/
  collision architecture decisions, Freight Winch gate, Sinkforge-as-stratum/layers-as-rule-sets/9-run
  curve/R1 scope ADR-0002, review-bandwidth and playable-fixtures protocols, doc triage, the LOC-ratio
  gate's rewrite as a trailing-window trend measure, clone-size Phase 1 (withdrawn), `docs/handoff/`
  (deferred) — all from earlier this session. Detail in those commits' messages and
  `docs/DECISIONS_LEDGER.md` D0001-D0004, D0016, not repeated here.

## Discoveries not yet written anywhere durable

The director's post-audit spot-audit-methodology finding (item 4): `git log | shuf -n 1` samples the
entire history, not just the ledger-covered portion, and the first attempt drew a commit that predates
`docs/DECISIONS_LEDGER.md`'s own creation — a null result, not a real audit. Fix in progress: a `tools/`
script constraining the sample to `bea703d..HEAD`, run by the director, never by this session. Remaining
after that: the ledger-numbering-rule header addition, `BRIEF.md`'s regeneration-timing rule, and the
README stage-count correction ("stage 3 of 12" → "stage 3 of 7 toward `C001`"). All are small and
already scoped; none are new findings requiring their own ledger entries. D0019 and D0020 (chunk size,
coordinate type scheme) remain open EXPENSIVE questions, unchanged this round. Anything found during
stage 4 gets logged here or to the ledger immediately, not batched.

**Hazard, not yet root-caused: a non-headless Godot launch rewrote `project.godot` once, silently
dropping `gdscript/warnings/enable=true`** (the parent flag `docs/DECISIONS.md` names as "Enforcement
tripwire #1" for the whole typed-everywhere rule — `untyped_declaration=2` alone, without `enable=true`,
may not actually fire) along with every documentation comment in the file. Caught by routine
`git status` before this session's own commit, not by any gate — `project.godot` is unpoliced by
`layer_lint.py` or any other check. Reverted (`git checkout -- project.godot`) before committing.
Could not reproduce on a second attempt (same non-headless `godot --path . tests/body/play_scene.tscn`
invocation, screenshot flags, left `project.godot` untouched); a headless `--check-only`/`--import` also
left it untouched both times. Likely a one-time resave triggered by something specific to an earlier
non-headless launch this session (first-open project-settings migration is one guess, not confirmed) —
flagged rather than chased further, since it doesn't reproduce on demand and this session's own
scope was (f)/(g), not a Godot-internals investigation. Practical mitigation for any session running
Godot non-headlessly: `git diff project.godot` before every commit, not just before this one.

**Closed, same day (D0054): the hazard above is now a CI gate, unreproducible or not.**
`tools/layer_lint/check_project_settings.py` asserts `project.godot`'s `[debug]` section still carries
`gdscript/warnings/enable=true` and `gdscript/warnings/untyped_declaration=2` — the exact flag the
director's own reasoning ties to `docs/ARCHITECTURE.md` §12 / `ONBOARDING.md`'s stated reason a Rust
migration was rejected ("untyped declarations are already a build failure via project settings").
Registered in CI alongside the other nine structural gates (now ten). Mutation-tested against the real
incident's own shape (the `enable=` line dropped), a demoted `untyped_declaration=1`, and the whole
`[debug]` section missing — all three fail with the specific wrong key/value; the real file passes clean.

**Closed (D0059/D0060): JUMP_CORNER embedding, root-caused to FOUR controller defects (not one), and the
fuzzer is now in CI.** Full chain in D0059: `extends_forward` (step-up/mantle onto an isolated tile),
`_resolve_ceiling`'s failed-nudge-never-backs-out, the corner-nudge's own missing world-bounds check, and
`grid_floor_backstop` (a pit-lip heightfield/grid mismatch, found only after the first three fixes cleared
JUMP_CORNER itself). `embedded`: 1,749 -> 1,068 -> 131 -> 1. `test_reachability_sweep.gd` was rewritten
along the way — its log-count assertion had a real blind spot (indistinguishable from "never corrected at
all"), now a direct per-tick `_box_in_bounds` check, strictly stronger. `sim/body/body.gd` split into
`body.gd` + `sim/body/vertical_resolve.gd` (internal to the module, same shape as `heightfield.gd`) once
five fixes' worth of WHY-comments pushed it past the 400-line gate with nothing left to trim honestly.
D0060: `tests/test_body_fuzz_fast.gd` (100x500, ~5s, hard zero on everything) runs in the existing `tests`
CI job every push/PR; `tests/test_body_fuzz.gd` (full 1000x1500, ~114-142s) runs nightly via a new
`fuzz_nightly` job, asserting a named, counted allowlist (`embedded <= 1`, `grounded_no_floor <= 32`) for
the residual D0059 explained but did not fully eliminate. The director's own explicit question — is this
related to D0056's fitted-threshold finding — answered NO in D0059: real controller bugs independent of
where the corner constant sits, sharing only a root CAUSE OF INVISIBILITY (one scripted route's narrow
coverage) with D0056, not the same failure mechanism.

Not built yet, per the director's explicit ordering ("JUMP_CORNER, then fuzzer into CI, then gate 10"):
item 2 (human-biased fuzzer — still blocked, `tests/body/recordings/` is still empty, held per director's
explicit choice), gate 10 (`reachable_state_can_reach_surface`, "No softlock" — the next task), item 4
(coverage metric), shrinking.

**Closed (D0056): `JUMP_CORNER_ROW` generalizes — a fixture tuned by watching the controller is not
independent of it.** New `docs/QUALITY.md` §2 rule; full `HostileChamber` constant audit found exactly
one constant in the bad category (`JUMP_CORNER_COL`/`JUMP_CORNER_ROW` — positioned twice by watching a
specific jump's own arc, zero margin, directly gates `corner_correction_success_rate`), everything else
either spec-derived, reachability-measured-with-margin, or arbitrary/procedural. Not rebuilt by hand —
the input fuzzer (next) makes the fixture's own circularity moot by validating corner correction against
arbitrary trajectories instead of one hand-placed graze. Full audit: D0056.

**Gate 10 research, parked mid-analysis pending the director's ANVIL decision (see `incoming/ANVIL_ARCHITECTURE.md` and the director's ANVIL brief) — not lost, written down before the pause so it survives regardless of what happens next.** Full continuous state (`pos_x, pos_y, vel_x, vel_y`, `Fx` fixed-point) is intractable to enumerate directly for `HostileChamber` — confirmed via real trace numbers, not estimated: `grid_max_x=47,185,920`, `grid_max_y=22,544,384` raw positions. The design converged on, but did not implement: a **settled-state reachability graph** — restrict nodes to `on_floor=true, vel_x=0, vel_y=0` exactly (an exact state-class reduction to a finite `(column, row)` set, not a numerical discretization), edges computed by running the real `Body.tick()` under a small, fixed, documented move-primitive library (walk_left, walk_right, jump_left, jump_right, jump_up, each holding `mantle_hold=true`), each run bounded-tick then settled. Algorithm: forward BFS from spawn = reachable set R; reverse-graph BFS from surface node(s) = CanReachSurface; violations = R \ CanReachSurface. Open at the pause: how to operationalize "the surface" for `HostileChamber` specifically (a lateral gauntlet, not a modeled shaft) — candidates were row-0-proximity per the fixture's own `TOP_MARGIN_ROWS` framing, or the fixture's own spawn rest position as a shaft-entrance proxy. Explicit caveats identified for the eventual docstring: a "no path found" result is a hypothesis bounded by the move-primitive library's completeness, not a proof of impossibility (false positives possible, false negatives on found edges are not — any edge found is real, physics-grounded); named classes of softlock this approach would miss: escapes needing a move outside the fixed primitive library, perpetually-airborne states that never settle (outside this graph's scope, covered instead by the fuzzer's deadlock/embedded checks), anything outside `HostileChamber`'s specific fixture, anything outside `Body`+`TileGrid`'s current mechanical scope. No code written for any of this.

**Closed (D0055): the jump-glitch out-of-bounds launch, root-caused to THREE independent causes, not
one.** (1) `Body._try_step` (auto step-up and mantle) had no cap on chained lifts against a wall —
fixed with a pre-emptive top-boundary refusal, checked before moving. (2) `ScriptedTraverse` asserted
`jump_held = true` unconditionally every tick, an oversight that silently defeated the variable
jump-height cut in every acceptance run to date and was the direct cause of the pit-area violation —
fixed by scoping it to the jump-press tick only (a tap, not a hold). (3) `HostileChamber`'s own row
constants had no headroom above row 0 at all — a body just STANDING on the mantle's intended post-climb
floor, no bug involved, already had its own top two rows past the boundary — fixed with a uniform
`TOP_MARGIN_ROWS = 40` shift across the fixture's four independent row anchors. Also added:
`Invariants.check_bounds`/`report_bounds` plus `Body._enforce_grid_bounds()` (a real, tested safety net
for any OTHER path to the boundary), and `tests/test_reachability_sweep.gd` (the director's second
ask: sweep the chamber's full reachable extent, not just the scripted route — closes the actual gap the
glitch exposed, that traversal-path coverage and reachable-space coverage are different sets). All 15
suites green together; every new guard mutation-tested, including one honest negative finding (the
pre-existing pinned "shaft wall" test turned out to be mutation-insensitive after the margin shift,
since that wall is shorter than the new margin — disclosed and fixed with a margin-independent
synthetic staircase test, not silently left green). Full reasoning: `docs/DECISIONS_LEDGER.md` D0055.
