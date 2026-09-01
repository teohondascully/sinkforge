extends "res://tests/test_base.gd"

## The HUD host (`view/hud/hud_layer.gd`) and its first chip (`view/hud/depth_chip.gd`), D0271.
##
## THE WHOLE CHIP IS ASSERTED WITHOUT A SCENE, and that is a property of how `DepthChip` is written
## rather than a trick played here. Godot exposes no way to read back what a `CanvasItem` was told to
## draw, so a suite written against `paint` could only assert "it did not crash" -- which is exactly
## what a broken early return does, while the HUD stays invisible. `label_for`, `width_for` and
## `layout` hold every decision the chip makes and return them as data; `paint` is left as a
## transcription with nothing in it that can be wrong on its own.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_hud.gd

func _initialize() -> void:
	_test_depth_label_signs_the_number_rather_than_clamping_it()
	_test_every_band_in_the_ladder_is_reachable_and_named()
	_test_the_chip_width_grows_with_its_contents_and_has_a_floor()
	_test_the_chip_lays_itself_out_where_legacy_put_it()
	_test_an_incomplete_frame_paints_nothing_rather_than_crashing()
	_test_the_host_puts_its_chips_above_the_world()
	_test_the_authoring_canvas_is_the_canvas_that_is_actually_drawn_into()
	_finish("hud")


## D0290. `UiTheme.CANVAS` said 640x360 while `project.godot`'s base viewport was 1280x720 — a HUD laid
## out for half the canvas it draws into. **Nothing caught it for two commits**, because the only chip
## that existed anchors to the TOP-LEFT, where the two canvases agree exactly; the first thing to CENTRE
## itself landed a quarter of the way across the screen.
##
## So the constant is read back from the project rather than trusted, and the two are compared. A HUD
## constant that names the viewport is the same shape as `docs/LEGACY_GAP.md`'s WG-4 — a number authored
## against one denomination and used against another — and it fails the same silent way.
func _test_the_authoring_canvas_is_the_canvas_that_is_actually_drawn_into() -> void:
	var w: int = ProjectSettings.get_setting("display/window/size/viewport_width", 0)
	var h: int = ProjectSettings.get_setting("display/window/size/viewport_height", 0)
	_check(w > 0 and h > 0, "sanity: the project declares a base viewport (%dx%d)" % [w, h])
	_check(UiTheme.CANVAS == Vector2(w, h),
		"UiTheme.CANVAS (%s) is the project's base viewport (%dx%d) -- `stretch/mode=canvas_items` means "
		% [UiTheme.CANVAS, w, h] + "a CanvasLayer child draws into exactly that many pixels")
	# The scale carrying legacy's numbers across is DERIVED from the two canvases, not written down.
	_check(is_equal_approx(UiTheme.UI_SCALE, UiTheme.CANVAS.x / UiTheme.AUTHORED.x),
		"and UI_SCALE (%.3f) is the ratio of the two canvases (%.3f)"
		% [UiTheme.UI_SCALE, UiTheme.CANVAS.x / UiTheme.AUTHORED.x])
	# ONE factor is only honest if the two canvases share an aspect. If they ever stop, a single scale
	# silently stretches every ported layout on one axis.
	_check(is_equal_approx(UiTheme.CANVAS.x / UiTheme.CANVAS.y,
			UiTheme.AUTHORED.x / UiTheme.AUTHORED.y),
		"and the two canvases share an aspect (%.4f vs %.4f), which is what makes ONE scale factor "
		% [UiTheme.CANVAS.x / UiTheme.CANVAS.y, UiTheme.AUTHORED.x / UiTheme.AUTHORED.y]
		+ "correct rather than an approximation")
	_check(UiTheme.pt(15) == 30 and is_equal_approx(UiTheme.px(10.0), 20.0),
		"CONTROL: the two converters actually convert (pt(15)=%d, px(10)=%.1f) -- an identity scale would "
		% [UiTheme.pt(15), UiTheme.px(10.0)] + "satisfy every row above")


## THE ONE BEHAVIOUR MOST LIKELY TO BE "FIXED" INTO A BUG. `depth_m` is negative above the surface
## datum and legacy renders that as `+3 m` rather than clamping to zero, deliberately: a clamp makes the
## readout lie for exactly the part of the world the player starts in. Asserted on both sides of the
## datum AND at zero, because a clamp and the correct code agree everywhere except above it.
func _test_depth_label_signs_the_number_rather_than_clamping_it() -> void:
	var per_m: int = MaterialLook.CELLS_PER_METRE
	# Rows are keyed to the SURFACE, which is `MaterialLook.SURFACE_ROW` and not row 0 since P017 (D0292).
	# Written as offsets from the datum rather than as absolute rows, so this asserts the FORMATTING and
	# the sign, which is what it is about, instead of where the world happens to put its surface.
	var datum: int = MaterialLook.SURFACE_ROW
	var cases: Array = [
		{"row": datum, "want": "0 m"},
		{"row": datum + per_m * 5, "want": "5 m"},
		{"row": datum + per_m * 137, "want": "137 m"},
		{"row": datum - per_m * 3, "want": "+3 m"},
		# And row 0 itself, which is now real sky rather than a hypothetical: the `+N m` branch D0271
		# ported "on purpose" had never once run against a generated world before P017.
		{"row": 0, "want": "+%d m" % (datum / per_m)},
	]
	for c: Dictionary in cases:
		var got: String = DepthChip.label_for(c["row"])
		_check(got == c["want"], "label_for(row %d) = %s (want %s)" % [c["row"], got, c["want"]])


## POPULATION CHECK. The chip prints whatever `band_at` returns, so a band whose record is missing a
## `display_name` -- or a ladder that silently collapses to one entry -- would show as a blank word
## beside the number and nothing would fail. This walks the whole authored ladder by its own `from_m`
## values rather than by a list written here, and asserts every band is BOTH reachable at some depth AND
## carries a name, so the set of bands the ladder can actually emit is the set that gets checked.
func _test_every_band_in_the_ladder_is_reachable_and_named() -> void:
	var look := MaterialLook.new()
	var seen: Dictionary = {}
	var blank: Array[String] = []
	var deepest_m: int = 260  ## this world runs to 256 m; legacy's own ladder stops at 66
	for m: int in range(-4, deepest_m):
		var row: int = m * MaterialLook.CELLS_PER_METRE
		var band: Dictionary = look.band_at(row)
		var name_text: String = String(band.get("display_name", ""))
		seen[String(band.get("id", "?"))] = true
		if name_text.strip_edges().is_empty():
			blank.append("row %d -> %s" % [row, band.get("id", "?")])
	_check(seen.size() >= 2,
		"sanity: the ladder is not one band answering every depth (%d distinct: %s)"
		% [seen.size(), seen.keys()])
	_check(seen.size() == BandsRecords.RECORDS.size(),
		"every authored band is reachable at some depth (%d of %d emitted; missing %s)"
		% [seen.size(), BandsRecords.RECORDS.size(),
		BandsRecords.RECORDS.keys().filter(func(k: String) -> bool: return not seen.has(k))])
	_check_over(seen.size(), blank.is_empty(),
		"every band the ladder emits carries a display_name (%d blank: %s)" % [blank.size(), blank])
	var tint: Color = look.band_color(0)
	_check(tint.a > 0.0, "band_color returns a usable colour rather than a transparent default (%s)" % tint)


## The floor is what stops the chip resizing on every metre boundary, so it is asserted as a floor and
## not merely as "some width": a chip that always returned its contents' width would twitch continuously
## during a descent, and that is a look bug no screenshot diff would attribute correctly.
func _test_the_chip_width_grows_with_its_contents_and_has_a_floor() -> void:
	var font: Font = ThemeDB.fallback_font
	_check(font != null, "sanity: a fallback font exists -- every assertion below measures with it")
	if font == null:
		return
	var narrow: float = DepthChip.width_for(font, 0, "")
	var wide: float = DepthChip.width_for(font, 999 * MaterialLook.CELLS_PER_METRE, "THE VERY LONG DARK")
	# The floor is a legacy-authored number, so it is compared through the same converter the chip uses
	# (D0290) -- restating it raw here would assert the authoring canvas rather than ours.
	_check(is_equal_approx(narrow, UiTheme.px(DepthChip.MIN_WIDTH) + UiTheme.px(DepthChip.PAD) * 2.0),
		"an empty chip sits exactly on the floor (%.1f vs %.1f)"
		% [narrow, UiTheme.px(DepthChip.MIN_WIDTH) + UiTheme.px(DepthChip.PAD) * 2.0])
	_check(wide > narrow,
		"a long band name and a three-digit depth widen it past the floor (%.1f vs %.1f)" % [wide, narrow])


## `paint` CANNOT be checked by calling it -- Godot exposes no way to read back a `CanvasItem`'s draw
## commands, so "it did not crash" is all such a test could assert, and not crashing is exactly what a
## broken early return does. `layout()` exists so this is assertable instead: every decision the chip
## makes is checked here as data, and the empty-layout cases are checked as EMPTY rather than as
## "returned without error", which is the difference between observing a no-op and assuming one.
func _test_the_chip_lays_itself_out_where_legacy_put_it() -> void:
	var font: Font = ThemeDB.fallback_font
	var frame := Frame.new()
	frame.look = MaterialLook.new()
	frame.obs = Interface.Observation.new()
	frame.obs.cell = Vector2i(4, MaterialLook.SURFACE_ROW + 12 * MaterialLook.CELLS_PER_METRE)
	var l: Dictionary = DepthChip.layout(frame, font)
	_check(not l.is_empty(), "a complete frame produces a layout (got %s)" % l)
	if l.is_empty():
		return
	var chip: Rect2 = l["chip"]
	_check(chip.position.is_equal_approx(DepthChip.MARGIN * UiTheme.UI_SCALE),
		"the chip sits at legacy's own top-left margin, carried onto our canvas (%s vs %s)"
		% [chip.position, DepthChip.MARGIN * UiTheme.UI_SCALE])
	_check(l["label"] == "12 m", "it reads the body's own row as depth (got %s)" % l["label"])
	_check(String(l["band"]).strip_edges() != "",
		"and names the band it is in (got %s)" % l["band"])
	_check(l["label_at"].x < l["band_at"].x,
		"the band name sits to the RIGHT of the numeral (%.1f vs %.1f)" % [l["label_at"].x, l["band_at"].x])
	_check(l["band_at"].y < l["label_at"].y,
		"the smaller type sits a pixel HIGHER, sharing an optical centre rather than a baseline (%.1f vs %.1f)"
		% [l["band_at"].y, l["label_at"].y])
	_check(l["band_at"].x + 1.0 < chip.position.x + chip.size.x,
		"and both strings fit inside the chip they are drawn on (%.1f vs %.1f)"
		% [l["band_at"].x, chip.position.x + chip.size.x])


## Every incomplete frame must produce an EMPTY layout, not a partial one. Each case is a real state a
## startup frame passes through, and the sanity row above them proves the same call is non-empty when
## nothing is missing -- without it, a `layout` that returned `{}` unconditionally would pass all four.
func _test_an_incomplete_frame_paints_nothing_rather_than_crashing() -> void:
	var font: Font = ThemeDB.fallback_font
	var complete := Frame.new()
	complete.look = MaterialLook.new()
	complete.obs = Interface.Observation.new()
	var no_look := Frame.new()
	no_look.obs = Interface.Observation.new()
	var no_obs := Frame.new()
	no_obs.look = MaterialLook.new()
	var cases: Array = [
		{"name": "no palette", "frame": no_look, "font": font},
		{"name": "no observation", "frame": no_obs, "font": font},
		{"name": "no font", "frame": complete, "font": null},
		{"name": "no frame at all", "frame": null, "font": font},
	]
	_check(not DepthChip.layout(complete, font).is_empty(),
		"CONTROL: the same call with nothing missing is NOT empty -- without this every row below "
		+ "passes on a layout() that returns {} unconditionally")
	for c: Dictionary in cases:
		var l: Dictionary = DepthChip.layout(c["frame"], c["font"])
		_check(l.is_empty(), "%s -> empty layout (got %s)" % [c["name"], l])


## The host's one structural claim: its chips are on a canvas layer ABOVE the world's default 0, so the
## HUD is not painted under the terrain. Asserted as an inequality against the world's own layer rather
## than as "== 10", so moving the world would break this rather than silently invert the two.
func _test_the_host_puts_its_chips_above_the_world() -> void:
	var hud := HudLayer.new()
	hud.setup(null)
	_check(hud.layer > 0, "the HUD sits above the default (0) canvas layer the world draws on (got %d)" % hud.layer)
	_check(hud.chip_count() == 0, "a fresh host holds no chips (got %d)" % hud.chip_count())
	var added: PaintLayer = hud.add_chip(DepthChip.paint)
	_check(added != null and hud.chip_count() == 1,
		"add_chip returns its canvas and the host counts it (%d)" % hud.chip_count())
	_check(added.get_parent() == hud,
		"the chip's canvas is parented to the HUD layer -- this is what makes it screen-space rather than world-space")
	hud.free()
