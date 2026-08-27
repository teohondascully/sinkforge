# Lane C: `UI01-OCCLUSION` proposal (read-only analysis, nothing applied)

Tree state at the time of writing: `git status --porcelain` empty, HEAD `defdc44`. Lane C wrote no
tracked file. No Godot process was booted for this document; every number below is either read out of
source, read out of a log already on disk, or measured off a PNG already on disk. Where a number is
derived rather than logged, it says so.

One engine run DID happen before the read-only correction arrived: the baseline
`check_hud_layout` run, which printed `check_hud_layout: PASS (114 asserted)`. That agrees with
`tools/assert_floors.txt:107` (`check_hud_layout	114	asserted`) as ratcheted by `defdc44`.

---

## 1. The mechanism, from source

Every citation below was opened and read in the working tree at `defdc44`.

### The placement is three lines of arithmetic

`scenes/hud.gd:674-680`, the whole of `hint_rect`:

```gdscript
static func hint_rect(font: Font, text: String, anchor: Vector2) -> Rect2:
	var box: Vector2 = hint_box(font, text)
	var tail: Vector2 = hint_tail(anchor)
	var origin := Vector2(clampf(tail.x - box.x * 0.5, 6.0, CANVAS.x - box.x - 6.0), tail.y - 7.0 - box.y)
	if origin.y < 38.0:
		origin.y = tail.y + 7.0
	return Rect2(origin, box)
```

with `hint_box` at `scenes/hud.gd:654-656` (size only: wrapped text width capped at `HINT_WRAP` 176 plus
16 padding, height plus 11) and `hint_tail` at `scenes/hud.gd:661-663` (the anchor clamped to
`x in [8, CANVAS.x - 8]`, `y in [60, HOTBAR_BAND_TOP - 6]`, and `HOTBAR_BAND_TOP` is
`360 - 28 - 30 - 7 = 295` from `scenes/hud.gd:26`).

So the placement has exactly **one** degree of freedom that is not the anchor: the sign of the 7px
offset. `origin.y = tail.y - 7 - box.y` puts the plate above the anchor; the single `if origin.y < 38.0`
branch flips it to `tail.y + 7` when the raised plate would climb under the objective line. There is no
term anywhere in this function that knows what is behind the plate.

`_draw_hint_bubble` (`scenes/hud.gd:683-714`) calls that same function at line 692 and derives everything
it draws from the returned rect, so the rect the measurement reads and the rect the screen shows cannot
diverge. Note lines 704 and 705: the plate is drawn as **two** `_round_rect` calls, a shadow offset
`(0, 1.5)` and the plate itself.

### The anchor is the body, not the subject

`scenes/main.gd:791-794`:

```gdscript
var anchor: Vector2 = _player.position + Vector2(0.0, -Player.HEIGHT * 0.5 - 6.0)
if _hints.active_gate() != &"":
	anchor = _cell_center(_aim) + Vector2(0.0, -float(CELL) * 0.5 - 6.0)
_hud.hint_anchor = (get_viewport().get_canvas_transform() * anchor) / HUD_SCALE
```

The comment above it (`scenes/main.gd:786-790`) is this bug's own sibling, already solved once: *"A gated
lesson points at its cell rather than at the miner. The bubble used to hang over the head whatever it was
about, so the planting lesson covered the ground it was describing and the tree beside it."* The
`wrapped` lesson has **no gate** (the logged line reports `gate=none`), so it falls through to the body
anchor and the fix that was made for gated lessons does not reach it.

### The measurement that already exists

`tools/capture_moments.gd:297-323`. The block header is verbatim *"THE OCCLUSION MEASUREMENT
(`UI01-OCCLUSION`), REPORTED AND NOT ASSERTED"*. It calls `Hud.hint_rect()` at line 306 with the live
`hint_text` and `hint_anchor`, maps each `grapple.pivots` entry through the canvas transform and
`MainView.HUD_SCALE` at line 311, tests `r.has_point(c)` at line 312, and at lines 315-316 computes the
**minimum of the four edge distances**, which is by construction the smallest push in any single
direction that would clear the plate. Nothing is refused; it `print`s at line 318.

`grapple.pivots` is `scenes/grapple.gd:229`, *"corners the line is currently caught on, anchor-first"*,
rebuilt every physics step by `update_line` (`scenes/grapple.gd:254-267`). **It is recomputed, so it
cannot be posed**; any fixture must reach a caught line by play.

### The arithmetic reproduces the logged rect exactly

Logged, real run, `scratchpad/t5.log:7`:

```
[UI01] bubble [P: (219.205, 113.939), S: (189.0, 47.0)] covers 1 of 1 pivot(s); deepest 23.3 canvas px inside (anchor (313.705, 167.939), gate=none)
```

Feeding `anchor = (313.705, 167.939)` through the source above by hand:
`tail = (313.705, 167.939)` (both clamps inactive: `167.939` is inside `[60, 289]`);
`origin.x = clampf(313.705 - 94.5, 6, 640 - 189 - 6) = 219.205`;
`origin.y = 167.939 - 7 - 47 = 113.939`; `113.939 >= 38`, so no flip. Both components match the log to
the last printed digit. The mechanism is understood, not guessed.

The brief's independently measured rect `(219.05, 113.86) 189x47`, deepest `23.4`, agrees with this run
to about 0.15 canvas px in position and 0.1 px in depth.

### Which term would have to change

`scenes/hud.gd:677`, the `y` component of `origin`, and only that. `origin.x` is already centred on the
anchor and moving it is a much larger push (below). The `if origin.y < 38.0` branch at line 678 is the
existing escape hatch and is the right place to hang a second one.

---

## 2. The visual evidence

Two captures of the `teach` moment already existed on disk, both 1920x1080, both from the real
`capture_moments` path:

- `<scratchpad>/ui01_now/_moment_teach.png` (the one `t5.log` describes, md5 `404363ab...`)
- `<scratchpad>/ui01/_moment_teach.png` (a later run into a different directory, md5 `11c13a41...`)

Canvas maps to image at exactly 3x (640 canvas -> 1920 image). I cropped `900x540+510+180`, which is
canvas `(170, 60)` to `(470, 240)`, and read both. **The crop's own mapping was checked against the
logged rect before anything was concluded from it**: the plate's four edges land at canvas
`(219.3, 114.3)` to `(407.3, 160.0)` measured off the pixels, against `(219.205, 113.939)` to
`(408.205, 160.939)` logged, so the picture and the log agree to about one canvas px.

**What I actually see, in both captures, indistinguishable from each other:**

The miner hangs near the centre of the frame with a head lamp lit and dust drifting around them. A pale
hemp-gold line, one to two canvas px wide, enters the top-left of the crop from a rock block off-frame,
runs down and to the right at roughly thirty degrees, and **disappears under the top-left corner of the
lesson plate**. It does not come out the other side. A separate, much shorter stub of the same line
re-emerges from the plate's **bottom** edge, near the body's column, and runs down at roughly fifty-three
degrees into the miner's hands.

The two visible fragments have visibly different slopes. That difference is the entire content of the
sentence printed on the plate covering them: **"THE LINE CAUGHT (em dash) it bent around the rock instead
of through it. A short line whips you round harder."** The bend itself is not in the picture. It is
behind the words.

Working the pivot's position back from the two fragments (extrapolating each to the depth the log
reports, canvas `y` about 137.3): the upper fragment continued reaches canvas `x` about 308, the lower
fragment continued back reaches about 290. So the corner sits at roughly canvas `(295, 137.3)`, which
puts it, in the crop, directly on the second line of text between "instead of" and "through it". That is
consistent with the logged depth: from the plate's left edge 76 px, from its right edge 113 px, from its
top edge 23.4 px, from its bottom edge 23.6 px, minimum 23.3, which is the number the log prints.

Two further things I saw that matter to the fix and are not in any log:

1. **The plate's tail is effectively invisible.** At 7 px of reach and 7 px of base it merges into the
   plate's own bottom edge. Nothing in the frame reads as "this plate points at that body"; the
   association is carried entirely by proximity.
2. **The gap between the plate's bottom and the miner is small**, about 7 canvas px, and the miner's
   sprite occupies roughly canvas `y` 160 to 190. That is the space a downward flip would have to land in.

---

## 3. The proposal (a sketch, NOT applied)

### The rule

> **The lesson plate may not cover a world point the lesson is about. When it would, it moves further
> away from its anchor along `y` until it is clear; if that would take it off the canvas or under the
> objective line, it takes the other side of the anchor instead.**

### Why not the flip the brief suggested

"Flips to the other side of the anchor when it would cover the world point it is anchored to" cannot
fire, because **the plate never contains its own anchor by construction**. Above the anchor,
`rect.end.y = tail.y - 7 < tail.y`; flipped below, `rect.position.y = tail.y + 7 > tail.y`. The anchor is
outside the rect on both branches. The covered point is the *pivot*, which is a different point from the
anchor, and no rule written in terms of the anchor alone can see it.

Taking the flip anyway, as a blunt instrument, is also the more expensive move in this frame: flipped,
`origin.y = 174.939`, a **61.0 px** push where **23.7 px** suffices, and it lands the plate on canvas
`y 174.9..221.9`, straight over the miner's sprite (about `y 160..190` measured off the capture) and the
dust the swing is throwing. It trades a plate over the bend for a plate over the body.

Sideways is worse. To clear a pivot at canvas `x` about 295 the plate's near edge would have to pass it;
`origin.x` clamps at `CANVAS.x - box.x - 6 = 445`, so the plate would travel 226 px and detach entirely
from the body it is talking about.

**Up is the cheapest direction and it is unobstructed here**: `rect.end.y` must rise above `137.24`, so
`origin.y` goes from `113.939` to about `89.2`, a push of `23.7` canvas px (`47.4` device px at
`HUD_SCALE` 2, `71` px in the 1920-wide capture). `89.2` is comfortably above the `38.0` guard, so the
existing fallback is not triggered and the composition is preserved.

### The diff sketch

Three files. Lane C's original ownership covered only the first; the second and third are named
explicitly so the coordinator can assign them.

**`scenes/hud.gd`** (the rule, and the tail it breaks):

```diff
+## Canvas points the plate must not print over: the world things this lesson is ABOUT. Pushed by
+## MainView beside `hint_anchor`, empty when the lesson has no world subject.
+var hint_avoid: PackedVector2Array = PackedVector2Array()
+
+## How far clear of a keep-out point the plate's edge must finish.
+const HINT_CLEAR: float = 2.0
+## The tail may reach this far and no further. See the note in `_draw_hint_bubble`.
+const HINT_TAIL_REACH: float = 9.0

-static func hint_rect(font: Font, text: String, anchor: Vector2) -> Rect2:
+static func hint_rect(font: Font, text: String, anchor: Vector2,
+		avoid: PackedVector2Array = PackedVector2Array()) -> Rect2:
 	var box: Vector2 = hint_box(font, text)
 	var tail: Vector2 = hint_tail(anchor)
 	var origin := Vector2(clampf(tail.x - box.x * 0.5, 6.0, CANVAS.x - box.x - 6.0), tail.y - 7.0 - box.y)
+	# ABOVE THE ANCHOR, LIFTED CLEAR. A keep-out point inside the plate is pushed out through the edge
+	# it is nearest, and above the anchor that edge is the bottom one: the plate rises until its lower
+	# edge sits above the highest point it was covering.
+	for p: Vector2 in avoid:
+		if Rect2(origin, box).has_point(p):
+			origin.y = minf(origin.y, p.y - box.y - HINT_CLEAR)
 	if origin.y < 38.0:
+		# No room above. Take the other side, and clear downward there for the same reason.
 		origin.y = tail.y + 7.0
+		for p: Vector2 in avoid:
+			if Rect2(origin, box).has_point(p):
+				origin.y = maxf(origin.y, p.y + HINT_CLEAR)
+		origin.y = minf(origin.y, HOTBAR_BAND_TOP - box.y)
 	return Rect2(origin, box)

 func _draw_hint_bubble() -> void:
 ...
-	var rect: Rect2 = hint_rect(_font, hint_text, hint_anchor)
+	var rect: Rect2 = hint_rect(_font, hint_text, hint_anchor, hint_avoid)
 ...
-	var tip_y: float = tail.y if origin.y < tail.y else origin.y - 1.0
+	# THE TAIL IS CAPPED, AND THE CAP IS PART OF THE FIX. Drawn to the anchor unconditionally, a lifted
+	# plate grows a 7px-wide bar 30px long down the body's column, which is exactly the column the lift
+	# was made to clear. It would re-cover the lower leg of the line the plate had just stopped
+	# covering. Reach, not destination: the plate points, and proximity carries the rest.
+	var tip_y: float = minf(tail.y, origin.y + h + HINT_TAIL_REACH) if origin.y < tail.y \
+		else maxf(tail.y, origin.y - HINT_TAIL_REACH)
```

**`scenes/main.gd`** (supply the subject, beside the anchor it already supplies at line 794):

```diff
 		_hud.hint_anchor = (get_viewport().get_canvas_transform() * anchor) / HUD_SCALE
+				# The line's corners are a subject a lesson may not print over. Same mapping as the
+				# anchor above, and only while a line is live, so a lesson on a calm screen is
+				# unaffected.
+				var avoid := PackedVector2Array()
+				if _player.grapple.state != Grapple.State.IDLE:
+					for pv: Vector2 in _player.grapple.pivots:
+						avoid.append((get_viewport().get_canvas_transform() * pv) / HUD_SCALE)
+				_hud.hint_avoid = avoid
```

**`tools/check_hud_layout.gd`** (the gate; see section 4 for its control).

### Functions the change touches

| function | file | what changes |
|---|---|---|
| `hint_rect` | `scenes/hud.gd:674` | new defaulted `avoid` parameter; two lift loops; a `HOTBAR_BAND_TOP` clamp on the flipped branch |
| `_draw_hint_bubble` | `scenes/hud.gd:683` | passes `hint_avoid`; caps `tip_y` |
| (new) `hint_avoid` field | `scenes/hud.gd`, near `hint_anchor` at line 224 | new state, pushed by MainView |
| `_update_hud` (the block at `scenes/main.gd:778-794`) | `scenes/main.gd` | pushes `hint_avoid` |
| (new) `_check_lesson_occlusion` | `tools/check_hud_layout.gd` | the gate |
| the `[UI01]` block | `tools/capture_moments.gd:297-323` | optionally promoted from `print` to a refusal |

### Deliberately NOT changed

`hint_box` and `hint_tail`. The size is not the complaint and `LESSON_MAX_H` (52.0,
`tools/check_hud_layout.gd:964`) already ratchets it downward. Nothing here raises that ceiling.

---

## 4. What could go wrong

### Who else reads `hint_rect`

`git grep hint_rect` returns exactly two call sites: `scenes/hud.gd:692` (the draw) and
`tools/capture_moments.gd:306` (the measurement). `git grep -l hint_anchor` returns exactly three files:
`scenes/hud.gd`, `scenes/main.gd`, `tools/capture_moments.gd`. No other gate reads bubble placement;
`check_hint_gate` and `check_teaching` are about arrival and readability, `check_ceremony_reads` reads
`hint_alpha` only. **The blast radius is small and known.**

### The defaulted parameter is itself a hazard

`avoid: PackedVector2Array = PackedVector2Array()` keeps `capture_moments.gd:306` compiling unchanged,
which is convenient and is also exactly how this repo's house failure arrives: a guard that cannot be
false at any call site that forgets to pass the argument. **`capture_moments.gd:306` would then be
measuring the UNFIXED placement while the screen shows the fixed one**, and the `[UI01]` line would keep
reporting `covers 1 of 1` after a correct fix. It must be updated in the same commit, or the parameter
must be made required and both call sites changed. This is the single most likely way to ship a fix that
looks broken, or to ship a broken fix that looks fine.

### Can the lift push the plate off-canvas or onto another panel

- **Off the top.** The `if origin.y < 38.0` guard already exists and the lift runs before it, so a lift
  that overshoots falls into the flip. That is correct behaviour, not a bug, but the flipped branch then
  needs its own clear-downward pass and a `HOTBAR_BAND_TOP` clamp, which is why the sketch adds both. A
  flipped 47px plate at `tail.y + 7` with `tail.y` at its clamp ceiling of 289 would otherwise reach
  `y = 343`, straight through the hotbar.
- **Into the PAUSED chip.** `PAUSED_CHIP` is `Rect2(10.0, 60.0, 104.0, 22.0)` (`scenes/hud.gd:493`), so
  `x 10..114`. The plate in this frame spans `x 219..408` and never reaches it. A body far enough left to
  bring the plate into that column is possible in principle; it is not reachable in the `teach` moment.
- **Into the arrival ceremony's strip.** The scrim core sits at `CANVAS.y * 0.26 - SCRIM_ABOVE` to about
  `y 111.6` (`scenes/hud.gd:302-305`, `SCRIM_ABOVE` 32.0 at line 841). A plate lifted to `y 89.2` reaches
  into that band. **Today this cannot collide**, because `Hints.active_alpha()` returns a flat 0.0 while
  `_ceremony` is set (`scenes/hints.gd:264`), so a ceremony and a lesson are mutually exclusive in time.
  That mutual exclusion becomes load-bearing for layout the moment this lift ships, and it is currently
  written down nowhere as a layout constraint. **Worth a comment at the lift site.**
- **Onto the world's other content.** The lift trades a plate over the pivot for a plate over whatever is
  23.7 px higher. In the `teach` capture that region is empty dark rock and a few motes. It is not
  guaranteed to be empty in general, and no rule proposed here can promise it. This is a real limit of
  the proposal and should be stated in the commit rather than discovered later.

### The tail, which is the non-obvious one

Covered in the sketch: with `tip_y = tail.y` unchanged, lifting the plate 23.7 px makes the tail
triangle 30.7 px long and 7 px wide at its base, drawn in `UI_BG` at the plate's own alpha
(`scenes/hud.gd:708-712`), centred at `tx = clampf(tail.x, ...) = 313.705`. The lower leg of the grapple
line runs from about canvas `(295, 137)` down to the body at `(313.7, 168)`. **That is the same column.**
The lift would reveal the bend and the lengthened tail would immediately re-cover the segment below it.
A geometry-only pass would score this as fixed. Only looking at the picture catches it.

### Which `check_hud_layout` states need a new row

**None, and adding one would be a mistake.** Reading the matrix at `tools/check_hud_layout.gd:93-152`:
all sixteen rows set MainView flags (`_paused`, `_minimap_mode`, `_inventory_open`, ...) and **not one of
them arms `_hints`**, so no matrix row has ever raised a lesson plate. `_check_lesson_footprint`
(`tools/check_hud_layout.gd:967-1006`) measures `Hud.hint_box` sizes from the definition tables and never
places anything. **Bubble placement has zero coverage in this layer today.**

A new matrix row would also fail for a reason that has nothing to do with this bug: `_draw_hint_bubble`
registers **two** probe rects, the shadow at `scenes/hud.gd:704` and the plate at `705`, both via
`_round_rect`, which appends to `panel_probe` at `scenes/hud.gd:1653-1654`. They are 189x47 and offset by
1.5 px, so they overlap by 189x45.5. `MIN_PANEL` is 6.0 and `TOUCH` is 1.5
(`tools/check_hud_layout.gd:43,45`), so a non-modal row with a bubble up would report the plate colliding
with **its own shadow**. That is an instrument artefact, and loosening the overlap test to swallow it
would blind the layer to real collisions.

So the gate should be a **standalone function**, not a matrix row: `_check_lesson_occlusion()`, driving a
real caught line and comparing `Hud.hint_rect(...)` against live `grapple.pivots`, exactly the two
quantities `capture_moments.gd:303-317` already reads.

### The positive control

**The assertion must be seen RED on the current tree before any fix is applied.** Three things about it:

1. **It already is red, and there is a log.** `scratchpad/t5.log:7` reports `covers 1 of 1 pivot(s)` on
   the real `teach` path. The cheapest control available is to promote `tools/capture_moments.gd:318`
   from `print` to `wrong.append(...)` and run `teach`: the shutter refuses, in the same voice as the
   existing sapling guard. This costs one line and needs no new fixture.
2. **The gate must not pass by absence.** Every early exit in the sketch above returns "not covered".
   `covered == 0` is the passing value when the lesson never came up, when the line never caught, and
   when the font is null. The assertion is therefore **four** `_check` calls, not one:
   - there is at least one pivot (`p.grapple.pivots.size() >= 1`), so there is a bend to cover;
   - the lesson is on screen (`hint_text != ""` and `hints.active_alpha() > 0.9`);
   - the rect is non-degenerate;
   - and only then: no pivot is inside it, printing the depth in canvas px when it is.
3. **The control should travel inside the run**, following the house pattern already in this repo:
   `SF_MOMENT_MUTANT=nosapling` / `nowrap` (`tools/capture_moments.gd:857, 883, 1033`). An
   `SF_HINT_NO_AVOID=1` mutant that makes `_draw_hint_bubble` pass an empty `avoid` reproduces the
   pre-fix placement inside a fixed tree, so the gate can be shown to fail on demand forever, not just
   once on the day it was written. An env switch rather than a hand-edit for the reason
   `capture_moments.gd:858-861` gives: a commented-out line is live for every run that follows.

**The fixture cannot pose its subject.** `grapple.pivots` is rebuilt every physics step
(`scenes/grapple.gd:254-267`), so writing it does nothing. The state has to be reached by play, the way
`_teaching` does it (`tools/capture_moments.gd:961-1024`), which costs up to `CATCH_FRAMES` 420 plus
`READY_MAX` 600 frames. Against a `SETTLE` of 6 in `check_hud_layout`, that is a large addition to the
layer's runtime and the coordinator should decide whether the gate belongs here or in
`check_grapple_reads` / `check_teaching`, which already boot a swinging body.

---

## 5. Acceptance contract

Nothing ships until all of the following have been done and quoted.

**Before the fix**

1. `check_hud_layout` baseline re-measured on the tree the fix will land on, and the number quoted. It
   was `PASS (114 asserted)` at `defdc44`, matching `tools/assert_floors.txt:107`.
2. The new assertion added **first**, and its failure quoted verbatim, naming the depth in canvas px.
   An assertion that has never been seen to fail is not evidence. If it cannot be made to fail, stop.

**The change**

3. One bounded change, all three files in one commit, `capture_moments.gd:306` updated in the same
   commit so the measurement and the screen cannot disagree.
4. `godot --check-only` output **grepped for `parse error`**, never trusted by exit code.
5. `bash tools/check_prose.sh` says `PASS (446 asserted)`. Every new comment in `scenes/` carries zero
   em-dashes, no dates, no ticket ids, no markdown emphasis. (The two new comment blocks sketched above
   are written to that rule already.)

**After the fix**

6. `check_hud_layout` green at the new, higher count, and `tools/assert_floors.txt:107` ratcheted to it.
   The gate proven to still bite by setting the row one HIGHER and seeing it FAIL, then restoring.
7. The `[UI01]` line from a real `teach` run quoted, reporting `covers 0 of N pivot(s)`.
8. The mutant control run: with `SF_HINT_NO_AVOID=1` the same gate goes RED and names the depth.
9. `check_grapple_reads` still red on `GR-06` only, and on nothing else. That red is a director-owned
   design call and is not evidence about this change.

**The captures, which are the part that cannot be skipped**

10. A **matched** before/after `_moment_teach.png` pair from ONE rig whose only difference is the change:
    capture, revert with a script, capture, restore, and `cmp` the restored files byte-for-byte against
    the committed versions.
11. **Both PNGs looked at**, and the following answered in words rather than in geometry:
    - Is the **bend** visible, as a corner, with line on both sides of it?
    - Does the **tail** now print down the body's column over the lower leg of the line? (This is the
      failure the geometry cannot see. See section 4.)
    - Does the plate now sit on anything else, in the band it moved into?
    - Does the plate still read as belonging to the body, with the tail capped?

    A geometry-only claim that the frame is fine does not satisfy this item.

---

## Disposition

**DEFER to the coordinator for assignment, then SHIP.** The mechanism is fully understood and verified
against a logged run to the last printed digit, the minimum push is measured at 23.7 canvas px upward,
and the change is small. It is deferred only because the correct fix touches `scenes/main.gd` and
`tools/capture_moments.gd`, neither of which is Lane C's to write, and because splitting it across lanes
would put the placement and the measurement of that placement in two different commits, which is the one
arrangement guaranteed to produce a green that means nothing.
