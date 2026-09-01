class_name DepthChip
extends RefCounted

## THE DEPTH READOUT. Ported from `legacy/scenes/hud.gd:842-863` (`_depth_chip_w`, `_draw_depth`),
## `docs/LEGACY_GAP.md` T1 #8.
##
## Why this one first, of sixty-five HUD rows: **the whole game is descent and nothing on screen says
## how deep you are.** And the data was already all here — `MaterialLook.depth_m()` is the conversion,
## `MaterialLook.band_at()` returns the record, `data/bands/*.yaml` carries `display_name`/`from_m`/
## `color` for all eight bands, and `Observation.cell.y` is the row. Only the chip was missing.
##
## A painter in the `(frame, ci)` shape of `docs/COORDINATOR_CONTRACT.md` §2, exactly like
## `view/visuals/sky_painter.gd` — static, stateless, no coordinator reachable. It draws in SCREEN space
## rather than world space, which is not a different contract but a different canvas: its `PaintLayer`
## is parented to a `HudLayer`, and a `CanvasLayer`'s children are not moved by the camera.
##
## **`layout()` IS SPLIT OUT OF `paint()` SO THE CHIP IS ASSERTABLE.** Godot exposes no way to read back
## what a `CanvasItem` was told to draw, so a test written against `paint` alone can only check that it
## did not crash — and *not crashing is exactly what an early return does*. A painter that returned
## immediately on every frame would pass that test while the HUD stayed invisible. Splitting the
## decisions out means the test asserts the rect, the strings, the tint and the two baselines directly,
## and `paint` is left as a transcription with nothing in it that can be wrong on its own.
##
## THE NEGATIVE DEPTH IS PORTED ON PURPOSE. `depth_m` is negative above the surface datum, and legacy
## renders that as `+3 m` rather than clamping to zero: "standing on a hilltop reads as a negative depth
## rather than a clamped zero, so the number is never fudged." A clamp would make the readout lie for
## exactly the part of the world the player starts in.

const LABEL_SIZE: int = 15   ## the metres numeral
const BAND_SIZE: int = 10    ## the band name beside it, deliberately smaller: it is context, not the value
const MARGIN := Vector2(10.0, 8.0)
const CHIP_HEIGHT: float = 22.0
const PAD: float = 12.0      ## inner air, left of the numeral
const GAP: float = 10.0      ## between numeral and band name
const MIN_WIDTH: float = 96.0  ## so the chip does not breathe on every metre boundary

## Legacy's two baselines, and they are NOT the same offset. The smaller type sits a pixel higher so the
## two strings share an optical centre rather than a baseline, which is what stops the band name from
## looking like it has sunk below the number it annotates.
const LABEL_BASELINE: float = 6.0
const BAND_BASELINE: float = 5.0


## The metres label. `+N m` above the datum, `N m` at or below it -- legacy's own formatting, and the
## sign is the point rather than a decoration (see the header).
static func label_for(row: int) -> String:
	var m: int = MaterialLook.depth_m(row)
	return ("%d m" % m) if m >= 0 else ("+%d m" % -m)


## Chip width from its own contents, so a three-digit depth and a long band name both fit. Legacy's
## `maxf(lw + 10 + bw, 96) + 24`: the floor stops the chip from resizing on every metre boundary, which
## would make the corner of the screen twitch continuously during a descent.
static func width_for(font: Font, row: int, band_name: String) -> float:
	var lw: float = font.get_string_size(label_for(row), HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x
	var bw: float = font.get_string_size(band_name, HORIZONTAL_ALIGNMENT_LEFT, -1, BAND_SIZE).x
	return maxf(lw + GAP + bw, MIN_WIDTH) + PAD * 2.0


## Everything the chip decides, as data. Returns an EMPTY dictionary when it has nothing to draw, which
## is what makes "the painter drew nothing" an observable state rather than a silent one.
##
## Reads `frame.look`, never a `TileGrid`: `view/` may depend on `{interface, core}` and never on `sim`,
## so the band ladder arrives through the palette adapter the same way every material colour does.
##
## A null `look`, a null `obs` or a missing font is an empty result rather than an error. `WorldView`
## builds a frame every rendered tick and a painter must not be the thing that turns an incomplete
## startup frame into a crash -- the same rule `view/paint_layer.gd` applies to a null frame.
static func layout(frame: Frame, font: Font) -> Dictionary:
	if frame == null or frame.look == null or frame.obs == null or font == null:
		return {}
	var row: int = frame.obs.cell.y
	var band: Dictionary = frame.look.band_at(row)
	var band_name: String = String(band.get("display_name", ""))
	var label: String = label_for(row)
	var chip := Rect2(MARGIN, Vector2(width_for(font, row, band_name), CHIP_HEIGHT))
	var cy: float = chip.position.y + chip.size.y * 0.5
	var lw: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x
	return {
		"chip": chip,
		"label": label,
		"label_at": Vector2(chip.position.x + PAD, cy + LABEL_BASELINE),
		"band": band_name,
		"band_at": Vector2(chip.position.x + PAD + lw + GAP, cy + BAND_BASELINE),
		"tint": frame.look.band_color(row),
	}


## The transcription. Deliberately holds no decision of its own -- if this function ever grows a
## conditional beyond the empty-layout guard, that conditional belongs in `layout` where it can be seen.
static func paint(frame: Frame, ci: CanvasItem) -> void:
	var l: Dictionary = layout(frame, ThemeDB.fallback_font)
	if l.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	UiTheme.panel(ci, l["chip"])
	ci.draw_string(font, l["label_at"], l["label"],
		HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, UiTheme.UI_TEXT)
	ci.draw_string(font, l["band_at"], l["band"],
		HORIZONTAL_ALIGNMENT_LEFT, -1, BAND_SIZE, l["tint"])
