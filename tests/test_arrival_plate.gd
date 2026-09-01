extends "res://tests/test_base.gd"

## `view/hud/arrival_plate.gd` — the stratum arrival ceremony (D0288, LEGACY_GAP T1 #8).
##
## Like `tests/test_crumble_painter.gd`, this is about LIFECYCLE rather than geometry, because the plate
## is the second thing in the build that keeps state across ticks: does it fire on the band CHANGING and
## not on the draw happening, does it stay silent for the band the player spawned in, does it expire, and
## does its fade actually go up and then down rather than one of the two.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_arrival_plate.gd

const CELLS_PER_M: int = MaterialLook.CELLS_PER_METRE


func _initialize() -> void:
	_test_the_band_the_player_spawned_in_is_not_announced()
	_test_crossing_a_boundary_fires_once_and_a_redraw_does_not_refire_it()
	_test_the_ceremony_expires()
	_test_the_fade_rises_then_falls_and_is_never_negative()
	_test_the_words_are_tracked_apart_and_the_plate_is_centred_on_them()
	_test_an_incomplete_frame_decides_nothing()
	_finish("arrival_plate")


## A frame with the body at `row`, at clock time `now`.
func _frame(row: int, now: float) -> Frame:
	var f := Frame.new()
	f.obs = Interface.Observation.new()
	f.obs.cell = Vector2i(0, row)
	f.look = MaterialLook.new()
	f.anim_time = now
	return f


## Two rows in different bands, found by walking the ladder rather than by writing depths down: the band
## table lives in `data/bands/*.yaml` and a test that hardcoded two metres would break every time an
## authored boundary moved, for a reason that has nothing to do with this plate.
func _two_bands() -> Array[int]:
	var look := MaterialLook.new()
	var first: String = String(look.band_at(0).get("display_name", ""))
	for row: int in range(1, 400 * CELLS_PER_M):
		if String(look.band_at(row).get("display_name", "")) != first:
			return [0, row] as Array[int]
	return [] as Array[int]


## The plate must not fire for the band the player is standing in when the session opens: every run would
## begin by announcing where you already are.
func _test_the_band_the_player_spawned_in_is_not_announced() -> void:
	var p := ArrivalPlate.new()
	_check(not p.note_frame(_frame(0, 0.0)),
		"the first band seen fires nothing -- it is recorded, not announced")
	_check(not p.on_screen(_frame(0, 0.0)), "and nothing is on screen for it")
	for _i: int in 5:
		_check(not p.note_frame(_frame(0, 0.0)),
			"and staying in that band goes on firing nothing")


## THE GUARD THAT MAKES FIRE-FROM-THE-FRAME SAFE, and the same one `CrumblePainter` needs: Godot redraws
## a canvas for reasons the coordinator did not initiate, and each of those hands the plate the same
## observation again. Without the band guard every resize would re-run a ceremony the player already
## watched.
func _test_crossing_a_boundary_fires_once_and_a_redraw_does_not_refire_it() -> void:
	var rows: Array[int] = _two_bands()
	_check(rows.size() == 2, "sanity: the band ladder has at least two bands in it (%s)" % [rows])
	if rows.size() != 2:
		return
	var p := ArrivalPlate.new()
	p.note_frame(_frame(rows[0], 0.0))
	_check(p.note_frame(_frame(rows[1], 1.0)), "crossing into a new band fires the ceremony")
	# NOT on screen on the firing tick itself, and that is the fade rather than a bug: legacy's alpha is
	# `min((1-t)*6, t*2.4)` and `t` is 1.0 at the instant of firing, so the plate begins at zero opacity
	# and rises. Worth an assertion because `on_screen` reads exactly what `layout` returns on -- legacy's
	# own bug at this spot was a caller reading "an announcement is still owed" as "a plate is visible".
	_check(not p.on_screen(_frame(rows[1], 1.0)),
		"on the firing tick it is transparent -- the ceremony fades IN from nothing")
	_check(p.on_screen(_frame(rows[1], 1.0 + ArrivalPlate.HOLD * 0.25)),
		"and a quarter of its life later it is on screen")
	for _i: int in 5:
		_check(not p.note_frame(_frame(rows[1], 1.0)),
			"five more draws of the same band fire nothing further")
	# CONTROL: the guard must not be so wide that it blocks a REAL later crossing. Without this row the
	# one above passes on a plate that fires exactly once and never again.
	_check(p.note_frame(_frame(rows[0], 2.0)),
		"CONTROL: crossing BACK still fires -- the guard is on the band changing, not on having fired")


## A ceremony that never expired would sit over the world for the rest of the session.
func _test_the_ceremony_expires() -> void:
	var rows: Array[int] = _two_bands()
	if rows.size() != 2:
		return
	var p := ArrivalPlate.new()
	p.note_frame(_frame(rows[0], 0.0))
	p.note_frame(_frame(rows[1], 0.0))
	_check(p.on_screen(_frame(rows[1], ArrivalPlate.HOLD * 0.5)),
		"halfway through its life the plate is still up")
	_check(not p.on_screen(_frame(rows[1], ArrivalPlate.HOLD + 0.01)),
		"and past its hold it is gone")
	_check(not p.on_screen(_frame(rows[1], ArrivalPlate.HOLD * 40.0)),
		"and stays gone rather than reappearing on a clock that wrapped")


## Legacy's fade is fast in, slow out, and BOTH halves have to be real: an alpha that only rose would pop
## the plate off at full opacity, and one that only fell would start it already fading. Asserted as the
## shape of the curve over its whole life, not at three sampled points.
func _test_the_fade_rises_then_falls_and_is_never_negative() -> void:
	# Measured as the two EDGES of the full-opacity plateau, not as where the peak is. The first version
	# of this row asked "does the peak land before the midpoint", which is governed by the fade-IN rate
	# alone: setting `FADE_OUT_RATE` equal to `FADE_IN_RATE` left it passing, so the row claiming an
	# asymmetry could not see the asymmetry. Both edges is what distinguishes the two curves.
	var full_from: float = -1.0   ## fraction of the life elapsed when it FIRST reaches full opacity...
	var full_to: float = -1.0     ## ...and when it is last still full
	var outside: int = 0
	var samples: int = 400
	for i: int in samples:
		var t: float = 1.0 - float(i) / float(samples - 1)   ## life runs 1 -> 0
		var elapsed: float = 1.0 - t
		var a: float = ArrivalPlate.alpha_at(t)
		if a < 0.0 or a > 1.0:
			outside += 1
		if a >= 0.999:
			if full_from < 0.0:
				full_from = elapsed
			full_to = elapsed
	_check_over(samples, outside == 0, "the alpha stays inside 0..1 across the whole life (%d outside)"
		% outside)
	_check(full_from >= 0.0, "it reaches full opacity at all (%.3f through its life)" % full_from)
	_check(is_zero_approx(ArrivalPlate.alpha_at(1.0)) and is_zero_approx(ArrivalPlate.alpha_at(0.0)),
		"and it starts from nothing and ends at nothing (%.4f, %.4f)"
		% [ArrivalPlate.alpha_at(1.0), ArrivalPlate.alpha_at(0.0)])
	# Fast IN, slow OUT is the asymmetry legacy chose, and it is the whole reason the plate does not read
	# as a blink: the rise has to be the shorter of the two.
	var fall: float = 1.0 - full_to
	_check(full_from < fall,
		"fast in, slow out -- it rises over %.3f of its life and fades over %.3f" % [full_from, fall])


## Tracking is the whole visual idea ("what makes small type read as engraved"), and it is the one thing
## Godot's `draw_string` cannot do, so it is per-glyph placement or it is nothing. Measured against the
## untracked width rather than a literal, so this asserts the letter-spacing and not the font metrics.
func _test_the_words_are_tracked_apart_and_the_plate_is_centred_on_them() -> void:
	var font: Font = ThemeDB.fallback_font
	var word: String = "DEEPSTONE"
	var plain: float = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1,
		UiTheme.pt(ArrivalPlate.SIZE)).x
	var tracked: float = ArrivalPlate.tracked_width(font, word, ArrivalPlate.SIZE, ArrivalPlate.TRACK)
	_check(is_equal_approx(tracked - plain, UiTheme.px(ArrivalPlate.TRACK) * float(word.length() - 1)),
		"a %d-letter word gains %d gaps of track (%.2f px over the plain %.2f)"
		% [word.length(), word.length() - 1, tracked - plain, plain])
	_check(is_equal_approx(ArrivalPlate.tracked_width(font, "X", ArrivalPlate.SIZE, ArrivalPlate.TRACK),
		font.get_string_size("X", HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.pt(ArrivalPlate.SIZE)).x),
		"and a single letter gains NONE -- the track is between letters, not after them")
	_check(is_zero_approx(ArrivalPlate.tracked_width(null, word, ArrivalPlate.SIZE, ArrivalPlate.TRACK)),
		"and a missing font measures nothing rather than crashing")
	# The plate is centred on the canvas, and the hairlines run past the words rather than to a fixed
	# width -- legacy's "rules only as wide as the text", which is what makes it not read as a panel.
	var rows: Array[int] = _two_bands()
	if rows.size() != 2:
		return
	var p := ArrivalPlate.new()
	p.note_frame(_frame(rows[0], 0.0))
	p.note_frame(_frame(rows[1], 0.0))
	var l: Dictionary = p.layout(_frame(rows[1], 0.4), font)
	_check(not l.is_empty(), "sanity: there is a plate laid out to measure")
	var mid: float = UiTheme.CANVAS.x * 0.5
	var w: float = ArrivalPlate.tracked_width(font, l["text"], ArrivalPlate.SIZE, ArrivalPlate.TRACK)
	_check(is_equal_approx((l["text_at"] as Vector2).x + w * 0.5, mid),
		"the words are centred on the canvas (%.2f vs %.2f)" % [(l["text_at"] as Vector2).x + w * 0.5, mid])
	_check((l["rule_half"] as float) > w * 0.5 and (l["rule_half"] as float) < UiTheme.CANVAS.x * 0.5,
		"and the hairlines run past the words (%.1f) without reaching the screen edge (%.1f)"
		% [l["rule_half"], UiTheme.CANVAS.x * 0.5])
	_check((l["scrim"] as Rect2).size.x > (l["rule_half"] as float) * 2.0,
		"and the scrim's solid core is wider still, so the rules end inside it rather than on its edge")


## Each is a real startup state. None may crash, and none may draw.
func _test_an_incomplete_frame_decides_nothing() -> void:
	var canvas := Node2D.new()
	var p := ArrivalPlate.new()
	var no_look := _frame(0, 0.0)
	no_look.look = null
	var no_obs := Frame.new()
	no_obs.look = MaterialLook.new()
	for f: Frame in [no_look, no_obs]:
		_check(not p.note_frame(f), "an incomplete frame fires nothing")
		p.paint(f, canvas)
	p.paint(null, canvas)
	_check(p.layout(null, ThemeDB.fallback_font).is_empty(), "and lays out nothing")
	_check(p.layout(_frame(0, 0.0), null).is_empty(), "and nothing without a font")
	# CONTROL: the same plate DOES fire from a complete pair of frames, so the rows above are not passing
	# on a plate that ignores everything it is given.
	var rows: Array[int] = _two_bands()
	if rows.size() == 2:
		p.note_frame(_frame(rows[0], 0.0))
		_check(p.note_frame(_frame(rows[1], 0.0)),
			"CONTROL: a complete frame crossing a boundary still fires")
	canvas.free()
