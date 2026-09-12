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

**D0496, read and deliberately excluded, not silently dropped:** its header names the WRONG STACK lesson
("names every floor drop and every wrong stack"), which trips the keyword scan on "wrong"; the entry adds
the drop's refusals to the refusal slot and corrects nothing. Noted so the freshness gate stops re-flagging
it, by the same reasoning as D0181 and D0185 rather than by narrowing the pattern.

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

## D0395 corrects D0394 — a file count written from the plan's list, not from the deletion

**What D0394 claimed** (2026-09-04): fifty dead legacy files removed, "nine `legacy/scenes/bazaar*.gd`,
two `legacy/src/data/` rule files, forty `legacy/tools/` scripts."

**What is wrong with it.** The deletion (`git show --diff-filter=D --name-only f3f39a59`) lists eight
bazaar scenes, not nine. The total of fifty source files stands (8 + 2 + 40; 48 `.gd` and 2 `.sh`), and
the commit removed sixty paths because ten of those scripts carried tracked `.uid` sidecars. The "nine"
was transcribed from `docs/A_PRIME_REFACTOR_PLAN.md` §3.4 rather than read off the tool's output, in the
same session that fixed an instrument for reporting green over a defect. There is no deeper origin: the
plan's list was a plan, not a claim about the tree.

## D0415 corrects D0412 — a pin count written from a sense of the suite, not from the tool

**What D0412 claimed** (2026-09-06): "`tests/test_hotbar.gd` -- an empty pack lays out nothing; the sixteen
carried-pack pins unchanged."

**What is wrong with it.** The suite asserts 34 in total across eight tests, and the commit's diff of the
file touches three `_check` lines (one rewritten, two removed). No partition of it yields sixteen. The
number was not read off any output; the standing rule against exactly this was in the same session's
brief. What stands: one pin changed, 33 unchanged and green (`ALL PASS (hotbar) -- 34 asserted`).

**D0425, read and deliberately excluded, not silently dropped:** its header says "tried and reversed" of
an experiment inside the same entry (the ore socket, captured, measured against two suites, and not kept).
Nothing earlier claimed the socket worked; there is no prior claim to correct. Noted here so the freshness
gate stops flagging it, with the same reasoning as D0181 and D0185.

## What this page is not

Not every ledger entry that says "found" or "fixed" is a correction — most entries describe new work,
not a repudiation of a prior claim. This page exists only for entries whose own text names an earlier
entry as wrong. A finding that was simply incomplete (e.g., D0139's own still-open investigation) is not
a correction until something explicitly supersedes its claim; it stays in `docs/WORKING.md` instead.

## D0438's chevron, reversed by D0443 (2026-09-06)

D0438 (2) hung a chevron over a near target so the tightened ring would be seen. It was seen: stranger 17
pointed at it, three times, on air. D0443 replaces it with an outline of the target's own metre. The D0438
entry stands as written; its chevron constants are gone from `view/hud/target_guide.gd`.

## D0433's tightening, reversed by D0447 (2026-09-06)

D0433 tightened the target ring to 0.35 m within 1.5 m of the body. D0447 restores 0.9 m at every range,
with D0443's outline of the target's metre inside it, after seven of fifteen strangers lost the first rung at
that range against none of eight who tried before. (The D0447 entry's "six of fourteen" was a miscount,
corrected here the same hour; the member lists are in the batch report.) The D0433 entry stands as written; `RING_NEAR_M` equals `RING_M`.

## D0464's metre, narrowed by D0474 (2026-09-07)

D0464 set the aim snap's tolerance to one metre for every cursor out of reach, on stranger 43's frames
(a hold on the WHITE SQUARE from 3.25 m cut the ground at the feet). The first fresh-game batch on it
(58-60) lost the opening: the strangers' habitual first press on the forge's open pocket, 3.9 m off, had
been snapping to the vein 2.3 m from the cursor, and D0464 refused it "air". D0474 keeps the metre for a
pointed ROCK out of reach and restores legacy's reach for a pointer on open air. The D0464 entry stands
as written; its far pin still holds (the cursor in that pin is on rock).

## D0536's own frame-rate claim, withdrawn inside D0536 before it was pushed (2026-09-08)

Not a correction of an earlier entry -- a correction of the entry's own first draft, recorded here
because the page's subject is being confidently wrong and this is the shape it took.

D0536's draft claimed the minimap fix moved `fps_wall` 381.4 -> 533.1 and frame p50 1.84 -> 1.38 ms, from
a before/after pair whose host-speed control held at 0.98x. A third `--front` run, of a build differing
from the second by an edit worth 0.7% of painter CPU, read 409.8 and 1.79 -- back inside the "before"
range, with the control at 61, 60 and 61 us across all three. The frame rate and the percentiles move
about 30% run to run on this host for reasons neither of the fixture's controls captures. Only the worst
frame (54.5 -> 21.5 ms, reproduced at 20.9) survived and is claimed.

**What the near-miss cost, and what stopped it:** nothing was published; the third run existed only
because a *separate* experiment (a repaint throttle, since reverted) needed a measurement. Had that
experiment not been run, a 40% frame-rate improvement would have been attributed to a change that moved
painter CPU by 0.7%. `tools/perf_fixture.py` now carries a measured noise floor per metric and prints
"not evidence" on any line that does not clear it, so the next reader does not depend on running a third
experiment by luck. `[[scrutiny-asymmetry]]`: the number that is changing is the one to distrust, and a
correction feels verified in exactly the way the original claim did.

## D0536's worst frame, corrected by D0538 and re-measured by D0540 (2026-09-08/09)

D0536 claimed the minimap fix took the worst frame of a mining run from 54.5 ms to 21.5. **D0538 (Astra's
audit) found the label was wrong**: the fixture's `max` was a MEDIAN OF PER-WINDOW MAXIMA, so neither
number was a worst frame, and the same defect had put an invented `/600` denominator under the
over-budget counts when a window actually holds 2,000-2,600 frames. The claim was withdrawn as unverified.

**D0540 re-measured it on the corrected fixture** -- the pre-D0536 minimap restored in the working tree,
both sides `--front` with the control at 1.02x -- and the claim survives with an honest number: the
observed maximum falls **61.08 -> 35.87 ms (-41%)**, and frames over 16.7 ms fall from 205 of 13,359 to
165 of 14,548. The direction was never in doubt from the meter's SLOW lines, which are actual per-frame
observations rather than medians; the fixture's own headline figure was the thing that was wrong.

**Two lessons, and the second is the one that generalises.** A summary statistic inherits the label its
author gives it, and "max" was mine; the fixture now carries `warm_window_max_median` and `warm_max`
under separate names because one of them had been answering to the other's question. And the correction
was found by an auditor reading the code, not by any run -- every number the defect produced looked
plausible, moved in the expected direction, and passed its own noise floor. `[[count-without-membership]]`,
`[[name-the-frame]]`.

Two of the same report's other conclusions were corrected in the same audit and are NOT restated: the
pass-3 utilisation figure compared repainted rectangle area against a solid-cell lane budget (different
populations), and the pass-2 "2.4-3.0x brighter" divided red channels of stale unmatched captures. Both
are withdrawn outright. `[[mechanism-vs-population]]`, `[[two-luma-conventions]]`.

## "An air chunk always fits", reversed by D0543 (2026-09-09)

`view/visuals/bake_lane.gd` promised, in its own docstring, that the window lane's budget is in solid
cells because "the painters' cost is per SOLID cell ... an air chunk costs it nothing and always fits",
and `tests/test_bake_budget.gd` pinned it as **"12 air chunks paint in one tick"**. Both were written
in D0524 and both were half right in the way that is hardest to catch: air costs the SOLID-CELL BUDGET
nothing, which is true, and the docstring then read that as costing nothing to paint, which is not the
same claim. `BakeChunk._paint` observes the whole rectangle, runs every retained painter over it --
the background wall included -- and fills the grammar map for air as well as rock; only
`TerrainPainter.cell_fill` skips air. Twelve air chunks in one tick were twelve real preparation
callbacks over 3,072 rectangle cells, admitted because the budget could not see them.

Astra's D0541 found it by reading the source, not by running anything, and the pin is what makes it
worth recording here: **the suite was green the whole time, and it was green because it asserted the
defect.** A rule and its test can share an assumption, and then the test is not a check on the rule --
it is a copy of it. `[[reversed-rule-has-a-pinning-suite]]`, `[[two-instruments-are-not-a-cover]]`.

Corrected in the same entry, and mine: D0540's "9 ms over 1024 cells" joined a peak duration and a peak
area that the instrument had maximised independently (D0541 finding 1, D0542's fix), and D0543's first
streaming verdict read "no newly-visible callbacks -> revisit only" when zero has two causes -- no new
terrain crossed, or a prefetch that never lost. The second is the answer, and the draft would have
reported it as an absence.

## `git add -A` committed a peer session's work, and the verification claim on it was false (D0546)

`d344a35d` is mine and its commit message ends "Verification: full local battery, 173 gates PASS 0 FAIL,
145 suites passed 0 failed." **That claim does not cover five of the twelve files in the commit.**

I staged with `git add -A` instead of naming paths. Astra was working in this same checkout at the same
time, and the sweep took their in-progress work with mine: `tools/metal_trace.py` (new, 73 lines),
`tools/perf_identity.py` (new, 80), `tools/test_metal_trace.py` (new, 39), and changes to
`tools/perf_fixture.py` (+57) and `tools/test_perf_fixture.py` (+96) -- 334 insertions, none of them
described by the message they were committed under, and all of them in the files the standing rule
names as Astra's.

**The timestamps make it worse than mis-attribution.** The battery ran 16:13:50-16:23:52. Those files
were written 16:20:51-16:24:03, so Astra was editing the tree while the sweep was reading it -- the
`[[sweep-reads-the-live-tree]]` failure, from the other side this time: I have been careful not to edit
during my own battery and did not think about a second session doing it. `tools/metal_trace.py` landed
at 16:24:03, **eleven seconds after the battery finished**, so it was never covered at all. The gate
that would have caught the new files, `check_untracked_files`, ran near the start of the battery when
they did not yet exist.

**What is and is not true.** Astra's own tests pass on the pushed tree (`tools/test_perf_fixture.py`
"all rules fire and all controls pass"; `tools/test_metal_trace.py` 2 tests OK), so nothing is known to
be broken. But "verified by a full battery" was not true of those files when I wrote it, and a
verification claim is exactly the kind that must not be inherited by whatever happens to be staged
beside it.

**Not reverted, deliberately.** The files are Astra's work and reverting would delete them from the
working tree they are still using; `[[never-delete-user-artifacts]]` and
`[[untracking-is-deferred-deletion]]` both apply. The record is corrected here instead, and the tree is
re-verified after the fact rather than the claim being left standing.

**The rule this earns:** stage by explicit path, never `-A`, in a repository a second session is
working in -- `[[git-add-with-a-missing-path-stages-nothing]]` warned about the opposite failure and I
took the opposite lesson too far. And a shared checkout means the battery's "do not edit during a
sweep" rule is not something one session can honour alone.

**And the guard I wrote to catch it next time was itself a no-op.** I re-ran the battery with a
before/after comparison of `git rev-parse HEAD^{tree}`, which cannot change unless someone commits --
`[[guards-that-cannot-be-false]]`, written while correcting an instance of the same class, in the same
hour. It reported "GUARD OK" over a run during which Astra wrote D0547, a new audit document, and
further changes to two `tools/` files. The quantity that discriminates is the WORKING tree, not HEAD's:
`git status --porcelain` plus a content hash of the tracked files. The re-verification passed (173
gates, 145 suites) but it is not a verification of any single tree state, and it is recorded that way.

## "360 fps is already met on the average and the median" — withdrawn on the first valid frame data (D0551)

`docs/WORKING.md` carried, since the five-pass programme: "The dig workload runs at 400-530 frames a
second with a frame p50 of 1.4-1.8 ms, so the director's 360 fps (2.78 ms) is already met on the average
and the median."

**The frame rate half is withdrawn.** Those runs drew into windows macOS was not presenting -- the same
regime `[[window-regime-is-inside-the-measurement]]` recorded at 114 against 381 fps for identical work,
and the reason `--front` exists. `--front` could not deliver it either: it launched the seat with
`--unfocused` until Astra's D0547, so every frame number since D0542 was WITHHELD at focus 0.00. On a
quiet desktop with the fix, three repetitions of each workload at 100% focus give **sustained `fps_wall`
of 348.7-394.6, straddling 360 rather than clearing it.** The median FRAME TIME claim survives: 1.46-1.62
ms against a 2.78 ms budget.

**And the same dataset moves the target.** A still frame with zero terrain preparation has a p99 of 15.73
ms; dig's is 17.70. **89% of the tail is there when the bake does nothing at all**, and the draw phase's
p99 is flat across every workload. Nine ledger entries of bake work are worth about 2 ms of the p99 --
real, bounded, and not where the rest of the tail lives. `[[an-average-cannot-see-a-burst]]` got the
programme to per-tick peaks; this is the mirror, `[[name-the-frame]]`: the peak was real and the frame it
described was not the one the player waits on.

**Mine, and corrected inside the same hour:** I read a SINGLE repetition (182.9 fps, p50 3.06 ms) as
proof the standing claim was false and said so before gathering more. Three repetitions put dig at
348.7 / 1.55 ms. One sample was never enough to overturn a claim, and it is the same
`[[scrutiny-asymmetry]]` trap -- a number is most dangerous when it is changing, and I was the one
changing it.

## "89% of the tail is there when the bake does nothing" — withdrawn, and the flag that caused it (D0555)

D0551 read its own valid dataset correctly and drew the wrong conclusion from it, and I wrote the
redirection into the ledger, `docs/WORKING.md` and the corrections file above: still's p99 of 15.73 ms
against dig's 17.70, therefore the bake is worth 2.0 ms, therefore "the next target is that floor, not
another bake treatment", therefore D0549's and D0550's treatments "are simply worth ~11% of the p99, and
that should be said before anyone spends a night on them."

**The floor I subtracted was not a property of the game.** Every run in that dataset passed
`--disable-vsync --max-fps 0`, which lets this app produce ~400 frames a second against a 120 Hz screen.
It then blocks in `RenderingServer.draw` on a drawable that does not exist yet, and that block is ~13 ms
at the p99 of **both** arms. Subtracting one from the other left the difference between two waits.
Measured in the shipped regime -- no vsync flag, which is what `project.godot` gives a player -- the same
comparison reads **13.81-15.97 for still against 23.37-25.45 for dig**, and the dropped-frame counts are
**1-5 a window against 28-30**. The bake is worth ~9.5 ms of the p99, not 2.0.

The tell was in the data the whole time and I had already quoted it: "the draw phase's p99 is flat across
every workload -- and *lowest* on the workload doing the most terrain work." A phase whose p99 is
indifferent to the work, and slightly *cheaper* when there is more of it, is not measuring the work.
I wrote that sentence as evidence for the redirection when it was evidence against the instrument.
`[[expected-null-carries-no-conclusion]]`: the treatment's domain was never checked before the null was
allowed to exclude a cause.

**The rate was the other half.** `over16.7ms` is a fraction, and the flag that inflated the wait also
inflated the denominator: dig drops 28-30 frames a window either way, over 597 frames vsynced and 1598
unvsynced. The rate moved 2.5-4x on a game that did not change, and it moved in the direction that made
the defect look smaller. `[[read-the-count-not-the-rate]]` was already in the index, and the count was
already in the log line beside the rate.

**Not withdrawn:** D0551's frame-rate correction stands (`fps_wall` 348.7-394.6 under those flags, and
the median frame time clears its budget), its refusal to claim a cause for the draw-phase floor stands
and was the right call, and the nine entries of bake work it questioned were real. What is withdrawn is
the sizing that told the next session not to bother with them.

## The reach is 3.2 metres, not one — my own playtest report published the wrong number (D0557)

`docs/playtests/2026-09-09_strangers127-132_hotbar.md`, reporting S128's and S132's failures at the RIG:
"`Reach.NUM/DEN` is 16/5 m = 3.2 m at legacy's cell, which is **one metre** in this world
(`core/reach.gd:13-15`)."

I read the docstring instead of the arithmetic. `in_reach` compares against `(NUM/DEN) * tile_px`, and
every caller passes `Interface.Observation.LOGIC_PX`, which is 16 px and IS the metre. So the radius is
**3.2 metres here, exactly as in legacy** -- the lines I cited say `tile_px` is one metre in both worlds,
which is the opposite of what I took them to mean. Measured on the sim's own call: in reach at 3.15 m,
refused at 3.25 m.

**It changed the diagnosis, which is why it is here and not just fixed.** "Reach is one metre" makes the
wall a cruelly tight rule and points at loosening it -- a sim change, on the director's desk. Reach of
3.2 m makes the wall a LEGIBILITY problem: nothing on screen distinguished 3.2 m from the 5 m at which
S128 was refused. That is what D0557 draws, and it is a view change that alters no rule. A wrong constant
had aimed the fix at the wrong layer. `[[invented-label-for-real-data]]` is the neighbouring failure --
this one is worse, because I did not invent the number, I misread a docstring that was trying to warn me.

The number is now printed by `tests/test_ring_word.gd` on every run rather than quoted from prose.

## "S134 never saw a drop lesson" — a window I drew from without naming (D0561)

Classifying strangers 133-138, I sampled the last forty bursts of S134's `observation_*.json`, found no
drop lesson in them, and wrote in this session that it "never saw a drop lesson at all". It saw one:
`dropped_short` at **burst 8**, outside the window I had sliced. I caught it two commands later, when a
full pass over every burst printed the lesson timeline, and said so before it reached the report.

**A window is a claim about a population.** I took the last forty of fifty-four bursts because the seat's
failure was at the END of its run — a reasonable place to look, and the wrong place to conclude "never"
from. The word "never" quantifies over everything, and nothing about a tail slice licenses it.
`[[name-the-frame]]`: the number described the frame that produced it, and I had not named the frame.

**What it would have cost.** Nothing, this time, because the fuller pass came before the write-up. Had it
not, the report would have said the game showed S134 no drop lesson while it stood at the rig — pointing
the next session at a missing-lesson bug that does not exist. The receipts say the opposite: the lesson
fired early, the seat then walked to the world's east edge, and the real finding is the edge.

The conclusion that survives is the one built on the full pass: S134's own final report ("TOO FAR every
time at the CREW RIG, from 7+ positions") is refuted by its receipts — one `dropped_short` in 54 bursts
and no `far` refusal at all. That stands, and it is why the batch is classified from receipts.

## "This does NOT flatten depth" — a claim about a clamp I never did the arithmetic on (D0576, D0577)

D0569 floored the veil at 0.55 to lift an underground that measured 0.0195 against a reference's 0.15,
and I wrote into `veil_light.gd`'s own header that the floor "does NOT flatten depth", with the
reference's brighter-deep-than-surface reading as the evidence. Astra checked the arithmetic. Underground
`sky` is `1 - AMBIENT_DARK` = 0.34 and `shade` cannot exceed `1 + KEY_STRENGTH` = 1.30, so the combined
output tops out at **0.442 — strictly below the 0.55 floor**. Every solid cell below the scatter band
clamped to the floor. Measured after they said so: buried rock, mid rock, a lit cut face, cave air and
true void all returned rgb (0.5500, 0.5610, 0.6382). Not flattened depth — flattened *everything*.

**The prose reasoned about the term I was thinking about, and the code multiplied all of them.** I
checked the floor against the depth term (`sky`), which the reference discussion was about, and never
against the product it was actually applied to. Three constants, one multiplication.
`[[caveat-in-prose-does-not-protect]]`, one layer up: I did not merely state a limit and then violate
it, I stated the limit's *inverse* and shipped it as a header.

**It cost a second, larger error.** With the veil constant underground, `material_colour` was the only
term left varying — so when the deep still measured short, brightening materials looked like the only
available lever. That was D0575: three per-material scale factors, a broken port provenance, and a real
gate red (`test_material_palette.gd`, coal 0.0933 against a 0.1426 floor). It was a symptom treatment on
a self-inflicted wound, and it is withdrawn. `[[stacked-faults-attribution]]` runs in this direction too:
a fault of mine made every nearby measurement look like it needed its own fix.

**And the suite was pinning it.** `test_flat_planes.gd` asserted `level_rgb(0.0) == level_rgb(DEEP_FLOOR)`
— "no light at all and floor-light are the same colour" — which is the flattening written down as a
feature. Green, true, and load-bearing in the wrong direction: `[[reversed-rule-has-a-pinning-suite]]`.
It now pins *distinctness and order* across the five things that exist underground, and restoring D0569's
clamp turns four assertions red.

The same audit reproduced two slump bugs my 33 green assertions missed (a grain moving twice in a step; a
grain the body blocked being dropped from the queue forever), and a third test of mine that was vacuous
in this repo's house way — `[[instrument-cannot-register-subject]]`, for the second time in that one
file. Measured both ways on this tree: delete the rest clause in `Slump.target` and the old test prints
`PASS: a cell resting on rock stays where it is`; the fixed test prints `FAIL` on the same line. D0576.

**What survives.** The brightness reading that motivated D0569 was correct and is unchanged — our
underground really did live in the bottom sixth of the range. What replaces the clamp is an ambient the
deep is *lifted by* rather than clamped to, ramped by depth so it cannot touch the surface, with the two
constants picked off a measured sweep rather than chosen. The lesson is narrower than "check your
arithmetic": **a guard placed on a combined quantity needs its bound checked against that quantity's
actual range, not against the one term the guard was designed for.**

## P036 was wrong a second way, and the first correction did not catch it (D0580)

The entry above withdraws P036's premise: I claimed the renderer multiplies only, and the light pass has
been additive since D0373. That correction was right and incomplete. **P036 was also wrong about its own
arithmetic**, and the reason nobody noticed is that the arithmetic was done through the defect.

P036 said a lit cell can never exceed the material's base colour, so the reference's lit rock (0.377)
was out of reach. Measured after D0577 removed D0569's floor: the multiply half alone gives lit deep
rock **0.163 to 0.234**, and the additive pass adds about **0.148** of luma at a pool centre
(`LAMP_BLOOM` 0.17 through `LAMP_COLOR`). 0.234 + 0.148 = 0.382, against a reference of 0.377.

**Every number P036 quoted was measured while the veil was a constant.** D0569 clamped the combined
output at 0.55 when the underground's whole range tops out at 0.442, so every measurement taken between
D0569 and D0577 was taken through a flat field. The conclusion "no light constant can reach it" was true
of that build and false of the model — `[[name-the-frame]]`, where the frame was a bug I had introduced
myself four commits earlier.

**The general shape.** When a measurement says a target is unreachable, check whether the instrument is
standing on something you changed. Two of my six false claims tonight (this one and the rock-texture
premise) were measurements taken through a condition I had introduced and forgotten was there.

A sixth, smaller one, for the tally rather than for the lesson: I reported twice in-session that "godrays
have no test at all". `tests/test_light_painter.gd:87` has `_test_the_godray()` with seven assertions.
The grep behind the claim ended in `| head -8` and the godray lines fell below the cut. Nothing shipped
on it. `[[read-the-count-not-the-rate]]`'s neighbour: a truncated list is not an empty one.

## "The routing step was unbuildable" — the premise the slump was built on (D0582)

`sim/mining/slump.gd`'s header justified the whole feature by claiming `docs/GDD.md` §13's "holes:
gravity routing. free. dug, not built" was "unbuildable, because nothing in the world moved unless a
verb moved it." **That step was already built**, and by a system this file never touches:
`sim/items/landing.gd`'s `column_landing` walks a dropped item down its column through open air and into
a machine's buffer if it meets one, and `Items.resettle_pile_above` re-drops a pile when the metre under
it is bored out. Items have always fallen through holes you dig.

**The conflation was between terrain falling and items falling through dug space.** They are different
systems with different owners, and "gravity routing" is the second one. Astra's audit reached this
independently — "moving clay terrain is not transporting consumable coal into a forge" — and I recorded
their conclusion in the queue without noticing it also invalidated the header of the file I had written.

**What made it durable.** The claim was written into the source as justification, so every later reader
— including me, four days later, quoting it back in a queue item — met it as an established premise
rather than a claim to check. `[[superseded-draft-above-its-amendment]]`: prose that was never true,
shipped beside the code that refutes it. The check that would have caught it is one grep for who else
moves an item down a column, and it takes a minute.

**The feature survives the correction, and its scope does not.** Slump does buy something real — the
world answering a blow, which `docs/NORTH_STAR.md` §2.1 says nothing did. But asked for the first time
what it costs, on the real world: a body-height corridor at 4 m or 8 m refills **100%**, and one 1 m
staircase step moves **1,571 cells** for the 15 it dug. That is P043, and it is the director's.

**The general shape, and it is the third time tonight.** A number or a claim is most dangerous where it
is load-bearing and oldest — this one, D0569's floor ("does NOT flatten depth"), and P036's arithmetic
were all premises written into source or a ledger and then reasoned from rather than re-checked.


## 2026-09-10 · "One ruling would reach all of it" — P042's central claim, and it was never checked

**What I wrote, in `docs/NEEDS_DIRECTOR.md` P042, and repeated in the decision brief as D2:** that a
`d3`/`d4` naming the orphan machines "reaches four machines and four recipes in a single data change —
no new systems, no new art, and the recipes already exist and are already tested."

**It is false.** Astra found the first link: `data/materials/ore_iron.yaml` yields `ore`, while
`data/recipes/smelt_iron.yaml` consumes `iron`. Checking the whole graph rather than that one pair,
**nothing in the game produces `iron` and nothing produces `rich_ore`** — the only two items any recipe
consumes that no material yields and no recipe outputs. A `d3` granting `iron_forge` grants a machine
that can never run once.

**What made it durable.** I counted the machines and I counted the recipes, and I checked that each
orphan recipe HAD a machine. I never asked the other question — whether its INPUTS existed. The two
counts were both right; the join between them was never computed. `[[two-instruments-are-not-a-cover]]`:
two correct counts are not a reachability proof, and the population they had to be reconciled over was
the item ids, which neither of them ranged over.

**And the shape of the number flattered it.** "6 orphan machines, 4 stranded recipes, one data change"
is a tidy story with a cheap ending, which is exactly the kind of claim that gets quoted forward instead
of re-derived — I quoted it twice myself, once into P042 and once into the brief Astra was reading.
`[[scrutiny-asymmetry]]`, and the same lesson as the entry above it: the claim was load-bearing, so it
was met as a premise.

**The correction is a strictly better item.** The four unreachable recipes are unreachable TWICE over —
no machine and no input — so the gap is one chain to author, not six switches to flip. That is a sharper
statement of the work than the wrong version was, and it is the one the director can rule on.

## 2026-09-10 · "Six orphan machines, not seven" — the correction was wrong too, and a bench is why

**What I wrote,** in `docs/WORKING.md` item 43 and `docs/NEEDS_DIRECTOR.md` P042: "**The queue said seven
orphans; it is six.** `torch` is placed by a start and is reachable. Recorded because the queue's list
has been quoted twice and would have been quoted again."

**`torch` is placed by `data/starts/lighting_bench.yaml`, whose own first line says it is "a scenario
record, not a start of play".** It appears in no other start. Under the start the game actually boots --
`shell/main.gd`'s `const START`, which is `tutorial` -- torch is an orphan, and so are `conduit` and
`lift`, which appear only in `dev_kit`. **The count is nine.**

**What made it durable, and it is the sharper lesson:** this was itself a *correction*. I had gone
looking for an error in the queue's number, found one, and stopped at the first thing that moved the
count — without asking what "placed by a start" had to mean for the claim to be about the shipped game.
`[[scrutiny-asymmetry]]` says a number is most dangerous when it is CHANGING, and that corrections feel
verified. This is that, exactly: the corrected number was quoted onward with more confidence than the
original, into P042 and into the decision brief Astra read.

**The structural cause is that nothing in `data/` marks which start is the shipped one.** `site:` is
present on `tutorial`, `beacon_probe` and `lighting_bench` alike — it separates "stamps world geometry"
from "stamps a pack", which is the wrong axis. The only machine-readable discriminator in the repository
is one GDScript constant. A human counting by eye has no partition to count against, which is why the
count was wrong twice and why `check_content_reachable.py` (gate 37) reads that constant rather than
accepting a list.

**Found by the gate on its first run against the real tree** (`check_content_reachable.py`, QUALITY gate
37, **D0591**), not by re-reading the claim — which is the argument for that gate in one line: the count
had been read twice and corrected once, and none of that reached the fact that a bench is not the game.

## 2026-09-11 · The grass did not exist, and its own 20-assertion suite said it did (D0595 → D0596)

**What shipped, in D0595:** `GrassPainter` built its batch with a colour per POINT.
`draw_multiline_colors` asserts `colors.size() * 2 == points.size()` in NATIVE code, so **every call
failed and drew nothing.** The feature was inert from the moment it landed.

**What said so, and what did not.** The suite written for it was 20 of 20 — every assertion was on a pure
function (`blade_height`, `blade_lean`, `grassy`, `blade_color`), and not one of them touched the draw.
The failure surfaced in **`test_main_boot` and `test_settings_live`**, two suites with nothing to do with
grass, because they boot the real stack and `tools/run_gd_test.sh`'s D0149 guard reads engine-level ERROR
lines. Exit code 0, no script error, no failed assertion — `[[error-path-returns-passing-value]]` in its
native-call form.

**Then the fix for the test was wrong too, and that is the sharper half.** I added a test that ran `paint`
with a real canvas inside a real draw pass, re-applied the bug as a mutation, and **it stayed green.** The
posed world produced no blades, so the batch was empty and the draw was never reached.
`[[instrument-cannot-register-subject]]`: a draw test that draws nothing registers nothing, and it
reports that as a pass. I had written the instrument and declared it good without running the mutation
first — the mutation is the only thing that caught it.

**What the suite does now.** `batch()` is split out so the field is data, and the test **proves the batch
is non-empty before asserting anything about it** — the control that the first version lacked. Two
mutations witnessed: the colour-per-point bug fires the invariant, and an emptied batch fires the control
rather than passing vacuously.

**The general shape.** Every pure-function assertion in that file was true while the feature was absent.
Purity is what makes a function testable and it is also what lets a suite be complete, green, and about
nothing that reaches the screen. A painter needs one assertion on the thing it hands the engine.

## 2026-09-11 · "At 0.15 the stars read" — they had never once been drawn (D0583 → D0598)

**What I wrote, in D0583 and in `sky_painter.gd`'s own header:** that moving `DAYLIGHT` to 0.15 "puts the
starfield well inside its `< 0.85` window instead of at the faint edge of it", and that "at 0.15 the
stars read". That reasoning moved the entire sky to night.

**The starfield was invisible, and had been since it was written.** Two scale errors, neither reachable
without rendering a frame: every star's radius was `(1.1..1.9) * SCALE` = **0.14 to 0.24 world pixels**,
sub-pixel; and the whole field was placed in a 47 px band sitting ON the horizon, behind the trees.
Measured on a real 1920x1080 night capture: `visible_stars()` returned 42 and the sky held **zero pixels
above 0.12 luma across 111,600 samples**.

**What made it durable.** The check I ran was `DAYLIGHT < 0.85` — the gate the code itself tests — and it
was true. `tests/test_sky_painter.gd` asserted the starfield was "non-empty and does not lattice", which
was also true: `visible_stars()` returns 42 positions whether or not a single pixel reaches the screen.
Both instruments measured the list, and the claim was about the picture.
`[[instrument-cannot-register-subject]]`, and the same shape as D0596 the same night: a suite complete,
green, and about nothing the player can see.

**The general lesson, and it is the one the whole night keeps landing on.** Every claim about how the
game LOOKS that was made without a frame this session has been wrong: the band colours (D0590), the
beyond's darkness (D0597), the grass that never drew (D0596), and this. Four for four. Measuring a
function is not measuring a picture, and no amount of assertion density closes that gap.

## 2026-09-11 · The shape test that could not see the shape — twice in a row (D0601)

**What I built.** Six crowns to replace the one ellipse every tree in the world wore, and a test meant to
prove a planted forest shows more than one of them: collect each tree's leaf cells relative to its root
column, count the distinct signatures, require at least three.

**Mutation M5 kept the table and forced every tree onto crown 0. The full suite passed, 32 of 32.** The
instrument written specifically to catch that defect could not see it. Twice:

1. **Keyed to the ground.** The signature recorded `row - DATUM`, so two trees wearing the SAME crown at
   the two available trunk heights produced different signatures. It was a trunk-height detector with a
   crown-shaped name.
2. **Keyed to the crown, but reading the neighbour.** Fixed to key off each crown's own top row, it
   passed M5 again — at the record's `gap_m: 3` two crowns stand 12 cells apart and each is 13 wide, so
   the window around one root was sampling the tree NEXT to it. Every signature differed for a reason
   that had nothing to do with crowns.

Only with the trees posed 7 m apart does M5 fail, at "6 trees wearing 2 canopy SHAPES".

**What made it durable.** Both drafts produced a *plausible, varying* number — 5 shapes, 6 shapes — and a
varying number reads as a working instrument. `[[instrument-cannot-register-subject]]`, and specifically
the form where the subject is present but a confound of the same magnitude sits on top of it: trunk
height in the first draft, spacing in the second. `[[control-inside-the-measurement]]` was what finally
resolved it, in the mutation rather than in the test.

**And the mutation is the only reason any of this was found.** M4 and M6 — the ellipse restored, and the
offsets rounded to whole cells — both fired immediately and loudly. It would have been very easy to read
two of three mutations firing as a pinned guard and move on. The standing rule is that each mutation
fires ITS OWN guard; M5 fired nothing, and that was the finding.

## 2026-09-11 · Four minutes of "slow ticks" that were zero ticks (D0600/D0601 capture)

**What I was about to write:** that a headed capture run was taking about 2.7 seconds per tick, and to
theorise about the occluded-window throttle (`[[window-regime-is-inside-the-measurement]]`) and the bake
cost at zoom 2.0. Both plausible, both already in the memory.

**`sample <pid> 3` took five seconds and refuted it.** The main thread was 100% inside
`_DPSNextEvent -> _BlockUntilNextEventMatchingListInMode -> __CFRunLoopRun` — blocked in AppKit's event
loop waiting for a window that could not become active. **Zero ticks had run.** `SINKFORGE_BOOT
phases_ms` had printed, which is what made it look like a running game.

**The error I nearly made is an arithmetic one:** dividing elapsed time by a tick count the process never
reached invents a rate for a loop that never advanced. `[[read-the-count-not-the-rate]]`, and
`[[elaboration-is-the-tell]]` — the explanations were getting more elaborate, which meant the instrument
was wrong.
