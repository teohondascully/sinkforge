# Working state

Not a log. Current stage, what's actually happening, and what would be lost if this session ended
right now. Updated as work happens. Resets when a stage closes — durable content moves to an ADR,
a MODULE.md, or a claim first.

**Last updated: 2026-08-27.** Bump this date whenever this file changes — a CI gate fails if it's
older than `HEAD`'s own commit date, so a session that lands commits without touching this file is
caught mechanically rather than relying on someone noticing later.

## Design reversal — run-based roguelite to persistent single shaft, 2026-08-27

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
