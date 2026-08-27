# Rolling queue — rewritten 2026-08-23 after the director course correction

UNTRACKED working record. Rewritten in place each time the queue moves; the evidence lives in the commits
and in `docs/tracelog/sweeps/`, never only here. The single present-tense statement of run state is the
`Current status` section of `docs/handoff/OVERNIGHT_RUN_STATE.md`; this file is the short form of it.

**The version this replaces reported a head of `0b9410c`, seventeen commits ahead of an `origin/main` of
`63b75cd`, and a suite of 113. All four numbers were obsolete.** It also listed four commits twice in its
own done-list. It is rewritten rather than patched.

## State

    HEAD                  9c6bb42 (was 50603f7; +2 commits: 3222939 "graybox the Freight Winch's first
                          vertical slice", 9c6bb42 "cover the cases the director's ruling required
                          evidence for" -- lifecycle tests for relocation-mid-trip and invalid-route-load.
                          9 commits ahead of origin/main, none pushed.)
    origin/main           c3e9ea8 (unchanged; 9 behind HEAD, all nine listed under Authorization boundary)
    worktree              clean except one UNRELATED untracked file, deliberately left alone (see below).
                          One CANONICAL worktree, one branch.
    lane A worktree       /tmp/sinkforge-agent-journey-eval, detached at 0d25347, approved + disposable
                          (an earlier line here said dacfd4c: that was its base, not its head)
    lane B worktree       /private/tmp/sinkforge-itm-visual-exp, detached at 9c6bb42 (== canonical HEAD),
                          director-assigned ITM item/hotbar three-way visual experiment. COMPLETE.
                          24/24 captures verified (a real climb_to_surface arg-order bug was caught AFTER
                          the evaluator panel ran, fixed, and all 24 recaptured -- see state doc). Three
                          independent evaluators scored all four states 0-10 x 8 weighted dims: baseline
                          5.00, A 6.25, B 6.45, C 7.11, all three ranked C highest. Report delivered:
                          `docs/handoff/ITM_THREE_WAY_EXPERIMENT_REPORT.md`, recommends Option C (fallback
                          B, zero-risk-now A). Stopped at the director-selection boundary -- no merge, no
                          push. Option A/B/C diffs preserved as named git stashes in that worktree +
                          exported patch files in this session's scratchpad; worktree can be torn down
                          without losing anything.
    engine / harness      IDLE right now, confirmed via ps aux. SERIALIZED: the coordinator runs it, no
                          lane may boot Godot. A fork's bare `--check-only` (bypasses the lock) collided
                          with the coordinator's own sweep earlier this session — caught and killed live,
                          `OVERNIGHT_RUN_PROTOCOL.md` corrected so check-only always routes through
                          `with_machine.sh` now, not just full boots.
    untracked, unowned    docs/VISUAL_DESIGN_SYSTEM_AND_THREE_WAY_EVALS.md (growing across the cycle, 17K
                          -> 24K, not by this session's own work) -- excluded from every commit this cycle
                          by staging files explicitly, left alone rather than deleted or claimed; likely a
                          peer session's in-progress work despite ListAgents showing all peers idle.
    sweep at HEAD 9c6bb42  FIVE sweeps this cycle, not one. Sweep 1 (against the pre-fix diff): 108 PASS /
                          7 FAIL, four real new gaps (missing Visuals entries, a prose test-reference, the
                          new play-test rung's fragile placement) -- all fixed. Sweep 2 (after those fixes):
                          110 PASS / 5 FAIL -- one more real bug (an unguarded key reference in new prose,
                          fixed) plus three failures whose signatures pointed at display flakiness, not the
                          diff. Sweep 3 (no further code changes, a pure repeat): 114 PASS / 1 FAIL / 0 SKIP
                          of 115, GR-06 only -- confirmed sweep-2's three were environmental. Committed
                          `3222939` on this result. Sweep 4, after adding the lifecycle tests: **114 PASS /
                          1 FAIL / 0 SKIP of 115, 335s, RESULT=yes QUOTABLE=yes, assert_floors PASS,
                          assert_skip_route PASS, GR-06 only** -- all 20 new assertions confirmed PASS by
                          reading the per-layer log directly (not inferred from the aggregate), including
                          both invalid-route-load sub-cases' diagnostic prints firing correctly. Committed
                          `9c6bb42` on this result.
    sweep at HEAD         78f1086: 113 PASS / 2 FAIL / 0 SKIP of 115, 327s, logs tmp.Ak8s26rb6l
                          RESULT=yes. assert_floors regenerated + reverified standalone: PASS, QUOTABLE=yes.
                          The two FAILs are both pre-existing, known, unrelated reds: GR-06
                          (check_grapple_reads) and MI-RESIDUE (check_machine_identity, ~12%-rate
                          intermittent tail, director-owned, see RED LEDGER). Neither new, neither worsened.
    sweep at f3ac889      c3e9ea8-equivalent tree: 113 PASS / 1 FAIL / 0 SKIP of 114, 323s, logs
                          tmp.B0GUbCKUhP. RESULT=yes QUOTABLE=yes. The one FAIL is GR-06.
    sweep at c3e9ea8      113 PASS / 1 FAIL / 0 SKIP of 114, 327s, logs tmp.lFa8cQdwST
                          RESULT=yes QUOTABLE=yes. mident clean, 2 clean post-6958cb2.
    sweep at 6958cb2      113 PASS / 1 FAIL / 0 SKIP of 114, 329s, logs tmp.FFC1xhAzzL
                          RESULT=yes QUOTABLE=yes. mident floors 11 -> 13.
    sweep at c744f2a      112 PASS / 2 FAIL: check_machine_identity at 0.0459. That red is what
                          exposed the _count_over unit bug.
    sweep at baff88f      113 PASS / 1 FAIL / 0 SKIP of 114, 325s, logs tmp.NeTuSgntFN
                          RESULT=yes QUOTABLE=yes. The one FAIL is GR-06.
    sweep at 918c210      113 PASS / 1 FAIL / 0 SKIP of 114, 327s, logs tmp.hsUDvuzO92
                          RESULT=yes QUOTABLE=yes. The one FAIL is GR-06.
    sweep at 95f36ea      113 PASS / 1 FAIL / 0 SKIP of 114, 344s, logs tmp.gyMFON92KR
                          RESULT=yes QUOTABLE=yes. The one FAIL is GR-06.
                          STAND-DOWN GROUPS 6 -> 5: ceremony.words-vs-sky PAID and retired.
    sweep at 5d39f93      113 PASS / 1 FAIL / 0 SKIP of 114, 391s, logs tmp.I33ZDkwWoo
    sweep at 3858b4e      112 PASS / 2 FAIL / 0 SKIP of 114, 411s, logs tmp.yplnEA1KOY
                          check_machine_identity FIRED AGAIN: 0.0799 against 0.0000 after 180
                          frames of clearing, reference settled in 30. **fac0c71 IS NOT THE FIX**;
                          post-fix record is FOUR CLEAN AND ONE FAILED, not a changed rate.
                          The "3 clean post-fix" line this replaces was true as a count and
                          false as an implication.
                          FAIL = GR-06, same assertion as the baseline, read from the log not assumed
    sweep at the parent   113 PASS / 1 FAIL / 0 SKIP of 114, 321s, clean tree, at 5963bba
                          FAIL = check_grapple_reads GR-06, known and director-owned
                          six stand-downs as registered, assert_skip_route PASS 114,
                          assert_floors PASS 114, HARNESS_RESULT=yes, HARNESS_QUOTABLE=yes
                          IDENTICAL to the baseline at 9377a91: no new red, no worsened red
    release receipt       docs/handoff/RELEASE_RECEIPT_2026-08-23b.md, SEVEN commits, push NOT taken

## GR-06 narrowed, 2026-08-24

The suite's one standing red is an instrument artifact, and the narrowing owed on it is delivered. Both
figures are p90 but the masks are not comparable populations: the preview is a 163px outline that
SATURATES (142.7 to 149.7 across its whole top decile) and the miner is a 1071px filled sprite that does
not (88.0 to 214.2). p90 over an outline samples the outline; p90 over a blob samples its flat interior.
The verdict reverses inside the top decile: miner loses at p90, wins at p99, wins by 1.44x at the max.
Nothing changed on the strength of it. `BODY_MARGIN` untouched, 13 asserted either way, ladder printed
every run. What the comparison SHOULD be is a design call and GR-06 is director-owned.

## Zoom, and the root cause its sweep handed over, 2026-08-24

Zoom (`c744f2a`): three acceptance clauses were already met; the failing one was that the CONTROLS card
listed 25 controls and not zoom, while its `REMAP_ROWS` neighbour SPEED was on it. One free row. The first
draft overflowed the panel and a photograph caught it; the card has no width guard.

`_count_over` (`6958cb2`): compared 0..1 luma against a 12.0 LEVEL bar, so it returned zero for every
input since it was written. That made the settle loop `0 == 0` (explaining the 30-frame minimum on every
run, open since `fac0c71`) and pinned `noisy_share` to 0.0000, so the empty-stage bar demanded a
bit-identical frame. Units repaired, thresholds untouched, controls added, floors 11 to 13. NOT claimed to
close the red: `5d39f93` now has the same four-clean-one-failed record its predecessor had.

## "Building under the player", 2026-08-24 — rule kept, refusal explained

Second playtest finding. It was the one placement refusal with no words, while every sibling refusal
explains itself. Rule is NECESSARY: `player.gd` blocks on `is_solid or machine_at`, so a machine is a
collider and placing one under yourself would embed you. Footprint measured on the real scene: 2 cells
mid-column, 4 straddling a boundary, never 1, because the body is 34px tall against a 32px cell. Reason
shipped at `baff88f` into the hover readout, placed last per the house rule. Still owed: the "nearby valid
placement path" clause, which is a visible affordance and needs a director selection.

## The adjacent-machine playtest finding, 2026-08-23 night

Reproduced statically. The player's verb `try_drop` targets correctly (nearest machine in reach that eats
the item); what is missing is that nothing SHOWS which one before the press, which is the acceptance
evidence the table already asks for. Legibility, T2.1, not the sim.

The reproduction found a driver fault first: `play_agent.gd` fed machines through `try_deposit`, which
`7d2b20b` took out of the input path, and which targets by BUILD ORDER with no check that the machine
wants the item. Repaired at `918c210`, byte-identical on the rung that uses it, twenty of twenty goals.
The mutation control showed the suite could not have caught it: no rung has two machines competing for one
item. Also corrected a stale published figure, "two trips", which is one seed; the default gives three.

## T2.1 open-sky arm, PAID 2026-08-23 evening

The arm had printed a number and asserted nothing since it was written. Thirteen boots of one commit say
the blocker was the STATISTIC, not the sample size: the mean spans 43.3 to 55.1 dE (27% of the low) and the
median spans 57.2 to 61.2 (7%). The withdrawn "swings 25% run to run" was the mean's. No pooling and no
pinned standing were needed.

`ceremony.words-vs-sky` retired from `tools/stand_downs.txt`, replaced by a ratchet at 50.0, 12.6% under
the worst of thirteen. A ratchet, not a design bound. Also: thirteen boots of sky drift peak at 247 ink px
against the positive control's bar of 400, which is the "anywhere near 400" the layer's own comment said
would mean that control wants rewriting. It is kept and joined by an in-run ratio at 27x observed margin.
My first version of that ratio was a guard that could not be false and its own mutant found it.

Floors 9 -> 11. Both new assertions shown to fail first.

## check_machine_identity, 2026-08-23 evening

Mechanism found for PART of the intermittent red, by removing the subject rather than theorising.
`tools/_scratch_mident_ladder.gd` burns the registry loop's frame budget with NO MACHINE EVER PLACED and
reads coverage at a ladder of checkpoints. On an EMPTY stage it reached 0.0247 and 0.0353 in two runs,
both at or above the 0.025 two machines must differ by, with a step-plateau-reversal shape and an onset
that MOVED between runs burning identical frame counts. Clocked by wall time, not by frames.

Cause, proved from the source and not from the picture: `repaint_world()` queues terrain chunks only,
while `_lights` and `_marks` are queued from `_process`, which `_luma_patch()` switches off before posing
the clock. Every capture showed those layers as the last free-running tick drew them, and `_paint_lights`
draws the ore glint flares off `fmod(_anim_time + offset, PERIOD)`. The back-to-back noise floor cannot
see this by construction: no `_process` frame falls between its two captures.

`5d39f93` redraws both layers under the pose. Empty-stage maxabs goes from 3.9/5.2/5.1/5.9/7.2/7.6 and
climbing to a flat 4.0 at every checkpoint, and the live tightest pair moves 0.014 to 0.007 against the
0.005 the layer's own free-versus-posed table records. **It does not close the red:** the treatment arm
still stepped to 0.0378 with maxabs 40.8 at t=500. A second transient is unidentified. Next experiment is
`_skylight_alpha` at every checkpoint, since `_update_veil()` is the remaining `_process` call the pose
does not make.

## Populations, re-derived today rather than carried forward

    P_REG       114   rows registered in tools/run_harness.sh
                      = 96 add + 14 add_gl + 3 add_excl + 1 add_excl_hl
    P_FILES     109   tracked tools/check_* = 103 .gd + 6 .sh
    P_INHERIT    92   tracked .gd extending check_base.gd
                      = 92 calling _verdict()  +  0 hand-rolling  +  0 neither
    P_SCENETREE  27   tracked .gd extending SceneTree (not all of them are layers)

**`git grep` without a path filter answers 94, and the extra two are not layers.** `CONTRIBUTING.md` and
`docs/HARNESS_LAYERS.md` quote the `extends` line at the start of a line, so a search for the load-bearing
line finds the prose that documents it. **A previous record carried 94 as an inheritor count for exactly
this reason.** Constrain the glob.

**`grep -r` answers 114, and that is also legitimate.** It sees the 22 untracked `tools/_scratch_*.gd`
probes that `git grep` cannot. 92 + 22 = 114, which is the reconciliation, and it is a coincidence that
this equals `P_REG`.

    Re-derive:
      grep -cE '^(add|add_gl|add_excl|add_excl_hl) ' tools/run_harness.sh
      git grep -l '^extends "res://tools/check_base.gd"' -- '*.gd' | wc -l
      git grep -l '^extends "res://tools/check_base.gd"' -- '*.gd' | xargs grep -L '_verdict(' | wc -l

## Current item

**2026-08-25, the recovery pass is genuinely exhausted of safe autonomous next-items — full detail in
`docs/handoff/OVERNIGHT_RUN_STATE.md`'s current block.** No code this entry. #7 checked and correctly
blocked: needs unbuilt L2 twist mechanics that `PROGRESSION.md` itself gates behind a design brainstorm;
the one concrete alternative (a tool-tier warning) is already handled — Descent's own sample requires the
same tier-2 pick iron needs. Checked the "active set" table (now unblocked, since recovery is worked
through): T2.3/T3.1 and all of Tier 3 + T2.1m are tagged **c2**, a real peer session confirmed via
`ListAgents` (idle, present, 8 days old) — not safe to touch. Tier 4 is vision-level or already stable
(T4.5 audio). **Tier 5 is categorically ruled out by a standing director ruling** ("may not consume
overnight capacity... unless a selected change touches them"). One live, unclaimed thread found and
deliberately NOT started cold: T1.9/T5.11 (calibrated agent-journey evaluation), real work already in the
disposable `/private/tmp/sinkforge-agent-journey-eval` lane (gate 6 done, gates 1-5 costed in that
worktree's own `READINESS_GATES_1_AND_5.md`). Held off because the lane's ownership isn't disambiguated the
way `c2`'s tags are and `CONVERGENCE_LEDGER.md` is stale, and because the costing doc hasn't been read in
full yet — reading both is the named next step, not a decision to skip the work.

Movement (priority #1) investigated earlier — no discrete bug found, needs a human feel pass; left open.
Next: read `docs/AGENT_PLAY_EVALUATION_PROTOCOL.md` and the lane's `READINESS_GATES_1_AND_5.md` in full,
verify lane ownership, then scope the cheapest real path to one manual pilot per that item's own explicit
mandate — its text forbids more gate-closure infrastructure for its own sake.

## Prior entry, 2026-08-25 (recovery priority #6 CLOSED)

`docs/PROGRESSION.md` reads stale ("DESIGNED, not yet built" for L2+), but `research_rules.gd` shows a real
10-tech tree already built and visible in the Bazaar Bench: `ironworks` (needs DESCENT, sample IRON)
unlocks the Iron Forge. The actual gap was framing, not content: the Seal's hover text and the "breach"
step both described only the mechanism, never the payoff. Text-only fix (per the bullet's own "do not add
more machines" constraint): both now name Stonereach/iron. New layer `check_seal_desire`, 7 asserted.
`HEAD` `39d924e`, 29 ahead of origin at the time.

## Prior entry, 2026-08-25 (recovery priority #2's reachability slice CLOSED)

Picked #2 over jumping to #6 last cycle: movement (#1) is blocked on a human feel pass, but #2 had real
unstarted scope ("reachability for piles landing under machines"), the same complaint the original
playtest report made. Root cause verified with a throwaway diagnostic: a Drill above a vein and a Forge
below it, both dug into the same one-cell shaft, together plug the only way back into that column via
`player.gd`'s own collision rule. `FactorySim.pile_reachable`/`first_unreachable_pile` (bounded BFS) detect
it; a new HUD chip says so, pointing at the existing (untaught) recovery: RMB picks the sealing machine
back up. New layer `check_pile_reach`, 13 asserted. `HEAD` `4898252`, 28 ahead of origin at the time.

## Prior entry, 2026-08-25 (recovery priority #5 CLOSED)

`662ff3e`: most of the bullet had already shipped earlier (filter/stock text, mouse-clickable clear-filter
knob); the one real gap was the Hopper having no `blocked` state, so a hopper backed up on a full
downstream machine looked identical to one genuinely feeding it. New `FactorySim._status_hopper` plus the
existing status-lamp/need-bubble system, zero new glyph code. New layer `check_hopper_status`, 12 asserted.
Registering it desynced the doc-count gate (fixed) and a full sweep surfaced 7 files of pre-existing
`check_prose` em-dash/vocabulary debt from earlier cycles, fixed separately in `ba95841`. `HEAD` `ba95841`,
27 ahead of origin at the time.

## Prior entry, 2026-08-25 (recovery priority #4 CLOSED)

Four slices, all harness-verified: `8bcc206` (new "hopper" tutorial step teaching coal routing), a
`docs/DRIFT.md` find that the "Powered Drill" idea already has a different shipped answer (the Drift Rig)
so it was deliberately NOT built, `1e84eb4` (hint entries for `drift_rig`/`crusher`, both real machines with
zero explanation), `286999c` (a systematic sweep of every machine found `spur` was the last real gap — and
it's the literal answer to this whole session's opening question, "is 1 drill + 10 lodes the best
approach"). `HEAD` `286999c`, 25 ahead of origin, none pushed. Godot confirmed closed throughout.

## Prior entry, 2026-08-25 (recovery priority #3 CLOSED)

Shipped `76cce28`, `05ea38e`, `890f1b7`: mouse click on all three bazaar tabs, plus a new `B` key opening
the Bazaar directly and a family-lock stopping the wheel/number row from wandering between Pack and the
Bazaar. Scoped narrower than the mapping fork's literal inventory (kept the shared panel geometry rather
than splitting it into two panels) — see the state doc's scope note for why that was the right call, not a
shortcut. All harness-verified.

## Prior entry, 2026-08-24 (product recovery pass opened)

**held: a live local Godot session is running.** `HEAD` still `9d3f1cd`, tree clean, 17 ahead
of origin, no new commits. Process check this cycle found `pid 70783`, `godot --path
/Users/thondascully/Projects/sinkforge`, no `--headless`/`--script` flags — an interactive editor-or-play
session, 7+ minutes elapsed at 100%+ CPU when first observed. Not a leftover harness process (those run
headless and exit); this is a real local session, plausibly the director/user reviewing the current build
directly rather than through the visual packet. Per the standing "never run concurrent Godot or harness
processes" rule, held this cycle rather than launching anything that touches the engine — no harness runs,
no captures, no verification. Nothing in the doc-only convergence-mode/T3.9 findings from the prior two
entries has changed and there is no new commit to audit, so there is nothing safe to do here that would not
either duplicate prior work or risk colliding with the live session. Re-check process state next cycle;
resume engine-touching work once the machine is free.

## Prior entry

**2026-08-24, short cycle: one new angle checked, nothing else changed.** `HEAD` still `9d3f1cd`, tree
clean, 17 ahead of origin, no new director/user input. Rather than re-derive the full Tier 1–5 screening a
third time, checked one genuinely new hypothesis: does T3.9 (build has no assembly) have a T4.5-style safe
cosmetic slice (a purely visual "assembly reveal" on placement, no economy change)? Read the actual machine
draw pipeline (`scenes/machine_view.gd:185-228`) to check, rather than reasoning abstractly again — it
already branches across sprite/casing/glyph/Head-frame draw paths depending on machine kind, so even a
cosmetic-only reveal would need a new `MachineState` field, save/load handling for it (a freshly-loaded save
must not replay the animation for machines placed in a prior session), and threading through all three draw
paths. That's real surface area, not an isolated single-function addition like T4.5's `_occlusion()`.
Confirmed negative, closes the one open angle. Tiers 1–5 remain exhausted of solo-executable items; the
convergence-mode findings from the prior entry (T5.12 flakiness, gate 5/6 verified accurate, 17 commits
audited publication-ready, worktrees preserved and not deleted) all still hold, nothing to re-derive.

## Prior entry

**2026-08-24, user-directed convergence-mode cycle.** Full account in
`docs/handoff/OVERNIGHT_RUN_STATE.md`'s current top block (four numbered sections: visual packet + its
user-caught fix, gate 5/6 re-verification, 17-commit audit, worktree-preservation status). Summary:

- Built and shipped a real director-facing visual comparison packet for the Winch and ITM three-way
  experiments (an HTML artifact with embedded captures, not just a markdown report) after direct user
  feedback that a citations-only report doesn't let a director actually see the pixels. First version was
  itself defective — over-compressed wide shots that stayed blurry even when "zoomed" — caught by the user
  in real time and fixed by cropping from originals instead of shrinking them, plus a doubled-embed bug that
  had pushed the file to 14.75MB (fixed to 7.4MB). The crop work itself surfaced a real finding the user
  named directly: the Winch may be too small to read at normal play zoom regardless of which visual option
  ships — a candidate for its own priority item, separate from the A/B/C pick.
- Re-verified (not re-asserted) the agent-journey gate 5/6 reconciliation against the lane worktree's actual
  latest commit. No contradiction found — the existing `docs/PRIORITY.md` table is accurate.
- Audited all 17 unpushed commits: trailer-clean, diff stats coherent, no scope drift. A 13-layer harness
  subset found two failures (`check_hud_layout`, `check_machine_identity`); traced both to pre-existing
  flakiness by re-running the identical checks against `origin/main` in the same worktree (checkout, test,
  checkout back — no new worktree created) — both fail intermittently on ORIGIN/MAIN TOO, at a similar rate,
  and neither of the 17 commits touches the relevant drawing code. New finding recorded as **T5.12** in
  `docs/PRIORITY.md`: `check_hud_layout` is flaky (~1-in-3 fail rate, never the same scenario twice, on both
  commits tested), not root-caused yet, flagged rather than fixed mid-audit. **The 17 commits are coherent
  and publication-ready; push stays withheld per explicit instruction regardless.**
- Confirmed all five disposable worktrees still present and their content independently preserved (captures
  copied to `docs/handoff/{winch,itm}_review/`, ITM patches copied alongside its git stashes). Did NOT delete
  any worktree this cycle — their commits are detached-HEAD only, and removing the worktree without first
  tagging the commit risks eventual garbage collection; tagging felt like it cut against "create no new
  worktrees or branches" this cycle, so left the decision for explicit authorization instead of improvising.

**Next three unblocked, unchanged from the confirmation cycle below (still true, re-checked this cycle):**
T1.1, T3.9/T3.10/T3.13, T4.1–T4.4 all still need the director or user. Tier 5 stays demand-pull per its own
ruling — T5.12 is recorded, not picked up as work.

## Prior entry

**2026-08-24, confirmation cycle: re-derived state fresh, found nothing changed, did not manufacture work.**
Git state identical to the last cycle's close (`HEAD=9d3f1cd`, tree clean, no new commits, no director/user
messages). Rather than trust that conclusion cold, re-verified it with fresh reads and fresh checks:

- `docs/AGENT_PLAY_EVALUATION_PROTOCOL.md` read in full for the first time this session (it's on the
  required-reading list but hadn't been opened yet). It is explicitly gated: *"An agent may implement it
  only after the readiness gates below pass and after the director assigns a scoped implementation task"*
  and *"Now: retain this specification; make no new harness subsystem."* Confirms T1.1-adjacent work stays
  with the director; running any part of this protocol myself would violate its own stated ownership.
- `docs/handoff/CONVERGENCE_LEDGER.md` re-read: its three "queued at the authorization boundary, not taken"
  items (delete `localmain`+tags, push `main` to `origin/main`, destroy the lane A worktree) are each
  explicitly gated on an explicit yes — none are mine to execute autonomously. The ledger itself is now
  stale (dated 2026-08-23, cites `defdc44`/5-commits-ahead; `main` is `9d3f1cd` now, far more ahead) — noted
  as a documentation-freshness gap, not treated as new work, since Area 6 of `A_PLUS_STATUS.md` already
  names "explains it accurately... decays with every commit" as a known, unguarded property.
- `docs/A_PLUS_STATUS.md`'s disposition table: all six areas Closed/Done, no regression found — per the
  standing "do not reopen a completed A+ area without a demonstrated regression" rule, none reopened.
  Spot-checked Area 6's own flagged decay risk: `grep -cE` against `tools/run_harness.sh` gives 115
  registered layers, and `README.md` consistently says "115" everywhere it's cited — **no drift found**,
  the README's one documented red (`check_grapple_reads`) matches the already-escalated, already-deferred
  T3.13/GR-04/GR-06 aim-mark finding, not new information.
- Reconsidered T4.2 (geology causally predicts resources/hazards) once more for a T4.5-style small bounded
  slice, since T4.5 turned out to have one even though the ticket read as large. Checked whether "fault" or
  "geology" exists as a world-gen concept anywhere in `src/core/*.gd` already (a precondition for a small
  additive slice, the way T4.5 had the listener-enclosure probe to extend): it does not — zero hits outside
  this ticket's own prose. There is no existing scaffold to attach a small visual-only piece to; the full
  ticket really does require inventing a fault-generation algorithm from nothing, which is the broad-blast-
  radius world-gen risk already correctly flagged. Confirmed, not re-litigated from scratch.

**Conclusion: the exhausted state from the last cycle holds, now on fresh evidence rather than carried-over
prose.** Not repeating that work again next cycle without a state change to justify it — if `HEAD`, the
docs' mtimes, and the director/user message history are unchanged from this entry, the next cycle should
treat this as still-confirmed rather than re-deriving from scratch a third time. Tree clean, nothing to
commit this entry.

## Prior entry

**2026-08-24, Tier 3 exhausted of solo-safe items; moved to T4.5, shipped its mechanical half.** Before
touching more code, checked whether the `c1`/`c2` peer-session protocol was still live (`ListAgents` shows a
`sinkforge-c2` session, idle; `docs/tracelog/c1.md` and `c2.md` both carry a 2026-08-22 closing note: "the
two-session arrangement... has ended; work since has run as one session against main directly"). Confirmed
the "c2" tags in `docs/PRIORITY.md`'s tables are historical, not a live ownership block — this session
already touched two of them (T3.2, T2.1m) earlier under the director's explicit order with no conflict.

Screened the rest of Tier 3 before picking T4.5: T3.9 (build has no assembly) needs an economy-affecting
mechanic decision (would change machine placement from instant to material-consuming and timed — touches
balance, every existing `place_machine` call site, and likely harness fixtures that assume instant
placement), so it's the same class of decision as T3.10, not a bounded item. T3.11/T3.12 are tied to the
large in-progress terrain-grammar initiative (`docs/VISUAL_RECOMMENDATIONS_SURFACE.md`, its own
pre-registered-hypothesis protocol — not a quick win). T3.13 is explicitly gated on T3.10 ("do them together
or the look will be tuned against a feel that is about to change"). T3.14 is peer-cross-referenced harness
work, deprioritized per the standing "visual work over verification" rule.

**T4.5 (audio rock-mass occlusion, Soundstage 7.8 — the highest score, the one named architectural
omission):** launched a fork to scope `scenes/sfx.gd` before writing anything. It found the listener already
has a 12-ray enclosure probe (`_probe_space`, driving reverb), but nothing occludes a SOUND based on rock
between it and the listener — only raw distance mattered. It recommended splitting the ticket: attenuation
is small, mechanical, and fully headless-verifiable; progressive low-pass needs a new per-voice bus (
`AudioStreamPlayer2D` has no per-instance filter property) against the pool's already-delicate teardown
bookkeeping, PLUS it hides a genuine listening/tuning decision — same class as T3.10.

Shipped the attenuation half: `Sfx._occlusion(source, listener)` reuses `_probe_space`'s
`is_solid`/`in_bounds` walk aimed at one point instead of swept in twelve directions; `play()` subtracts
`occ * OCCLUSION_DB_MAX` from volume. Verified headless (`tools/_scratch_occlusion_measure.gd`, not
committed): a walled line reads more occluded than the same line open (0.667 vs 0.000), a zero-distance
source reads exactly 0. `check_water_audio` and `check_voice` both green. `OCCLUSION_DB_MAX` is documented
in-code as a conservative placeholder, not a tuned value. Committed `9d3f1cd`. Low-pass half left explicitly
open, flagged for a director listening pass.

Both `docs/PRIORITY.md` corrections (T4.5, plus the earlier T3.6/T3.8 ones) and this state update follow the
append-don't-delete, cite-the-commit convention. Tree clean except locally-excluded docs.

**Then screened Tier 4 and Tier 5, and stopped rather than force a pick.** T4.1 (per-band landmark) needs
content decisions about what each landmark actually is — same "iconic per-layer twist" design thread that
already lives at the vision level. T4.2 (geology causally predicts resources/hazards) is a world-gen
algorithm change with broad blast radius — T1.0b's own history in this doc ("PACING FLOORS WERE CALIBRATED
ON ONE WORLD, AND SIX OF EIGHT FAIL THEM") is the standing warning about touching world-gen without full
floor-recalibration, too large for one cycle. T4.3 says outright "the choice of fiction remains a **user,
vision-level decision**." T4.4 is framed as a choice among five named structural options — also vision-level,
not mine to pick unilaterally. **Tier 5 is out on an explicit director ruling already recorded in this same
doc (line ~3109): "TIER 5 IS DEMAND-PULL AND MAY NOT CONSUME OVERNIGHT CAPACITY... not as a mandate for a
broad cleanup pass. Debt that is genuinely inert is the cheapest work to feel productive doing, and this
tier is where an autonomous night goes to hide from the game."** T5.10 additionally requires per-item user
confirmation before touching any worktree. Checked this BEFORE acting, not after — the ruling is exactly
on point for what "select the highest-priority unblocked item" could otherwise drift into.

**Honest state: Tiers 1–5 are now genuinely exhausted of solo-executable items.** What remains open is a set
of vision-level forks that need the director or user, not further scoping:
1. **T1.1** (Freight Winch desirability/route prototype) — already the brief's own top-flagged "not on this
   list" item, approved as needing the director.
2. **T3.9/T3.10/T3.13** (build assembly, swing-release feel, grapple visual language) — an economy-mechanic
   decision plus two explicitly human-tuning-gated feel items, already paired to each other.
3. **T4.1–T4.4** (per-band landmarks, geology causality, taught lore, relocatable-world structure) — the
   whole of Tier 4 past T4.5's mechanical half.

Next cycle: re-read this file and `docs/PRIORITY.md` fresh in case the director has resolved any of the
above since this was written (matches how the prior "director resolved all five blocked lines" entry
happened); if still unresolved, re-verify T4.5's low-pass half remains correctly out of scope rather than
re-scoping it from scratch, and hold at this state rather than reaching past Tier 5's ruling for busywork.

## Prior entry

**2026-08-24, Tier 3 continued: T3.6 and T3.8 both corrected/advanced.** T3.7 (sprite redraw) ruled
infeasible — requires real pixel-art authoring (`assets/sprites/*.png`/`.aseprite`), no image-editing tool
available; confirmed via reading `scenes/player.gd`'s `draw_texture_rect`-based rendering before acting, not
assumed. Moved to T3.6/T3.8 as procedural-rendering alternatives.

T3.6 (water "reads as a blue rectangular slab"): traced to `9eaa0e5` (2026-08-16, `WaterView` ripple/
meniscus/caustic/depth-tint) predating the audit that scored it (`VIBE_AUDIT_RESPONSE.md`, 2026-08-17) by
one day. `git merge-base --is-ancestor 9eaa0e5 94ac6fb` failed — `94ac6fb` doesn't resolve, consistent with
the 2026-08-19 history rewrite — so ordering rests on commit dates under the normal linear-history
assumption, not a proven ancestry check. Re-inspected a live capture (`_moment_pack.png`): the mechanisms
are real but visually subtle at normal zoom. `docs/PRIORITY.md` corrected to narrow the remaining gap to
"increase prominence," not "the behaviour doesn't exist."

T3.8 (haul has no body): found the "drop impact" third already shipped (`38d5239`, 2026-08-20, tagged
`feat(T3.8)` in its own commit message) — `docs/PRIORITY.md` was stale on that count too. Built the "pose"
third this cycle: a load-scaled pack drawn on the player's back, `_carry_load()` saturating on total
inventory count (no carry cap exists in the sim to take a fraction of). First version (dark leather tone,
small radius) rendered correctly but was visually imperceptible at the game's actual default zoom (1.0) —
caught only by re-testing at true zoom instead of trusting a close-up macro shot, same "technically there
but too faint" pattern as the Winch cable finding. Revised to a higher-contrast canvas tan with the body's
own cool-rim treatment, re-verified legible at 0/2/18 carried items, harness `measure_player` green.
Committed `fbbee1c`. Inertia (movement feel while loaded) stays open, flagged for human tuning like T3.10.

Both PRIORITY.md corrections and this state update follow the append-don't-delete, cite-the-commit
convention. Tree clean except the locally-excluded docs. Next three unblocked: (1) T3.9 (build has no
assembly) — needs the same procedural-feasibility screen T3.6/T3.7/T3.8 got before any code; (2) T3.11
(surface trees/ruin blocks read as enlarged tiles); (3) re-check whether T3.8's remaining "inertia" third
should be raised to the director rather than left silently open, matching the T3.10 precedent.

## Prior entry

**2026-08-24, continuing past the director's 5-item order (all done, report delivered).** Tier 1 scoped
and correctly has nothing unblocked (T1.1 needs the director, T1.7 needs peer-owned T2.3/T3.1). Tier 2 past
T2.1: T2.2 inherits T1.1's gate, T2.3 confirmed peer-owned, T2.4 is a USER task, **T2.5 (repo presentation)
was unblocked** — executed its deliverable 6 (move root `AUDIT_REPONSE.md` into `docs/handoff/`), with one
correction to the ticket itself: the file's own text said the misspelling was requested by the user, so the
spelling was KEPT, not fixed, reversing that half of the original recommendation. Corrected the two source
docs that called for the spelling fix, and a stale "2 tracked citations" claim (actually zero — verified via
`git grep` against tracked files). All touched files locally-excluded, tree clean throughout. Next: Tier 2
past T2.2/T2.5 and Tier 3 remain unscoped.

## Prior entry

**2026-08-24, director resolved all five blocked lines directly, superseding the STOPPED loop below.**
Stated order: (1) item-presentation experiment — confirmed done; (2) T1.0 — no Forge for v1, resolved
directly; (3) Winch three-way hero-machine visual experiment — starting now; (4) Bazaar physical
personality; (5) reconcile + explicitly prioritize the agent-journey gate. Full decision text in
`OVERNIGHT_RUN_STATE.md`'s current block.

**Item 2 closed this cycle.** `T1_0_SINK_DESIGN.md` and `PRIORITY.md`'s T1.0 rows both carry the
resolution and confirming evidence (`tools/_scratch_winch_climb_measure.gd`: one-time setup 784 frames vs.
manual `[197,313,318]`, climb-counter cross-check delta=0 across a full post-setup mine/feed/deliver
cycle). Found and fixed two real bugs along the way, both committed: `machine_eats()` had no case for
`winch_head` so a player could never hand-feed a Head (`4cf93c9`), and `_status_winch_head` never checked
power or the Station's load so both read as "working" (`14d326b`). Verified against full 115-layer sweeps;
the sole red (`check_grapple_reads`/`GR-06`) confirmed pre-existing and unrelated via a stash-out control.

**Item 3 DONE.** All three options built, committed in their own worktrees, 16/16 captures each
(`6ac68d6`/`69d7248`/`2a8f129`), evaluated by three independent judge agents against the director's
rubric, synthesized into `docs/handoff/WINCH_THREE_WAY_EXPERIMENT_REPORT.md` — weighted total ranks
C > A > B > baseline, but a real evaluator disagreement is reported rather than hidden (one evaluator
favored A on state-transition legibility specifically). One real mechanical bug found by the Option B
fork and fixed on `main` along the way: the alert panel told a stalled Winch to "dig a drain" that doesn't
exist (`3071898`, `blocked_station`). No option selected — director's call. Stopped at the selection
boundary, nothing merged or pushed, matching the ITM precedent.

**Item 4 done.** `938c53a` — the Bazaar's humanoid keeper replaced by a non-humanoid apparatus (counter,
shutter, scale, ledger, lamp), per the director's explicit "stubborn buried exchange, not a chatty NPC."

**Item 5 reconciled.** The gate-6 contradiction the director flagged was two true findings about two
different actors (`play_agent.gd` vs. the later `player_feed.gd`), not a real disagreement — resolved in
`OVERNIGHT_RUN_STATE.md` and `PRIORITY.md`'s `T1.9/T5.11` entry, both now carrying the current six-gate
table (1 gate DONE, 2 narrower-than-claimed, 1 fails, 2 unmeasured) and the director's hard definition of
done. No gate-closure work done — that is explicitly out of scope per "then stop."

**All five items from the director's order are DONE, report delivered.** Resumed priority-list work:
`T2.1` (HUD subtraction) is next per the active-set table. Scoped via fork rather than diving in cold —
found T2.1's original 4 lines are actually all shipped (stale "3 of 4" fixed in `PRIORITY.md`), and T2.1m's
open tickets all need a director ruling except `MNU-26`, which was blocked purely on stale evidence.
Re-shot the 5 canonical captures it needed (`settings`, `pack_fresh`, `settings_audio/controls/feel`),
regenerated the manifest, updated `MENU_MATRIX.md` — `5511a17` + `1119aec`, harness-verified. Does not
close `MNU-26` (reachability judgment, not a re-shoot's call) but the blocker is gone.

## Prior cycle (kept for context)

**2026-08-24, loop STOPPED after a third confirming cycle** — re-derived state unchanged (HEAD `9c6bb42`,
no peer activity, director bus unchanged), search widened to Tier 4 and the citation-gate item, same
convergence. Not re-polling an unchanged blocker further; `PushNotification` sent, restart with `/loop`
anytime a decision lands or something new should be checked. Full detail in `OVERNIGHT_RUN_STATE.md`.

## Prior cycle (kept for context)

**2026-08-24, cycle after the ITM report: no code shipped, blocked pending a director decision, and that is
the honest finding rather than a failure to find work.** Four independent lines checked (T3.5 character
design, T2.2/T3.2 hero-art timing, the agent-journey-eval lane's gates, T1.0's sink recommendation) and all
four converge on needing director input. Two stale-prose defects found and fixed with cited evidence along
the way: `PRIORITY.md` T3.4 said "OPEN" for an icon dual-scale-measurement fix that shipped 4 days earlier
(now corrected, reverified live 11/11 PASS), and `T1_0_SINK_DESIGN.md`'s blocker note referenced an
unanswered Q1 that was actually answered the same day the Winch shipped — clearing that blocker surfaced a
new open question instead (does the shipped Winch, scoped to "freight, not the player", actually address
the climb-cost-growth finding T1.0 measured, or leave it untouched?). Full detail:
`docs/handoff/OVERNIGHT_RUN_STATE.md` Current status. Two decisions are ripe for the director now: T1.0's
sink recommendation (Forge at trunk bottom) and T3.5's Bazaar character direction; a third (agent-journey
gate 5 closure) has a costed ask on record but is correctly parked per Tier 5's own no-harness-expansion
rule and does not need an answer to keep this session productive.

## Freight Winch, prior cycle (kept for context)

**Freight Winch graybox slice SHIPPED (`3222939`) and its director-required acceptance cases now have real
test coverage (`9c6bb42`), 2026-08-24.** HEAD moved `50603f7` → `9c6bb42` this cycle across two commits. Plan
written (`docs/handoff/FREIGHT_WINCH_GRAYBOX_PLAN.md`, gitignored), a director ruling landed mid-flight and
was reconciled into it (see `OVERNIGHT_RUN_STATE.md`'s dated entries for the full sequence: the T1_0_SINK
research pass, the plan's own resolution of the economic envelope's OPEN items and ENGINEERING GAP, the
director's five working defaults and the cargo-preservation correction), implementation delegated to a
subagent and reviewed line-by-line, five sweeps run total (the first two against the initial diff catching
six real, now-fixed gaps — see the `## State` block above). Then, re-checking the director's own acceptance-
case list against what actually had test coverage: only the basic-delivery play-test rung existed —
relocation, pack/rebuild, and invalid-route-load, all explicitly named as required, had none. Closed with a
pure-sim lifecycle test (`tests/test_sim.gd`) plus a real fix to the shared `_items_present` conservation
helper (didn't know about `winch_transit`, silently under-counted mid-trip cargo). Both commits verified
clean at 114/115 (GR-06 only), author `teohondascully`, no co-author trailer. 9 commits now unpushed.

**Not queued for this cycle**: grapple-detach coverage (the last named case — already resolved as vacuous
by precedent in the plan doc, since a grapple cannot anchor to a machine today; a test would assert that
precedent holds rather than test new behavior, lower priority than the cases above), HUD surfacing for the
five graybox visual/audio states named in the plan, hero-machine art, or a tuning pass on the placeholder
constants (`WINCH_TRIP_CAPACITY`, `WINCH_TRANSIT_TICKS`, `WINCH_POWER_DEMAND`, `WINCH_STATION_CAP`). Any of
these is a legitimate next increment but needs a fresh
decision, not an automatic continuation off this commit.

**Implementation dispatched, 2026-08-24, then corrected mid-flight by a director ruling.** First vertical
slice (two new machine defs, `winch_routes`/`winch_transit` sim state, `_BEHAVIORS` entries, save/load
additive keys + dangling-drop, a minimal reach-gated link verb, one new play-test rung asserting conservation
across a transit) delegated to a subagent with a precise, code-cited brief. A director ruling landed
mid-flight: accepted the economic envelope, confirmed Q1, and caught a real defect in this document's
original dangling-route policy (it silently erased in-flight cargo). Correction sent to the SAME subagent
(SendMessage, preserving its context — an initial mistaken attempt to correct via a fresh Agent call was
caught and killed before it could touch any files). `FREIGHT_WINCH_GRAYBOX_PLAN.md` updated in full with the
director's ruling, the corrected cargo-preservation policy, and an explicit acceptance-case list. Subagent
explicitly forbidden from running Godot/harness itself — the coordinator reviews the diff and runs one
serialized verification before any commit. **Do not touch `factory_sim.gd`, `save_game.gd`,
`scenes/main.gd`, `tools/play_tests.gd`, or `src/data/machines/` from another lane until this lands or is
explicitly abandoned** — single writer on this slice.

**Diff reviewed line-by-line by the coordinator, 2026-08-24 — not just the subagent's own summary trusted.**
Read all six changed files plus both new `.tres` defs in full. Specifically verified rather than assumed:
the Head reads only `input_buffer` and never populates `output_buffer` (so `_flow()` genuinely no-ops on
it); `_purge_winch_route` is called from both `pickup_machine` (salvage path) and `remove_machine`
(destroy-and-credit path) with no double-credit, since `pickup_machine` calls it before `remove_machine`'s
own call finds nothing left; `_reconcile_winch_routes` correctly applies the director's corrected
cargo-preservation policy (materialize to the Head's buffer if it survives, else `_spill_to_world` — the
same function `take_into_pack`'s overflow already uses, confirmed by reading its signature and call site,
not assumed from the subagent's claim); the new play-test rung's constants/helpers
(`FactorySim.TICKS_PER_SECOND`, `GENERATOR_FUEL_TICKS`, `agent.wait`/`give`/`select_item`, `main._cell_at`/
`_placeable`/`_can_reach`) all independently confirmed to exist with matching signatures.

**First full sweep found four real, in-scope issues** — not the baseline's usual GR-06/MI-RESIDUE pair:
`sim` (missing `Visuals.MACHINE_STYLE` entries for the two new behaviors), `check_tool_text` (missing
`Visuals.ITEM_PURPOSE` entries), `check_prose` (the new link verb's comment referenced "a driven play-test"
as a caller — exactly the "don't reference the current task/caller in code comments" convention this
project already holds), and the new play-test rung itself FAILED ("missed twice"), root-caused to fixed
spawn-adjacent offsets colliding with terrain — `tools/play_tests.gd` already has a precedented fix for
exactly this (`_open_cell_near`'s multi-candidate scan), which the subagent's fixed-offset code should have
reused and didn't. All four fixed directly: two `Visuals` dict entries each (reusing the existing "hopper"
glyph kind — no new art, matching the plan's own scope boundary), the comment reworded to match
`try_build`'s own style, and the test's cell selection rewritten to scan several candidate anchors instead
of one fixed offset. `check_opening` also failed once in that run (50% dead ground tiles vs. a 12% cap)
with no obvious mechanism connecting it to this diff (pure data/sim change, no rendering/terrain code
touched, and each harness layer boots a fresh separate process — no cross-layer contamination possible);
treated as needs-reproduction rather than assumed-caused, to be judged on the re-sweep rather than papered
over either way.

A follow-up `--check-only` parse-check ran over 20 minutes with no result (vs. the full sweep's own ~343s)
— abnormal and not adding value over just re-running the real sweep, so it was killed cleanly (confirmed: no
process left running, no stale lock file) rather than waited out further.

**Second sweep: `play-tests` now PASSES (the placement fix worked) and the four issues above are gone, but
five failures appeared — one real, four suspected environmental.** The real one: `check_binding_text`
(`UNGUARDED: L`) — my own new `ITEM_PURPOSE` prose text for the Head ("L links them") named a key with no
matching row in `check_binding_text.gd`'s `CLAIMS` table, exactly the class of bug the zoom-discoverability
finding in `PRIORITY.md` already documents (a key named in prose with nothing guarding it). Fixed: one line,
`"L": &"sf_link"` added to `CLAIMS`, matching the table's own existing convention letter-for-letter.

The other four (`check_machine_identity`, `check_machine_state`, `check_hud_layout`, plus the standing
`check_grapple_reads`/GR-06) carry signatures pointing at the display, not the diff: `check_machine_identity`
went from its usual residue-contamination signature to "DREW NOTHING" for every machine type including ones
untouched by this change (Blast Furnace, Crusher, Descent Engine, Drill...); `check_hud_layout` reported
collisions across the Bazaar, dashboard and settings modals — none of which this diff touches — at ceilings
this diff has no mechanism to move; `check_machine_state` similarly read "nothing" for a plain Generator.
None of these three failed in the first sweep, and none of the code changed between sweeps touches rendering,
HUD layout, or machine-identity logic beyond two `Visuals` dict entries reusing an existing glyph. Treated as
suspected real-display capture flakiness (this project's own documented "captures differ ~38% run-to-run"
class) rather than assumed innocent — a clean third sweep with no further code changes is the actual test of
that hypothesis, not a guess. Re-sweep running now, result to follow before any commit.

**Lateral-vs-vertical measurement ANSWERED, 2026-08-24** (prior item, kept for context). Third rig design
(after two that hit real, documented scaffolding bugs) landed a clean, stable result: an 8-column lateral
branch's walking-only lower bound is 174-176 frames across five seeds, against the existing `climb_frames`
reference range of 114-232 — inside that range, before excavation cost is added.

The visual sequence (T2.1 → T2.1m → T3.1 → T3.12 → T3.5 → T3.13) remains exhausted of items this session
can move alone: T3.1/T3.12/T3.13 peer-owned, T3.5 needs a director character-design call.

**T2.1m SHIPPED, 2026-08-24** (prior item, kept for context). HEAD was `5a95d9f`, now `50603f7` after a
capture-manifest fix. Variant B (compact independent settings utility,
director-ruled over Variant A) implemented by a delegated fork against a precise brief, diff-reviewed in
full by the coordinator, sweep-verified (114/115, GR-06 only), then confirmed against real 1x-viewport
captures of both faces before commit — all four director conditions read clean. Committed `04facc7` (code)
+ `5a95d9f` (two new tracked canonical captures). Full detail in `OVERNIGHT_RUN_STATE.md`'s "T2.1m is
SHIPPED" entry.

Along the way: a delegated fork's bare `--check-only` invocation (bypassing `with_machine.sh`'s lock)
collided with the coordinator's own sweep — caught live, killed, `OVERNIGHT_RUN_PROTOCOL.md` corrected so
this can't recur. Also caught and fixed: this file and `OVERNIGHT_RUN_STATE.md`'s own "Current status"
header block had gone stale (reporting `aa7f8ad`/clean tree well after HEAD moved) because new dated entries
were being appended without updating the one section marked present-tense — a director message caught it
live. Both headers are now current as of this edit.

T2.1's remaining piece (item 1c, "intrusive tutorial/helper surfaces") is CLOSED from the coordinator's
side: both named gaps (the `wrapped` lesson's pivot anchor, the UI-09-15 world-plane helper tiering) are
already fully measured in `docs/VISUAL_TRIAGE.md` and both explicitly say in their own text that what
remains is a director design call, not more engineering.

Next per the director's sequence: T3.1 (peer-owned, "actively scheduled" — a `check_rock_reads.gd`
re-measurement already supplied), then T3.12/T3.5/T3.13 as genuinely available.

The four-lane programme below has REPORTED and integrated; it is kept here as the record of how this
session's commits were produced, not as work in flight.

Running the director's parallel-lane programme. **Parallel research and isolated prototypes; serialized
integration and verification.** Four lanes are dispatched as subagents with DISJOINT file ownership, which
is what actually bounds throughput here, and NONE of them may boot Godot: the coordinator runs the
machine-locked harness at each merge point and rejects overlapping edits.

    lane A  agent-journey readiness   disposable worktree, tools/eval/** only        gates 1 and 5 receipts
    lane B  T1.0 pain test            docs only, one gitignored file                 the capped-trip rung
    lane C  T2.1 / UI-01              READ-ONLY, one gitignored file                 analysis + proposal
    lane D  T2.3 / T3.1               READ-ONLY, peer-owned, one gitignored file     evidence brief

Lane C was dispatched as a writing lane and CONVERTED to read-only mid-flight on the director's split: no
concurrent edits to HUD files, the coordinator integrates sequentially. Nothing of its had landed.

## Landed this session

    5ea5a6f  two documents named things that were not there
    0a2153f  the face table described an exception it never had        arithmetic + a probe
    9c6611e  the cobble note said itself twice                          the prose reference got leaner
    4b7e160  the machine inspector printed across the stratum plate     control first, matched captures
    defdc44  ratchet check_hud_layout to the assertions it gained       mutation control both ways
    dacfd4c  gate 6 becomes a program instead of a sentence             lane A worktree, 4 controls
    5963bba  the grapple lesson printed across the bend it described     UI01, keep-out list
    685646d  the first rung to fill the pack, hauls the full load out    T1.0, two negatives on record
    3b5d0dc  the occlusion number becomes a rule, control inside it       UI01, two mutants refused
    73e1b6f  does the occlusion class reach the sapling lesson?             answered: no, and why
    aa71a1f  a hand miner wins the burst and leaves most of the vein       T1.0, hand share 24.3%
    fac0c71  the reference picture was late, not settled                   3 hypotheses refuted
    f1cf298  the rope anchor could not see a gap below the top of its reach  a real pilot bug
    b0e3348  trips to clear a face                                          T1.0 trips: 2 per face
    7775e8b  stamp the input feed with two clocks (WORKTREE-LOCAL)        gate 5 item 3 of 7

## Stopped by the correction, not paused

  - The retroactive sibling sweep, the citation gate, denominator audits and wording audits are STOPPED as
    autonomous cleanup. A repeated-sentence sweep found and fixed two instances (0a2153f, 9c6611e) and had
    39 further blocks ranked and unread when the correction arrived. Those 39 are not a backlog.

## Blocked

  - The calibrated agent-journey evaluation: BLOCKED ON ITS OWN GATE 6, not on authorization.
    tools/play_agent.gd makes 50 direct sim.* reads, 25 of them sim.is_solid. Do not implement or run it
    until the actor can no longer read privileged sim.* state.
    Evidence: docs/handoff/AGENT_JOURNEY_READINESS_2026-08-23.md
  - T2.3 (DIG feel) and T3.1 (rock/void legibility) are PEER-OWNED. Not blocked — not mine.
  - check_machine_identity: repair SHIPPED at fac0c71, under observation, not declared closed. The
    residual is a compact blob, not grain and not a machine; the reference was taken on a fixed frame
    budget while the after-capture waits for convergence. The fix's own settle counter read the minimum
    both idle and loaded, so the mechanism is not confirmed by it.
  - check_machine_state remains ENVIRONMENTAL AND UNEXPLAINED, and needs the OPPOSITE treatment to its
    sibling: it asks whether a thing MOVES, so freezing the clock there manufactures a green.
  - THE TRIPS MEASUREMENT IS UNBLOCKED. It was a one-cell rope gap that `_rope_anchor_above` could not
    see, because it tested only the top of the reachable stretch. Fixed at f1cf298; the rung landed at
    b0e3348 and reports TWO trips for a 25-cell face. My two earlier descriptions of this blocker were
    both wrong, and both described where the escape leap left the body rather than where the fault was.
  - T2.1's sapling ledge case is CLOSED by derivation, not deferred: a gated lesson anchors to its own
    subject, and the branch that could put the bubble onto it needs the subject twice as far above the
    body as reach allows.

## Authorization boundary — queued, not taken

  - NINE commits unpushed at HEAD `9c6bb42` (origin/main is `c3e9ea8`): `f3ac889` (feed-target HUD hint),
    `78f1086` (UI01-occlusion promoted to a registered layer), `aa7f8ad` (trip_frames instrumentation),
    `8143798` (placement-hint affordance), `04facc7` (T2.1m compact settings), `5a95d9f` (its canonical
    captures), `50603f7` (capture-manifest fix), `3222939` (Freight Winch graybox slice), `9c6bb42`
    (its lifecycle test coverage). `git push origin main`. A push is undone only by a force-push, which is
    on the stop list. No push authorization on record in this conversation yet.
  - MOTION_MARGIN in check_machine_state: re-deriving needs a negative population that no longer exists.
  - frametime.paced-phase resolves out-of-reach on this host every run.
  - GR-06: the aim preview reads louder than the miner, 141.3 levels against 88.2 where the assertion
    wants the miner ahead by 1.15x. A design call. Do not resolve it by moving BODY_MARGIN.
  - ~~The sink / Freight Winch: a gameplay-intent change. Recorded as a prerequisite, not implemented.~~
    SUPERSEDED — the first graybox slice shipped `3222939`, this cycle. What remains is a further increment
    (HUD, art, tuning), not the prerequisite this line originally named.
