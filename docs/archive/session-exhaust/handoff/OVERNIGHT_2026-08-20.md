# Overnight 2026-08-20 — what shipped, what I found, what needs you

Gitignored, so this does not ship. `main` moved from `3c85b32` to the tip below, sole author, no
trailers, **nothing pushed**.

## Shipped

| commit | what |
|---|---|
| `143ae3c` | harness: the sweep summary excerpted failing layers with `tail -14` — a positional rule doing a selective job. `worldgen` is 162 lines with its one `FAIL:` on line 130, so the summary announced "1 FAILURE(S)" and printed thirteen *passing* assertions |
| `c1837b3` | capture: the register still called RESEARCHED a verb; it is a state |
| `1f5301c` | harness: **my own fix above was wrong and I caught it before it shipped.** There is no single FAIL format — 79 layers inherit `check_base.gd`, eleven roll their own. Zero hits routes into a branch that declares the layer *dead*, so the first version would have answered a real failure with a confident wrong diagnosis |
| `f128b8a` | **MNU-29a closed.** `rebind` was fixed so a duplicate cannot be *created*; `load_settings` read bindings off disk into `apply_bindings` with no conflict check, so a config written by the pre-fix build reinstated it every boot. New layer, 49 assertions |
| `120eee9` | **MNU-12, the clipping half.** The compact PACK plate reserved a fixed two lines and passed that count as a **cap**, so the longest item description lost its tail silently |
| `4fca217` | ceremony: gave the open-sky arm a drift floor |
| `0c4824e` | docs: MNU-12 and MNU-29a ledger entries were stale **in opposite directions** |
| `67290d3` | **MNU-18.** Selecting a row you cannot afford lit the plate and not the ink — 3.74:1, under the floor and *below* what the same row read unselected. Selecting made it worse |
| `550cf28` | **`check_plunge` green.** The purchase probe was physically yanking the body 10.7px sideways every 8 frames. **My published mechanism was wrong** — see below |

Verification: **92 PASS / 4 FAIL of 96**. Of the four, two (`check_rock_reads`, `play-tests`) are already
fixed on the peer's branch and land when it merges; `check_texture` is theirs and open; `worldgen`'s
frontier-richness margin is your parked call. So main is one parked decision away from a clean sweep.

## The two results worth your attention

**`check_plunge` was an instrument defect, and I published a wrong mechanism for it before finding
the right one.** The ride's own purchase probe — fired sideways every 8 frames to ask whether rock is
there — plants the grapple at `distance * SLACK_TAKEUP`, and the constraint projects the body onto that
shorter circle in the same physics step, **yanking it 10.7px sideways**. The body needed ~7 frames of
walking to clear a ledge; the probe put it back every 8. Second fault: steering stopped once the body's
*centre* crossed a cell boundary while 6px still overhung, and a sliver is a floor.

I first diagnosed a two-cell steering oscillation and briefed hysteresis. Wrong: `dir` was constant for
90+ frames at one stall and 0 for 100+ at the other. What alternated was the reported *cell*, because
the position was being yanked — I built a mechanism out of the quantisation of my own trace. Twice
before that I inferred from static terrain and was wrong both times, once because my scan started at
`surface_row()`, which returns the first *solid* row.

**The control that matters**: disabling the probe made the ride *worse*, 10 rows against 27 — the yank
had been carrying the body past the second fault early and pinning it against the first later. Two
faults of opposite sign, partially cancelling; fixing either alone moves the number the wrong way.
Legs 27 rows / 775 frames → 34 / 156. `TARGET_ROWS` untouched.

**The ceremony sky arm's premise was wrong.** Its new drift control says the sky does not move at all
within a run (3 pixels, 0.0 dE). The run-to-run swing is not background animation, which both
`PRIORITY.md` and the file's own comment assumed. It is something that differs *between* runs — the
standing. Narrower problem than we thought.

## Needs you — decisions, not work

1. **The tell surface.** Unchanged and still yours: `docs/handoff/TELL_SURFACE_DECISION.md`. 64 hits
   across `PRIORITY.md` and `VISUAL_RECOMMENDATIONS_SURFACE.md`, where the attribution *is* the
   document's structure, so it cannot be reworded — only gitignored, rewritten, or accepted. Nothing I
   committed tonight adds a tell; I checked, and the check's control caught a broken first attempt.
2. **MNU-18's remaining state.** "Unavailable" is not a per-row fact — `can_craft` is one bool for the
   whole counter, so a per-row mark would paint every row identically. It wants one panel-level
   statement, and *where it goes* (head band, or the tally line at the bottom of WORKS) is a layout
   call that touches `_bazaar_wanted_h`. The review does not settle it and I did not invent one.
3. **The per-ingredient cost red**, 4.20:1 on the selected plate. Every colour lift I costed trades a
   contrast defect for a greyscale one — the green/red gap is the *only* thing carrying per-ingredient
   affordability without colour. The review's answer is a text change (print the signed deficit, `−3`),
   which is a different ticket.

## New findings, filed rather than fixed

- **Two resolvers disagree about "which thing is works row i".** `_craft_id` falls back to
  `machine_icons.keys()[i]`; `_unlocked` filtered on `craft_ids`. They agree only while `craft_ids` is
  at least as long as `craft_options`, which `scenes/main.gd` gets right by building both in one loop
  and which **nothing asserts**. Latent, not active. This is what makes the machine `LOCKED` branch
  unreachable — by coincidence, not by construction — which is why I left that branch in place.
- **`with_machine.sh`'s cap is 1800s.** A cap six times longer than the caller's timeout is
  decoration; my own scratch tool hung 4.5 minutes holding the box because I omitted its `quit()`.
  Discipline fix (set `SF_RUN_CAP` on scratch tools), not a code change.
- **A sweep worth running: greedy local decision rules in play drivers.** The plunge oscillation and
  the peer's rung-3 failure are the same class — a driver unable to execute a route that exists. Brief
  it as *greedy local decision rules*, not "driver bugs", or it returns unrelated findings.

## One live defect on main I deliberately did NOT fix

`tools/check_rock_reads.gd` on main has three docstrings attached above the wrong function —
`_patch_chroma` carries 11 doc lines while `_patch_aniso` and `_patch_stats` have none. The peer has
already fixed this on their branch (`aa05456`), so repairing it here would hand them a conflict in a
file they hold. It stays until that branch lands, which is your call and not theirs or mine.

The cause is not a merge, as first reported, but an authoring pattern: each new patch-statistic was
inserted immediately above the existing ones and its docstring prepended onto the existing block.

**The part worth keeping is how badly we both searched for it.** Two of my detectors and one of theirs
returned a clean zero on the very file holding the defect. My third was aimed at exactly the right
fingerprint and still missed, because a `rate >= 0.60` guard I added to keep the output tidy excluded
the file at 0.58 — by two hundredths. Calibrating the detector against the known positive first makes it
fire, and then returns 20 candidates repo-wide, of which the ones I sampled are legitimate house style.
So the entitled claim is "a calibrated heuristic returns 20 mostly-legitimate candidates", not "the repo
is clean".

## The parked worldgen decision, now measured — and it is NOT an instrument artifact

`9d1841c` has four layers downstream of it. The peer showed three of them are the instrument reporting
its own sampling: `check_texture`'s qualifying-cell count moved 57660 → 57132 while the paint passes are
byte-identical, `check_rock_reads`' air side rose, and `check_plunge` was the probe displacing the body.
In all three the world is fine.

**The fourth one is different, and it is yours.** Same single-variable rig — the instrument at `550cf28`,
all other commits held constant, only `src/core/layered_world_gen.gd` reverted to `9d1841c`'s parent:

| | spawn | frontier | ratio | floor 1.15x |
|---|---:|---:|---:|---|
| current terrain | 19288 | 21806 | **1.13x** | FAIL |
| terrain reverted | 10258 | 31316 | **3.05x** | PASS |

This is not a population the layer sampled differently. **Spawn nearly doubled and the frontier lost
30%** — the ore genuinely redistributed. At a fixed depth the world went from strongly frontier-weighted
to nearly flat, so the layer is measuring a real property and measuring it correctly. The floor of 1.15x
was set when the margin was 3.05x, which is why it had never been close.

The design question, which is why I am not touching anything: **"horizontal ore pull" is the incentive to
travel sideways rather than just dig down, and the strata repair has largely flattened it.** 1.13x means
walking to the frontier is barely worth it. Three options, and none is mine to pick:

1. **Accept it** — declare the flat distribution correct and re-derive the floor from the terrain that
   now ships. Legitimate, but it is re-deriving a *quality bar* downward, so it needs saying out loud.
2. **Restore the pull by other means** — I already measured that `STRATA_SHELF_EVERY = 2` takes it to
   1.51x, but it turns three `surface_row` assertions red. One failure traded for three; reverted
   byte-identically.
3. **Accept a flatter world as a design change** and retire the assertion, on the grounds that the
   horizontal-pull incentive is no longer part of the design.

`9d1841c` itself is correct and stays — `docs/PRIORITY.md` already settles that, and nothing here
reopens it. What changed is that the consequence is now measured rather than assumed.

Numbers are from the layer's own fixed seed, so both arms are deterministic; a different seed would give
different totals and the same direction is not guaranteed without re-running.

---

# Second half of the night (06:30 onward)

## Shipped to main

| commit | what |
|---|---|
| `3f1c055` | `check_fixture_pointer`'s `warp_mouse` budget was **7 against a real count of 0**. Flat ban now, proved by knockout (a probe file with one real call goes red naming it) |
| `ff7fcfd` | **MNU-32 contrast** — 125 text/plate pairs enumerated from the draw calls, 11 under 4.5:1, all 11 fixed by lifting ink, no plate recoloured. `check_text_contrast` 9 → 13 pairs, now composites an ink's own alpha |
| `4169d4b` | **MNU-20 grouping** — owed lines first, settled lines lose their card; `_cost_gap` is the one predicate (was written at four addresses); dead `_cost_text` removed |
| `…` | **MNU-32 focus-visible** — and the finding under it: `move_settings_row` opened with `if settings_cat != CAT_CONTROLS: return`, so **the arrow keys did nothing at all on AUDIO and FEEL**. Those controls were unreachable, not unstyled |
| `e7e02b8` | `MENU_MATRIX` updated for both tickets, including a finding of mine that did not survive |
| `5a7f240` | `check_grapple_reads` — the saturation guard was right, and now says why |

**Full sweep after all merges: 94 PASS / 3 FAIL of 97 — identical to the pre-merge baseline.** The three
reds (`worldgen`, `check_texture`, `play-tests`) were confirmed already failing at `13bd7cf` before any of
tonight's work, from the retained sweep corpus.

## Two things I got wrong, both caught before they cost anything

**The `UI_ACCENT` inversion — withdrawn.** I found that the accent (Y709 169.3) is dimmer than daylit
ground (180s) and reported it as the act-on-this colour losing where a new player starts. **The population
is empty**: every accent draw site lands on a panel, and the one accent mark over the world is under an
0.82 veil already reading 6.54:1. Two further errors in the same claim — the "180s" took its maximum from
`LIT_LIP`, a 1px highlight nothing is drawn on, and "dimmer than the ground" is a *saliency* claim wearing
a *contrast* number, which is symmetric and cannot express it. Recorded in `MENU_MATRIX` rather than
deleted, because the reasoning is the reusable part.

**The grapple guard — I loosened it, then reverted.** A derivation said the bow guard fires on success
because `rope_sag` clamps at the posed slack. Every step correct; it neglected that `rope_sag` returns a
hang in **Y** while `_bow_now` measures the **perpendicular** departure. The chord is at 49.3°, so the
cap's 0.42 is 0.2736 of the chord — the rejected 0.4634 was 1.69× the geometric maximum and really was
saturation. I had already moved the threshold to the mask rim before working this out, which put the guard
on the far side of the exact reading it exists to refuse. Reverted to byte-identical predicates; what I
kept is the layer now **printing the renderer's prediction beside the measurement**, which is what made the
units error visible at all.

## T1.0 — the rig was voiding its own runs and reporting the result as a fact about the vein

`tools/_scratch_t10_cap.gd` returned *"the face yielded nothing — vein dry or unreachable"*, 0 delivered,
and **"share of the session NOT digging: 0.0%"** over a session that did no digging. Instrumenting the
hold:

```
HOLD  body at (50, 36), first workable (61, 67), 3 of 9 cells workable
      aim posed (1968.0, 2160.0), game reads (1968.0, 2160.0), delta 0.00 px;
      body-to-target 1037.0 px
```

Aim exact, vein workable, body a thousand pixels short — `walk_to_column` descends only by falling and the
site is 31 rows down. **The rig had already counted the pathing failure and ran the full 720-game-second
hold anyway.** It now aborts as VOID naming the gap, and the body is stood in the corridor as declared
unmeasured setup (at the SPINE end, so no trip count is bought by the placement).

**The control then reproduces: 1 trip, 3.0% of the session not digging**, against the recorded 1 trip /
3.2%. Delivered moved 263 → 318 because the world did — this face carries 927 units where the record says
263. The cap ladder is running; the caps were calibrated against a 263-unit face, so expect the trip band
to move.

Also converted the rig off `warp_mouse` — it held the real cursor for minutes at a time while you work.

## Still parked for you, unchanged

1. **The worldgen frontier-richness decision** (three options earlier in this file). Still the one red that
   is a design call rather than a defect.
2. **The 64-hit tell-surface editorial call** — `docs/PRIORITY.md` (40) and
   `docs/VISUAL_RECOMMENDATIONS_SURFACE.md` (22). See `TELL_SURFACE_DECISION.md`.
3. **T1.0's real blocker is a design question, not a measurement one**: the gravity trunk is not a sink, so
   ore dropped down the shaft is walked back into and re-collected. A cap creates repetition but there is
   no destination that keeps what arrives. *What the sink should be* is yours.
4. **MNU-07's remaining half** — a quiet opaque work surface versus a deliberately contextual counter view.
   A vision fork, skipped per your standing instruction rather than guessed at.

## T1.0 cap ladder — the open question had an answer

The ticket left two things open: *what the sink should be* (yours) and *whether the 2–4 trip band survives
on other sites* (mine). Once the rig stopped voiding itself, the second one runs:

| cap | trips now | not digging | recorded | recorded |
|---|---|---|---|---|
| OFF | 1 | 3.0% | 1 | 3.2% |
| 130 | 3 | 8.5% | 3 | 9.3% |
| 90 | **4** | 11.0% | 3 | 9.3% |
| 65 | 5 | 13.4% | 5 | 14.7% |

**The band survives.** One difference and the arithmetic predicted it: the recorded run noted *"the curve
is a staircase — 90 and 130 buy the same three trips"*, and that does **not** reproduce. With 309 units
reachable instead of 263, `309/90 = 3.4` against `263/90 = 2.9`, so 90 buys four trips and the two arms
separate.

**What limits a run, because it is not what either of us assumed.** The recorded baseline delivered 263
against a face carrying exactly 263 — it exhausted the whole body. This one delivers 309 of a **927**-unit
body while working 180 game-seconds against a 720-second cap, so it is neither vein- nor time-limited. It
is **exposed-face-limited**: 3 of the body's 9 cells are workable, 927/9 ≈ 103 each, predicting 309, and it
took exactly 309. The other six are behind rock.

So the two runs are the same *kind* of experiment after all — both stop when the material in reach runs
out — and the reachable quantity is 263 then against 309 now, 17% apart rather than the 3.5x the body
totals suggest. I predicted the band would move, from the body total rather than the reachable face, and
withdrew that before running it.

Ladders on other seeds are running; two data points on one seed is still one site.

## One more harness gate that was not wired in

`tools/check_trailers.sh` — the layer enforcing your locked one-author no-trailer rule — **was registered
in no sweep**, despite its own header arguing it must be a suite layer because `--no-verify` is routine.
The runner had no shell-layer support at all, which is likely why. Added (`.sh` paths now run under bash)
and registered as layer 98.

**It is red, and the failure is real: two distinct author identities exist across the refs.** 1322 commits
under `121736842+teohondascully@users.noreply.github.com` and one under `teohondascully@gmail.com`. Local
`user.email` is correct; the **global** one is the gmail address, so any worktree that does not pick up the
local setting authors as the wrong identity. The stray commit is not on main — it is on a feature branch
and its worktrees, which is one merge from bringing it in. Flagged to the session that owns that branch;
it is a one-line amend. **Left scanning `--all` rather than scoped to main**, because narrowing a
population to clear a red is the failure that file exists to prevent.

### Second site (seed 7) — the band does NOT survive, and the reason is your parked question

Genuinely different geometry: face 26 cells lateral instead of 12, depth 47 instead of 67, and **1 of 9
cells workable instead of 3** — about 101 units reachable against 309.

| cap | trips | not digging | took |
|---|---|---|---|
| OFF | 1 | 13.8% | 101 |
| 130 | 1 | 13.8% | 101 |
| 90 | **1** | 17.3% | 77 |
| 65 | **1** | 23.5% | 52 |

**Every cap buys exactly one trip.** The rising "not digging" share is not repetition — it is the *same*
fixed 26-cell haul divided by a shorter dig, because the cap truncated the one hold. A cap that cuts the
session shorter without adding a trip makes the ratio look better while making the game worse, which is
the metric-shaped trap again.

**And the second trip fails in a way that names the mechanism.** At caps 65 and 90 the run reports:

```
trip 2: the face yielded nothing — workable cells remaining: 1 of 9
```

A workable cell exists and the hold still produces nothing, because **the actor is already at cap when
trip 2 begins**. It dumped at the spine, walked back into its own pile, and auto-pickup re-collected it.
`carried 114 back` on the uncapped arm is the same thing stated directly.

**This is your `T1.0` recommendation demonstrated at a second site, harder.** The spike concluded *"the
gravity trunk is not a sink — a Freight Winch automates a route, and this route has no destination that
keeps what arrives."* Site one partly hid it (the trips still counted). Site two does not: **with no sink,
a cap does not create repetition at all, it creates an actor that is permanently full.**

So the honest answer to "does the 2–4 trip band survive on other sites" is **no**, and the trip count is
not a property of the cap. It tracks *reachable units ÷ cap* wherever the trunk drains — 309/65→5,
309/90→4, 309/130→3, all observed — and collapses to 1 wherever the actor re-collects its own delivery.

**Nothing here changes the recommendation, it strengthens it.** No cap value fixes a route with no
destination, and picking one before there is a sink would be tuning the wrong number. *What the sink
should be* is still yours and is now the only thing standing between T1.0 and a decision.

### Third site (seed 99), and the answer

| seed | workable / body | reachable | lateral | OFF | 130 | 90 | 65 |
|---|---|---|---|---|---|---|---|
| 1337 | 3 of 9 | ~309 | 12 | 1 | 3 | 4 | 5 |
| 7 | 1 of 9 | ~101 | 26 | 1 | 1 | 1 | 1 |
| 99 | 5 of 11 | ~530 | 17 | 1 | 5 | 7 | **8** |

**The 2–4 trip band does not survive. Across three sites the same caps buy 1, 3–5, and 7–8 trips.**
Seed 99's 65 arm hits `MAX_TRIPS` — the rig's stop, not a target — so 8 is a floor there, not a result.

**And the trip count is not a property of the cap.** It is `reachable units ÷ cap`, and the model holds
everywhere the trunk drains:

```
309/65 = 4.8 -> 5      101/65 = 1.6 -> 1 (see below)      530/65 = 8.2 -> 8 (capped at 8)
309/90 = 3.4 -> 4      101/90 = 1.1 -> 1                  530/90 = 5.9 -> 7
309/130 = 2.4 -> 3     101/130 = 0.8 -> 1
```

The one place it over-predicts is seed 7, and the miss is the finding: 101/65 should buy two trips and
buys one, because **the actor dumps at the spine, walks back into its own pile, and auto-pickup returns it
to a full pack** — so trip 2 begins at cap and can mine nothing. The run says so in its own words:
`trip 2: the face yielded nothing — workable cells remaining: 1 of 9`.

**So a cap does not create the repetition the Winch would retire. Geology does.** How much of a body is
exposed sets the trip count; the cap only scales it, and where there is no sink the cap produces an actor
that is permanently full instead of a repeated job. That is the spike's own recommendation — *the gravity
trunk is not a sink* — now demonstrated across three sites rather than argued from one.

**What this means for the decision.** Choosing a cap value now would be tuning a number whose effect
ranges from 1 to 8 depending on where the player happens to dig, against a route with no destination that
keeps what arrives. **The sink is the prerequisite and it is a design call — still yours.** Nothing else in
T1.0 is blocked on measurement any more.

### Correction to the above, and the model closed exactly

Two numbers in the table above are wrong and are corrected here rather than edited away.

**`reachable ≈ 530` at seed 99 was an estimate, not a measurement.** It was `5 of 11 cells × 1165/11` —
a uniform-units assumption, quoted as though it were a quantity. The rig reports total body units and cell
count, never per-cell. Summing what was actually taken gives **514**, and it is genuinely constant: the
OFF, 90 and 130 arms each take exactly 514, and the 65 arm takes 491 = 36 + 7×65, which is 514 censored at
`MAX_TRIPS`.

**And `reachable ÷ cap` was missing a term.** The actor starts each run already carrying ore — the rig
prints it as `loop-start` — so the first trip fills only `cap − start`:

```
trips = 1 + ceil((reachable − (cap − start)) / cap)
```

| seed | cap | reachable | start | predicted | actual |
|---|---|---|---|---|---|
| 1337 | 65 / 90 / 130 | 309 | 9 | 5 / 4 / 3 | 5 / 4 / 3 |
| 7 | 65 / 90 / 130 | 52 / 77 / 101 | 13 | 1 / 1 / 1 | 1 / 1 / 1 |
| 99 | 65 / 90 / 130 | 491 / 514 / 514 | 29 | 8 / 7 / 5 | 8 / 7 / 5 |

**Nine of nine exact.** One honesty note: seed 7's three rows use `reachable` = what was *taken*, which
under a cap is the cap rather than what was available, so those are consistency checks and not
predictions. The six real predictions are at 1337 and 99, where the arms agree on `reachable`
independently of the cap.

**A competing hypothesis was tested and failed**, which is why the model can be trusted: that mining opens
new cells, making `reachable` grow. The rig prints workable-cell count at each hold, and it falls
monotonically in every arm at every seed — `5 5 4 4 3 3 2 1`, `3 3 2 2 1 0`, `1 0`. Nothing new is exposed
by working a face.

**The conclusion does not move.** Geology sets the repetition, the cap only scales it, and the sink is the
prerequisite. What changed is that the number underneath it is now measured rather than assumed — and the
thing I had to correct was a quantity I derived myself and then stopped treating as derived.

---

## T3.4 — the hotbar icons. CLOSED, and it found two things nobody was looking for

**Commits:** `511d9fe` · `62998fa` · `b7782f8` · `bfe88a6` · `69bdbcf`. All measured, none guessed.

**The ticket.** `deepslate`/`iron` were the closest colour pair in the whole catalogue at **dE 1.0** — at or
below a just-noticeable difference — and both are carryable, so both can sit in the hotbar at once.

**Why a colour change could not fix it, which the file had already established by trying.** `_item_iron` was
`_item_ore`'s polygon and fleck positions *byte for byte*. The two were one nugget separated by a single
parameter, the matrix value, and that one number had to carry two separations in opposite directions: dark
enough to be told from ore and it lands on deepslate; light enough to be told from deepslate and it lands on
ore. A previous attempt moved the tint and immediately reddened the layer with `ore/iron` at IoU 1.00.

**The fix is the outline first, then the tint.** Iron is now a two-lump cluster on a diagonal — nothing else
in the catalogue is a cluster, and the diagonal leaves opposite corners empty so the footprint stops filling
the square. Only *then* does the host move to the steel band its own `item_color` always promised.
`deepslate/iron` leaves the six closest colour pairs entirely and **every other entry is unchanged**.

The silhouette half was checked **without the engine** — glyphs are polygons, so IoU is arithmetic. The
rasteriser was calibrated against two figures the layer had already published (0.72 and 0.75; it returns
0.703 and 0.747) *before* being asked anything new.

### Finding 1 — the suite ranked six colours and one shape

`check_item_reads` printed the six closest COLOUR pairs but exactly ONE closest OUTLINE pair, chosen with a
strict `iou > worst_iou`. **Three pairs sat at IoU 1.00**, so the first found kept the slot and the rest
could never print. The one it never named was `ore`/`iron` — the entire ticket. Fixed symmetrically; on its
first run the new ranking named **`rope`/`torch` at IoU 1.00**, which nobody knew about.

*Screens: a strict inequality plus a single slot silently truncates ties; asymmetric reporting depth is a
blind spot with a number on it.*

### Finding 2 — a pairwise metric cannot register "reads as the wrong object"

`rope` and `torch` turned out to have **no glyph at all**. Both fell through the dispatch to its default arm,
a bare filled square in the item's colour. Not similar shapes — *the same* shape, because neither had one.
Every other one of the 27 items had a glyph. The climb and the light were the two that did not.

I wrote them glyphs, the layer went green, and **the rope read as a magnifying glass** — thin even rim, thin
straight tail at a diagonal — two cells from the `scanner`, which is a prospecting instrument.

> **`check_item_reads` was correct. The icon WAS distinct from all 26 others.** Distinctness is a property of
> a PAIR. Reading as the wrong object is a property of ONE icon and a person. No pairwise metric can register
> that however many pairs it ranks — the arity is wrong, not the implementation.

Caught by rendering the set to a PNG and looking at it. That viewer is now tracked at `tools/icon_sheet.gd`;
it asserts nothing and is not a harness layer.

### Still open, and deliberately not "fixed"

- **`rope`/`torch` and the 48px question.** `check_item_reads` renders at `ICON = 48.0`, commented *"roughly
  a hotbar cell"*. It is roughly **four**. The game draws items at **13.0** through most of the HUD, 12.0 in
  pack rows and **9.0** on the ground. The rope's six wrap marks are `size * 0.035` — 1.7px at 48 and
  **0.46px at 13**. Verification at true size was still running when this was written; `SF_ICON_PX` exists
  on the viewer for it. *Correct instrument, wrong scale.*
- **`ingot`/`iron_ingot` and `stone`/`sealrock` are still IoU 1.00 and I left them.** They are families — two
  ingot bars, two blocks — separated by gold-vs-steel and a bright seam. Changing them because a number
  reads 1.00 would be serving the metric.
- `coal`/`ore` sits at **0.894 against a 0.90 clash floor**: 0.006 of margin nobody chose.

---

## T3.3 — the green/red stubs. CLOSED. There was never anything to fix

**It was fixed on 2026-08-18 by `deff5e7` and nobody noticed.** One line:
`_terrain_viewport.own_world_3d = true` (`world_renderer.gd:391`). Verified rather than taken on trust — it
is the only commit that has ever touched that string, it is an ancestor of HEAD, and `_moment_delve.png` was
committed 2026-08-17 14:03, **eleven hours before the fix**. Three sessions were debugging a photograph of a
renderer that no longer exists.

**What the colour was.** Nobody wrote it. The bake SubViewport retains its target (`CLEAR_MODE_NEVER`) and,
before the fix, inherited the world environment — so `adjustment_saturation = 1.18` was re-applied to the
*stored pixels* on every incremental bake, compounding as 1.18^n until the dominant channel clips to 1 and
the rest to 0. **A pure primary is the fixed point of that map.** There is a third bar, pure BLUE, at device
`23x23+0+256`; three primaries is what a repeated saturation transform gives and what an authored colour
cannot.

### The expensive lesson: four empty greps, one wrong premise

`.gd` colour literals → empty. `Color.NAME` constants → empty. All five shaders → empty. `.tres`/`.tscn` →
empty. Each result was read as *"therefore it is computed at runtime, so a grep cannot reach it"*. **The
first half was true and the second half was a statement about the searches.** It was computed by the GPU, on
stored pixels, by a pass that runs every frame. No source search over any population could have found it.

> The failure was not a bad search. It was continuing to widen the search instead of asking whether a search
> was the right instrument at all.

**And the ticket's own justification was withdrawn while its conclusion survived.** *"Proven world-layer
because the depth chip's alpha dims it"* does not follow — being dimmed proves only that it draws BEFORE the
chip, which includes earlier draws inside `hud.gd`. The valid exclusion: the bars carry the post-FX lens
signature the HUD cannot have — film grain at 238-242 pixel to pixel rather than a flat fill, and chromatic
aberration displacing red `+0.62px` and blue `−0.65px` against `±0.655px` predicted from
`aberration = 0.0007`. HUD is `CanvasLayer.layer = 10`; the lens is 5.

**LEFT FOR YOU:** the delve captures need re-shooting. They are pictures of a pre-`deff5e7` renderer, and
they are now stale on a second axis since the icon work changed `iron`, `rope` and `torch`. Not done here
because it rewrites tracked binaries and you should see that diff.

---

## Icon suite: it now reports where the player is, not only where it is comfortable

`check_item_reads` asserted at 48px. The HUD asks for 13 at almost every call site and 9 for an item on the
ground. A margin measured at 48 is not a margin the player has, so the layer now runs a **second pass at 13
and prints it beside the default on every run** — asserted at 48, reported at 13, with a WOULD-CLASH line
for any pair sharing both axes down there.

Reported and not asserted on purpose. The disjunction the layer is built on — share an outline OR a colour,
never both — was calibrated at 48, and a second floor at a size nobody has reviewed a screen at would be an
invented threshold. The WOULD-CLASH line is the evidence such a floor would need first.

It pays immediately: at 13px `ore`/`coal` reads **0.92** and `earth`/`ore` **0.90**, both over the outline
floor that neither crosses at 48, and the closest colour pair is `gravel`/`iron_pickaxe` at dE 1.5 — absent
from the top six at 48 entirely. Nothing shares both axes at either size, so the verdict did not move and no
floor was touched.

### Two things I measured and then declined to act on

**Coverage at 9px.** Eyeballing the world-size sheet, `gravel` and `wood` looked like the faintest icons and
I started building a case. Measured, the lowest coverages are `sapling` 0.020, `scanner` 0.031, `deepslate`
0.035 — **neither gravel nor wood is in the bottom six.** The metric and the impression disagree because
visibility is coverage TIMES contrast against dark ground and I had measured only the first term. Parked
rather than turned into a threshold. *A number that contradicts your eye means one of them is measuring the
wrong thing, and it is not automatically the eye.*

**Three tickets are stale, not two.** T3.3 was fixed two days before anyone investigated it. T3.5's premise
("the ruin has no art at all") is contradicted by `bazaars.gd:145`, which says ruin art was since added.
MNU-12's "compact inspector" is substantially built — `_draw_bazaar_detail` already has three plate variants,
two depths, and an art square derived from the plate height rather than written down twice. **The list is
now old enough that verifying a ticket is cheaper than building against it**, which is why three read-only
agents are checking T3.2, T3.5, T3.6, T3.8, T3.9 and T3.11 against HEAD before any of them gets worked.

---

# Later the same night — the session after the one above

`main` moved to `76c212c`. Five commits, sole author, no trailers, **nothing pushed**.

| commit | what |
|---|---|
| `14df970` | `capture_manifest.sh` computed each capture's renderer signature from a hard-coded list of drawing files, and `sky_painter.gd` and `bazaars.gd` were not in it — between them the sky gradient, the star field, the birds, the skyline cog, and every stall and ruin |
| `3b16de9` | `tools/machine_sheet.gd` — a contact sheet of all 18 machines, casing and glyph together, the sibling of `icon_sheet.gd` and for the same reason: T3.2 is a comparative claim about eighteen drawings and no per-machine assertion can make one |
| `d0e0155` | the sheet now refuses to mislead above one cell — see below |
| `a7d5076` | UI-01 and UI-02 marked shipped, and one false claim of mine corrected |
| `76c212c` | `check_hint_gate`, 32 assertions — the lesson gate had **zero** coverage. 99 layers declared |

## The one that matters most: I nearly rebuilt two features that already existed

`VISUAL_RECOMMENDATIONS_SURFACE.md` listed `UI-01` and `UI-02` as the two open items in `P1`. I read them off
the table and worked up a plan for both — a cursor-proximity predicate to build, a source-bound anchor to
move. **Both had shipped hours earlier.** `d57e02a` built the predicate as a real gate; `6df9bd7` moved the
anchor to `_cell_center(_aim)` for any gated lesson, which is verbatim the "source-bound cue beside valid
ground" `UI-01` said was still owed.

Nothing caught this but reading the source before writing any. That is now **five** rows in that table that
survived the change which closed them, and it is no longer a documentation nuisance — it is a live risk of
duplicated work reverting a better version. The table now carries a note about its own reliability, directly
above the `P1` closure line. **Closure lands in commits, not in rows.**

The knock-on: with `UI-01`/`UI-02` closed, `P1` is code-complete and waiting only on your review of the quiet
frame. `P4`'s last two are `GR-04` (escalated) and `GR-07` (explicitly human). `P5b` wants settled ground.
`T3.2`'s residual is your call on machines wider than one cell. **Every unblocked item on my list is done**,
which is why the back half of tonight is harness and record work.

## What needs you

Nothing new. The four decisions in the section above are unchanged, and tonight added no fifth.

## Two hours lost to a flag, and the reason it was hard

`machine_sheet.gd` renders through a `SubViewport` and awaits `RenderingServer.frame_post_draw`. Under
`--headless` that await **never fires**, so Godot prints its banner and sits at ~1% CPU indefinitely. Two
seven-minute timeouts. The same command without `--headless` finishes in six seconds.

The cost was not the flag, it was the failure mode: a wrong `--headless` **hangs rather than errors**, so it
presents as a wedged machine. I blamed peer contention (true once, then not), then the keychain boot hang,
then a corrupt isolated `HOME` — and tested a fresh one, which also hung and correctly killed that theory.
The evidence had been on my screen an hour earlier: a `ps` line from the peer's *working* run carried no
`--headless`, and I read it while chasing something else without comparing it to my own failing command.

Worth knowing generally: `%cpu` separates the two cases in one sample. Stalled on an await sits near 1% with
flat RSS; genuinely working does not.

## A measurement I ran, then threw away

I rendered the machine family at play size, thought several glyphs read dark-on-dark, and scored each cell
as WCAG contrast of its brightest 5% against its median. The ranking put `lift` **last** — and `lift`'s
bright chevrons are the most legible thing in the set.

The statistic is dominated by casing brightness and footprint area: small-footprint machines (`rope`,
`conduit`, `torch`) leave dark background inside their cell, dragging the median down and inflating the
ratio. It measures the cell, not the glyph. **Discarded; no art was changed off it**, and the eyeball
impression stays unverified rather than promoted on the strength of a number that agreed with nothing.

The same shape produced `d0e0155`. The sheet renders at any size, and I asked for 96px to judge detail —
but glyph scale is `px / CELL`, so that is `s = 3.0`, and **`s` never exceeds 1.0 anywhere in the game**
(HUD boxes of 13/15/17 against a 20-unit design space; the renderer passes a literal 1.0 and clamps its
only other path to it). Twenty-one `draw_line` widths in `visuals.gd` are absolute rather than `* s`, which
below 1.0 is a *minimum stroke* keeping hairlines alive at 13px — and at 3.0 renders three times thinner
than the game ever draws. Judging "spindly" off that sheet would have invited scaling all twenty-one, which
would have thinned the hotbar icons the floor exists to protect. The tool now prints the caveat above one
cell. **The finding was that nothing needed changing.**

## The new layer, and why passing did not count as evidence

`check_hint_gate` covers the relevance gate from `d57e02a`. Nothing in `tools/` referenced `SAPLING_GATE`,
`note_relevant` or `_gate_of` — the only gated hint in the game, untested, and silent in both failure
directions: stuck open the lesson runs its nine seconds out over a rock face, stuck shut the lesson is
simply gone and no screenshot shows an absence.

It passed 32/32 on the first run, which is when a layer has proved nothing. Forcing `_ready_to_show` to
`true`: red. To `false`: red. Unmutated: 32/32.

The mutation earned its keep twice, because it caught a defect in **my own layer's message**. With the gate
stuck open it reported *"the sapling lesson has FIRED and is waiting in the queue (0 queued)"* — which sends
the reader to the acquisition edge, when the real cause is that the bubble went straight to the screen. An
empty queue has two causes wanting opposite repairs. It now checks `_active` first and names which one it
found. **A failure message that names the wrong half of its own disjunction sends the next person to the
wrong file**, and running the layer only against a healthy tree could never have surfaced it.

## Three reds, re-run serially, all known

`JOBS=1`, logs retained — my previous sweep threw 323 seconds of detail away and kept one summary line.

    worldgen        FAIL  frontier richness 1.13x spawn         <- your parked decision, unchanged
    check_texture   FAIL  lag-1 0.91 (floor 0.55), roughness 6.5% (ceil 6.5%)
    play-tests      FAIL  RUNG 3, the L2 iron chain, missed twice

None is new and none is contention: a serial run reproduces all three. `check_texture` is failing **at** its
ceiling rather than past it, which is worth knowing before anyone tunes it.

## Mistakes worth recording

**I deleted a lock another process owned.** Twice I ran `rm -rf` on the machine lock as cleanup after killing
a probe, and the second time `run_harness.sh` still held it. No harm landed — only because the peer's fleet
was parked and I started nothing in the gap — but the box was unprotected for those minutes and my cleanup
checked nothing about ownership. I now wait on the pid.

**I claimed an API was undocumented when it was documented.** I wrote in `machine_sheet.gd` that neither
`draw_machine_casing` nor `draw_machine_glyph` said what units it took. False: one parameter is literally
named `cell_px`, and the other carried a docstring reading *"scaled by `s` (1.0 = full 32px world icon)"*. I
read the two signature lines and not the four above one of them. The remedy I proposed — add a docstring —
was the remedy already in place and already failing, which is the useful half: at a call site GDScript shows
a bare `1.0`, so the only channel left is the parameter's name. The peer renamed it `s` -> `cells`.

**I predicted noise where the arithmetic says moiré.** `WATER_CAUSTIC_LEN2 = 29.0` sampled once per 32px cell
is below Nyquist — true — and I concluded it renders as per-cell noise. Wrong: a single sinusoid below
Nyquist folds to a deterministic *lower* frequency. It renders ~141px x ~309px, so the band named as the
finer one is the coarsest structure on the water and coarser than the 78px primary. The peer did that
arithmetic; I reproduced it independently before agreeing. *"The instrument cannot represent X" says nothing
about what it outputs instead* — that second question always needs its own derivation.
