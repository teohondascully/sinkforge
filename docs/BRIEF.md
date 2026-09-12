# Brief

## What was learned — the audit instrument itself had the defect it was built to find (gate-reconciliation arc, 2026-09-11)

The 37-gate reconciliation (`docs/audits/2026-09-11-gate-reconciliation.md`: 30 ENFORCED, 3 ADVISORY,
4 NO-CODE, 0 CANNOT-FAIL) started from "does the enforcing code exist and does it fail" — and the
answer that kept surfacing was that **the measuring instrument shares the failure class it measures**:

- Gate 24's bounds probe ran and reported, but could not see its own defect class — an instrument
  that never fails is indistinguishable from one that always passes.
- Gate 5's enforcer declared "autoloads/singletons" in its docstring while carrying no pattern for
  either — the declaration lived in `project.godot`, outside every file the tool greps. A docstring
  overclaim inside the tool whose own header warns about docstring overclaims.
- `gate_status.py`, built to answer "is it wired", missed two wiring shapes: test citations reached
  through a glob-run step, and `--report-only` steps that map exit 1 to 0. Both classified gates wrong
  until the matcher grew up.
- `check_corrections_freshness.py` — built to catch a filename-substring false positive — false-
  positived on its *own* filename in a header (D0617).

The pattern is not "the checks are bad". It is that **a check's declared subject and its actual
subject diverge silently**, and only a mutation (or a live fire) ever closes the gap. Every gate
re-armed this arc carries a test that watched it go red.

## What was learned — the ratio everyone quotes is the number the gate refuses to gate on

The famous instrument:game ratio (measured this arc: tests+tools ≈ 50.7k vs game ≈ 32.3k, ratio 1.57)
is *informational, never gated* — gate 7's real property is **velocity** (instrument growth ≤ 2× game
growth over trailing 10 commits, blocking only at zero game growth). The absolute number gets quoted
because it is easy to state; the velocity number is what the project actually defends. Two further
measurements sharpen it: `tests/` alone is 35.9k lines — more than `sim/`+`interface/`+`shell/`
combined — while `harness/` and `experiment/` contain **zero code lines**, skeleton layers that exist
in the architecture and in gate 15's corpus check but not in code. The ratio question has the wrong
numerator: the instrument is big where it is *test*, and empty where it claims to be *harness*.

## What was learned — the ledger is read, and CORRECTIONS.md is the load-bearing product

Of 615 ledger entries, **450 (73%) back-reference earlier entries — 994 citations total — and 59%
are correction-shaped** (corrects/wrong/supersedes/falsified). That is a citation network, not a
write-only log: entries routinely cite the entry they supersede, and this arc's own queue direction
changed when P042's ruling was read back out of it. `docs/CORRECTIONS.md` (943 lines) is the
projection of that network the project actually consumes — every "confidently wrong" the regime is
built to catch, with the deepest chain (D0059→D0137, six weeks, five corrections) traced end to end.
If one artifact explains why this codebase's green tests are trustworthy-ish, it is the corrections
record, because it documents the exact shape of every past green-that-wasn't.

## What was learned — the prose earns its lines, measurably

`sim/` runs 31% comment lines (3,009 of 9,697). The cost is real — gate 3/4 caps exist partly because
of it — but this arc collected the counter-evidence directly: `run_suites.sh`'s header documents why
verdicts key on exit codes not `grep 'ALL PASS'` (a real false-green history, D0262), which is
precisely the sentence that stops the next agent reintroducing it; `hints.gd`'s D-annotated detector
table made the T030 lesson a one-line `note()` because the mechanism's contract was written down.
Prose-heavy code pays when the prose is *load-bearing* — named defects, dated numbers, "the detector
cannot tell its subject from its failure text". It fails when it merely narrates. The check that
distinguishes them is unautomatable, which is why it lives in the ledger.

## What was learned — every claim about how it LOOKS, made without a frame, was wrong. Four for four.

The director lent the screen late in the session. Four separate things I had measured, asserted and
shipped as correct turned out to be wrong the moment a frame existed, and no test could have said so:

| claim | what a frame showed |
|---|---|
| the beyond reads as receding earth (D0590) | luma **0.022-0.054** against the terrain's 0.185 — blue where the ground is brown. A hole, not a wall. |
| the grass draws (D0595) | **it drew nothing at all.** A colour per point; `draw_multiline_colors` asserts `colors * 2 == points` natively. |
| "at 0.15 the stars read" (D0583) | the starfield had **never once been drawn** — sub-pixel radii, in a 47 px band behind the trees. |
| band colours suit the beyond (first draft) | luma 0.381 against a 0.190 reference: a garish striped wall brighter than the terrain. |

**Each was green under a complete, honest suite.** The grass had 20 assertions and not one touched the
draw. The starfield had `visible_stars()` returning 42 and a suite asserting the field was "non-empty and
does not lattice" — both true of the LIST while zero pixels reached the screen. The beyond had a
brightness guard that passed because it asked "is this dark enough", not "is this the colour of the
ground beside it".

**The shape is one thing, and it is the house failure class in its rendering form:** measuring a function
is not measuring a picture. A painter's suite can be complete, green, and about nothing anyone can see.
The only assertion that closes it is one made on the data the painter hands the engine — which is why
`GrassPainter.batch` and `SurroundPainter.mass_color` are now split out and pinned, each opening with a
control that the fixture can register its subject at all.

**And the second-order lesson cost more than the first.** My initial repair to the grass suite — run
`paint` on a real canvas in a real draw pass — was itself wrong: the posed world grew no blades, so the
draw never ran and re-applying the bug left the suite green. I had written the instrument and declared it
good. Only the mutation caught it. Three times this session a mutation contradicted a conclusion I had
already reached and reported.

**What the frames also settled, positively:** the beyond now continues the edge column's own material, so
the seam needs no calibration at all; the stars fill the sky; and the grass gives the ground a soft edge
in place of a one-cell line. Evidence: `docs/media/moments/2026-09-11-*.png`, before and after on both.


## What was learned — prose outlives code, and one comment was advocating the design its own file rejected (D0587)

Astra's review of the decision brief closed on a caution about "old slump comments describing transient
saves". Checked, it was four claims, and three were the ordinary kind — a header that said the queue was
transient after D0579 made it persistent, in two places, and a bullet saying the drill does not wake
earth after D0579 made it do so.

**The fourth was a different animal.** `shell/session.gd` said "the set is rebuilt from the world itself
by the automaton's own rule" — four lines above `restore(data.get(KEY_SLUMP, []))`. It does not describe
stale behaviour. It describes the load-time SCAN that was tried first and measured wrong: the generated
world holds 1,061 unsupported loose cells, so a scan collapses a tenth of its loose earth on every load,
and `tests/test_boot_snapshot.gd` is what caught it. A session reading only that comment would have
re-derived the defect the test already rejected. `[[superseded-draft-above-its-amendment]]` in its worst
form — not prose that is merely wrong, but prose that ARGUES FOR the thing the code beside it refuses.

## What was learned — two correct counts are not a reachability proof, and the wrong one was mine (D0588)

P042 said a `d3`/`d4` naming the orphan machines "reaches four machines and four recipes in a single data
change". Astra caught the first link: `ore_iron` yields `ore`, `smelt_iron` consumes `iron`. Computing the
whole graph — with `yield_of`'s real default rule, that an absent `yields` means the material's own id —
**`iron` and `rich_ore` are consumed by recipes and produced by nothing anywhere.**

The set of recipes whose MACHINE is unobtainable and the set whose INPUTS are unproducible are the same
four. They are unreachable twice over, so neither half of the obvious fix does anything alone.

**What made it durable:** I counted the machines, counted the recipes, and checked that each stranded
recipe HAD a machine. I never asked whether its INPUTS existed. Both counts were right; the join between
them was never computed, and the population it had to be reconciled over — the item ids — was one neither
count ranged over. `[[two-instruments-are-not-a-cover]]`. And the shape of the number flattered it: "six
orphans, four recipes, one data change" is a tidy story with a cheap ending, so it got quoted forward
twice instead of re-derived, once into P042 and once into the brief Astra was reading.

## What was learned — a file can state its own bug in its header and be read past (D0589)

`light_painter.gd`'s header closed: "day/night — this build has no day clock, so the godrays run at full
day." True when written. D0583 then moved the sky to night and gave the ground a night level, and the
shafts were the half that did not move — a night sky pouring noon sunlight down every hole. The sentence
naming the defect had been sitting in the file the whole time, in a header I had edited that same night.

The fix derives both the beam's hue and its level from the sky (`SkyLight`), so no painter holds a second
opinion about the weather. It also turned up a free control: `sky_tint(0.0)` reproduces
`SkyPainter.STAR_COLD` to four places, and that constant was authored by a completely different route
(the night zenith held at hue 225.0, saturation 0.571). Two derivations of one blue that agree, so the
suite pins the new function against a number the repo already believed rather than one I chose.

## What was learned — the two defects in the new painter were both invisible to reasoning (D0590)

The earth past the world's edge — which the sim has called rock since D0457 and the view never drew. Both
of its bugs came out of probing numbers, and neither would have appeared in a test I would have thought
to write:

1. The first draft took band colours as the material. `BackdropPainter`'s header had **already named that
   trap** — they are announcement colours, "far too bright to use as fills at full strength". Measured at
   luma 0.381 against the reference's 0.190 for unlit deep rock: a garish orange-and-blue wall brighter
   than the terrain in front of it, and `the_seal`'s band colour is purple.
2. The mass shade was applied flat. But the beyond's top row sits directly under the sky and is not
   mass-shaded: 0.041 against the 0.155 of the ground beside it, a four-fold step that draws a black bar
   along the boundary.

The second now has a guard **because nothing else in the suite could see it** — the spread and
distinct-colour counts both survive it. That guard exists only because the mutation run asked what a flat
shade would break, and the answer was nothing.

## What was learned — a blocked item was blocked by an unchecked cost premise

Item 21 ("a cut face reads as cut") had stood as *needs a ruling first: per-cell provenance is sim state,
with a save-format cost*. Astra ruled not to build the provenance plane at all. Checking what the cheaper
version would actually cost: `bake_data.gd`'s **G channel uses 4 of its 8 bits**, so 4 are free for a
geometry-derived finish code. The item was never waiting on a save format. The real cost is that the
baked path and the CPU path must compute the same finish — which that file's own header warns about, for
the hash it already shares. A blocked item's stated blocker is a claim like any other.


## What was learned — the queue was measuring the wrong things, and a fix of mine was the cause (D0575-D0581)

Astra audited the overnight run and was right on every claim I could check mechanically. **P036 is
withdrawn, not answered:** I wrote that the renderer multiplies only, and `view/view_stack.gd`'s
`_mount_light` has mounted the light pass on a `BLEND_MODE_ADD` canvas since D0373, whose header says so
in capitals. D0575 — three per-material `base_color` scales — is withdrawn with it; it also failed a real
gate (`test_material_palette.gd`, coal 0.0933 against a 0.1426 floor) and the audit's qualification is
the load-bearing half: that floor is *derived* from inter-rock separation, so widening the palette moved
its own bar.

**The larger finding is that D0569 had turned the veil into a constant.** Its floor clamped the COMBINED
output at 0.55 while the underground's output cannot exceed `sky` 0.34 × `shade` 1.30 = 0.442. Measured:
buried rock, mid rock, a lit cut face, cave air and true void all returned rgb (0.5500, 0.5610, 0.6382)
— one colour for every structurally different thing below the scatter band. The file's own header said
the floor "does NOT flatten depth". D0577 replaces it with a depth-ramped ambient LIFT, restoring
two-thirds of the destroyed contrast at the brightness D0569 was reaching for, and leaving the surface
bit-identical. **This is why D0575 looked necessary:** with the veil constant, material colour was the
only term left varying.

**Every number P036 quoted was measured through that flat field.** Post-D0577 the multiply half alone
gives lit deep rock 0.163–0.234 and the additive pass adds ~0.148 at a pool centre — 0.382 against a
reference of 0.377. `[[name-the-frame]]`, where the frame was a bug I had introduced four commits before.

## What was learned — ten queue items were already built

Measured, not read: items 10, 13, 15, 16, 23, 26, 31, 32, 33 and half of 11. The camera's world-edge
clamp landed at D0333 and is called from `shell/main.gd:106`; the default zoom already IS
`ZOOM_LEVELS[0]`; the world is already 64 m, which is what P031's ruling asked for; godrays, bloom and
motes are all implemented and pinned. **The queue was authored from stale diagnoses** — earlier
observation notes and a triage pass that read intent rather than running against the tree. Measuring an
item before building it cost nothing and saved most of a night. It also caught the queue quoting seven
orphan machines when there are six.

## What was learned — a helper can be green while its call site is dead, three times in one night

`[[instrument-cannot-register-subject]]`, three fresh instances, each found by running the mutation
rather than by reading the test. D0578's correction bound was tested by calling the helper directly, so
deleting the call in `BodySwing.step` left every assertion green. Its landing-datum guard was tested in a
shaft, where `_slide` tries the vertical candidate first and the accepted y therefore always equals the
requested one. And D0579's reseed seeded a `MineHold` that `Interface.reset_transients()` had already
replaced — the direct assertion beside it was green through the whole mistake. Every guard in those two
entries is now posed through the real seam.

## What was learned — the world is not at rest, and most of the crafting content cannot be reached

Two measurements that were not the point of anything and are the most useful things found:

- **1,061 of the generated world's 28,572 loose cells are unsupported** (`shallow_clay`, seed 12345).
  They sit there until a player digs near one. Found because deriving the slump queue on load made a
  restored session diverge from a fresh one, and `test_boot_snapshot.gd` said so. The queue now travels
  with the save instead. Whether the world *should* arrive settled is P041.
- **Four of six recipes are unreachable.** Six machines are named by no start and no demand, and four of
  them strand a recipe each. `mine_ore` and `smelt_ingot` are the whole reachable crafting tree. A
  `d3`/`d4` naming those machines would reach four machines and four recipes in one data change; what
  the tiers should ask for is the director's, and it is P042.

## What was learned — a null result, reported because it was mine

I expected the warm lamp to erode the axis the three country rocks are told apart on: they separate on
hue (closest luma pair 0.029, *smaller* than clay's own within-patch spread of 0.037), and `lamp_tint`
multiplies blue by 0.690 against red's 1.000. Measured, it does the opposite — under the lamp the cool
spread across the three rises from 0.1009 to 0.1365. T012's ruled 0.38 gives 0.1459, so 0.62 costs about
6% of the hue separation: real, small, and the opposite sign from the prediction. It feeds P038 and does
not decide it.

## What was learned — the frame was lit for a sky it was not under (D0583-D0586)

With the director's screen for three hours, the decisive finding was not on the 49-item queue. **The sky
was painted as night and the world was lit for noon.** Measured on the opening frame: zenith 0.086,
horizon 0.254, ground beside the player **0.344**, tree canopy **0.479** — the brightest and most
saturated thing in the picture, against a reference whose surface rock at night is 0.148. No painter was
wrong on its own: the sky is drawn as night, terrain takes `sky_light` = 1.0 above the surface line, and
`leaves`/`wood` carry `depth_darken: 0.0` because "a tree stands in the sky". Three correct local
decisions that had never been seen together in one frame.

Two root causes underneath the art complaints, neither findable without looking at a picture:

- **Foliage was being shaded as rock.** `_cell_jitter` samples in METRES (17-48 m periods) and a canopy
  is 1.5 m across, so every leaf cell in a tree drew the same value — that is why canopies were flat
  rectangles. They were also taking `_strata`'s sedimentary hue bands, because `leaves` carries no
  `nugget_color` and so read as country rock.
- **The deep had no dark end.** `void_floor` multiplied the shade BEFORE D0577's ambient lift, so the
  lift's constant 0.48 handed it straight back: a void at s 0.119 and mid rock at s 0.153 both resolved
  near 0.58. Ambient is light on a surface; a void has none.

| | before tonight | now | reference |
|---|---|---|---|
| unlit deep rock | 0.0195 | **0.1926** | 0.190 |
| surface ground at night | 0.344 | 0.155 | 0.148 |
| the lamp's pool | 0.210 | 0.4355 | 0.515 |
| rock 1 m from the lamp | 0.157 | 0.2758 | 0.377 |

**A method note that paid for itself in one cycle.** Setting the minimap's `ROCK_DARKEN` to 0.20 to
darken it made it BRIGHTER — `Color.darkened()` takes an amount, not a multiplier. The capture said so
immediately. Every measurement above was taken headless, but none of the three findings would have been
found that way.

**Item 49's stopping rule moved three of its four conditions** — materials read as themselves, carved
space is separable from rock, and the lighting is attractive rather than merely bright. The fourth,
**holds under a moving camera**, is untested and every judgement here is a still.

## What was learned — reliable evidence has several boundaries (D0547)

`--front` contradicted itself by sending `--unfocused`; fixed, with PID-scoped activation added.
The desktop can still steal focus, and that must withhold frame claims. Setup/density measurements
now survive JSON, while source/settings/engine identity prevents mismatched comparisons. A real
Metal trace produced GPU intervals, not a zero timer. Shader parity is still unimplemented; the old
blanket brightness diagnosis is withdrawn, not a compensation to apply. Claude's `d344a35d` already
included the first tooling changes. [Checkpoint and remaining limits](audits/2026-09-09-runner-gpu-closeout.md).

## Paired evidence now identifies optional work (D0542, September 9)

The slowest preparation receipt now carries its own cells, callback count, execution/planning
IDs and scheduling reasons into JSON. One dig trace measured 9.793 ms in four optional-margin
callbacks. Lost window focus invalidates FPS conclusions, not this preparation attribution.
Six focused engine suites and Python fixture tests pass. No scheduler or art change yet.
Next: cold-descent coverage, then spread optional work without delaying cuts or visible terrain.
[Implementation and Claude handoff](audits/2026-09-09-bake-burst-handoff.md).

## What was learned — burst attribution before scheduling (D0541, September 9)

The peak-cell count and peak preparation time can come from different ticks. D0540's "9 ms over
1024 cells" is not one joined observation, and 1024 rectangle cells does not identify streaming.
No scheduler change landed. [Claude's next-step handoff](audits/2026-09-09-bake-burst-handoff.md)
specifies a paired receipt, lane attribution, one cold-descent fixture and the treatment decision.
Three focused bake/fixture suites pass. This is code analysis, not a new FPS or visual-parity claim.

## Small follow-up — camera reset correctness (D0539)

An explicit camera cut left old interpolation endpoints alive, including on the following tick.
Resetting them fixes it without touching body history or simulation. Four new assertions caught
the defect; camera, main-boot and world-view suites pass. Interpolation stays opt-in. No new FPS
or complete-motion-validation claim; broader performance work remains open.

## What was learned — performance audit correction (D0538)

The fixture could announce a refusal and still print the forbidden comparison. Its maximum was a
median of maxima, and a missing repetition could pass. Those defects now have failing-then-passing
regressions and fixes. Real dig validation reports 10/5195 warm frames over 16.7 ms, actual max
22.70 ms; no speedup claimed. Peak-per-tick preparation exposes a widest-zoom fall burst of 6.865 ms
behind a 0.306 ms average. Its focus was invalid, so frame statistics are withheld.

Fresh matched cave captures do not reproduce the old blanket brightness claim; do not compensate
ambient shading for it. Shader parity, lane-specific burst attribution and interpolation motion
evaluation remain open. See the corrected [programme audit](audits/2026-09-08-performance-programme.md)
and [performance queue](PERF_PLAN.md). Full local battery passed: 145 suites, zero failures, and
local quality gates. The suite phase took 175 seconds at jobs=4. Python fixture regressions also
pass. Gate-status has no unnumbered FAIL/SKIPPED steps; no new-head CI claim or push.
Historical completion statements below do not certify unresolved renderer work.

**Last updated: 2026-09-08.** Director-requested session-limit closeout; prior entries retained.

**Final checkpoint:** pass 1 is committed at `6b4b5e6c` (D0533). Pass 2 is partial: D0534 restores
surface tufts to the disabled shader prototype; four focused suites pass and a headed mining capture
shows the blades restored. Shader noise/parity and seam investigation remain open. Passes 3-5 are
not started; resume the queue in [PERF_PLAN](PERF_PLAN.md). No sustained FPS target is certified.
The complete current-head 144-suite battery is still required before integration; no push requested.

## What was learned — tooling and terrain closeout, September 8 (D0525/D0526/D0532)

**Sequential pass 1 completed (D0533):** sharing neighboring-cell work per paint region halves or better
the sampled 16x16 rock-shading cost, including preparation. 16,392 reference colour comparisons pass;
the headed mining PNG is byte-identical to a31fa3cf. Nine focused suites pass; the whole battery will
run at the integration checkpoint. Pass 2 addresses the existing, still-disabled shader prototype.

The existing CPU shading contained avoidable work: name decoding for solidity, zero-weight bedding,
and per-cell AO arrays. Removing those reduces the sampled shading cost 40-56%, with identical colour
hashes; it does not establish sustained 360 fps. The headed runs still have long-tail stalls, and
presentation updates on the physics tick. Commands and bounded results live in [PERF_PLAN](PERF_PLAN.md).

The iteration tools are committed at 5151e8ac: complete runner accounting, optional parallel battery,
timing summaries, explicitly historical reporting receipts, and the original-PNG tool-response pilot.
The pilot is not a measured live-model speedup. The long fuzz regression now starts first; one jobs=2
comparison fell from 290 to 270 seconds without removing any of its 747,000 ticks.

Verification: all 28 gates and 142 suites passed in the completed full battery after correcting the
stale suite-count label. During the pause the engineer incorporated the CPU work in c8385ca3 and
advanced main to 41f00226. Its additional work raises the suite population to 144; twelve focused
integration suites pass there, but the earlier full run is not certification of that later head.
D0528's shader prototype exists and stays off by default; resolve its reported seam/appearance
differences before enabling it. D0531's redraw optimization is also present. Do not duplicate either.
The closing gate-status report completed on 41f00226: no unnumbered FAIL/SKIPPED steps; the Linux
display-install command fails locally on macOS while CI reports success. This is not a full local
144-suite rerun. The reconciliation below is documentation-only and has not been pushed by this session.

## Delivered

Public setup and build status now describe the implemented game and missing rig economy.
Onboarding no longer instructs a new agent to repeat the pivot.
C003 is executable as of 2026-09-11: `tests/test_cold_start_d1.gd` drives a scripted bot through
`apply()`/`observe()` to `demand_satisfied(d1)` in 414 ticks (bf662a85); remaining gaps are the
constrained envelope, pacing threshold, and save/reload fidelity — documented on the claim file.
WORKING is a short current-state page. BACKLOG routes work to existing P/T/V records.
Five prior operational documents and the preceding gameplay brief are preserved under
`docs/archive/cleanup-2026-09-07/`. No code, tests, historical evidence, or gameplay rules were removed.

## Verification

- The documented item-suite command passed 78 assertions under Godot 4.6.2.
- Schema validation, generated-data freshness, working-date and ledger integrity checks passed.
- CI non-shrink check passed: no jobs, suites, or enforcing steps removed.
- The five operational snapshots match their source at 61b50fa4.
- Local documentation links and diff whitespace checked.
- Claim-reference check reports VOID (no claim-linked scenarios); it is not proof of a measured claim.
- Gate-status completed but found no completed CI run for the starting HEAD, so remote outcomes
  are UNKNOWN. Its initial untracked-doc failure was resolved by staging and rerunning that check.
  Its Linux display-install step fails on this macOS host. No full CI pass is claimed.

## What was learned

The suite runners already share CI-derived selection; another suite list would duplicate the solution.
Gate-status actively executes checks and repeats local step resolution, including mutation sweeps.
This is concrete avoidable overhead, now a Batch 3 item. Engineering's percentage split remains an
estimate; measure implementation, model waits, simulation/capture, verification and documentation
separately before changing orchestration.

## Next

Batch 3: harness/test/tool organization and module contracts, with gate-report deduplication a
bounded first candidate. [Cleanup plan](CLEANUP_PLAN.md) records scope and acceptance.
Gameplay continuation remains the forge checkpoint and subsequent opening rungs; see the
[preserved gameplay brief](archive/cleanup-2026-09-07/BRIEF.md).

## Gameplay (the engineering session, 2026-09-07 night; D0482–D0487)

**The opening is the spec's loop now.** The director's contract (D0482, after Astra's audit): fuel-fed
forge, dug supply, rig demand; the free drill, the coal-free smelt and the wood rung named as legacy
fixture behaviour and removed. Built: `smelt_ingot` is 2 ore + 1 coal, the need bubble names what a
machine lacks, a drill lets one coal fall with its stream when the machine below wants it (D0483); the
crew's rig -- a machine, the demand ladder as data (`data/progression/d1.yaml`: two ingots buy the drill),
its runner, `stage` through the save (D0484, `tests/test_rig.gd`); the rig in a well two metres right of
the spawn, no drill pile, the sinkhole mouth capped four metres wide, deliver in place of wood, the guide
rings the rig then the drill at its foot (D0485); the smelt ring goes to the coal seam until coal is
carried (D0486); a stranger's command returns the screenshot and the clock only (D0487). The scripted
witness plays the new opening in 17.7 s (ore 1.3, coal 3.4, two ingots 9.6, the drill in hand 17.7; set in
the shaft 4.2 s later). The playthrough suite drives all six rungs through the door.

**The one batch (70-75, six seats, all VALID):** ore 6 of 6, smelt 0 of 6. The build's smelt how-to had
run to a third line and lost "press Q" to the ellipsis (CI's objective-line suite caught it; fixed
8c6fc9f4); three of six never found the coal seam (D0486 answers); one fed the rig. The next batch
measures the fixed label and the seam ring together, after the next discoverability change.

**The morning's three (D0488–D0490), against the director's list.** Item 2 is complete: the REFUSAL SLOT
says the live refusal's headline (TOO FAR, NOTHING THERE, THAT IS A MACHINE...) on the dock from the press's
first frame, 1.5 s after, on every press, unlatched, yielding to its own lesson (D0488; captured at tick 28
and 70 with the new `--act=far`); the receipts leak was D0487; the RETICLE is pinned to the effective cell
through the door and the mark layer on S61's geometry (D0489, no code change: S61's big square was the smelt
rung's guide outline, the small chrome one stood on a broken vein cell). Item 3's flag: `intake: pass | jam`
on the machine record, `pass` shipped, `jam` holds a foreign item and reads `blocked` (D0490). Item 3's
elevated coal pocket is NOT built: hand-cutting yields into the pack, not a falling pile, so a coal cap over
the forge would feed nothing; the falling route is the drill's stream (D0483). A finding on the way: from a
body on a flat floor, floor cells a few metres off are occluded by the nearer floor (the grazing line of
sight, D0452), which is why a pointer along the ground gets TOO FAR where one on a face gets the snap.

**The director's rulings, applied (D0491, D0492).** The forge's intake stays `pass`, provisional, D0490's
suite pinning both rules. No elevated coal pocket: hand-cut yield goes to the pack, so a coal cap over the
forge would feed nothing; the ledger keeps the shipped DRILL-STREAM route (a machine's behaviour, D0483)
distinct from the spec's future DUG COAL CHANNEL (a discovery with bare hands, waiting on a yield rule). D2
pays the WINCH pair for six ingots and the winch leaves the starter cache, so the rig is the way up's one
source; the winch rung names the price, rings the rig until the payout and counts its second demand. CI is
green on 2f3e2041 (four jobs); 7037e526 carries D2 and is on CI now.

**The batch (76-81, six seats, all VALID, D0493).** Ore 6 of 6 (four in under 5 s). Coal 2 of 6, smelt 1 of
6, **deliver 1 of 6: S77 is the first stranger the rig has ever paid (the drill in hand at 54.0 s)**, BUILD
0 of 6. The wall is the coal's legibility, not the forge's: the seam is a black metre beside a black hole
(S79 stood on it with the ring under its feet and strode on), its hover card called it "Ore Vein", and the
card's "right of you" is true only at the spawn. Three fixes with frame-and-input causes: the seam's card
says COAL SEAM in coal; the smelt card says "press each stack's NUMBER then [DROP]" (S76 took forty bursts
to the number key); BUILD on a solid metre says IN THE ROCK (S77's RMB on the vein itself was silent). The
slot could not be isolated: no seat repeated a refusal on one cell after a release.

**The fleet on the batch's findings (D0494–D0499), six workers in six worktrees, cherry-picked and pushed
as d7a6eeda.** The coal seam reads as a solid block: its matrix sat 0.014 from dug space's own colour
(five times closer to a hole than any two rocks are to each other) and 16% of coal metres carried no facet;
lifted to anthracite, 17 facets a metre, the seam's on-screen luma 0.183 -> 0.247 with the hole and the clay
unchanged to six places (D0494). The smelt card points at the ring, the vein's card at the open metre above
(D0495). The refusal slot names every floor drop and every wrong stack (D0496; its worker found two
unguarded reads in D0488's pins, now guarded). The seam is two metres wide, +5 and +6 (D0497). A need
bubble the rung does not ring stands down to 0.30 while the ladder runs, on terrain rungs every bubble
(D0498, the worker's reading of the strangers' case). The ring carries the target's word: ORE, COAL SEAM,
FORGE, RIG, DRILL, MOUTH (D0499). One capture of the pad shows all six together. Every worker's commit was
re-run here before the pick; gates 28 of 28.

**Strangers 90-95 on the fleet's head (all VALID; `docs/playtests/2026-09-07_strangers90-95_fleet.md`):**
ore 6 of 6, coal 3 (from 2), two ingots 3 (from 1), delivered 2 (from 1), the drill set, fuelled and the
first automation 1 (from 0): **S91 is the first stranger through the automation rung (56 s) and the first
to say it would keep playing;** S94 forged in 19 s. The seam is found and its word read; nobody hunted
"black", nobody fed the rig. Two new walls with receipts, both fixed: TOO FAR DOWN at a surface seam
(D0473 measured "buried" from the body's centre; now from the feet, D0504) and a stack of ingots dropped
eight metres past the rig with the ring still on the rig (the ring goes to the dropped stack first, D0505).
Batch 82-87 before it was VOID: a rejected boot had already run into the directories.

**The harness, at the director's ask (D0501, D0503):** `playtest/batch.py` boots N clients at once, each
from a 6 MB copy-on-write copy of the runtime tree (a worktree was 589 MB), tiled across the screen with the
render pinned at 1280x720, into fresh directories by construction; the recordings are `.gdignore`d (the
import cache 2.9 GB -> 3 MB, `--import` minutes -> 3 s); six seats boot in 13 s. The tiles hold still
between bursts by design (the sim runs only for a stranger's ticks). The ring's word is pinned on the real
draw pass (D0500, the 137th suite) and the card's lines fit the card (D0502).

**Strangers 97-102 on D0504/D0505 (all VALID; `docs/playtests/2026-09-07_strangers97-102_feet.md`):** ore
6 of 6 under 3.3 s, coal 4 of 6, two ingots 2 of 6, delivered 0 of 6. TOO FAR DOWN at the seam is gone. The
delivery card was the wall (S97 at the shaft's lip, S101 at the forge, both quoting "beside you" and "hold
them"; fixed D0507) and DROPPED read as success (S98, S102; the headline is NO MACHINE HERE, D0508). The boot
measured: ready at 3.8 s, then 6.2 s drawing the FIRST frame under every renderer -- the terrain bake paints
the whole world at boot; a worker is making it bake the chunks in view first (D0506).

**Landed since (D0506, D0509, D0510):** the terrain bake paints only the chunks in the camera's window
first, the rest as they scroll in (`view/visuals/bake_window.gd`): receipt-to-first-frame 6.17 s → 1.64 s
on main, the first frame byte-identical; six seats now boot in 8.1 s wall together (`batch_103-108.json`).
The pit under the spawn is closed sim-side: a blow spares the four cells under a standing body's boots
unless aimed at one (`sim/mining/footing.gd`, D0509). The batch's dirty check reads only the runtime
tree it copies, so the harness's untracked recordings no longer block a batch (D0510).

**Strangers 103-108 on D0506–D0509 (all VALID; `docs/playtests/2026-09-07_strangers103-108_drop.md`):**
six seats booted in 8.1 s wall, played in parallel, last report at 12.5 min. Ore 6 of 6, coal 6 of 6 (the
first batch with every seat fuelled; TOO FAR DOWN at the seam never appeared), two ingots 1 of 6, delivered
0 of 6. The pit under the spawn is closed. One wall: 44 DROP presses and not one first drop within reach of
the forge; the stack falling at the feet read as LOSS ("resources disappeared", "materials respawned"), and
NO MACHINE HERE beside the RIG read as a contradiction. S104 alone fed the forge, after the aim_machine
lesson said "stand beside it", then carried the ingots 30 m past the rig to the world's edge (the stride:
10.5 m/s measured, 84 cells in 120 ticks). Workers on it: D0513 (a drop with its eater in sight but out of
reach is REFUSED, stack in hand), D0517 (a FED receipt, a TOO FAR lesson that points, the plate lets go),
D0515 (the cards lead with WALK and STAND), D0516 (the floor-ambiguity invariant's 40-170 reports a session),
D0518 (new_game's 2.8 s by sub-phase). Found by reading G's report: D0506 left the tooth's grammar texture
blank for the session (created from an empty image at mount, never uploaded); fixed D0511, evidenced by a
GPU readback (2439 non-clastic cells on the CPU, 0 on the GPU before, 2439 after).

**The five landed (D0513, D0515, D0516, D0517, D0518) plus D0519:** a drop with its eater in sight but out
of reach is refused with the stack in hand (`Interface.Result` moved to `interface/result.gd`); the smelt
and deliver cards open with WALK and STAND; the HUD's slot prints a FED receipt ("6 COAL → FORGE"), a TOO
FAR lesson names the machine, its metres and LEFT/RIGHT, and the plate lets a drop lesson go on a feed
(`view/hud/drop_lessons.gd`); the floor-ambiguity check reports only a surface the feet had reached (19
reports in a 600-tick walk to 0, three wrong pins turned around); `new_game` clocks its phases (generation
2.1 s of 2.7 s) and the snapshot restore was proven by signature, so the batch now makes one snapshot per
head and every seat opens it: 2733 ms to 701 ms a seat, first frame byte-identical. 139 suites.

**For the director:** the stride (T035, the number above); the layout (the forge is the only thing LEFT of
the spawn, the RIG at +2 is the machine strangers find and feed first); D3–D6's rewards; the hotbar when
the pack is empty (D0412's history); the receipt names the rig CREW RIG where the ring says RIG (W3's flag).
**Next:** strangers 109-114 on this head.

**Strangers 109-114 on D0513–D0519 (all VALID; `docs/playtests/2026-09-07_strangers109-114_stride.md`):**
six seats in 5.4 s wall from the snapshot; four ore 6 of 6, coal 5 of 6, two ingots 2 of 6, delivered 1 of
6 (S111 held the drill at 28.6 s, the fastest run recorded); nobody lost a stack; three quoted the TOO FAR
lesson's metres and direction and one the FED receipt; zero floor-ambiguity reports in six logs. The wall
moved to where the body STOPS: the receipts give 36 cells a 60-tick press (9 m/s) and the mission's own
text set the shortest walk at 30 ticks (4.4 m) against a 22-cell reach band, so strangers landed in reach
by luck. The template now says what a tick moves (D0520, the adapter's calibration).

**Strangers 115-120 on the calibrated mission (all VALID; `docs/playtests/2026-09-07_strangers115-120_reach.md`):**
four ore 6 of 6 at 2.2 s, coal 5 of 6, two ingots 2 of 6, delivered 0 of 6. The calibration did not change
the actor: 126 of 140 walks were still 30 ticks or longer. The wall, read from the receipts: nothing
persistent on screen says whether the body is within the drop's reach. S119 pressed 1 then Q eleven times
from cell 128, the reach band's last cell, every press refused, the 1.5 s slot flash gone before each
capture. The ring outlines its target within 2.2 m (D0443's rule for the block), the drop reaches 3.2 m
centre to centre (the sim's rule): two rules, and the eye sees the wrong one. Worker W8 (D0521): one
reach function in core, used by the verb and the ring, and the ring reads "FORGE · IN REACH" as a state.
Eleven of eighteen seats across the three batches walked to the world's right edge (the director's:
the layout and the clamp). **D0521 landed:** `core/reach.gd` holds the one reach rule (16/5 tiles), `Aim` and `Mining` delegate to it,
and the ring on a machine target draws a solid rim, a filled disc and "FORGE · IN REACH" by that same
test from the body's centre (`view/hud/ring_painter.gd`; `RingWord.last_drawn` carries the suffix, 22
pins). Mutating the constant reddens both the sim's reach pins and the ring's. 140 suites. **Strangers 121-126 on D0521 (all VALID; `docs/playtests/2026-09-07_strangers121-126_inreach.md`):** two
ingots 3 of 6, delivered 3 of 6, the drill placed 2 of 6, two seats into the fuel rung; one delivery in the
eighteen seats before. The strangers named the state ("RIG-IN-REACH, MOUTH-IN-REACH"). Left: the east edge
(14 of 24), the ceremony card read as the end (2), a self-dug pit (1). **D0523:** the spider cracks removed
at the director's ask. **In flight:** the director's freeze on every blow, measured: a blow costs a 17-27 ms
frame and the first blows 178-417 ms, all on the view side (the sim is 0.3 ms a tick headless); W9 (D0522)
repaints the bite's own rectangle, shrinks chunks to 32 cells and budgets the window lane. **D0522 and D0524 landed:** a blow repaints its own dilated rectangle (worst blow frame 419 ms -> 60 ms;
later blows under a frame), chunks are 16 cells, and the streaming lane paints at most 512 solid cells a
tick (a shaft fall's worst frames 80-90 ms -> 22-23 ms; a 384 budget measured the same, the floor is the
per-cell cost). The first frame is byte-identical. What remains is the per-cell shading itself, 18-25 us
a solid cell on the CPU: T040 in the taste queue puts the fork (a per-chunk data texture with the tone in
the rock shader) to the director with the numbers. **Next:** the director's read of T040; the batch queue
resumes on the next discoverability change.

**The four-hour window while the peer session was rate-limited (D0528-D0531, plus D0529/D0530 renumbered):**
THE EDGE lesson fires at the world boundary (fourteen of twenty-four seats had walked to it); the
acknowledged rung's card now names the next rung and the FED receipt says RIG, not CREW RIG (two of three
seats that finished a rung on its tick card had quit reading it as the end); the standing-still 18 ms
frames were measured and are NOT a painter (display pacing at 120 Hz plus an intermittently ~3x slower
host: a null result, D0527), which named the redraw lever now shipped as D0531 (the two static world
layers queue 0 of 600 in a settled window; ~5% off the still tick, no walk regression, the seat's first
frame byte-identical). T040's evidence landed behind a flag that is off (D0528): 48.6 -> 12.7 microseconds
a solid cell and a shaft fall's settled p50 halved, but the shader's rock is paler and flatter than the
CPU's and carries a red seam the CPU picture does not; the taste queue records that read and the fork.
Three workers died mid-ticket on a model rate limit: two were finished from their worktrees, one relaunched.
