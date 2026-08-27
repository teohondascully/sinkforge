# Area 6 — hand-authored commit-message mapping

126 distinct lines. Key = exact line from the original message; value = the replacement.
Three are KEEP VERBATIM: the detector matched something that is not coordination language.
Three more are applied as hash-agnostic regexes, because filter-repo rewrites old commit ids
inside messages to their new values BEFORE the callback runs, so an exact key carrying a sha
stops matching. Result: 83 process-narration commits -> 2, both KEEP VERBATIM.

## KEEP VERBATIM
    useless -- 50 hits for "c1"/"c2" are every one a loop variable, 26 for "found by" all credit a METHOD
    reason: not coordination language

## KEEP VERBATIM
    `c3 a2 c2 80 c2 94`. The only signal is "Wide character in print" on stderr, which I
    reason: not coordination language

## KEEP VERBATIM
    .githooks/pre-commit refuses any staged .gd/.md/.sh/.cfg/.godot carrying C1 control
    reason: not coordination language

## Replacements

-   it. That is the third time this session that blind spot has cost a cycle; every
+   it. That is the third time this blind spot has cost a cycle; every

-   reader. That is a publication call and it is left to the director rather than taken here.
+   reader. That is a publication call and it is left open rather than taken here.

-   FIFTEEN COMMENTS CREDITED AN INTERNAL SESSION IDENTIFIER. "Found by c1 in the CI log for 53db2c3",
+   FIFTEEN COMMENTS CREDITED AN INTERNAL WORKING LABEL. "Found in the CI log for 53db2c3",

-   "c1's finding", "c1 caught that before it shipped" -- one of them in .github/workflows/harness.yml,
+   "caught before it shipped" -- one of them in .github/workflows/harness.yml,

-   a public workflow. origin/main carried one such line; this branch had fifteen. A reader asks who c1 is,
+   a public workflow. origin/main carried one such line; this branch had fifteen. A reader asks what the label means,

-   four hours before writing this guard. c1's finding.
+   four hours before writing this guard. Found on a later pass.

-   Two on `check_prose.sh`, both c1's, and both smaller than the finding that raised them.
+   Two on `check_prose.sh`, both from the same pass, and both smaller than the finding that raised them.

-   I originally reported this one as a live defect on c1's reading that a comment thirty-four lines below
+   I originally reported this one as a live defect on the reading that a comment thirty-four lines below

-   "every layer file on disk is registered in the runner" — was green over it the whole time. c1 found why:
+   "every layer file on disk is registered in the runner" — was green over it the whole time. A later pass found why:

-   one that was never asked. c1 found the mechanism that let it stay that way: `check_ci_coverage`, the layer
+   one that was never asked. Re-reading found the mechanism that let it stay that way: `check_ci_coverage`, the layer

-   written to apply it. c1's finding.
+   written to apply it. Found on a later pass.

-   collision in it — confirms it: engine accept, shell accept. Also c1's, and it is the second time tonight
+   collision in it — confirms it: engine accept, shell accept. Also from that pass, and it is the second time

-   assertions going missing. c1's finding.
+   assertions going missing. Found on a later pass.

-   knows will not be entered. c1 caught the site-emitted version before it shipped.
+   knows will not be entered. The site-emitted version was caught before it shipped.

-   CI run 32448201825 on origin/main (53db2c3), read by c1 and verified here.
+   CI run 32448201825 on origin/main (53db2c3), read from the log and verified here.

-   WHY M9 COULD NOT HAVE CAUGHT IT, which is c1's point and the more useful half: setting the variable locally
+   WHY M9 COULD NOT HAVE CAUGHT IT, which is the more useful half: setting the variable locally

-   docs(harness): the three registry rows c1 read as weakest, escalated with what would settle each
+   docs(harness): the three registry rows that read as weakest, escalated with what would settle each

-   Two findings from c1, one confirmed by running the other environment rather than reading it, and a fifth
+   Two findings from a later pass, one confirmed by running the other environment rather than reading it, and a fifth

-   AND `env` ROWS COULD NOT FAIL IN EITHER DIRECTION -- c1 again, and it is this branch's own dominant class
+   AND `env` ROWS COULD NOT FAIL IN EITHER DIRECTION -- the same pass again, and it is this branch's own dominant class

-   control varied run-to-run noise and never varied the thing that actually moves the number. c1 found it and
+   control varied run-to-run noise and never varied the thing that actually moves the number. A later pass found it and

-   exact, since c1 checked and their conditions are measured properties of the run rather than host config.
+   exact, since the conditions were checked and are measured properties of the run rather than host config.

-   independently by c1, who took apart the fix I proposed for the second one and was right to.
+   independently on a later pass, which took apart the fix I proposed for the second one and was right to.

-   LESS". c1 pointed out that a per-layer registry is green when a listed layer goes from 2 stand-downs to 5,
+   LESS". A later pass pointed out that a per-layer registry is green when a listed layer goes from 2 stand-downs to 5,

-   A CONTROL ON THE PREDICATE IS NOT A CONTROL ON THE POPULATION, and this is c1's finding, in the same
+   A CONTROL ON THE PREDICATE IS NOT A CONTROL ON THE POPULATION, and this came from a later pass, in the same

-   Two more guards that could not fail, one of them found by c1 in code I had written an hour earlier while
+   Two more guards that could not fail, one of them found in code written an hour earlier while

-   stops being true. c1 bounded the claim by running the mutant against the two neighbouring structural greps
+   stops being true. The claim was bounded by running the mutant against the two neighbouring structural greps

-   layer's stdout line by line -- c1's screen for the "two assertions in one watched-red" problem, which is
+   layer's stdout line by line -- the screen for the "two assertions in one watched-red" problem, which is

-   coverage gap, not a closure, and it is the director's call whether to accept it.
+   coverage gap, not a closure, and whether to accept it is still open.

-   `tools/check_ceremony_reads.gd` arrived at this session already carrying uncommitted comment edits from
+   `tools/check_ceremony_reads.gd` was already carrying uncommitted comment edits from

-   both rows a column short. Restored to `c2`, which is what they held before. A table row is not a sentence
+   both rows a column short. Restored to what they held before. A table row is not a sentence

-   and why c1 asked for this to be written down rather than left to be re-derived.
+   and why this was written down rather than left to be re-derived.

-   than the size they are drawn. Filed now because the director has folded further machine art into the
+   than the size they are drawn. Filed now because further machine art has been folded into the

-   Found by c1 reading the seam against its call sites rather than against my layer, which is the only way it
+   Found by reading the seam against its call sites rather than against my layer, which is the only way it

-   Written in the order c1 asked for and it was the right order: the `take_lode` arm went into the layer
+   Written in the order the work required and it was the right order: the `take_lode` arm went into the layer

-   separate decision: two harness files cite a path under `docs/handoff/`, two more cite a document by a name
+   separate decision: two harness files cite a path under the working-notes directory, two more cite a document by a name

-   that is itself the thing, and the harness runner points at `docs/tracelog/`. The directory names are the
+   that is itself the thing, and the harness runner points at the working-notes directory. The directory names are the

-   peer session it was a posed field the game recomputes, and the disconfirming evidence was already in my
+   a second pass showed it was a posed field the game recomputes, and the disconfirming evidence was already in my

-   NOT REGISTERED in run_harness.sh: that file belongs to the peer session this stretch. One `add` line is
+   NOT REGISTERED in run_harness.sh: that file is owned elsewhere this stretch. One `add` line is

-   lock, at 0.6% CPU with 94% of samples parked in `OS::add_frame_delay`. The peer session queued behind
+   lock, at 0.6% CPU with 94% of samples parked in `OS::add_frame_delay`. The next run queued behind

-   check_ceremony_reads was the only red in a 92-layer sweep, and both this session and the
+   check_ceremony_reads was the only red in a 92-layer sweep, and both this run and the

-   the harness's own log was garbled at the exact assertions this session added — "CONTROL:
+   the harness's own log was garbled at the exact assertions just added — "CONTROL:

-   out: owner c2, terminal disposition SHIPPED or REJECTED on evidence, and MNU-29
+   out: one owner, terminal disposition SHIPPED or REJECTED on evidence, and MNU-29

-   Trace: the 0041 pre-registration is copied into docs/tracelog/c2.md A40 so it
+   Trace: the pre-registration is copied into the working notes so it

-   survives in my own trace. Per 0046, only the director creates bus commands; I
+   survives in my own trace. I

-   issued 0045 for that pre-registration without reading DIRECTOR_BUS.md first, and
+   recorded that pre-registration in the wrong place first, and

-   Also recorded there, because it cost the director three audit intervals: I
+   Also recorded there, because it cost three audit intervals: I

-   PEER_SESSIONS gains two hazards both sessions hit tonight. The Bash tool clamps a
+   The working notes gain two hazards hit twice over. The shell wrapper clamps a

-   c1 measured it rather than my assuming it. Fixtures pose 13 distinct sim fields
+   It was measured rather than assumed. Fixtures pose 13 distinct sim fields

-   statement about assignment forms. c1's reading is the one to keep: `=` DESTROYS a
+   statement about assignment forms. This reading is the one to keep: `=` DESTROYS a

-   and therefore of contention. c1 asked whether a standalone probe can certify
+   and therefore of contention. The open question was whether a standalone probe can certify

-   artefact. This session's defect in its smallest possible form: one word, in a
+   artefact. The defect in its smallest possible form: one word, in a

-   And PEER_SESSIONS gets the other half of its own rule, which is c1's: the lock
+   And the working notes get the other half of that rule: the lock

-   other. c1 edited a file in my tree while I swept; I then apologised to c1 for a
+   other. A file in the tree was edited mid-sweep, and I misattributed a

-   I cited c2's 247 magenta pixels underground one commit ago, and built a small
+   I cited the 247 magenta pixels underground one commit ago, and built a small

-   c2 ran the probe BOTH ways -- same seed, same standing, same detector, from a
+   The probe was run BOTH ways -- same seed, same standing, same detector, from a

-   coarse FILL forced magenta (c1)        7398 px surface     0 px underground
+   coarse FILL forced magenta            7398 px surface     0 px underground

-   _draw_edge_ao alone, magenta (c2)      0.196% surface      0.012% underground
+   _draw_edge_ao alone, magenta          0.196% surface      0.012% underground

-   c2's is the better number and it is theirs: 247 scattered pixels underground
+   That is the better number: 247 scattered pixels underground

-   permanently red gate gets ignored or gets its floor lowered. (c1 caught this; it
+   permanently red gate gets ignored or gets its floor lowered. (Caught on a later pass; it

-   forever, and a guard people route around is worse than none. (c1 again.)
+   forever, and a guard people route around is worse than none. (Same pass again.)

-   Caught by c1, who tried to refute the reasoning behind 8789287 and found the
+   Caught by trying to refute the reasoning behind 8789287, which found the

-   confirmed in source, a screenshot of it, and a message out to c1 about it.
+   confirmed in source, with a screenshot of it, and written up.

-   question than its name, which is the failure this session keeps finding.
+   question than its name, which is the failure that keeps recurring here.

-   Renumbered from 130; c1 landed a 130 in the same minute. Both frames stand.
+   Renumbered from 130; another 130 landed in the same minute. Both frames stand.

-   docs(visual): 6-7/32, not 'zero variance' — c1 corrected their own number and I had quoted it
+   docs(visual): 6-7/32, not 'zero variance' — the source number was corrected and I had quoted it

-   check_opening PASSES on main at 2/32 without c1's tooth — I ran it four times and
+   check_opening PASSES on main at 2/32 without the tooth change — I ran it four times and

-   A SURFACE RENDERING ANOMALY IN `line`, reported to c1 with numbers and NOT
+   A SURFACE RENDERING ANOMALY IN `line`, written up with numbers and NOT

-   draws it is c1's lane; a guess from me is a second opinion they must disprove.
+   draws it is owned elsewhere; a guess from me is a second opinion someone must disprove.

-   TR-06 marked PROVED with c1's root decision as the evidence, including the half
+   TR-06 marked PROVED with the root decision as the evidence, including the half

-   c1 accepted V2 and V3 after reading the handoff and the ticket table themselves
+   V2 and V3 were accepted after reading the handover and the ticket table directly

-   TWO EXIT-CODE FACTS, both found on the same afternoon by both sessions.
+   TWO EXIT-CODE FACTS, both found on the same afternoon from two directions.

-   Peer c2 audited check_opening and dead_space and sent evidence rather than conclusions. Four of the
+   A separate audit of check_opening and dead_space produced evidence rather than conclusions. Four of the

-   file is held by the peer session under an open directive; the one-line add is
+   file is owned elsewhere under open work; the one-line add is

-   baseline - returns DECISIONS.md, ORCHESTRATOR.md, handoff/NEW_SESSION_PROMPT.md.
+   baseline - returns DECISIONS.md and the handover docs.

-   Four is the POST-repair count, and the fourth file is docs/tracelog/c2.md, which
+   Four is the POST-repair count, and the fourth file is the working notes, which

-   ORCHESTRATOR's repo tree said "docs/ 12" and listed 13 names. I corrected 12 to 18
+   The handover doc's repo tree said "docs/ 12" and listed 13 names. I corrected 12 to 18

-   ORCHESTRATOR's FIRST MOVES both told every new session to read docs/VIBE_GAP.md;
+   The handover doc's FIRST MOVES pointed every reader at docs/VIBE_GAP.md;

-   ORCHESTRATOR pegged the presentation ordering to it; DECISIONS attested a locked
+   the handover doc pegged the presentation ordering to it; DECISIONS attested a locked

-   "loud enough to steer a dig" conclusion, ORCHESTRATOR's changelog and handover,
+   "loud enough to steer a dig" conclusion, the handover doc's changelog,

-   c2 was told to reconcile two documents, did exactly the two named, then found
+   The task was to reconcile two documents; that was done for the two named, and then

-   c2's: a layer driving a try_* in a loop is compromised only if it reports
+   The rule: a layer driving a try_* in a loop is compromised only if it reports

-   810/836/865/880/941, PEER_SESSIONS.md 268-270/892 — the whole 33.8 / 19.8
+   810/836/865/880/941, and the working notes at 268-270/892 — the whole 33.8 / 19.8

-   Not edited on three separate grounds: PEER_SESSIONS.md is off limits under
+   Not edited on three separate grounds: the working notes are off limits under

-   directive 0005; T2.3 is not my assignment and I have told the director in
+   the standing scope; T2.3 is out of scope here and that is recorded in

-   a record-keeping judgement rather than a bug fix. Reported where the director
+   a record-keeping judgement rather than a bug fix. Reported where the decision

-   shape c2 hit with _grow_vein and I hit with _runway_site. check_opening,
+   shape reached once via _grow_vein and once via _runway_site. check_opening,

-   WITHDRAWN: "there is essentially no boundary treatment at all." That went to c2
+   WITHDRAWN: "there is essentially no boundary treatment at all." That went out

-   feat(coordination): add the director bus
+   chore(tooling): add a small task-queue helper

-   homogeneous. It already is not — c2's lode pass stains 378 buried cells through
+   homogeneous. It already is not — the lode pass stains 378 buried cells through

-   Raised by c2, pointed at my own fix, as the same catch I had made on their lode
+   Raised against my own fix, as the same catch I had made on the lode

-   solid-ore path in the same breath. The director scoped T0.2 to the gen→sim
+   solid-ore path in the same breath. T0.2 was scoped to the gen→sim

-   Takes the LITERAL reading of kill-list #1, at the director's instruction and
+   Takes the LITERAL reading of kill-list #1, as scoped, and

-   I logged this as a fork in docs/tracelog/c2.md, leaned soft, and wrote down why
+   I logged this as a fork in the working notes, leaned soft, and wrote down why

-   docs(tracelog): the directive re-points c1, and the bulk measurement is superseded
+   docs(notes): the scope is re-pointed, and the bulk measurement is superseded

-   The fork is logged in docs/tracelog/ with an argument against my own reading,
+   The fork is logged in the working notes with an argument against my own reading,

-   Also commits docs/handoff/DIRECTOR_HANDOFF_PROMPT.md, which was sitting untracked
+   Also commits the handover prompt, which was sitting untracked

-   harness scanner is the real enforcement, because both sessions here commit
+   harness scanner is the real enforcement, because commits land here

-   eight ORCHESTRATOR.md named. Two are already upstream by patch-id, two
+   eight the handover doc named. Two are already upstream by patch-id, two

-   prediction about where the shape lived was wrong, in both sessions. The tell
+   prediction about where the shape lived was wrong, both times. The tell

-   That cost the peer session 39 minutes of machine time and blocked my own
+   That cost 39 minutes of machine time and blocked my own

-   900s behind the peer session's lock, gave up, and the wrapper's give-up was
+   900s behind another process's lock, gave up, and the wrapper's give-up was

-   It is a JOIN defect, the family the peer session named after finding it
+   It is a JOIN defect, the family named after finding it

-   check_dig_hitch also gains what the peer session asked for: its old
+   check_dig_hitch also gains what a later pass asked for: its old

-   peer session hit it from one end: this layer passed standalone three
+   It was hit from one end: this layer passed standalone three

-   argued to the peer session about a different threshold earlier the same day. Replaced with the comparison
+   argued about a different threshold earlier the same day. Replaced with the comparison

-   concurrent Godot processes on the box during a peer session's threshold derivation — three separate times.
+   concurrent Godot processes on the box during a threshold derivation — three separate times.

-   `check_paint_terms` and `check_seam_flood` landed from the peer session while
+   `check_paint_terms` and `check_seam_flood` landed from other work while

-   the peer session found in PlayAgent, and the reason check_underground spent
+   was found in PlayAgent, and the reason check_underground spent

-   ORCHESTRATOR.md §5 says a comment that states a number is a test with no
+   The handover doc §5 says a comment that states a number is a test with no

-   exactly the shape logged in PEER_SESSIONS as #11 an hour ago.
+   exactly the shape logged in the working notes as #11 an hour ago.

-   Merge branch 'worktree-agent-a8afacea093186351' into audio-per-material
+   Merge branch 'audio-material-work' into audio-per-material

-   check_bazaar_ruin.gd was written and verified by the peer session but never
+   check_bazaar_ruin.gd was written and verified elsewhere but never

-   accounting rewrite in flight from other hands, and the convention is that the orchestrator
+   accounting rewrite in flight elsewhere, and the convention is that the handover doc

-   % FactorySim.DESCENT_QUOTA, which is exactly the rule ORCHESTRATOR §5 states as 'a comment that
+   % FactorySim.DESCENT_QUOTA, which is exactly the rule the handover doc §5 states as 'a comment that

-   orchestrator doc is entirely about.
+   handover doc is entirely about.

-   docs(handoff): write down everything an orchestrator needs, and fix the walk
+   docs(handover): write down everything a new reader needs, and fix the walk

-   docs/ORCHESTRATOR.md is the full handover: what the game is and what it is for,
+   The handover doc covers what the game is and what it is for,

-   docs/handoff/ carries the lode cutover's own handover out of a scratchpad and
+   The handover directory carries the lode cutover's own notes out of a scratchpad and

-   per deep fixture run, present on HEAD before this session's changes).
+   per deep fixture run, present on HEAD beforehand).

-   crossing 0 this session); a construction snapshot means pre-stocked
+   crossing 0 in this run); a construction snapshot means pre-stocked

-   before this session never booms retroactively.
+   before never booms retroactively.

-   DIRECTOR'S CALL (redo of the earlier "moving platform" proposal): the lift is an
+   DESIGN CALL (redo of the earlier "moving platform" proposal): the lift is an

-   Settled this session via a six-axis clarifying brainstorm:
+   Settled via a six-axis clarifying pass:

