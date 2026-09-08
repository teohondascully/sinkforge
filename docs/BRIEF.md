# Brief

**Last updated: 2026-09-07.** Repository cleanup Batches 1–2, starting at `61b50fa4`; D0480.

## Delivered

Public setup and build status now describe the implemented game and missing rig economy.
Onboarding no longer instructs a new agent to repeat the pivot.
C003 remains BLOCKED with current dependencies, rather than claiming saves and interfaces do not exist.
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

**For the director:** the stride (T035); D3–D6's rewards; the hotbar when the pack is empty (D0412's
history); a world snapshot for new_game's 2.8 s. **Next:** strangers 103-108 on D0506–D0509 (running
at the time of writing), their report, then the improvement workers on the findings.
