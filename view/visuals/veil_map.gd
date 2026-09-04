class_name VeilMap
extends RefCounted

## THE LIGHTMAP. One texel per METRE, stretched over the window with LINEAR filtering and composited as a
## MULTIPLY, replacing a `draw_rect` per visible cell. Ported from `legacy/scenes/world_renderer.gd:330`:
##
##   > "The lightmap veil. The darkness is a small texture, one texel per cell, stretched over the whole
##   > world with LINEAR filtering so light grades smoothly in every direction instead of stepping cell to
##   > cell."
##
## **THIS IS THE 120 Hz FIX, AND IT WAS MEASURED BEFORE IT WAS WRITTEN.** `VeilPainter._paint_with` issued
## one `ci.draw_rect` per visible cell: at the 40-metre framing that is a 160x88 draw rect, **14,080 draw
## calls a frame**, and `WorldView.draw_cost_report` attributed **41.47 ms of a 54.23 ms frame** to this
## one painter against a 120 Hz budget of 8.33 ms. Legacy issues exactly ONE `draw_texture_rect`
## (`world_renderer.gd:2769`) and its veil costs are invariant to zoom.
##
## **ONE TEXEL PER METRE, NOT PER TERRAIN CELL, AND THAT IS THE WHOLE REGIME QUESTION** (D0305/D0310).
## Legacy's "one texel per cell" is one texel per METRE, because legacy's cell WAS a metre — 32 px, and
## its veil was 128x128 for a 128-metre world. This build's terrain cell is a QUARTER metre, so reading
## "cell" literally would give 16x the texels for the same picture and re-import legacy's constant into a
## regime it does not belong to. At one texel per metre the on-screen texel density matches legacy's
## exactly: legacy 32 px/m at zoom 1.0, here 16 px/m at zoom 2.0, both 32 screen px per texel.
##
## **WHY MULTIPLY RATHER THAN AN ALPHA WASH**, legacy `world_renderer.gd:80`:
##
##   > "Because it multiplies, a cell keeps its own hue and its own relative contrast for free: dark brown
##   > topsoil stays brown, dark grey stone stays grey, and the bedding, fissures and carved edges painted
##   > into the rock survive as structure rather than being averaged under a haze."
##
## **WHAT THIS DELIBERATELY DOES NOT PORT YET.** Legacy splits the field into a cached `_veil_base`
## (skylight and burial, re-baked only on terrain change) and a per-frame `duplicate()` into which the
## lamp cuts holes bounded by its own radius. That split matters when the map is the whole world's 16,384
## texels; here the map is the WINDOW's ~1,200, so a full evaluation per frame is already cheaper than
## legacy's memcpy-plus-cut path and the extra state would buy nothing measurable. `VeilPainter`'s
## existing `field_for` cache still spares the expensive part — the two blur passes behind `openness`.
## If the map ever covers the world rather than the window, port the base/scratch split with it.

## Texels per metre. One, and it is not a tuning knob: see the regime paragraph above.
const TEXELS_PER_METRE: int = 1

## Terrain cells per texel — the sampling stride, derived so a change to the grid moves it rather than
## silently desynchronising this file from `MaterialLook`.
const CELLS_PER_TEXEL: int = MaterialLook.CELLS_PER_METRE / TEXELS_PER_METRE

var _img: Image = null
var _tex: ImageTexture = null
var _bytes: PackedByteArray = PackedByteArray()
var _w: int = 0
var _h: int = 0
var _origin: Vector2i = Vector2i.ZERO   ## the terrain cell that texel (0,0) samples


## Rebuilds the map for this observation and returns the texture, or `null` when the window is degenerate
## (which a caller must treat as "draw nothing", never as "draw black").
##
## `shade` is called as `shade.call(col, row) -> float`: the composed light level for a terrain cell, 0
## fully dark and 1 fully lit. Passed in rather than computed here so this file owns the TEXTURE and
## `VeilPainter` keeps owning the light model — the same split as legacy's `_update_veil` (the model)
## against `_paint_darkness` (the one draw call).
func build(window: Rect2i, shade: Callable) -> ImageTexture:
	# One texel per metre, rounded UP so the map always covers the whole window: rounding down would
	# leave the right and bottom edges of the window sampling past the texture and clamping to its last
	# texel, which reads as a bar of stale light exactly at the screen edge.
	var w: int = int(ceil(float(window.size.x) / float(CELLS_PER_TEXEL)))
	var h: int = int(ceil(float(window.size.y) / float(CELLS_PER_TEXEL)))
	if w <= 0 or h <= 0:
		return null
	_origin = window.position
	if _img == null or _w != w or _h != h:
		_w = w
		_h = h
		_bytes.resize(w * h * 4)
		_img = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
		_tex = ImageTexture.create_from_image(_img)
	_fill(shade)
	# `set_data` + `update` mutate the texture IN PLACE, which is what lets the consumer's retained
	# `draw_texture_rect` command show new content without being re-queued (legacy `world_renderer.gd:526`:
	# "the veil's one draw command ... content updates via the texture").
	_img.set_data(_w, _h, false, Image.FORMAT_RGBA8, _bytes)
	_tex.update(_img)
	return _tex


## Writes one texel per metre, sampling the light model at the CENTRE cell of each texel rather than its
## corner. A corner sample biases the whole map half a metre up-left, which at the surface puts the
## skylight gradient's edge visibly off the ground line it belongs to.
func _fill(shade: Callable) -> void:
	var half: int = CELLS_PER_TEXEL / 2
	for j: int in _h:
		var row: int = _origin.y + j * CELLS_PER_TEXEL + half
		for i: int in _w:
			var col: int = _origin.x + i * CELLS_PER_TEXEL + half
			# CLAMPED TO 1.0 BECAUSE A MULTIPLY CANNOT BRIGHTEN. The light model can return above 1.0
			# where `KEY_STRENGTH` lifts fully up-facing mass, and the old per-cell path drew that as an
			# additive white rect. Legacy carries the same split and answers it with a SECOND canvas —
			# `_dark` multiplies at z 50, `_lights` ADDS at z 51 — rather than by letting one pass do
			# both. Until that additive layer is ported the lift is clamped, which keeps every darkening
			# cue exact and loses only the above-ambient half of the key. Recorded rather than silent.
			var lit: Variant = shade.call(col, row)
			var at: int = (j * _w + i) * 4
			# Opaque: under a multiply the RGB IS the light level and the alpha must not attenuate it. A
			# texel of (v, v, v, v) would multiply the destination by v twice on a premultiplied path and
			# darken the world quadratically. Grey for a float, tinted for a Color (6l (ii), D0375):
			# legacy's cuts lift each channel toward the source's tint, so lamp-lit rock comes out amber.
			if lit is Color:
				var c: Color = lit
				_bytes[at] = int(round(clampf(c.r, 0.0, 1.0) * 255.0))
				_bytes[at + 1] = int(round(clampf(c.g, 0.0, 1.0) * 255.0))
				_bytes[at + 2] = int(round(clampf(c.b, 0.0, 1.0) * 255.0))
			else:
				var v: int = int(round(clampf(float(lit), 0.0, 1.0) * 255.0))
				_bytes[at] = v
				_bytes[at + 1] = v
				_bytes[at + 2] = v
			_bytes[at + 3] = 255


## The world-pixel rect the texture must be stretched over: exactly the cells the map sampled, so the
## texel grid lands on the metre grid. Derived from the same `_w`/`_h` the fill used rather than from the
## window, because the ceil above can make the map wider than the window and stretching it to the window
## would shear the whole gradient by up to one metre.
func world_rect(cell_px: int) -> Rect2:
	return Rect2(
		float(_origin.x * cell_px), float(_origin.y * cell_px),
		float(_w * CELLS_PER_TEXEL * cell_px), float(_h * CELLS_PER_TEXEL * cell_px))


## Texel dimensions, for a test that needs to assert the map is at METRE resolution rather than cell
## resolution — the one property that separates this port from a 16x-too-expensive reading of legacy.
func size() -> Vector2i:
	return Vector2i(_w, _h)


## THE LIGHT LEVEL THIS MAP ACTUALLY WROTE at one texel, 0..1. Exists so a test can read the map's OWN
## output rather than recomputing what it should have been — the first version of `tests/test_veil_map.gd`
## derived its "got" from its "want" and therefore compared a value to a quantised copy of itself, which
## is true whatever `_fill` does. A corner-sample mutant passed it. Reading the bytes back is what makes
## the assertion able to fail.
func texel(i: int, j: int) -> float:
	if i < 0 or j < 0 or i >= _w or j >= _h:
		return -1.0   ## out of range is distinguishable from every real level, which are all in [0, 1]
	return float(_bytes[(j * _w + i) * 4]) / 255.0


## The three channels of one texel, for a test that has to see the tint (D0375) -- `get_image()` on the
## texture reads back nothing under the headless renderer, exactly as `texel()` above records.
func texel_rgb(i: int, j: int) -> Color:
	var at: int = (j * _w + i) * 4
	if at < 0 or at + 3 >= _bytes.size():
		return Color(0.0, 0.0, 0.0, 0.0)
	return Color(float(_bytes[at]) / 255.0, float(_bytes[at + 1]) / 255.0, float(_bytes[at + 2]) / 255.0, float(_bytes[at + 3]) / 255.0)
