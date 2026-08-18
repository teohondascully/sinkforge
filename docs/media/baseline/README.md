# P0 — the visual-triage baseline

**This is `P0` of the visual-triage program** (`docs/PRIORITY.md`, head of Tier 3). It is the gate on every
phase below it, and its whole job is to make "it looks better now" a claim someone can check.

**Owner:** `c2`. **Captured:** 2026-08-17.

---

## What these are, and the one property that makes them worth having

**Every frame here was rendered by `tools/capture_moments.gd` — the same script, the same scene, the same
settle, the same moment helper and the same shutter that produce the canonical `_moment_*.png`.** Only the
destination differs, via `SF_MOMENT_DIR`.

That is not a convenience. **A baseline captured by a different code path than the layer that judges it is
a different frame, and the divergence is silent and total rather than marginal.** It has already happened
in this repository once: a standalone probe of the opening — same scene, same `dev_start = false`,
differing only in settle frames — photographed the **Bazaar modal over a dimmed world with no terrain in
the frame at all.** Judged as a baseline it would have "confirmed" that a working layer was measuring a
scrim, and filed a false finding against correct code.

`SF_MOMENT_DIR` **fails closed**: an unusable directory refuses the capture rather than falling back to the
repository root, because that fallback would overwrite a canonical frame with a baseline — the exact
accident the redirect exists to prevent.

## Provenance

| | |
|---|---|
| commit | **`4e0444c`** (`origin/main`) |
| working tree | clean except `tools/capture_moments.gd`, carrying the `SF_MOMENT_DIR` redirect and the new `sapling` moment. **Neither touches rendering, the scene, or the sim.** |
| seed | **1337** — `MainView.WORLD_SEED`, reached because `SF_SEED` was unset (read from `scenes/main.gd:51,64`, not recalled) |
| settings | defaults; `tools/with_machine.sh` redirects `HOME`/`XDG_*`, so no player save or `settings.cfg` was read or written |
| resolution | 1920×1080, zoom 1.00 |
| input | `_deafen` + `Controls.deaf` — every frame is a pure function of the fixture, re-checked at the shutter |
| lock | machine lock held for every capture |

## The frames

| file | moment | what it is for |
|---|---|---|
| `_moment_boot.png` | `boot` | **surface** — the first frame a player ever sees |
| `_moment_sapling.png` | `sapling` | **sapling-help** — the one lesson a player can earn without being told to; `P1`'s required opening treatment |
| `_moment_delve.png` | `delve` | **underground** — lamp-lit rock on every side; the frame `P2` is about |
| `_moment_swing.png` | `swing` | **grapple** — the frame `P4` is about. **The moment was broken and is now fixed; see below. This file is the corrected frame** (the frame it replaced is in this commit's parent). |
| `_moment_map.png` | `map` | **map-open** — the only view that shows the descent's whole shape |
| `_moment_line.png` | `line` | **first-machine** — the first-automation beat. **See the defect below: it contains a surface rendering anomaly.** |
| `_moment_haul.png` | `haul` | not one of the six; captured as a control for the `line` anomaly |

## Closure conditions — and why they are not "the tree is clean"

**`P0`'s completion condition was `git status` clean, and that gate's subject was the whole box while its
claim was about six captures.** Parallel work and several worktrees write to this repository, so a dirty
tree is the normal condition and the peer could redden my gate by saving a file — a measurement-boundary
error arrived at from the unusual direction: not a population too small for the claim, but too large.
Narrowed to two checks that name `P0`'s own outputs and cannot be reddened by anyone
else:

    $ git status --porcelain -- '_moment_*.png' | wc -l      0
    $ git diff --stat HEAD -- '_moment_*.png'  | wc -l       0
    $ git status --porcelain | grep _moment | grep -v '^?? docs/media/baseline/'
      (nothing but tools/capture_moments.gd, which is the tool and not an artifact)

**`_moment_drift_before.png` and `_moment_drift_after.png` in the `capture-deafness` worktree were not
touched, renamed or regenerated.** They are untracked, match no ignore rule, and are the **inputs** to a
tracked sibling added by `3c46c8c`. *Untracked is evidence about tracking; it is not evidence about value.*

---

# Observations — separated from inference, per the evaluation protocol

**These are readings of the frames above. None of them is a ticket, an assignment, or a verdict on how the
game feels; several are already covered by existing tickets and are recorded here as photographed evidence
for them.**

## 1. Two defects in the instruments themselves — found by looking at what the instrument produced

### `swing` did not photograph a swing, and nothing could have told us — FIXED

`_moment_swing.png`'s docstring says *"mid-arc on a live grapple line, so the rope, the hook and the pose
can be judged together."* **The body in the frame is standing on a ledge.** The rope is a single faint
line, most of it behind the GRAPPLE lesson bubble, with the anchor out of shot.

The contamination table checks that delved moments are underground, that input is deaf, that no modal is
open. **It has nothing that can observe whether the line is taut or the body is airborne** — so this moment
can photograph a standing body and exit 0, exactly as it just did. It is the same shape as the day's other
findings: *a guard that cannot register what its frame is named for.*

**Why it survived:** the old helper waited up to 90 frames for an anchor **without caring whether one
arrived**, then teleported the body up-left — which *shortens* the distance to the anchor and drops the
line slack — shoved it right, and shuttered 26 frames later, by which time it had landed.

**Fixed.** It is a real pendulum now: anchor up-and-right, shove the body *away* from the anchor and off
the ledge so gravity loads the line, then step until both conditions the picture is about hold —
`grapple.taut` (the constraint did work last step, which is what drives the render) and `not on_floor`.
`_contamination` re-checks both **at the shutter**, so if the frames between there and the write land the
body, the capture is refused rather than repeating the old lie.

`SF_MOMENT_MUTANT=noswing` is the positive control and it has been run: it takes the anchor and stays on
the ledge — **the exact frame that used to pass** — and the guard refuses it with both reasons named,
leaving the existing file untouched. The corrected frame is a body mid-arc with a lit, loaded rope and
motion streaks; it is archived as `history/125-the-swing-that-was-never-a-swing.png`.

### The frame that exists to judge the grapple is covered by the text explaining the grapple

In both `delve` and `swing` the GRAPPLE bubble occupies the centre of the screen directly above the body,
and in `swing` it sits **on top of the rope**. Whatever `P4` does to the line's visual language, this frame
cannot show it.

## 2. A surface rendering anomaly in `line`, reported to `c1` and not diagnosed here

**Reached by the real ArcDriver playing the real opening arc on `main` at `4e0444c`.** Large parts of the
surface render as **pure `#00FF00` grass over a `#FF0000` dirt band** — unpalettised primaries, with
individual grass tufts, terminating at a hard vertical seam where the normal palette resumes.

    saturated-primary pixels (max>=240, min<=40, exactly one channel high), sampled every 2px:

      docs/media/baseline/_moment_line.png    6508 / 518400 = 1.26%   fresh, main @ 4e0444c
      _moment_line.png  (committed canonical)  857 / 518400 = 0.17%   and NOT in the same rows
      docs/media/baseline/_moment_boot.png      108                   fresh, same commit, t=0
      docs/media/baseline/_moment_haul.png        0                   fresh, same commit, underground

    fresh `line`, by 60px row band:     y-band 9 (y 540-599) = 11416    canonical, same band: 11
    fresh `line`, by 160px column band: 0,1,2,3 and 6..11 — everything EXCEPT bands 4-5 (x 640-959),
                                        a ~320px window sitting just left of the body

    sampled: y=575  x=60 #ff2300   x=1700 #ff0000        (boot, same pixels: #12090a, #5e6272)
             y=570  x=60 #b6ff00   x=1700 #0dff00        (boot, same pixels: #12090c, #6a7083)

**What is established:** it is a surface strip; it is pure primaries; it is absent at t=0 and present after
the arc on the same commit; it is absent from the committed canonical of the same moment; the one region
spared is a narrow window near the body. **What is not established: which layer draws it.** Renderer
diagnosis belongs to `c1`, who was told with these numbers. A guess from me would only be a second opinion
they have to disprove first.

**One consequence is `P6`'s, not the renderer's:** this would poison any capture-based evidence taken after
progression, including half of `T2.1m`'s fresh/midgame/full-catalogue capture matrix. **The matrix waits on
the answer.**

## 3. What the guidance frames actually show — `P1`'s photographed premise

**`boot`, the first frame of the game, carries seven simultaneous screen-space surfaces:** the depth plate,
the two-line objective slab, the FORGED counter, the zone ceremony (title, subtitle, rule lines and a large
ghosted gear behind the sky), the aim cursor and its pointer, the held-item name plate and hotbar, and the
bottom-left key legend. **The ceremony's gear sits directly behind the tree** — the only vertical landmark
on the surface and the object the first wood comes from.

**`sapling` is the collision, and it is the game's own best-behaved lesson that loses.** The SAPLING bubble
draws **on top of** the zone ceremony's "TOPSOIL", and covers the tree the lesson is about.

**`map` is T2.1's "stop zone ceremony colliding with map" — photographed.** The ceremony renders over the
open map panel, crossing its `TOPSOIL` band label and its `0 m` depth reading.

**`line` is the worst of the four, because of what it costs.** The first-automation plate — *"IT WORKS
WITHOUT YOU / THE LINE RUNS"*, the single biggest emotional beat the opening has — is **overlapped by the
SAPLING bubble telling the player that wood is renewable.**

**And the guidance is stale in the frame that most needs it to be current.** In `delve`, 15 m underground,
the objective slab still reads *"Mine 4 ore — hold LMB on the metal-flecked rock by spawn"* — pointing the
player back to the surface they just left.

## 4. Two numbers with the same unit disagreeing in one frame

`delve`, `swing` and `map` each show **`15 m THE CLAYBAND`** in the top-left plate and **`10 METRES DOWN /
THE CLAYBAND`** in the ceremony. Both are correct — current depth against the band's start depth — and
neither says which it is. *Recorded as an observation, not a defect: it needs a human ruling, and it may
be the cheapest legibility fix on this page.*

## 5. Two identical Forges in the opening frame

`boot` shows two Forges: the bootstrap forge at `(46, SURFACE)` that the player hand-feeds, and the AUTO
line's forge at `(56, SURFACE+3)` that belongs to a line they have not built. **Both are seeded by design**
(`scenes/main.gd:607,612`) — checked before writing this, because the frame reads like a duplication bug
and it is not one. **Nothing in the frame distinguishes them:** same sprite, same `FORGE` label, same
arrows. That is `PC-05` (*"give installed machines a visible active/idle distinction"*), and the opening
frame is its strongest evidence.

## 6. What already reads well, recorded so the next pass does not break it

- **The map is the most legible screen in the game.** The shaft reads as a shaft, the strata read as
  strata, the water pockets and the violet seal line at 66 m are unmistakable, and the descent reads as a
  journey rather than a grid.
- **`line`'s DRILL → FORGE stack is legible**: the counts, the feed arrow and the lit forge say what is
  happening without a label explaining it.
- **The lamp pool in `delve` is doing real work** — inside it, carved edges and floor read clearly.

## 7. The one thing every frame here agrees on

**Outside the lamp, rock and void are the same near-black.** In `delve` the left third of the frame cannot
be parsed into solid and empty by eye. That is `T3.1` **6a**, and it is `P2`'s subject.

> **STATUS, and it moved while this page was being written.** `c1` has since landed a treatment
> (`scenes/rock_tooth.gdshader`) taking VALUE 52% → 67% and GRAIN 61% → 79% against a 75% floor, with the
> rock/air value relation no longer inverted, `check_opening` 5–6 dead tiles of 32 → **0 of 32**, and no
> threshold moved. **These frames are therefore a genuine BEFORE.** They should not be regenerated; the
> after belongs beside them under a different name.
