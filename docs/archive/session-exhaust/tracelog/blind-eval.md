# tracelog — `blind-eval`

Owner: the blind agent-play opening evaluation lane. **This file is mine; `c1.md` and `c2.md` are
read-only to me.** Append-only.

Deliverable: [`docs/handoff/BLIND_EVAL_READINESS.md`](../handoff/BLIND_EVAL_READINESS.md).

---

## 0. Ownership and constraints, declared before writing anything

**Files I created:** `docs/handoff/BLIND_EVAL_READINESS.md`, this file. Nothing else, in the repo or
outside it.

**Files I did not touch, by explicit instruction:** `scenes/`, `src/`, `tools/*` (any extension),
thresholds, `docs/PRIORITY.md`, `docs/DECISIONS.md`, `docs/tracelog/c1.md`, `docs/tracelog/c2.md`,
`.github/`, any config. Also untouched though not listed: `docs/ORCHESTRATOR.md`, despite finding a
defect in it (§3.2 below) — reported, not repaired.

**Commands run:** read-only only. `git log`, `git show --stat`, `git log -L`, `git merge-base
--is-ancestor`, `git branch -a`, `git status --short`, `grep`, `sed`, `wc`, `ls`. **No write-side git
command. No Godot. No `run_harness.sh`, `seed_corpus.sh`, `with_machine.sh`, or capture tool.** The
machine lock was contended for this session's whole duration and was never approached.

**Tree identity.** Working tree clean at `eb3a1e4` when I started; `c7f3898` landed mid-audit (c2's
T1.0b row) and is cited where used. `git status --short` was empty at start.

---

## 1. What I measured, and what I reasoned about

**Measured: nothing.** I executed no instrument. This is worth stating flatly because the deliverable is
full of numbers and none of them are mine.

Every number in the report has one of three provenances, and each is attributed in place:

| number | whose | where it came from |
|---|---|---|
| HUD footprint 7.84% / 91.95% and the per-state table | c2 | `docs/PRIORITY.md:388-398`, `8333bf5` |
| 6a boundary 79% / interior 56%, floor 75% | peer (c1) | `docs/PRIORITY.md:541-543`, floor at `check_rock_reads.gd:104` |
| T1.0b's 8-seed pacing table | c2, relayed to me mid-task | `docs/PRIORITY.md:179-188`, `c7f3898` |
| 56 privileged inputs | me | a **count of source sites I read**, not a measurement of anything running |
| per-seed opening frame counts (664 … 10086) | c2's sweep, **read off the primary logs by me** | `${TMPDIR}/seed_corpus.check_pacing.<seed>.log`, kept by `seed_corpus.sh:158`; format `check_pacing.gd:116` |

**Amended on the second pass.** The last row is a real change to "measured: nothing." I still executed no
instrument — but I stopped short of the primary artifact the first time. When the correction to §3.3
arrived as a summary table, the reflex worth having was *"can I read the logs myself"* rather than
*"do I believe the sender"*, and `seed_corpus.sh:158` says exactly where they are. All six figures
matched, and reading the logs rather than the table is what surfaced the two boundaries the table did not
carry (failing-subset selection; `descent 0` on seeds 7 and 99). **Verifying a peer is not only checking
whether they are right — it is checking what their summary dropped.**

**Reasoned about: all six gate verdicts.** A gate verdict is an inference from source text. Three of the
six (1, 4, 5) would be settled differently by a run than by a read, and those are listed as open items in
the report's §7 rather than resolved.

---

## 2. Method

Read in full: `docs/AGENT_PLAY_EVALUATION_PROTOCOL.md` (188 lines), `tools/play_agent.gd` (613),
`tools/arc_driver.gd` (312), `docs/PRIORITY.md` (890). Read in the relevant part:
`docs/DIRECTOR_BRIEF.md` §4 (261-506), `docs/ORCHESTRATOR.md` §§3-9, `docs/PEER_SESSIONS.md` rules 1-16,
`docs/tracelog/c1.md` and `c2.md` (status + coordination sections), `tools/with_machine.sh` (whole),
`tools/run_harness.sh` (isolation block + layer registry), `tools/capture_moments.gd` (header + write
path + `_deafen`), `tools/zoom.gd` (whole), `scenes/objectives.gd:1-115`, `scenes/hud.gd:665-820`,
`scenes/world_renderer.gd:1439-1478`, `scenes/main.gd` (targeted), `scenes/world_seeder.gd` (targeted),
`tools/save_sentinel.gd:1-60`, `tools/check_lock.sh:1-45`, `tools/check_loop_health.gd:1-70`,
`tools/check_pacing.gd:30-52`, `tools/seed_corpus.sh:24-36`.

Grepped rather than read end to end: `tools/play_tests.gd` (1,478 lines). **The report says so** — its
§3 marks entries 5-49 as complete for the two driver files and a floor elsewhere.

**Every citation was verified before it was written.** Where a symbol is named, I ran `grep -n` for it in
the file I attributed it to. Two claims survived only because I did that, and both are below.

---

## 3. Findings I did not expect, in the order they changed the report

### 3.1 The brief I was handed cited the wrong commit for the thing gate 3 is about

I was told *"The permanent objective slab was retired (`18af7cd`)."* I checked before citing it.
`18af7cd` is titled **"feat(hud): the key legend retires itself, one key at a time"** and its body is
entirely about the bottom-left legend. `docs/PRIORITY.md:348` agrees with the commit and not with the
brief.

Recovering the real commits took `git log -L 718,723:scenes/hud.gd`, which surfaced **`adb947e`** and
**`e57f381`** — both ancestors of HEAD, both 2026-08-17 afternoon.

**Why I am recording this rather than quietly fixing it.** The instruction to verify every citation is
in the brief because this repo has shipped four phantom citations. This one was *in the verification
instruction's own accompanying text*. That is not an indictment of c2 — it is evidence that the failure
mode survives being named, which is a stronger argument for the rule than any of the four originals.

### 3.2 `docs/ORCHESTRATOR.md:245-247` names three `PlayAgent` methods that do not exist

The onboarding document says `PlayAgent` exposes `place`, `research` and `grapple`. It exposes none of
them: `grep -c grapple tools/play_agent.gd` returns 0, and neither `place` nor `research` appears in the
30-function list.

The same three lines also say it *"drives `MainView`'s actual input path, not the sim directly"*. Both
halves are wrong in the direction that matters for gate 6: it writes `player.input_dir` /
`player.input_climb` / `player.facing` directly (bypassing the input map) and it reads and writes the sim
directly (`give()` at `:597`, the `sim.solid` scan at `:605`).

**The file's own header is honest** (`play_agent.gd:4-14` names the `give()` hatch outright). The
overstatement is in the paraphrase — and the paraphrase is what a new session reads first. **It is the
sentence that would let someone conclude gate 6 is nearly met.**

Not my file to edit. Reported in the deliverable's §1.2.

### 3.3 A new game is not an unmodified generated seed — TRUE; and the conclusion I drew from it — WITHDRAWN

`main.gd:683-688` generates a `LayeredWorldGen` world and then calls
`WorldSeeder.seed_tutorial(sim, dev_start)` — which unconditionally injects the starter vein, the coal,
the tree, a **pre-dug adit with lode written straight into `sim.lode`**, a pre-carved drill shaft, the
drill's target vein at richness 400, **two pre-placed forges**, and a starter pickaxe, all at hardcoded
`MainView` coordinates.

I went looking for this because `arc_driver.gd` uses `MainView.MINESHAFT_COL` and
`MainView.MINESHAFT_FORGE_CELL` as if they were world facts, and a *generated* world cannot have a
forge at a compile-time constant. Pulling that thread found the seeder.

**~~The consequence I did not anticipate.~~ WITHDRAWN IN FULL, 2026-08-17, refuted by measurement the
coordinator had and I did not.** What I wrote was: *"Three seeds give one opening with three backdrops …
seed variance is not a property of the opening on this build."*

**The refutation, which I verified myself rather than accepting relayed.** `seed_corpus.sh:158` keeps a
log per failing cell; the T1.0b `check_pacing` logs were still in `$TMPDIR`. `check_pacing.gd:116` prints
Act One separately, so the opening phase is directly readable per seed:

    20260817   opening    664      99   opening  1318 (descent 0)
    31337      opening   1381       7   opening  1441 (descent 0)
    4242       opening   1669     512   opening 10086

All six match the figures I was sent. **A fifteen-fold spread is not one opening.** The fixtures are
seed-invariant; what varies is everything the agent crosses *between* them, and that effect is large.

**Two boundaries I added that were not in the figures as relayed**, both from reading the logs rather
than the summary:

1. **This is the failing subset, selected on the outcome.** `seed_corpus.sh:157-158` copies a log only for
   a failing cell, so 1337 and 8675309 left none and their opening lengths are unmeasured. Selection on a
   correlated outcome can inflate the spread's *magnitude*; it cannot manufacture variance that is absent.
   The direction is safe, the "fifteen-fold" is six of eight.
2. **Seeds 7 and 99 show `descent 0`.** `check_pacing.gd:110` calls `dig_down_to(...)` without
   `require_arrival` — T5.2 (`PRIORITY.md:742-745`) — and `play_agent.gd:345-353` documents that call
   returning true immediately on a world with a void under the spawn column, **naming seed 99**. Seed 99
   at `descent 0` is what that defect predicts. Corroboration of a known defect, labelled INFERRED; I did
   not check seed 7 for a void and cannot run anything.

**And I nearly repeated the error inside the fix.** My first replacement paragraph called 1337 *"the
shortest kind of opening in the corpus"*. **1337's opening length is unmeasured** — it passed, so no log
exists. I caught it on re-read and replaced it with what is actually known (it clears the pacing floors
at 15% / 32.2, `PRIORITY.md:181`). The correction to an overclaim was itself an overclaim, one paragraph
later, in the same direction.

**What survives, and it is still load-bearing for §5.5 of the report:** *the opening's scripted features
are seed-invariant, while the world the player crosses between them is not, and the second effect is
large.* That makes the pilot's single-seed caveat do real work rather than being a formality — which is
the opposite of what my withdrawn version implied.

### 3.3a The shape: my gate-1 find and this error are the same defect in opposite directions

Worth recording because it is the shape of the day rather than an incident.

- **Gate 1** (`with_machine.sh:38-42`): a **true claim in prose** — the tool documents that it isolates
  `user://` — **that the code could not honour**, because the redirect sat inside a bare `if mkdir` with
  no `else`. Prose ahead of code.
- **§3.3**: a **true claim about the code** — `seed_tutorial` is called unconditionally, six features, no
  `if` — **from which I drew a behavioural conclusion that measurement contradicts.** Code ahead of
  behaviour.

**Both read as careful.** Both cite a real line. Both are the kind of statement that survives review
because the evidence offered is genuine — it is the *inferential step past* the evidence that fails, and
in neither case does the citation warn you. The generalisable rule is not "verify citations", which I did
throughout: it is **when a claim about code becomes a claim about behaviour, the behaviour needs its own
measurement**, and I had one available in `$TMPDIR` the whole time and did not think to look for it.

The asymmetry in how the two were caught is also worth noting: the gate-1 defect was found because
somebody asked *"what is the interactive launch path"* rather than *"is there isolation"*; my seeder
inference stood because nobody, including me, asked *"does the opening actually differ between seeds"*
when the answer was one `grep` away.

### 3.4 An existing green gauge and gate 3 pull in opposite directions

`check_loop_health.gd:18-20` penalises **the absence** of a world guide target — its heaviest per-frame
weight (`:69`), against `SCORE_FLOOR = 90.0` (`:61`), reading `main._guide_targets()` at `:187`. Gate 3
wants exactly that surface gone or at least ruled on.

I am not proposing anything about it. I am surfacing it because whoever eventually acts on gate 3 will
otherwise discover it by turning a green layer red and then having to decide, under time pressure,
whether they have found a regression or a design change.

### 3.5 `with_machine.sh` fails open where `run_harness.sh` fails closed

`run_harness.sh:131-132` exits 2 if the isolated home cannot be created. `with_machine.sh:38-42` wraps
the same redirect in a bare `if mkdir …; then export …; fi` — no `else`, no message. If that `mkdir`
fails, the wrapper runs Godot against the player's real `user://` and says nothing.

I found this only because gate 1 forced me to ask *"what is the interactive launch path"* rather than
*"is there isolation"*. The answer to the second question is yes on both paths; the answer to the first
exposed the asymmetry.

**Same shape as `PEER_SESSIONS.md:1066-1069`** — a safety mechanism whose broken state is
indistinguishable from its working state, sitting inside the tool used to guarantee the thing.

### 3.6 `with_machine.sh` explicitly refuses the shape a pilot needs

`with_machine.sh:55-64` refuses any invocation whose first argument is not a Godot flag, and its own
error text names the failure as Godot *"just play[ing] the game"*. A blind pilot **is** "just play the
game". It is reachable with a leading flag, but **no invocation for it is documented anywhere in the
repo and the interactive path has never been exercised under isolation.**

### 3.7 There is no channel by which an agent could act as the actor

I checked rather than assumed: I loaded `mcp__claude-in-chrome__computer`'s schema. It is described as
driving *"a web browser"* and `tabId` is **required** on every action. It cannot touch a native macOS
window.

**This is what moved the recommendation.** Everything else on the pilot's critical path (gates 1, 3, 5)
is convertible with zero code — a procedure, a ruling, and a screen recorder. Gate 6 is the one that
needs a capability to be provisioned. Without it, the only available actor is the person who built the
game, and `protocol:152` makes that run `INVALID` by its own text.

---

### 3.8 The report's load-bearing sentence was buried, and has been promoted

The coordinator's read, which I agree with: the most valuable framing in the deliverable was the
**effect channel / decision channel** split — the effect channel is mostly legitimate (reach-gated
`try_*` verbs), the decision channel is 100% privileged with no non-privileged path at any point — and it
was sitting inside gate 6's verdict in §2, four hundred lines above the enumeration it explains.

It is now **§3.0**, at the head of the privileged-input tables, with §2's copy reduced to a two-line
summary pointing at it. Nothing was added or softened; it moved.

**Why it belongs there rather than in the gate verdict.** The 56 entries are otherwise just a long list
of things a tool touches, and a reader could reasonably conclude that most of them are minor and the
tooling is close to compliant. The split is what says otherwise: it is the difference between *"gate 6
needs a cleanup pass"* and *"gate 6 needs an actor that does not exist"*, and it is the reason the
recommendation is `FIX READINESS BLOCKER` rather than a punch list. A framing that changes the verdict
should not be discoverable only by reading the verdict.

---

## 4. Where I am uncertain, and what would change my mind

Ordered by how much a wrong answer would cost.

0. **The one I already got wrong is the class I should be most worried about, not least.** §3.3's
   withdrawn inference was not a careless line — it was the item I labelled *"the single most
   consequential finding for the experimental design"*, and it was wrong in the step past the evidence,
   not in the evidence. **Every remaining item on this list has the same structure**: a verified source
   fact, plus a claim about what it means for behaviour, with no behavioural measurement behind it. Items
   1, 3, 4 and 7 below are all one `check_pacing`-log-shaped artifact away from being settled or refuted,
   and I do not know which artifacts those are. Read the rest of this list as *"here is where the same
   move was made again"*, not as hedging.

1. **Gate 3's verdict is a reading, not a viewing.** I called it UNCERTAIN on source text alone. I have
   not seen a frame of this build. If the guide ring turns out to be visually marginal — a faint pulse
   nobody's eye goes to — then it does not supply the answer and gate 3 is READY. If it is as prominent
   as `world_renderer.gd:1465-1477` describes, it is the whole ballgame. **A Sees-tier pass on one
   current opening frame would settle this in ten minutes and I could not run it.**

2. **I may be reading gate 3's second clause too strictly, or c2 too loosely.** The gate permits
   "contextual world guidance" and forbids "an on-screen command". A pulsing reticle is world-space and
   is not a command. My argument that it nevertheless supplies the answer is a *functional* reading
   against the gate's *formal* wording. **A director could reasonably rule the other way**, and if they
   do, gate 3 is READY and my UNCERTAIN was over-cautious. I flagged the ruling rather than making it,
   which I think is correct, but it is the judgement call in this document I am least sure of.

3. **The pilot's shape may be too clever.** Operator-relay satisfies gate 6 on paper. It also creates a
   human in the loop whose restraint is the only thing preserving the boundary — and §5.7's rules 3 and 4
   are the kind that are easy to write and hard to keep for five minutes. **If the pilot's honest finding
   is "the operator leaked", that is a real result about the apparatus**, which is what the pilot is for.
   But I should not pretend I designed a clean instrument. I designed the cheapest one that clears the
   gate's text.

4. **Turn-based input may destroy more than I claimed.** I said it invalidates timing, fatigue and flow.
   It may also invalidate *orientation itself*: an actor that gets to think for thirty seconds between
   frames is not disoriented in the way a player is. If so, a five-minute relay pilot cannot validate the
   evidence process for a measurement that only exists in real time. I do not know how to test that
   without running one.

5. **My privileged-input count is a floor, not a total.** 56 is complete for `play_agent.gd` and
   `arc_driver.gd`, which I read line by line. `play_tests.gd` (1,478 lines) was grepped. Layers that
   construct a `PlayAgent` — `check_loop_health`, `check_pacing`, `capture_moments`,
   `check_contact_edge`, `check_depth_reads`, `_scratch_t10_deadhead` — were not audited for privileged
   access of their own beyond the one I happened to find (`check_loop_health.gd:187`). **Someone
   sweeping those six files should expect to add entries, not to confirm the count.**

6. **I asserted that `play_tests.gd` carries a second copy of the arc. I did not diff it.** I claim only
   that two implementations exist where `arc_driver.gd:11-14` says there must be one. I make no claim
   that they have drifted, and the report says so.

7. **I read one state of the HUD and generalised carefully, but I did read one state.** Gate 3's
   evidence is `hud.gd:738-804` plus the constants above it. I traced the `GOAL_PERSISTS_THROUGH` branch
   and the `HINT_STUCK` branch by reading, not by running. The minimap-open early return (`hud.gd:750-751`)
   and the `all_done` branch (`:757-759`) are two more states I noted but did not reason about. **If a
   later reader needs "what the HUD shows", this document covers the running-with-objectives state and
   nothing else.**

---

## 5. Two things I want challenged

1. **My recommendation may be too conservative.** `FIX READINESS BLOCKER` on gate 6 is defensible, but
   an alternative reading is available: run the relay pilot *now*, accept that it validates only the
   recording and invalidation machinery, and treat the actor-channel question as the pilot's first
   finding rather than its precondition. That would produce evidence today instead of a plan. I chose
   the conservative call because recommending a run I already believe returns `INVALID` — against a
   contended machine lock — buys a known answer at a real cost. **That reasoning could be wrong and I
   would rather be told now than after the plan sits for a week.**

2. **Kill-list #13 indicts this document.** One model read the source and produced six verdicts. If the
   same model family later judges the pilot, or re-audits these gates, its agreement with me is partly a
   shared prior. `PRIORITY.md:857-858` names this; `docs/tracelog/c2.md:984-986` records c2 having no
   answer to the same question about their own file. I do not have one either. The most useful challenge
   to this report would come from something that is not another instance of me — and the cheapest
   approximation is a fresh zero-context reader given only the deliverable and the protocol, asked
   whether each gate verdict follows from its quoted evidence.

---

## 6. Status

| Item | State |
|---|---|
| Six gate verdicts with source evidence | **done** — report §2 |
| Privileged-input enumeration (56 across 8 categories) | **done** — report §3; floor, not total (see §4.5) |
| Five-minute pilot design | **done** — report §4 |
| Pre-registration (feed, controls, prompt, seed, artifacts, invalidation) | **done** — report §5 |
| What the pilot can and cannot conclude | **done** — report §6 |
| Open items requiring a run | **done** — report §7, seven items |
| Recommendation | **done** — `FIX READINESS BLOCKER`, gate 6 actor channel |
| Anything committed by me | **no** — c2 commits; first pass landed as `62b0a83` |

### 6a. Second pass — 2026-08-17

**What the audit caused upstream, recorded so the trace shows outcome and not only output.**

| finding | disposition | who |
|---|---|---|
| gate 1 — `with_machine.sh:38-42` fails open | **FIXED, pushed `c6fc29f`** — now fails closed with `exit 2` and a message naming the slot it refuses to touch | c2 |
| `ORCHESTRATOR.md:245-247` phantom `place`/`research`/`grapple` + false input-path claim | **FIXED** — verified zero definitions, eleven real verbs were unlisted | c2 |
| `PRIORITY.md`'s unmarked slab bullet | **FIXED** — c2 identified it as the *root cause* of the `18af7cd` misattribution in my brief and repaired the trap, not just the attribution | c2 |
| §3.3's seed-invariance inference | **WITHDRAWN by me**, this pass — see §3.3 | me |

**One thing about the gate-1 fix worth carrying forward, because it is a method and not an incident.**
c2 demonstrated the old fail-open **as a standalone snippet with no Godot at all**, on the grounds that
booting the old code to watch it reach the player's save would have been *the demonstration and the
accident in one action*. That is `PEER_SESSIONS.md:165-170` ("check whether the remedy is destructive
when the alarm is wrong") applied to a *proof* rather than to a remedy: **when the thing you want to
prove is "this can touch the sacred artifact", do not prove it on the sacred artifact.** I asserted that
defect from source reading alone and had no plan for how anyone would confirm it safely; the answer was
better than the finding.

### 6b. Changes made this pass

- report §1.3 — inference withdrawn, replaced with the verified per-seed opening table, the corrected
  narrow claim, and two stated boundaries (failing-subset selection; `descent 0` on 7 and 99).
- report §3.0 — **new**: the effect/decision channel split promoted to the head of the enumeration;
  §2 gate 6's copy reduced to a pointer.
- report §5.5 — the single-seed caveat rewritten to say *why* it is load-bearing, since the withdrawn
  inference had made it read as near-vacuous.
- report §6 — the "cannot conclude anything about worldgen" bullet strengthened rather than softened.
- trace §1 — "measured: nothing" amended; §3.3 rewritten; §3.3a, §3.8, §4.0 added.

**Constraints held on both passes:** two files only, no commits, no runs, no Godot, no write-side git,
nothing else touched. `docs/VISUAL_TRIAGE.md` and `docs/handoff/VISUAL_TRIAGE_ENGINEER_BRIEF.md` appeared
untracked in `git status` during this pass; they are not mine and I did not read or touch them.

---

## CLOSING NOTE — appended 2026-08-22 by the single-session main-line lane, not by `blind-eval`

**Attribution first, because this file's own rule is that only its owner writes in it.** This section is
not written by `blind-eval` and does not speak in their voice. The two-session arrangement this file was kept
under has ended; work since has run as one session against `main` directly, with no worktrees and no
peer bus. Appending here rather than editing anything above, so nothing already recorded is disturbed and
an auditor can see exactly where the lane stops and a different author begins.

**Where this file stops.** Last dated entry: 2026-08-17. Nothing in it is retracted or superseded by what follows.

**What has happened since, in one paragraph.** The A+ programme's Area 2 closed:
`scenes/world_renderer.gd` went 4601 -> 3557 lines across three measured extractions (`097c769`
machines, `8fa99a8` water, `d1d5ab8` rope and grapple), each proven token-identical to its original and
each shown to break a check layer under a deliberate mutant. Every remaining candidate in that file, and
both other large files, now carry measured rejection numbers. Area 4's frame SLO was evaluated for the
first time on named hardware. One control tightening was made and then withdrawn when it failed inside the
sweep on an honest frame, because its sixteen samples all came from the one condition the gate does not
run in.

**The current record, for anyone continuing.** `docs/A_PLUS_STATUS.md` is the tracked, publishable
disposition. `docs/A_PLUS_PROGRAM.md` is the untracked working record and carries the corrections,
including three older Area 2 sections now marked superseded at their own headings rather than deleted.

**Evidence for the state this note describes.** Configured sweep retained at
`docs/tracelog/sweeps/2026-08-22-area2-close/` — 112 per-layer logs, `summary.txt` stamped
`head: 793d834, worktree: clean`, verdict `110 PASS / 0 FAIL / 0 SKIP of 110`, `HARNESS_RESULT=yes`,
exactly the six registered stand-downs. **Not a full sweep, and the runner says so in the same file:**
six conditional assertion groups stood down under `SF_STRICT`, so it prints "this run does not count as a
full sweep". The accurate sentence is that the CONFIGURED sweep passed with six documented stand-downs.
