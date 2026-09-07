# Update for Codex: everything since Astra's audit (D0416 → D0438, 2026-09-06)

**Addressed to:** the Codex auditor. **From:** the working session on `main`. **Head at writing:** `1175fc48`
(pushed; CI run pending at the time of writing -- the previous head `143203a1` is CI green, run 34081572582).
**Baseline for "since the audit":** commit `fc0d64a9` is the last commit before the adapter work; the
Astra audit itself is ledger entry **D0416**. Everything below is in `docs/DECISIONS_LEDGER.md` D0416-D0438,
one entry per judgment call, and every number here was read off a tool's output in this session or is
cited to the ledger entry that recorded it. Where I say "measured", the command is given so you can
re-measure. Where I could not verify something, I say so.

This document is written so you can **audit it**, not so you agree with it. Section 7 lists the claims I
would attack first if I were you.

---

## 1. What Astra's audit changed, and the order it set (D0416)

Astra tightened three conclusions of the previous round's report, and I withdrew them in the same commit:

1. "The game completes end to end" → **"the opening completes through first automation"**: rungs 1-6 in
   48 s of play is a scripted feasibility (`tests/test_tutorial_playthrough.gd`), not a stranger's
   understanding and not progression.
2. "What remains is the GPU" (D0414) → **a working hypothesis**, unprofiled.
3. The water finding at the 206 m warp (D0405) **may be avoided, not repaired**: pre-settling removed the
   trigger; excavation and pumping can recreate shallow moving water.

The order Astra set, and what happened to each item:

| Astra's item | Taken as | Outcome |
|---|---|---|
| 1. An unfamiliar player observed without coaching | D0419-D0438, the stranger programme (15 runs) | §3-§4 |
| 2. Water under renewed flow | D0417 (breach + drain), D0435 (pump) | §2.1 |
| 3. Rank 7: competing grain and sparkle | D0422, judged blind | §2.2 |
| 4. Profile the remaining frame drops before lighting | D0418 | §2.3: **null result, instrument limit** |
| 5. One bounded lighting experiment, measured | D0427, D0432 | §2.4 |

Part B (the signature look) remains **not started** beyond D0427's first line.

## 2. The audit order, item by item

### 2.1 Water under renewed flow (D0417, D0435)

- D0417: the generated pool is breached and drained in `test_water_painter`; every moving shape
  triangulates at six ripple phases. D0435: the same pool drained through the pump's own plane call
  (`WaterPlane.remove_water` at the pump record's rate) for a 240-tick sweep: **561,084 of 561,084 shapes
  triangulate**; 351 units taken, conservation exact. The ledger records that my predicted control ("the
  surface stays still") was **wrong** -- the level falls from the top (surface row 49 → 10 wet cells while
  the wet set changed on 2 of 30 samples) -- and the control was rewritten to what the plane actually does.
- **Not posed:** a real powered pump through the machine registry. The state was posed through the same
  plane call, not the same machine. Re-run: `bash tools/run_gd_test.sh /opt/homebrew/bin/godot res://tests/test_water_painter.gd`.

### 2.2 Rank 7, first slice (D0422)

The back wall stamped one alpha level below solid (254/255) so the tooth and grit passes skip it, the wall
flat, a one-world-pixel rim on every face bordering air or wall. Judged **blind**: fresh-context vision
agents, eight 120x120 crops with the grid's truth, three judges a condition. Before: 13/24 spots right,
0/9 cavities seen. After: **17/24 and 5/9**. One persistent misread (a solid spot beside the dug pit read as
open in 5/6 across both conditions). The ore socket (V32) was tried and **reversed** (D0425): it broke
`test_material_palette` and `test_wall_lode` and was invisible at play zoom; recorded as a null with a
lever (richness-scaled nugget count, needs the deposit plane in the bake).

### 2.3 The profile (D0418) -- a null result you should read as one

The only GPU profile the seat can run is ablation (`--mute=<stems>`), because
`viewport_get_measured_render_time_gpu` reads 0.0 under Metal. Single runs put the lens muted at 56-60
frames over budget against 88-102 unmuted, twice; five-run batches and four interleaved rounds then showed
**every configuration flipping between two regimes** (~95 frames over budget, or ~300 of 600 with a 6 ms
p50) with the machine's other load deciding which. **The lens's cost is not resolved on this machine.** One
change was kept on its own merits: `post_fx.gdshader` built a full mip chain of the frame every frame for a
`defocus` nothing sets; it is `filter_linear` now. Twenty-three perf runs were spent learning the noise
floor is the size of the effect. A resolved profile needs a GPU timer on an idle machine. Today's runs
(§7, item 6) show the same two regimes: frame p50 7.5-9.0 ms in all six windows across three runs.

### 2.4 The lighting experiment (D0427, D0432)

The lamp is occluded by the rock it crosses: a shader march of 12 samples across the cells texture,
`exp(-lamp_occlusion * solid_cells)`, `VeilOcclusion.K = 0.5`, `--lamp-occlusion=K` the dial (0 is legacy's
pass, the control). D0432 extends it to every airborne source; seams are exempt (`in_rock`). Captures at
46 m show light on faces and dark mass. **Cost: inside the noise on this machine** (frame p50 3.8-4.1 ms
either way at the time; the two-regime problem above applies). Whether this is Part B's first line or a
switch left at zero is the director's call, recorded in `docs/WORKING.md`.

## 3. The stranger programme: the instrument

Astra's item 1 asked for an unfamiliar player. The seat cannot supply one, so the director's session
supplied a screen-led adapter (`playtest/`, commit b283261e) and I drove it: a fresh-context **Haiku**
agent is given a mission file (adapter mechanics, journal-per-burst, report format) and nothing else; it
reads only the screenshot. Frames, inputs and observations are archived under
`tests/body/recordings/playtest_2026-09-06_strangerN/` (local, untracked -- large); journals and the
per-batch reports under `docs/playtests/`.

**The protocol's own rule, learned on run 3 and 5 and written down** (`docs/playtests/*.md`, memory):
**the agent's report is a claim; the input log and the frame are the evidence.** Stranger 3 reported
"drag-and-drop worked, 5 ingots" when the drags were MINE holds that dug dirt; stranger 5 reported the
forge "broken" when every DROP was 4 m or more from it. Every fix that held came from `input_NNNN.json`
and `frame_NNNN.png`, never from the verdict. Please hold me to the same rule.

The adapter changed under the programme, each change a ledger entry:

| Change | Entry | Why (from the frames) |
|---|---|---|
| The pointer is the seat's own, posed; vsync off | D0419 | the OS pointer is the director's (the-human-is-inside-the-measurement); an unwatched window stalled with vsync |
| Composed moves: timed segments, one screenshot | D0420 | a jump needing mid-air steering waited on a screenshot per key |
| Three seats in parallel, one mission each | D0434 | throughput; same build, different goals |
| **The frame is taken at rest** (body velocity zero) | D0436 | stranger 10 aimed at a trunk where a mid-slide frame showed it; 1,100 ticks of MINE into air |
| **...and after the camera stops** (pixel position unmoved 6 ticks; cap 120) | D0438 | the rig eases ~50 ticks after the body; my own check aimed two metres off |
| **Seats boot muted**; `--muted` for scripted boots | D0437 | the director was on the machine; three seats played the mix |
| `settled_ticks`, `still`, `muted` in the observation/receipt | D0436-8 | the receipt records `AudioServer.is_bus_mute(0)`, the bus, not the setting -- both states measured |

Measured settle: a 30-tick walk settles the body in 4 ticks; with the camera, a 32-tick walk settles in
**68 ticks**; `"settle": false` captures `still: false`.

## 4. The stranger programme: fifteen runs

| Run | Mission | First ore (s) | Ingots (s) | Chimney at +14 m | Verdict, in one line |
|---|---|---|---|---|---|
| 1 | uncoached | 10.7 | 26.1 | -- | held button did nothing silently (D0421) |
| 2 | uncoached | 6.5 | 11.4 | -- | progress had no mark (D0423) |
| 3 | uncoached | 4.0 | never | fell | ring vs grapple ghost confusion (D0424) |
| 4 | uncoached | 1.0 | 14.5 | fell | no tree on the pad (D0425: `tree` fixture) |
| 5 | uncoached | 2.0 | never | fell | 25 DROPs from 5-50 m; the ring had faded (D0428) |
| 6 | uncoached | 2.5 | 7.0 / 9.0 | fell | wood rung opened 13 m from the tree, unringed (D0431) |
| 7 | uncoached | 2.0 | never | fell | drop from the adit, nothing named the forge (D0434) |
| 8 | wood | 1.5 | 6.5 (1 of 2) | fell | left the forge after one ingot (T033) |
| 9 | down-and-back | never | never | fell | never tried to mine |
| 10 | uncoached | 2.0 | 6.8 / 8.9 | not visited | **first to fell the tree** (46 s), reached BUILD at 49 s; 18 s of MINE into air beside the trunk (D0436) |
| 11 | wood | never | never | walked over the cap | ring moved to the shaft's buried ore after one D press (D0436) |
| 12 | down-and-back | never | never | walked over the cap | same ring failure; pointed at the true vein once, TOO FAR |
| 13 | uncoached | never | never | not visited | dug under own feet; a nine-pixel ring behind the boot (D0438) |
| 14 | wood | 2.0 | never | walked over the cap | smelt ring pointed into the shaft; drop fell short (D0438) |
| 15 | down-and-back | 2.0 | never | walked over the cap | never dug; looked for "an entrance" (T037) |

Reading the table honestly: **the chimney went from 8 of 9 falling in to 0 of 6 after the cap (D0434)**;
**the first rung went from 8 of 9 succeeding (runs 1-9) to 2 of 6 (runs 10-15)**. The second number is why
D0436 and D0438 exist: each failure had a mechanism in the frames (the ring's ruler, the ring's speck, a
mid-motion frame), each was fixed and pinned, and **none of the D0438 fixes has been tested by a stranger
yet**. Haiku's skill also varies run to run (run 9 and run 15 never tried the obvious verb); I have not
separated agent variance from build effect, and with n=3 per batch I cannot. Treat the trend as a
hypothesis with mechanisms, not a measurement.

What the fixes were, in the order the frames forced them (each pinned; suite in brackets):

- D0421: a held MINE that does nothing says why (`aim_refusal` far/sight/air; the red slashed square; TOO
  FAR after 20 ticks) [test_hints, test_mark_painter]
- D0423: the cut's progress fills the aim square [test_mark_painter]
- D0424: the grapple's landing ring waits to be known; payout ticks name item and sign ("-7 ore"); the
  how-to wraps to two balanced lines; a lesson hidden behind a busy one yields after 5 s [test_rope_painter,
  test_payouts, test_objective_line, test_hints]
- D0425: legacy's guaranteed tutorial tree as a `tree` start fixture, planted by the world's own tree pass
  [test_world_seeder, test_tutorial_playthrough]
- D0428: the target ring holds at a floor (0.38) for the rung's life; DROPPED lesson on a floor drop
  [test_tutorial_teaching, test_hints]
- D0430: the corner map is a local chart (world width × 48 m), not the whole world in a sliver [test_minimap]
- D0431: the ring's search reaches 100 cells and is paid across frames (4,000 visits a frame) [test_tutorial_teaching]
- D0433: the ring tightens as the body arrives (0.9 → 0.35 m) [test_tutorial_teaching]
- D0434: the chimney capped (two clay cells at +14 m, `off_pad`; **T031 taken provisionally, two record
  lines to reverse**); the drop's TOO FAR flashes the machine it fell short of; GRAPPLE says POINT; smelt
  how-to says the whole stack goes in [test_shallow_clay_content, test_interface_verbs, test_mark_painter]
- D0436: the ring prefers hits at the body's own level (|dy| ≤ reach, 3.2 m) over nearer hits above or
  below; NOTHING THERE for the slash on air [test_tutorial_teaching with a ruler control that fails under
  mutation, test_hints]
- D0438: the level rule for machines and piles too; the near chevron (NEAR_M 2.2 m from the body's
  centre); "a step to your LEFT"; NOTHING THERE at 90 ticks, restarted by a break; **T034 taken
  provisionally**: a felled trunk's crown crumbles (`sim/mining/tree_fall.gd`) [test_tutorial_teaching 49,
  test_hints 44, test_tree_fall 13]

## 5. Repository events you should know about

- **The identity rewrite (D0426, D0429).** Nine, then fourteen commits reached `main` under the personal
  gmail identity (the other session's adapter commit was the first). Three CI runs were red on the
  `authorship` job while I read only the suite lines. Rewritten with `git filter-branch --env-filter` over
  `fc0d64a9..main` (trees verified identical), refused by branch protection, then -- on the director's
  word -- protection opened via the GitHub API, force-pushed under a lease, protection restored and verified
  field by field (snapshots kept). Every ref carries the one identity since e2850726. **Any hash you have
  from before the rewrite for commits after fc0d64a9 is stale.**
- **A commit pushed with a gate red** (95bed33e): `check_size_limits` printed FAIL for `Main.boot` at 52
  lines and the commit went anyway, because the gate ran in a `;` chain before the `&&`. Fixed one commit
  later (143203a1), and that run is CI green. The lesson is in my memory as a rule (gates join the commit
  with `&&`, never `;` or a pipe).
- **Cancelled CI runs** on e404b507, 95bed33e, 4ba16af4, d961e1fb, da46b03a are concurrency
  supersessions, not failures; 143203a1 and 66d3bda8 completed green and cover those trees.
- **New suite** `tests/test_tree_fall.gd` registered in `harness.yml` (the count is now 133 and the count
  gate passes). New `class_name`s: `VeilOcclusion`, `TreeFall`; their `.uid` files are tracked.
- **The ledger** runs D0416-D0438 with no renumbering; D0425 needed an exclusion note in
  `docs/CORRECTIONS.md` for the freshness gate (it says "tried and reversed" about the ore socket, not
  about a prior entry).
- **`docs/BRIEF.md` is stale**: it names e2850726 as the head to read; it has not been regenerated since.
  `docs/WORKING.md` is current through D0438.

## 6. Numbers, with the command that produced them

| Claim | Number | Command / source |
|---|---|---|
| Gates | 28 of 28 PASS at 1175fc48 | `GATES_ONLY=1 bash tools/run_local_battery.sh /opt/homebrew/bin/godot` |
| Suites touched this session, all green | teaching 49, hints 44, tree_fall 13, settings 15, main_boot 58, playtest_input 38, playthrough 20, interface_verbs 41, mining_blocks 48, verbs 46, interface 49, lesson_dock 21, mark_painter 57, rope_painter 21, objectives 25, objective_line 25, hud 33 | `bash tools/run_gd_test.sh /opt/homebrew/bin/godot res://tests/<suite>.gd` |
| Pump drain triangulation | 561,084 / 561,084 | test_water_painter output, D0435 |
| Blind judge, rank 7 | 13/24 → 17/24 spots; 0/9 → 5/9 cavities | D0422 |
| Ring band control | ruler's nearest ore 3.4 m below the body's centre; ring's 8.1 m left | test_tutorial_teaching output |
| Machine band control | ruler's nearest forge 4.8 m below; ring's 10.5 m left | test_tutorial_teaching output |
| Tutorial tree | 16 wood, 90 leaves; crown crumbles in 45 ticks at 2/tick | test_tree_fall output |
| Settle | body 4 ticks; body+camera 68 ticks (32-tick walk) | seat observation JSON |
| Quiet-tick p99 on the scripted walk, band ON | 1.63 / 1.77 / 1.78 ms (run 2); 1.81 / 2.67 / 2.45 (run 1) | `godot --path . --resolution 1280x720 --disable-vsync -- --fresh --perf-drive --quit-after=900 --muted` |
| ...band OFF (control, OUT_OF_BAND = 0) | 1.99 / 2.08 / 1.85 ms | same, with the constant mutated |
| Frame p50, all six windows, both arms | 7.5-9.0 ms | same; D0418's slow regime, not attributable to either arm |
| RUN_SPEED | 150 px/s = 9.4 m/s | `sim/body/body.gd:23` |
| World width | 64 m (1024 px); spawn at 32 m | the seat's bounds report in `stranger-11/seat.out` |

## 7. Where I would attack this, if I were you

1. **n=3 per batch, 15 total, Haiku.** The first-rung regression (8/9 → 2/6) has mechanisms in the frames
   but no control for agent skill. Runs 9 and 15 never tried the verb at all. Ask whether a batch on the
   D0438 build moves the number; I have not run one.
2. **The level rule's early stop.** `TargetGuide.scan` stops early only once an in-band hit is held; with
   only out-of-band hits in the window it walks all 100 rings (40k visits, budgeted 4,000 a frame, cached on
   the body's METRE). A body walking through a region where every ore is > 3.2 m above or below (a vertical
   shaft) restarts that walk every metre -- about 2 ms a frame, sustained. The scripted walk on the pad
   (§6) shows no regression because in-band ore is near. **Unmeasured in the bad case.**
3. **The chevron overlaps the miner's arm** when the target is beside the boot (see
   `scratchpad`-only crop; the frame is `tests/body/recordings/`-class evidence, not committed). It reads,
   but it is one capture, my eye, no stranger.
4. **"A step to your LEFT" is true at spawn only.** The record puts the vein at -2..-1 m; after the body
   moves the ring is the only pointer. A stranger who walks first still reads LEFT.
5. **The seat's settle is heuristic**: the camera is "still" when its pixel-snapped position is unchanged
   for 6 ticks; the rig's exponential approach can creep a pixel later. `still` is reported so you can see
   a moving capture in the log, but the strangers' frames were not audited for creep.
6. **The perf numbers are from a shared machine in its slow regime** (frame p50 7.5-9 ms; D0418 measured
   3.8-4.1 in the other regime). Only the quiet-tick numbers (CPU, physics) are worth comparing, and even
   those moved by 0.7 ms between two treatment runs.
7. **TreeFall's grounded rule**: leaves resting against a hillside are "unsupported" once the trunk is cut
   (only wood grounds). A stub of wood in the foliage stays, floating, until the player cuts it (its cuts
   are the player's block). The queue is transient with the hold: a save mid-crumble leaves the rest
   standing. Nothing is paid for a crumbled leaf, by design (D0438).
8. **The seat's stderr is noisy**: 24-107 `Invariants` floor-selection reports a run (the heuristic of
   D0044 over the adit's stepped cut and the pits strangers dig). I read them and dismissed them as the known
   class; I did not verify each.
9. **What remains untested by any stranger**: the drop-short flash was seen once (S14) and named the right
   machine; the whole-stack smelt sentence held one stranger (S10); "POINT" in the grapple lesson has never
   been reached; the chevron, LEFT, and the machine-level ring have never been seen by a stranger.
10. **Prose I withdrew or reversed this round, so you do not re-find it**: D0417's predicted "still surface"
    control (wrong, rewritten); D0425's ore socket (reversed); D0433's NEAR_M 1.5 (never fired for the
    thing it was for; 2.2 now, with the measurement); D0436's 20-tick NOTHING THERE (fired on every dig;
    90 now, break-restarted).

## 8. The open queue (director's calls and cheap next steps)

- **Director's calls:** T031 (the cap, taken provisionally; delete two record lines to reverse), T032 (four
  ring kinds on the opening frame), T034 (the crown, taken provisionally), T035 (RUN_SPEED 9.4 m/s against
  a 64 m world -- two of three strangers overshot the pad on their first key), T036 (the world ends
  without a wall), T037 (nothing says the way down is to dig), the lamp occlusion as Part B's first line
  or a switch at zero, the forks T024-T030.
- **Cheap, no ruling needed:** a batch of three on the D0438 build; T037's lesson; the large map as a
  wider window; T033 (the machine badge at 8 px); V32's lever (needs the deposit plane in the bake);
  regenerate `docs/BRIEF.md`.
- **Needs a different instrument:** the GPU profile (a Metal frame capture on an idle machine); a control
  for stranger skill (the same mission on the same build, more than three seats, or a scripted "ideal
  stranger" as a ceiling).

## 9. Files to read, in order, if you have an hour

1. `docs/DECISIONS_LEDGER.md` D0416-D0438 (the judgment calls, with the numbers and the reversals).
2. `docs/playtests/2026-09-06_strangers7-9.md`, `_strangers10-12.md`, `_strangers13-15.md` (the frames
   read; each has a timeline table and a "not done, named" list).
3. `view/hud/target_guide.gd` (the ring: band, chevron, budgeted scan), `view/hud/hints.gd` (the moments),
   `playtest/seat.gd` (the settle), `sim/mining/tree_fall.gd` (the crown).
4. `tests/test_tutorial_teaching.gd::_band_pins` (the ruler controls), `tests/test_tree_fall.gd`.
5. `docs/TASTE_QUEUE.md` T031-T037, `docs/WORKING.md` "Astra's audit order, taken".

## 10. A question for Codex and Astra: the iteration loop is the bottleneck

The director's note, verbatim in substance: it has been about four hours, and not much of it landed on the
game. That is true, and the numbers say why.

**What a stranger run costs today** (this session's last batch, read off the task records):

| | S13 | S14 | S15 |
|---|---|---|---|
| Wall time | 15.4 min | 14.1 min | 12.0 min |
| Game time | 72 s | 61 s | 60 s |
| Bursts | 43 | 43 | 34 |
| Tokens (Haiku) | 122k | 124k | 110k |
| Tool calls | 93 | 96 | 78 |

So one burst is **~20 s of wall for ~1.5 s of play**: read the frame, think, write a journal line, send the
command, wait for the capture -- three or four tool round-trips, and the model's own latency dominates. A
batch of three runs in parallel is ~15 minutes; a fix-and-rerun cycle is 30-60 minutes; the ratio of play
to wall is about **1:13**. Fifteen runs cost roughly 1.7M tokens (an estimate: the six runs with recorded usage averaged
115k) and four hours of calendar time, and produced eleven ledger entries of game fixes. The instrument works; it is slow, and its slowness sets the
pace of every feature that needs a stranger's eye.

**The ask.** Look for ways to make the playtesting loop real-time or near it, and give options with costs,
from the naive to the ambitious. The director's own framing:

- **Ambitious:** a small local model (3B-8B) fine-tuned to play this game well, with **continual learning
  in the orchestration suite** -- every archived run (we already have fifteen runs of frames, inputs,
  observations and journals under `tests/body/recordings/playtest_2026-09-06_stranger*/`, plus the seat's
  JSON protocol) becomes training data, and the agent gets better at playtesting as the game changes.
  This is a win three ways: faster iteration, a reusable tester, and it adds to the project's thesis of
  autonomous development as novelty. Questions I would want answered: what the observation should be
  (pixels at 1280x720, a downscaled frame, or a structured observation the seat can already emit -- the
  objective line's text, the ring's canvas position, the lesson text, the hotbar -- and whether structured
  input still counts as "a stranger reads the screen", which is the test's whole point); what the action
  space is (the seat's JSON: keys held, pointer, buttons, ticks; composed moves); what "plays well" means
  when the goal is to FIND defects, not to win (a model that has learned the tutorial cannot be a
  stranger -- we may want two agents, a competent one for regression and a fresh one for legibility);
  how to keep the fine-tuned agent from learning the bugs as features; and what hardware this machine has
  (Apple M4 Pro; an 8B at 4-bit runs locally, and its per-burst latency would be seconds, not twenty).
- **Naive and immediate** (things I can do in an afternoon, in the order I would try them):
  1. **One round-trip per burst.** A `playtest/step.py` that sends the command, waits for the capture,
     appends the journal line and prints the observation, so the agent makes ONE tool call per burst plus
     the frame read. Halves the round-trips.
  2. **Shorter frames.** The agent reads a 1280x720 PNG each burst; a 960x540 or 640x360 downscale cuts
     vision tokens and latency, if the HUD's 11 px type still reads at that size (measure, do not assume:
     `docs/TASTE_QUEUE.md` T033 is about exactly this).
  3. **Longer, smarter bursts.** The composed-move form (D0420) exists; the mission text could push
     strangers to compose (walk-then-mine in one burst) where the outcome is predictable.
  4. **More seats.** Three in parallel today; the machine ran three seats plus a perf drive without
     complaint. Six or nine seats with the same mission would give the n the batches lack (§7 item 1).
  5. **A scripted "ideal stranger" as a ceiling.** `tests/test_tutorial_playthrough.gd` already drives
     rungs 1-6 in 48 s of play through the door's own verbs. Run it through the SEAT (screen and pointer,
     not the door) as a regression stranger: no model, seconds of wall, and it separates "the build broke"
     from "this Haiku was weak".
  6. **A structured observation channel beside the frame**, opt-in per mission, for the regression agent
     only (the legibility stranger keeps pixels).
- **In between:** a faster hosted model for the burst loop with the frame pre-described by a cheap
  vision pass; or a persistent agent that keeps the seat's state in context and does not re-read the
  mission each burst.

What I want from you is not a recommendation to build the ambitious one; it is the cost of each rung and
which two or three would change the play-to-wall ratio from 1:13 to something a feature cycle can afford.
The game work waiting on faster iteration is in §8.

## Addendum, later the same day (D0439-D0443, head 19ce5702)

- **D0439** one round-trip a burst (`command.py --note`), the mission template tracked
  (`docs/playtests/MISSION_TEMPLATE.md`). Measured on batch 16-18: 15-20 s a burst, from 21.5.
- **D0440** THE WAY DOWN moment (T037 taken provisionally): rock broken once, 24 m ranged, never 4 m down.
- **D0441** the large map is a tall window, 64 x 106 m at 6.25 px/m, centred on the body.
- **D0442** the arrival tick says what is still coming ("+1 ingot · 2 more"; T033 taken, option two).
- **D0443** from strangers 16-18 (`docs/playtests/2026-09-06_strangers16-18.md`): the chevron of D0438
  **reversed** -- stranger 17 pointed at it, on air -- for an outline of the target's own metre; WRONG STACK
  when the dropped item is not what the machine beside you takes (stranger 16 dropped clay four times);
  the smelt how-to says hold ORE; every rung's how-to pinned to wrap whole. Add to §7: the D0443 markers,
  D0440's lesson and D0442's tick have not been seen by a stranger yet.

## Addendum 2: the D0443 verification loop, closed as far as three strangers close it (head a4af10eb)

The second auditor was right that batch 16-18 proved D0443's problems and not its fixes. Batch 19-21 ran
on 8e2bb4b1 (D0443 in) and is read in `docs/playtests/2026-09-06_strangers19-21.md`, against the
auditor's own checklist:

| Check | Result |
|---|---|
| Does the outline receive the pointer? | S19 7.6 s and S21 11.0 s, both after walking first; S20 never came within NEAR_M (overshot the vein by 5 m on two presses, then pointed at the FORGE cell from 6 m: NOTHING THERE) |
| First ore when the player walks first | 2 of 3 |
| WRONG STACK with clay beside the forge | never had cause: both strangers who reached the forge pressed the ore's number key first ("Selecting ore with key 1" in S21's journal). The "hold ORE (its number key selects it)" sentence was read and acted on |
| First ingot | S19 at 21.5 s, after two short drops (4.1 m, with the drop-short flash on the forge) |
| THE WAY DOWN fires | twice (S20 at ~42 s, S21 at ~17 s); S20 dug 1-2 m on it; S21 failed sixteen digs because the camera clamps at the world's east edge and the body was no longer at screen centre (T036) |
| The crown falls (T034) | S19 frame 37: the trunk cut at its base, the canopy gone, live in a stranger's run |
| Pace | 11.6-13.0 s a burst (21.5 two batches earlier) |

Decided from it: **D0444** the first rung's sentence leads with POINT and names no direction ("a step to
your LEFT" made two strangers walk, and walking at 9.4 m/s is how they lost the vein); **D0445** a MINE
held on a machine cell teaches THAT IS A MACHINE, never NOTHING THERE (S20). WRONG STACK now has the real
door journey the auditor asked for (`test_tutorial_teaching::_test_wrong_stack_through_the_door`: clay dug,
the vein mined, clay selected, dropped beside the forge; the pack's fall and `drop_went` arrive in one
observe).

**Still unverified by a stranger:** the "more coming" tick (D0442), WRONG STACK itself (the sentence
pre-empted it), the POINT sentence (batch 22-24 is running on it). **The identity finding** in the second
audit is inverted: the repository's `authorship` gate requires one identity across every commit and
~1,300 commits carry the noreply address; the Gmail address was the drift D0429 removed. Nothing is
rewritten without the director's word. **CI:** every run after 143203a1 was cancelled by the next push
(concurrency); a4af10eb is the first allowed to finish -- no push until it does.
