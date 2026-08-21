# P0: the visual-triage baseline

The baseline for the visual-triage program. It is the gate on every phase below it, and its job is to
make "it looks better now" a claim someone can check.

Captured 2026-08-17.

---

## What these are

Every frame here was rendered by `tools/capture_moments.gd`: the same script, the same scene, the same
settle, the same moment helper and the same shutter that produce the canonical `_moment_*.png` at the
repository root. Only the destination differs, via `SF_MOMENT_DIR`.

That matters more than it sounds. A baseline captured by a different code path than the layer that judges
it is a different frame, and the divergence is silent and total rather than marginal. It has already
happened here once: a standalone probe of the opening, same scene, same `dev_start = false`, differing
only in settle frames, photographed the Bazaar modal over a dimmed world with no terrain in the frame at
all. Judged as a baseline it would have confirmed that a working layer was measuring a scrim, and filed a
false finding against correct code.

`SF_MOMENT_DIR` fails closed. An unusable directory refuses the capture rather than falling back to the
repository root, because that fallback would overwrite a canonical frame with a baseline, which is the
accident the redirect exists to prevent.

## Provenance

| | |
|---|---|
| commit | `4e0444c` |
| working tree | clean except `tools/capture_moments.gd`, which carried the `SF_MOMENT_DIR` redirect and the new `sapling` moment. Neither touches rendering, the scene, or the sim. |
| seed | 1337, `MainView.WORLD_SEED`, reached because `SF_SEED` was unset (read from `scenes/main.gd`, not recalled) |
| settings | defaults. `tools/with_machine.sh` redirects `HOME` and `XDG_*`, so no player save or `settings.cfg` was read or written |
| resolution | 1920×1080, zoom 1.00 |
| input | `_deafen` plus `Controls.deaf`, so every frame is a pure function of the fixture, re-checked at the shutter |

## The frames

| file | moment | what it is for |
|---|---|---|
| `_moment_boot.png` | `boot` | surface. The first frame a player ever sees |
| `_moment_sapling.png` | `sapling` | the sapling lesson, the one thing a player can earn without being told to. P1's required opening treatment |
| `_moment_delve.png` | `delve` | underground. Lamp-lit rock on every side, the frame P2 is about |
| `_moment_swing.png` | `swing` | grapple, the frame P4 is about. The moment was broken and was fixed in `975071f`; this file is the corrected frame |
| `_moment_map.png` | `map` | map-open, the only view that shows the descent's whole shape |
| `_moment_line.png` | `line` | first automation. Contains a surface rendering defect, described below |
| `_moment_haul.png` | `haul` | not one of the six. Captured as a control for the `line` defect |

## These frames are immutable

They are a before. Regenerating them would destroy the only thing they are for. Two checks name this
directory's own outputs and confirm that no canonical capture moved while it was being built:

    $ git status --porcelain -- '_moment_*.png' | wc -l      0
    $ git diff --stat HEAD -- '_moment_*.png'  | wc -l       0

---

# Observations

Readings of the frames above. None of them is a ticket or a verdict on how the game feels. Several are
already covered by existing tickets and are recorded here as photographed evidence for them.

## 1. A defect in the instrument itself, found by looking at what the instrument produced

### `swing` did not photograph a swing, and nothing could have told us (fixed in `975071f`)

`_moment_swing.png`'s docstring said it captured "mid-arc on a live grapple line, so the rope, the hook
and the pose can be judged together". The body in the frame was standing on a ledge. The rope was a
single faint line, most of it behind the grapple lesson bubble, with the anchor out of shot.

The contamination table checks that delved moments are underground, that input is deaf, and that no modal
is open. It has nothing that can observe whether the line is taut or the body is airborne, so the moment
could photograph a standing body and exit 0, which is exactly what it did. It is a guard that cannot
register what its frame is named for.

Why it survived: the old helper waited up to 90 frames for an anchor without caring whether one arrived,
then teleported the body up and left, which shortens the distance to the anchor and drops the line slack,
shoved it right, and shuttered 26 frames later, by which time it had landed.

The fix makes it a real pendulum. Anchor up and to the right, shove the body *away* from the anchor and
off the ledge so gravity loads the line, then step until both conditions the picture is about hold:
`grapple.taut`, meaning the constraint did work last step, which is what drives the render, and
`not on_floor`. `_contamination` re-checks both at the shutter, so if the frames between there and the
write land the body, the capture is refused rather than repeating the old lie.

`SF_MOMENT_MUTANT=noswing` is the positive control and it has been run. It takes the anchor and stays on
the ledge, which is the exact frame that used to pass, and the guard refuses it with both reasons named,
leaving the existing file untouched. The corrected frame is a body mid-arc with a lit, loaded rope and
motion streaks, archived as `history/125-the-swing-that-was-never-a-swing.png`.

### The frame that exists to judge the grapple is covered by the text explaining the grapple

In both `delve` and `swing` the grapple bubble occupies the centre of the screen directly above the body,
and in `swing` it sits on top of the rope. Whatever P4 does to the line's visual language, this frame
cannot show it.

## 2. A surface rendering defect in `line`, since diagnosed and fixed

Reached by driving the real opening arc on `main` at `4e0444c`. Large parts of the surface render as pure
`#00FF00` grass over an `#FF0000` dirt band, unpalettised primaries with individual grass tufts,
terminating at a hard vertical seam where the normal palette resumes.

    saturated-primary pixels (max>=240, min<=40, exactly one channel high), sampled every 2px:

      docs/media/baseline/_moment_line.png    6508 / 518400 = 1.26%   fresh, main @ 4e0444c
      docs/media/baseline/_moment_boot.png     108                    fresh, same commit, t=0
      docs/media/baseline/_moment_haul.png       0                    fresh, same commit, underground

    fresh `line`, by 60px row band:     y-band 9 (y 540-599) = 11416
    fresh `line`, by 160px column band: 0,1,2,3 and 6..11 — everything EXCEPT bands 4-5 (x 640-959),
                                        a ~320px window sitting just left of the body

    sampled: y=575  x=60 #ff2300   x=1700 #ff0000        (boot, same pixels: #12090a, #5e6272)
             y=570  x=60 #b6ff00   x=1700 #0dff00        (boot, same pixels: #12090c, #6a7083)

What that established: a surface strip, in pure primaries, absent at t=0 and present after the arc on the
same commit, with one narrow region near the body spared.

**The cause, found later.** The coarse terrain bake renders into a `SubViewport` that retains its render
target between updates, which is what makes a dig cost one chunk instead of the whole world. That
viewport also inherited the `WorldEnvironment`, whose adjustment pass runs as a viewport post-process, so
saturation 1.18 was re-applied to the same stored pixels on every bake and the terrain compounded
1.18^n. The fine layer covers the coarse bake everywhere except the walked surface line, which is why it
surfaced as a band across the frame where the ground meets the sky. Fixed in `deff5e7` by giving the
viewport its own `World2D`, and guarded by `tools/check_bake_idempotent.gd`.

These frames therefore record a real, since-closed defect. They are still usable as a before for
everything except surface colour, and any capture-based comparison that crosses `deff5e7` has to account
for it.

## 3. What the guidance frames show, which is P1's photographed premise

`boot`, the first frame of the game, carries seven simultaneous screen-space surfaces: the depth plate,
the two-line objective slab, the FORGED counter, the zone ceremony (title, subtitle, rule lines and a
large ghosted gear behind the sky), the aim cursor and its pointer, the held-item name plate with the
hotbar, and the bottom-left key legend. The ceremony's gear sits directly behind the tree, which is the
only vertical landmark on the surface and the object the first wood comes from.

`sapling` is the collision, and the game's own best-behaved lesson is the one that loses. The sapling
bubble draws on top of the zone ceremony's TOPSOIL title, and covers the tree the lesson is about.

`map` is T2.1's "stop the zone ceremony colliding with the map", photographed. The ceremony renders over
the open map panel, crossing its TOPSOIL band label and its `0 m` depth reading.

`line` is the worst of the four because of what it costs. The first-automation plate, "IT WORKS WITHOUT
YOU / THE LINE RUNS", which is the single biggest emotional beat the opening has, is overlapped by the
sapling bubble telling the player that wood is renewable.

The guidance is also stale in the frame that most needs it to be current. In `delve`, 15 m underground,
the objective slab still reads "Mine 4 ore — hold LMB on the metal-flecked rock by spawn", pointing the
player back to the surface they just left.

## 4. Two numbers with the same unit disagreeing in one frame

`delve`, `swing` and `map` each show `15 m THE CLAYBAND` in the top-left plate and `10 METRES DOWN / THE
CLAYBAND` in the ceremony. Both are correct, being current depth against the band's start depth, and
neither says which it is. Recorded as an observation rather than a defect. It needs a ruling, and it may
be the cheapest legibility fix on this page.

## 5. Two identical Forges in the opening frame

`boot` shows two Forges: the bootstrap forge at `(46, SURFACE)` that the player hand-feeds, and the AUTO
line's forge at `(56, SURFACE+3)` that belongs to a line they have not built. Both are seeded by design in
`scenes/main.gd`, which was checked before writing this, because the frame reads like a duplication bug
and is not one. Nothing in the frame distinguishes them: same sprite, same `FORGE` label, same arrows.
That is `PC-05`, "give installed machines a visible active/idle distinction", and the opening frame is
its strongest evidence.

## 6. What already reads well, recorded so the next pass does not break it

- The map is the most legible screen in the game. The shaft reads as a shaft, the strata read as strata,
  the water pockets and the violet seal line at 66 m are unmistakable, and the descent reads as a journey
  rather than a grid.
- `line`'s DRILL to FORGE stack is legible. The counts, the feed arrow and the lit forge say what is
  happening without a label explaining it.
- The lamp pool in `delve` is doing real work. Inside it, carved edges and floor read clearly.

## 7. The one thing every frame here agrees on

Outside the lamp, rock and void are the same near-black. In `delve` the left third of the frame cannot be
parsed into solid and empty by eye. That is `T3.1` item 6a, and it is P2's subject.

The treatment has since shipped as `scenes/rock_tooth.gdshader`, a post-veil rock tooth wired in
`scenes/world_renderer.gd`, which draws texture above the darkness veil and adds in absolute levels
rather than multiplying into the dark. These frames are therefore a genuine before, and the after belongs
beside them under a different name rather than replacing them.

## A note on the dead-space figure from this commit

`tools/check_opening.gd` scores the ground in the opening frame, and at the time these frames were taken
it was reading two things wrongly. It located the horizon with a broken projection, so it judged a band
too high and missed the deadest subsoil row entirely, and `tools/dead_space.gd` scored a tile on
horizontal neighbour differences alone, so ground that is banded horizontally and flat vertically read as
alive.

Both repairs have since merged. `check_opening` now judges from the live horizon down to the hotbar,
y 613 to 864 on the current opening, and `dead_space` averages the horizontal and vertical neighbour
differences, which its own A/B record says took `check_opening` from 1 of 32 dead tiles to 7 of 32. Any
dead-space figure quoted from this commit is a lower bound, and this page does not use one as a baseline.

The PNGs themselves are unaffected. They are pixels, and the pixels are what they are.
