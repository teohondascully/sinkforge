# Corrections

The "when we were confidently wrong" page. A projection over `docs/DECISIONS_LEDGER.md`'s own
resolves/corrects/supersedes links — not a new instrument, not hand-curated judgment, just every place
the ledger's own append-only record shows an entry naming an earlier one as wrong, overstated, or
falsified. Numbers are permanent addresses; nothing here edits the ledger, it only re-reads it.

**The rule this page follows:** a correction earns a place here only if it names the entry it corrects.
Where a correction's own chain runs deeper than the entry it directly cites — the ORIGIN of the claim,
not just its most recent restatement — that deeper origin is traced below explicitly, per the standing
instruction that a correction naming only its immediate predecessor while the real origin sits further
back is itself an incomplete citation.

Regenerate this by re-reading `docs/DECISIONS_LEDGER.md` for entries whose own text says "corrects,"
"correction," "FALSIFIED," "was wrong," "superseding," or similar — this file is a snapshot, not a live
query; re-derive it rather than hand-edit it when the ledger grows further corrections. First generated at
`docs/DECISIONS_LEDGER.md` D0170; `tools/check_corrections_freshness.py --check` catches when the ledger's
own candidate set has grown past what's written here (it cannot regenerate the prose itself — reading each
candidate in context to write it up stays a judgment call, per D0170's own account).

## The deepest chain: `grounded_no_floor`'s mechanism, D0059 → D0137

The longest-running correction chain in the ledger, spanning six weeks and five corrections. Traced in
full because the audit that prompted D0133/D0135 flagged exactly this: a correction citing only its
immediate predecessor when the claim's real origin sits further back.

1. **D0059** (2026-08-26) — `JUMP_CORNER` embedding root-caused to four separate controller defects.
   Establishes `_grid_floor_backstop` (D0059f) as an accepted design trade-off: rests a body on the
   topmost solid row in its footprint when that's the only real ground available (a pit's own lip).
2. **D0060** (2026-08-26) — the fuzzer's standing allowlist for D0059's residual, framed as ONE
   undifferentiated bucket.
3. **D0061** (2026-08-27) — **corrects D0060's own framing**: splits the allowlist into two different
   KINDS of thing — `RESIDUAL` (a genuine unresolved leftover, should trend to zero) vs. `DESIGN_TRADEOFF`
   (`grid_floor_backstop`'s own accepted behavior, D0059f) — conflating them was D0060's mistake, corrected
   here for the first time.
4. **D0122/D0127/D0128** (2026-08-28 – 2026-08-29) — dig raises `grounded_no_floor` from 32 to 59.
   D0127 explicitly cites the pre-dig bound as "D0061" by number. D0128 attributes the entire 27-violation
   excess to "the SAME `_grid_floor_backstop`/D0059f pit-lip trade-off" — a claim that cites D0059's own
   mechanism directly, but adds no new measurement of its own between D0127's hedged version and D0128's
   unqualified one.
5. **D0133/D0135** (2026-08-29) — **correct D0127/D0128**: D0132's own telemetry (built specifically to
   settle this) measures the real split — 84/91 violations trace to `resolve_floor`, only 7/91 to
   `_grid_floor_backstop`/D0059f. D0135 goes further: the 32→59 raise wasn't merely unproven, it was
   **FALSIFIED** by an instrument built specifically to check it. Both corrections cite D0059f directly;
   neither re-cites D0061's own distinct act (splitting residual from trade-off) — that citation gap is
   what this section closes by tracing the chain here rather than leaving D0059 as the only cited
   ancestor.
6. **D0137** (2026-08-29) — the actual mechanism, diagnosed after D0133/D0135 opened the question:
   `resolve_floor` takes `mini()` of three heightfield samples, so `Heightfield.NO_FLOOR`'s sentinel value
   never wins even when a real gap exists — measured across all 84 non-backstop occurrences, 100% show
   this exact shape. Not fixed (explicit instruction); the attempted fix and its own further complications
   are `docs/WORKING.md`'s own "OPEN, MID-INVESTIGATION" section, unresolved as of this queue.

## Other corrections, chronological

- **D0035** (2026-08-25) — `body.gd`'s `STEP_UP_PX`/`MANTLE_PX` used the wrong unit (a 4px terrain cell
  instead of a 16px logic tile). Caught before anything was built on top of it, not a correction to a
  standing claim so much as a same-session catch — included for completeness.
- **D0044** — corrects **D0043**: a floor-selection guard shared `_resolve_floor`'s own 6-row scan
  window, which could not see the 16-row gap its own test fixture was built to require — "a zero that
  cannot be nonzero is not evidence." Widened to 48 rows.
- **D0050** — corrects **D0006**'s claim that `SplitRng.split()`'s order-independence was "verified in
  the same test suite" — every existing test called `.split()` on a freshly-constructed RNG with zero
  prior draws; none tested what the claim actually asserted. An external audit demonstrated the gap
  directly.
- **D0051** — corrects **D0042/D0046**'s own reading of a 0/4,800 result: not "an accepted documented
  limitation" but a bug in an adjacent module (`ValueNoise` over-carving) — the two are different claims,
  and the ADR previously blurred them together.
- **D0061** — see the chain above.
- **D0068** — self-correction: the "unreconciled snapshot" framing applied to two archived files in
  **D0062** was wrong, disclosed plainly rather than quietly fixed.
- **D0070** — language correction: **an earlier claim** that "contradictions [are] unrepresentable" was
  false, per external audit judgment 11 — the director's own words adopted verbatim as the corrected
  claim.
- **D0098 → D0104** — D0098's own FINDING corrected via a superseding FINDING (Anvil's own
  `--supersedes` mechanism), the same append-only discipline as the ledger itself: the original stays,
  unedited, in the log.
- **D0109** — the director's correction to a prior operationalization of the reveal metric ("bias toward
  unrevealed features") that was circular by `docs/EXPERIENCE_EVALUATION.md`'s own Readiness Gate 6.
- **D0112** — **D0110**'s dig mechanic had a real off-by-one in its right-facing case, invisible to its
  own mutation tests because they were self-referential (derived their own "expected" value by calling the
  same function under test) — found only by actually running the scene end to end.
- **D0128 → D0133/D0135** — see the chain above.
- **D0152** — `tests/test_body_fuzz.gd`'s own doc-comment still told **D0128**'s falsified story after
  D0135 corrected it; fixed to match D0135/D0137 (comment only, no bound changed).
- **D0157** — corrective: an earlier commit's own message claimed a harness.yml fix and three ledger
  entries that were never actually staged, due to a `git add` with an invalid pathspec silently aborting
  the whole invocation — caught by re-reading real CI state, not by trusting the prior commit message.
- **D0161** — this queue's own E6 instruction assumed the size gate covered `tools/**/*.py`; it never
  covered Python at all, GDScript-only, at any point in its history. Corrected the premise, then answered
  the actual ask anyway.
- **D0165 → D0167/D0168/D0169** — this queue's own Part G work: a first "prove sim/ deletion turns the
  test red" attempt was itself invalid (an in-tree rename let Godot's importer silently rediscover the
  same code, D0165's own account has the full finding). Corrected methodology confirmed the real closure
  proof. D0167 then found the committed golden hashes were captured on the wrong platform (macOS, not
  CI's own canonical Linux build) — corrected by sourcing golden hashes from CI directly. D0168/D0169
  found a further real gap (the golden scenario never mantles on CI regardless of spawn placement) and
  downgraded that specific assertion from gated to reported, rather than force a fix neither queue
  authorized.
- **D0180** — a Codex certification pass disproved `test_shaft_replay_determinism.gd`'s own docstring
  claim exactly as it was written ("moving sim/ aside" turns the real test red, the stub stays green):
  removing ALL of `sim/` reds BOTH, because `test_base.gd`'s shared `_flat_grid()` needs `TileGrid` too.
  The real isolating methodology (D0165's own second, corrected attempt) was already right, just never
  made it into the docstring — rebuilt and re-verified in a scratch clone, docstring corrected to match.
- **D0182** — `project.godot`'s own pin comment said CI "replaced" the Godot-installing job with pure
  static analysis needing no engine at all; the real `tests` job (harness.yml:199) boots Godot and
  checksum-verifies this exact pin before running every suite. Same class as the retired roguelite
  description corrected earlier this session (D0177) — shipped metadata nobody re-read before quoting it.
- **D0183** — five docs framed `ValueNoise.sample()` as "the one place" `sim/` departs from fixed-point;
  a certification pass found float arithmetic on the same terrain-generation/RNG state path in three more
  places (two in `shaft_generator.gd`, one in `core/split_rng.gd`). The direction of D0171/D0172's own
  correction (proven within-platform, not across) was right; the SCOPE was still an undercount — corrected
  to name all four sites, enumerated in D0183 itself.

- **D0191** — corrects `docs/LEGACY_MIGRATION_MAP_2026-08-29.md` in eleven places, after five full reads
  closed the coverage gap the map states about itself (§12 item 2: `main.gd` and `world_renderer.gd`, 6,659
  lines, never read in full — a gap the 2026-08-25 compat audit flagged first and also left open). The
  load-bearing one: the map places the head-lamp and darkness-veil math in `main.gd`, and it is all in
  `world_renderer.gd`. The map inherited that from a **stale docstring inside `light_layer.gd`** ("MainView
  owns all the light math"), written before the light pass moved out — prose outliving the code it
  describes, shipped beside the code refuting it. The others are counting and category errors (a breakdown
  summing to 15 against a stated 16; "21 of 22" reported as 22, contradicting the map's own manifest row;
  6 private fields + 2 methods described as 8 private fields; two file populations mixed into one ratio;
  a constant named as portable that does not exist on the receiving side). The map file is deliberately
  NOT edited — it is a pinned historical record at two fixed hashes, and editing the artifact being
  corrected is what an append-only ledger exists to avoid.
- **D0191 also CONFIRMS a prior correction rather than making one**, which is worth recording separately:
  the map's own correction to `docs/archive/COMPAT_AUDIT_2026-08-25.md` §2 ("scenes/ uses `%UniqueName` 71
  times", then a walk-back telling readers to distrust its own correct measurement) is verified — there are
  zero — **and the mechanism is now identified**: `grep -rn '%[A-Za-z_]' legacy/scenes | wc -l` returns
  exactly 71, so the old audit counted LINES holding a printf format specifier (58 `%d` + 43 `%s`) and read
  them as node paths. That turns "we looked and found nothing" into "we found what they actually counted",
  which is the difference between a null result and an explanation. The archived audit's §2 should be
  marked corrected.

**D0185, read and deliberately excluded, not silently dropped:** it trips this page's own keyword scan
because its header says "docs/CORRECTIONS.md updated with ... real corrections" — but D0185 IS the update,
not a correction of anything. Listing it here would make the page cite itself. Noted so the freshness gate
stops re-flagging it, and noted with the same reasoning as D0181 below rather than by widening the gate's
pattern, which would blind it to real entries.

**D0181, read and deliberately excluded, not silently dropped:** its own header matches this page's
keyword scan ("7 files corrected"), but it is drift cleanup — annotating already-true comments as
"parked, see D0153-D0155" — not a correction of a claim that was ever WRONG. Noted here so the freshness
gate (`tools/check_corrections_freshness.py`) doesn't keep re-flagging it as unreviewed drift.

## D0195 supersedes D0110 — a deferral answered by dissolving the question, not by picking a side

**What D0110 claimed** (2026-08-28): digging is horizontal-only, and the reason given was that a vertical
or diagonal dig "would raise the aim-direction design question — which key means 'down,' does it compete
with `mantle_hold`'s up-key — without a stated answer yet." The scope restriction was a *consequence* of an
unanswered design question, and the ledger said so honestly at the time.

**What D0195 establishes** (2026-08-29): cursor-aim answers the question by removing it. Aim is a point
against a reach radius, not a facing direction, so "down" is simply a cell below the body and **no key has
to mean it**. The competition with `mantle_hold` that D0110 was avoiding cannot arise, because direction
was never a key in the first place.

**Why this is a supersession and not a reversal.** D0110 was not wrong about anything it measured — a
facing-based dig genuinely does raise the key-competition problem, and deferring rather than guessing was
correct. What changed is the input model, which is a director ruling (Q2 of the Slice 1 brief), not a
discovery that D0110 mis-reasoned. The horizontal column dig it introduced is still in the tree and still
what the reveal metric and every committed V1 recording run on; both verbs exist through Slice 1.

**The origin, traced past the immediate citation** per this page's own rule: D0110's restriction is not the
origin of "no downward digging." That goes back to the reveal-layer scope itself — `docs/GDD.md` §8/§12
scoped the Reveal want-layer to *lateral* search, and D0110's horizontal-only dig was built to serve it.
So what D0195 actually reopens is a GDD-level scope question, not just a controller decision, and the
director should read it that way rather than as a bug fix.

## D0200 corrects D0195 — the port was checked in the wrong units, one paragraph from the right ones

**What D0195 claimed** (2026-08-29): the hardness port is faithful at the shallow end, anchored on
seconds-per-cell. Clay breaks in 17 ticks = 0.283 s against legacy earth's 0.28 s; hardrock in 51 ticks =
0.850 s against legacy stone's 0.850 s, exact. Both numbers are correct and both are still asserted.

**What D0200 establishes** (2026-08-29): seconds-per-cell was never the portable quantity. Legacy's cell is
32px and one charge removes one of them — one square **metre**. This world's metre is the 16px logic tile,
which is **16 terrain cells**, and Slice 1 charged a full metre's worth of legacy hardness-seconds to
remove ONE of them. Per unit volume, Slice 1 mines at **0.06x legacy** — sixteen times slower — and no
seconds-per-cell comparison could ever have shown it, because the comparison holds fixed the very thing
that differs.

**Why this one is worth reading twice.** D0195 states the correct rule explicitly, about a different
constant, in the same entry: legacy's `REACH_CELLS = 3.2` is 102.4px there and 51.2px here **because both
codebases' cells are one metre, so the portable quantity is metres, not pixels**. The reach was converted
through the metre and the hardness was not — and the hardness section even opens by saying the two hardness
scales do not agree, which is true and which is what drew attention away. Having the general rule written
down, in the same file, adjacent, was not enough to make it get applied to the second constant.

**What this suggests for the rest of the migration.** Every ported constant should be asked which unit it
travels in, and the answer "seconds" or "cells" is not sufficient on its own — seconds *per what*, cells
*of what size*. `docs/DECISIONS_LEDGER.md` D0195's own framing ("two codebases can share a constant's name
and not its units") was right and was applied to only one of the two constants in front of it.

## D0203 corrects D0202 — I asserted a missing check by analogy, without reading ours

**What D0202 claimed** (2026-08-29): "the step-up's HEIGHT is checked, the destination's FIT is not."

**What is actually there:** `sim/body/horizontal_resolve.gd::_try_step` calls
`_box_blocked(grid, left, top - lift, right, bottom - lift)` and refuses the step if anything in that box
is solid — the destination, validated, at the body's post-integration x, with the half-open bounds right.

**How the wrong claim got made, which is the reusable part.** I read legacy's step-up first
(`var lifted := Rect2(...); if not _aabb_blocked(lifted)`), saw a destination check, saw our body ending
up inside rock, and concluded ours lacked one. That is an inference from a difference in OUTCOME to a
difference in CODE, across two files, one of which I had read and one of which I had not. The trace was
already showing the real tell and I did not use it: the tick ends with `floor_source_this_tick =
"try_step"` and `on_floor = false`, which `_try_step` cannot produce, because it sets `on_floor = true`.
The step is undone later in the same tick by the vertical pass.

**The screen:** before naming a missing guard, open the function and look for it. A reference
implementation having a check is evidence about the reference, not about us.

**What survives:** the defect, its reproduction, its independence from mining, and its reachability at
bite radius 0. Only the mechanism sentence was wrong — which matters, because that sentence is what tells
whoever takes the collision arc where to look, and it pointed at the wrong stage of the tick.

## D0204 corrects my own handover instruction — "immaterial for a feel judgment" was a guess

**What I wrote** when telling the director how to play the build: the working tree carries D0139's
uncommitted `vertical_resolve.gd`, "it changes how the body settles… **immaterial for a feel judgment**."

**Measured after they played it:** the same 710-tick session replays to **8 bad ticks in 4 episodes (1%)**
on a clean checkout and **268 bad ticks in 12 episodes (38%)** with D0139's change. **33x.** A third of
the session they judged was spent inside rock or outside the world, for a reason that is not in `main`.

**The error, precisely.** The only evidence I had was D0198's 7% tick-count difference on a scripted
`--mine-down` agent run, and I generalised it to a human at the keyboard. A scripted mine-down run never
presses LEFT or RIGHT against a wall — **the input class the defect requires is absent from the run I
extrapolated from**. This is `docs/DECISIONS_LEDGER.md`'s "expected null carries no conclusion" applied to
a null I did not even have: check the treatment's DOMAIN before letting an unrelated measurement stand in
for it.

**The remedy is procedural, not technical:** a build handed over for a feel judgment is played from a
clean checkout, or the dirty-tree difference is measured before it is characterised.
`tools/capture_moments.sh` already refuses to let a dirty tree pass as reproducible (D0198); "go play it"
had no equivalent.

## D0206 corrects D0137's remedy, and supersedes D0139 — the criterion, not the caller

**What was claimed:** D0137 diagnosed `resolve_floor`'s ground plane as the source of the embedding, and
D0139 built the remedy: make `resolve_floor` refuse a landing that does not have full-footprint support.

**Measured:** the flaw moved rather than closing. `grounded_no_floor` stayed at exactly **59** while the
attribution flipped — `resolve_floor` 55 to 0, `grid_floor_backstop` 4 to 59. The count could not tell a
fix from a relocation, so the SET was diffed: all **805,456** violations byte-identical in seed, tick and
position, with only the source field changing hands.

**The error, precisely.** The diagnosis was right and the remedy was aimed at one CALLER of a shared
criterion, while the other caller kept using the old one. A criterion two paths both depend on cannot be
fixed in one of them; that is what "the flaw just relocates" means mechanically. D0206's fix is
`footprint_surface_y`, the single height either path may ground at.

**The remedy that generalises:** when a count does not move, diff the SET before believing either story.
D0213 was held to the same test and passed it differently — one line removed, zero added.

## D0212 corrects D0209 — "the player asked for it" was the wrong test

**What was claimed:** D0209 gated the auto step-up on being recently grounded and explicitly EXEMPTED the
mantle, reasoning that it "already requires `input.mantle_hold`, so it is a thing the player asks for
rather than something that happens to them."

**Measured, from the director's own session:** three mantles at the identical cell (217, 33), the body
travelling UPWARD past the movement course's perch, yanked **17.4 / 26.8 / 24.7 px in ONE tick** — up to
1605 px/s, nearly 3x terminal velocity. It bypassed the jump and made a section built to demand a precise
landing free. The director's word for it was "glitch".

**The error, precisely.** `mantle_hold` is toward-and-UP held, and holding up while jumping is not a
request to climb. The gate I reasoned about was a gate on INTENT; what the flag actually reports is a key
state a player has every reason to be holding for other reasons. **An input flag is not consent unless
the input means only one thing.**

**The remedy:** the same `recently_grounded` precondition as its sibling. D0213 later found the third
instance of the class and gated it on MOTION instead, because a ceiling is only ever contacted airborne —
so the shared principle is consent, not grounding.

## D0217 corrects D0201's gate — a regex read a workflow that could not parse

**What was claimed:** gate 31 (`check_suite_coverage.py`, built in D0201) certifies that every tracked
`tests/test_*.gd` is actually run by CI, by matching `res://tests/test_*.gd` in `.github/workflows/harness.yml`.

**Measured:** two step names written with an unquoted colon made that workflow invalid YAML. GitHub ran
**zero jobs** on the commit and reported it as an ordinary red push; the gate read the same bytes locally,
found every suite it was looking for, and printed **PASS**.

**The error, precisely.** A regex over a file that does not parse still finds every string it is looking
for. The gate was built to compare two SETS and never asked whether the file it was reading was a
workflow at all — and this file is the one where that matters most, because a workflow that cannot load
runs no gate, so every OTHER gate's verdict for that commit was also unchecked and nothing said so.

**The remedy:** parse before matching, and a permanent mutation test
(`tools/layer_lint/test_check_suite_coverage.py`, 5/5 branches observed) that asserts both the new
behaviour AND that the old regex-only version passes on the broken files.

## D0222 corrects `docs/NEEDS_DIRECTOR.md` P007 — the paragraph explaining what was left undone was the one nobody measured

The odd one out on this page: the corrected claim is not in the ledger at all, it is in the parked-items
document written the same day. Recorded here anyway, because the failure is about *where* verification
stopped, and that is a lesson about this page's own subject.

**What was claimed:** P007 closed by naming two sub-items as cheap and needing no ruling — that
`test_reveal_spawn_bounds` "generates each grid at least twice ... caching roughly halves its 82s", and
that in the fuzz probe "each seed is fully independent (`SplitRng.new(seed)`), so a `--seed-start=` of
about three lines makes 4-way sharding exact."

**Measured:** the suite calls `ShaftGenerator.generate` **517 times, 149.3 ms each, 77.2s of its 81.1s**
— four passes over the same 128 `(site, seed)` pairs, not two. And the seeds are not independent by
design: the probe builds `HostileChamber` **once, above the seed loop**, and every seed shares that one
object.

**The error, precisely.** Every number in the round it belonged to was checked against tool output. The
paragraph describing the work *not* being done was written from reading, because a parked item feels
like a note rather than a claim. It is a claim — a director reads "cheap, no ruling needed" and
schedules against it. **Verification has to cover what you are declining to do, not only what you
shipped**, and the tell is that both errors ran the same direction: each made the deferred work sound
safer and smaller than the measurement shows it to be.

**What it turned up.** Checking whether the shared world actually bites found that the fuzzer rarely
excavates at all — and the first write-up of *that* was itself wrong, which is the next entry.

## D0223 corrects D0222 — a zero from a window too small to contain the event, written in the same hour as the note warning about exactly that

**What was claimed:** D0222 measured **1,544 `dig_pressed` presses and 0 excavations** over 6 seeds x 500
ticks and concluded that `--no-dig` is a control that cannot fail, that the fuzz suite has never
exercised mining, and that seed independence holds by accident.

**Measured at the configurations that ship:** gate 26 (100 x 500) does **1** excavation in 50,000 ticks;
gate 29 (498 x 1500) does **107** in 747,000. The dig path works. At roughly one event per 25,000
presses, a 3,000-tick window is *expected* to be empty.

**The error, precisely.** The null was predicted by a working dig path as surely as by a broken one, so
it discriminated nothing — this page's own expected-null class, applied to the write-up of this page's
own expected-null class. Two things made it feel verified rather than guessed. First, **corroboration
inside one window is one measurement, not three**: the constant solid-cell count and the identical
`--no-dig` A/B were the same 3,000 ticks reporting the same absence. Second, **the refutation was already
in the ledger** — D0127's full-sweep A/B measured `bounds` at 805,397 dig-on against 18,157 dig-off,
which no dead code path produces, and D0222 was written without re-reading the entry it contradicted.

**Direction, again.** D0222's own lesson was that unverified claims lean toward whatever made stopping
feel justified. This one leaned the same way: "the path is dead" is a tidier finding than "the path fires
once in 50,000 ticks", and tidier was wrong.

**What survives, and it is the better finding.** The per-commit fuzzer's entire mining exposure is one
excavation, so nothing dig-caused is meaningfully gated per commit. And the seeds are **not** independent
— the shared chamber is genuinely mutated mid-run (seed 45 digs a cell; seeds 46-99 inherit it), so
P007's sharding proposal is inexact today rather than fragile later.

## D0233 corrects D0230 — the tool written to stop a quiet green shipped as one

**What was claimed:** `tools/run_local_battery.sh` runs exactly the suites CI runs per commit, and closes
the trap where a hand-written battery picks up the schedule-only 1.5M-tick sweep.

**Measured:** run on this machine it printed `mapfile: command not found`, executed **zero suites**, and
the pipeline it was called in reported success. macOS ships bash 3.2; `mapfile` is bash 4.

**The error, precisely.** The file's entire subject is a battery that appears to work while covering the
wrong population, and it shipped covering the empty one. Two things kept it invisible for as long as they
did: `set -euo pipefail` did not save it because the failure was swallowed by the pipeline it was called
in, and — the part worth carrying — **the only reason it was caught is that the tool was RUN rather than
reported.** A commit message describing it would have been entirely accurate about the intent.

**What that says about the guard.** The zero-suite check was written as belt-and-braces and turned out to
be the only thing between a broken parse and a green report. A guard against the house failure class is
not redundancy; it is the load-bearing part, and it deserves to be treated that way when the temptation
is to trim it.

**A number with a twenty-minute shelf life.** D0230 recorded 37 suites against a whole-file grep's 38.
Adding `test_recorded_sessions` to CI in the same run made it 38 against 39 — the difference still exactly
`test_body_fuzz.gd`. Corrected in four files. A count is only true against the tree that produced it, and
writing one into prose while still editing that tree is how it goes stale before anyone reads it.

## D0293 corrects the draught's own port — a lifted mechanism that carried the sentence and not the behaviour

**What was claimed:** `view/fx/particles.gd::draught` was ported from legacy, and
`tests/body/debug_scene_common.gd` documented it as "the hollow tell's visual half".

**Measured:** read against `legacy/scenes/main.gd:1600-1609`, it was wrong in four independent ways —
it fired on BREACH rather than during the charge, drifted a hardcoded direction rather than the swing's,
threw a hardcoded 6 rather than `1 + int(2 * hollow)`, and sat on the broken cell's centre rather than
the near face.

**The error, precisely.** `sim/mining/mining.gd` already carried legacy's own sentence about why the
amount rides the reading — *"closing on a cavity is a crescendo you can act on rather than a flag that
flips"* — while the code five files away was the flag. A quoted rationale is not an implemented one, and
a port that lifts the comment reads as more finished than one that lifts nothing.

**Why nothing caught it.** Each of the four is a plausible cue on its own, so watching the screen could
never separate them; and `Particles` reports only its own size, so a test written against the emitter
could tell that something was emitted and nothing about where it went, which way it drifted, or how much
of it there was. `draught_plan` returns the decision as data now, and all four are rows.

## D0304 corrects D0300 — a mechanism guessed and stated as a finding, in the same entry that measured the thing correctly

**The claim.** D0300 recorded that milestone captures are not byte-reproducible when an animated layer is
active, and gave the cause as *"`WorldView.anim_time()` is deterministic in RENDERED ticks, and the number
of render ticks before a given SIM tick is not."*

**What is wrong with it.** `tests/body/reveal_scene.gd` calls `WorldView.refresh()` from
`_physics_process`, once per sim tick, so `_anim_ticks` and `_tick_count` advance together and the clock
is deterministic in exactly the way that sentence says it is not. The observation D0300 was built on — two
runs of one commit differing by 35,408 pixels — was real and correctly measured. The explanation attached
to it was never checked, and it reads with the same confidence as the measurement beside it.

**What was actually going on**, found by subtraction rather than by reasoning (D0304): the shutter's two
`process_frame` awaits let the sim keep running while the pixels were read (38,900 -> 33,572 in `aim`),
and `view/fx/particles.gd`'s `randf_range` runs on an unseeded global RNG (33,572 -> **0** once the scene
seeds it). Two causes, neither of them the one named.

**The shape worth keeping.** The particle header's own argument is the interesting half: it says `randf()`
is safe here because a particle never feeds back into the sim, so it cannot make a replay diverge. That is
true, and it names the SIM as its frame. The cost of an unseeded RNG landed on a different instrument
entirely — capture-diffing, which is what caught D0289 and D0300 — and the header is silent about it
because nobody was standing in that frame when it was written. A safety argument is scoped to the frame it
names, and the scope is rarely written down.

**Why nothing caught it.** Nothing had ever compared two captures of the SAME commit. Every diff this
project has run was across a change, where a difference is expected and its size is not examined. The
control was one command away and had never been run.

## D0323 corrects D0322 — a gate built on an unmeasured number, an undisclosed modelling choice, and a floor it could not afford

**What D0322 claimed** (2026-09-01): it built `tools/coverage_check.py` — the first coverage metric this
repository has ever enforced — and wired it as QUALITY gate 33 (BLOCKING). Its threshold comment said
"63.0% at the time this was written," and it disclosed that the metric overcounts ("a name can appear
for a different reason").

**What is wrong with it.** Three things, each a different class.

1. **The number was never measured.** The tool, run then and now, reports **89/144 = 61.8%**. The 63.0%
   was the pre-engine-called-exclusion count (92/146), written into the comment before the exclusion was
   added and never re-checked — a direct violation of the standing rule that a numeric claim is verified
   against actual tool output before being written down.
2. **The load-bearing modelling choice was undisclosed.** Coverage is keyed by function NAME, not by
   definition. The real declaration count in core/+sim/ is 156; the gate's denominator is 144 (156
   declarations → 146 distinct names → 144 after engine-called exclusion). So `state_signature` in
   `sim/body/body.gd`, `sim/mining/mining.gd`, and `sim/world/tile_grid.gd` is one unit in the
   denominator, and one test reference covers all three. D0322 disclosed the overcounting direction and
   not this one — and zero of its 9 mutation branches tested it. D0323 added a 10th
   (`branch_name_collision`): two same-named functions in different files, both covered by a single
   reference.
3. **The verdict depended on that undisclosed choice, with almost no margin.** The gate was BLOCKING at
   a 60% floor with 1.8 points of headroom (89/144 = 61.8%). Keyed by definition instead of name,
   89/149 = **59.7%** — the gate flips from PASS to FAIL on a modelling decision the gate never stated,
   and three new untested functions in core/ or sim/ would have turned CI red on the next feature commit.

**The correction.** Gate 33 demoted to reported-only (`continue-on-error: true`), the floor set to
61.8% as a ratchet at the measured value — it can only go up. The gate reports; it does not block.
D0323 also states the tool's three properties (measures reference, not execution; keyed by name, not
definition; margin is thin) in the tool's docstring, `docs/QUALITY.md`, and the ledger, so a future
session does not cite 61.8% as evidence that 61.8% of `sim/` is exercised — a dead identifier never
called counts as covered, and the metric could be taken to 100% with zero new testing.

**The chain here is shallow, and worth saying so.** D0322 was written and corrected the same day; there
is no deeper origin for the wrong number than D0322 itself. What D0322 was answering — gate 14's
long-standing NO-CODE status ("≥ 85% line coverage" with no enforcing code) — is context, not a
corrected claim: gate 14's declaration is still open, and D0322 said plainly that its own weaker metric
does not satisfy it. Nothing further back needed correcting, so per this page's own rule, nothing
further back is traced.

## What this page is not

Not every ledger entry that says "found" or "fixed" is a correction — most entries describe new work,
not a repudiation of a prior claim. This page exists only for entries whose own text names an earlier
entry as wrong. A finding that was simply incomplete (e.g., D0139's own still-open investigation) is not
a correction until something explicitly supersedes its claim; it stays in `docs/WORKING.md` instead.
