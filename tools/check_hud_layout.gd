extends "res://tools/check_base.gd"

## THE HUD MUST NOT PRINT ON TOP OF ITSELF, OR OFF THE EDGE OF THE SCREEN.
##
## COMPREHENSIVE_AUDIT §413 asks for exactly this and nothing in the suite provides it: a scripted matrix
## of HUD states (title, arrival, hint, alert, hover, pause, Bazaar) with zero bounding-box overlap and
## zero clipping. Every other legibility layer in the suite judges PIXELS; this one judges GEOMETRY, which is
## the half that breaks silently. Two chips that collide still render, still look deliberate in a
## screenshot, and simply hide each other's text.
##
## And the risk is not hypothetical, it is structural. Reading `Hud._draw()`, three pairs are aimed at the
## same corner by design:
##
##   top-left     the depth readout AND the "▶▶ Nx" fast-forward chip
##   top-right    the FORGED counter AND the machine inspector, which is documented as sitting "under"
##                it: a relationship maintained by two independent constants
##   top-centre   the objective line AND the PAUSED chip
##
## Each of those is fine at the sizes they happen to have today. Each is one longer string from
## overlapping, and the depth chip and the FORGED chip both size themselves to their CONTENTS.
##
## HOW IT OBSERVES. The HUD is immediate-mode (no Control nodes, nothing to read off the scene tree), so
## `Hud.panel_probe` collects the rects `_panel()` actually drew. That matters more than it sounds: a
## layout test that re-derives where each chip goes is checking its own arithmetic against itself and
## would agree perfectly with a HUD that draws somewhere else entirely.
##
## WHAT IT ASSERTS, and the distinction is deliberate:
##
##   CLIPPING, in every state.   No panel may extend past the canvas, ever. A modal is allowed to cover
##                               the furniture; nothing is allowed to fall off the screen.
##   OVERLAP, only unmodal.      A Bazaar/help/settings overlay is SUPPOSED to sit over the furniture.
##                               That is what an overlay is. Asserting no-overlap there would fail the
##                               design rather than a bug. So overlap is judged in the states where every
##                               panel is furniture and every collision is a defect.
##
## Needs a real window: it reads what was drawn, and the dummy renderer draws nothing.
##
##   godot --path . --script res://tools/check_hud_layout.gd

const SCENE: String = "res://scenes/main.tscn"
const SETTLE: int = 6
## Panels smaller than this on either axis are rules and separators, not boxes competing for space.
const MIN_PANEL: float = 6.0
## Overlap smaller than this is a shared 1px border, not two panels fighting.
const TOUCH: float = 1.5

var _skipped: bool = false
var _main: MainView = null
var _probe_cell := Vector2i.ZERO


func _initialize() -> void:
	print("== the HUD must not print on top of itself ==")
	await _run()
	# _skip_layer() sets the exit code and leaves at the end of the frame, so the _verdict below would
	# overwrite a 42 with a 0 and the runner would count a layer that drew nothing as a pass.
	if _skipped:
		return
	_verdict("check_hud_layout", "every panel is on screen, and the furniture does not collide")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_skipped = true
		_skip_layer("check_hud_layout",
			"no display; nothing is drawn, so every state would report zero panels and pass empty")
		return

	MainView.dev_start = false
	MainView.boot_skip_title = true
	_main = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(_main)
	for _i: int in SETTLE:
		await physics_frame
	var hud: Hud = _main._hud
	if hud == null:
		_check(false, "the scene has a HUD to measure")
		return

	# A real machine, so the inspector and the alert stack have something true to describe. Placed where
	# the body already is rather than somewhere convenient, so `_can_reach` is satisfied and the inspector
	# draws its full panel instead of the short out-of-reach form.
	var def: MachineDef = load("res://src/data/machines/generator.tres") as MachineDef
	_probe_cell = _main._cell_at(_main._player.position) + Vector2i(1, 0)
	if def != null:
		_main.sim.place_machine(def, _probe_cell)
		for _i: int in 4:
			await physics_frame

	# The matrix. `modal` marks the states where an overlay is MEANT to sit over the furniture, so overlap
	# is not judged there; see the header. Everything is judged for clipping.
	var states: Array[Dictionary] = [
		{"name": "the bare screen", "modal": false, "set": {}, "keep": "bare"},
		{"name": "paused", "modal": false, "set": {"_paused": true}},
		{"name": "running fast (the ▶▶ chip beside the depth readout)", "modal": false,
			"set": {"_time_scale_idx": 2}},
		{"name": "a machine hovered (the inspector under FORGED)", "modal": false, "set": {}, "hover": true,
			"keep": "hover"},
		{"name": "running fast AND hovering at once", "modal": false,
			"set": {"_time_scale_idx": 3}, "hover": true},
		{"name": "the minimap up", "modal": false, "set": {"_minimap_mode": 1}},
		# THE ZONE CEREMONY, which T2.1 reports as "colliding with map, rope and action". It draws no
		# `_panel()` by design, so the sweep above was blind to it until `_draw_arrival` began registering
		# its scrim core. Paired WITH the corner map because that is the reported collision and because a
		# descent is exactly when both are up: you cross a stratum line with the map open.
		{"name": "a stratum arrival, map up", "modal": false, "set": {"_minimap_mode": 1},
			"announce": true},
		# ...and the LARGE form, which no state here has ever produced. `_minimap_mode` cycles
		# hidden -> corner -> LARGE and only a 2 sets `minimap_large` (`main.gd`); this
		# matrix shipped with a 1 and nothing else in the file ever wrote a 2. NOT modal: an overlay is
		# allowed to cover furniture, and the big map's rule is the opposite: the furniture stands down
		# for IT (`hud.gd`). So it must face the same collision sweep as the bare screen.
		{"name": "the BIG map up (M twice)", "modal": false, "set": {"_minimap_mode": 2},
			"keep": "big_map"},
		# The ceremony against the LARGE map. The corner form clears it (measured: no collision), but the
		# large form spans x 181..459 / y 41..319 and the arrival plate sits centred at y ~62..112. So
		# This is where "zone ceremony colliding with map" would actually bite, if it bites anywhere.
		{"name": "a stratum arrival, BIG map up", "modal": false, "set": {"_minimap_mode": 2},
			"announce": true, "twin": "the BIG map up (M twice)"},
		# ...and the big map WITH a machine hovered. The inspector is right-anchored and its width has a
		# 218px floor (`hud.gd`'s `HOVER_MIN_W`), so its left edge is at most 640-218-12 = 410 against a large map
		# spanning x 181..459. `hud.gd` asserts in prose that the large map is centred and off this
		# column — so the inspector never collides; that is false for a 128-wide world, and this row is
		# what makes the claim answerable instead of asserted.
		# EXPECTED TWIN of the row above, and declared rather than tolerated: once the inspector stands
		# down under the large map, these two states draw the same screen BY DESIGN. That is the fix, so
		# the states-differ check is told about it here instead of being loosened for everyone.
		{"name": "the BIG map WITH a machine hovered", "modal": false, "set": {"_minimap_mode": 2},
			"hover": true, "keep": "big_hover", "twin": "the BIG map up (M twice)"},
		# UI-07 PREDICTED THIS ROW BEFORE IT WAS RUN, which is the only reason it is worth adding.
		# Tag the always-on surfaces and the CRITICAL ones separately (Hud.HELPER_TAGS) and two of the
		# criticals turn out to aim at the same strip: `PAUSED (P)` is pinned at y 50..76, and the arrival
		# plate's scrim core sits at `CANVAS.y * 0.26 - SCRIM_ABOVE` = y 61.6..111.6. The PAUSED chip has
		# already been moved once for exactly this reason; it used to print across the objective line,
		# and it was moved INTO the ceremony's strip. Pausing on the frame you cross a stratum is not
		# exotic; crossing a band is when a player stops to read.
		{"name": "PAUSED during a stratum arrival", "modal": false, "set": {"_paused": true},
			"announce": true},
		{"name": "the Bazaar open", "modal": true, "set": {"_inventory_open": true}},
		{"name": "the dashboard open", "modal": true, "set": {"_show_dashboard": true}},
		{"name": "the help overlay", "modal": true, "set": {"_show_help": true}},
		{"name": "settings open", "modal": true, "set": {"_settings_open": true}},
	]

	var total_panels: int = 0
	var bare: Array[Rect2] = []
	var big: Array[Rect2] = []
	var hover: Array[Rect2] = []
	var big_hover: Array[Rect2] = []
	var sigs: Array[String] = []
	var sig_names: Array[String] = []
	var foots: Array[float] = []
	var foot_names: Array[String] = []
	var twin_of: Array[String] = []
	for st: Dictionary in states:
		var rects: Array[Rect2] = await _snapshot(hud, st)
		match String(st.get("keep", "")):
			"bare": bare = rects
			"big_map": big = rects
			"hover": hover = rects
			"big_hover": big_hover = rects
		sig_names.append(String(st["name"]))
		sigs.append(_signature(rects))
		twin_of.append(String(st.get("twin", "")))
		total_panels += rects.size()
		var name: String = st["name"]

		# --- clipping: every state, no exceptions ---
		var off: Array[String] = []
		for r: Rect2 in rects:
			if r.position.x < -TOUCH or r.position.y < -TOUCH \
					or r.position.x + r.size.x > Hud.CANVAS.x + TOUCH \
					or r.position.y + r.size.y > Hud.CANVAS.y + TOUCH:
				off.append("%s" % r)
		_check(off.is_empty(), "%s: all %d panels are on screen%s"
			% [name, rects.size(), "" if off.is_empty() else " — OFF: " + ", ".join(off)])

		# FOOTPRINT, reported and not judged here; see `_report_footprint`. IT GOES ABOVE THE MODAL
		# EARLY-OUT, and it did not the first time: four states returned before reaching it and the report
		# simply had ten rows instead of fourteen, with nothing saying which four were missing. A report
		# that silently omits its most-covered cases is worse than no report.
		foot_names.append(name)
		foots.append(_covered_fraction(rects))

		# --- overlap: only where every panel is furniture ---
		if bool(st["modal"]):
			continue
		var hits: Array[String] = []
		for i: int in rects.size():
			for j: int in range(i + 1, rects.size()):
				var a: Rect2 = rects[i]
				var b: Rect2 = rects[j]
				if a.size.x < MIN_PANEL or a.size.y < MIN_PANEL:
					continue
				if b.size.x < MIN_PANEL or b.size.y < MIN_PANEL:
					continue
				var over: Rect2 = a.intersection(b)
				if over.size.x > TOUCH and over.size.y > TOUCH:
					hits.append("%s x %s (overlap %.0fx%.0f)" % [a, b, over.size.x, over.size.y])
		_check(hits.is_empty(), "%s: no two panels collide%s"
			% [name, "" if hits.is_empty() else " — " + "; ".join(hits)])

	# NON-VACUITY. Every assertion above passes perfectly on a HUD that drew nothing at all, which is
	# exactly what a headless run produces and what a broken probe would produce. The states are supposed
	# to differ from each other too; if they all reported the same panels, the matrix would be one state
	# tested eleven times.
	_check_help_text()
	await _check_controls_reachable()
	_check_big_map(bare, big)
	_check_hover(bare, hover, big_hover)
	await _check_pack_window()
	await _check_announce_channel()
	_check_lesson_footprint()
	_check_helper_registry()
	await _check_probe_is_off()
	_report_footprint(foot_names, foots)

	_check(total_panels >= states.size() * 2,
		"the matrix drew %d panels across %d states, so there was geometry to judge"
			% [total_panels, states.size()])

	# ...AND THE STATES ACTUALLY DIFFER, which the paragraph above has always PROMISED and nothing has ever
	# CHECKED. "If they all reported the same panels, the matrix would be one state tested eleven times" was
	# the stated reason for the panel-count floor. But a count cannot tell one screen from eleven copies of
	# it, and ~50 panels clears a floor of 20 whether or not any state is distinct. Two of these rows were
	# in exactly that condition until this commit: both "hover" rows drew the bare screen, because the
	# latch they set was overwritten before the frame.
	# Declared identities are resolved to a GROUP rather than checked pairwise. Three states now draw the
	# same screen by design (the big map alone, with a machine hovered, and with a stratum arrival held),
	# and pairwise naming cannot express that: the arrival row and the hover row are twins of each other
	# only transitively, through the row they both name.
	var twins: Array[String] = []
	var declared: int = 0
	for i: int in sigs.size():
		var gi: String = twin_of[i] if twin_of[i] != "" else sig_names[i]
		for j: int in range(i + 1, sigs.size()):
			if sigs[i] != sigs[j]:
				continue
			var gj: String = twin_of[j] if twin_of[j] != "" else sig_names[j]
			if gi == gj:
				declared += 1                       # an identity the matrix expects, named at its row
				continue
			twins.append("'%s' == '%s'" % [sig_names[i], sig_names[j]])
	_check(twins.is_empty(), "every state drew a different screen from every other%s"
		% ["" if twins.is_empty() else " — IDENTICAL: " + "; ".join(twins)])
	# ...and every declared twin must ACTUALLY be a twin, or the declaration is just an exemption. Three
	# states in one group = three pairs. If the inspector stops standing down, or the arrival stops being
	# held, this drops and the pairs above start failing again.
	_check(declared == 3,
		"all 3 declared identities in the big-map group really are identical (%d)" % declared)

	await _check_bazaar_rail()

	_main.queue_free()
	await physics_frame


## THE BIG MAP IS THE SCREEN, so nothing may be left under it. And nothing may be left HALF under it.
##
## This layer already CAUGHT this, once, and then stopped being able to. A real failing run named two
## collisions against the large map; the banner was fixed by standing it down at `hud.gd`, and the
## second (a 46x44 panel at (297,295), overlap 46x24) was left as an open lead: *"either that panel moved,
## or it is state-dependent and the current fixture no longer samples it."* It is the second. The panel
## is `_draw_inventory`'s backing at ONE slot (`x0 = (CANVAS.x - total_w) * 0.5` = (640-30)/2 = 305, and
## `backing = Rect2(x0 - 8.0, ..., total_w + 16.0, ...)` = Rect2(297, 295, 46, 44)), drawn unconditionally
## from `hud.gd`'s top-level `_draw()`. It never moved. The matrix asked for
## `_minimap_mode` **1**, which is the CORNER map (122x122 in the top-right, 142px clear of the bar), so
## the state that collides was never entered.
##
## THE FIX TO THE FIRST COLLISION IS WHAT HID THE SECOND. Once the banner stood down the sweep went green,
## and a green sweep is indistinguishable from a sweep that is no longer looking.
##
## WHY THIS IS NAMED RATHER THAN LEFT TO THE GENERIC SWEEP ABOVE. That sweep judges whatever a state
## HAPPENED to draw, so it also passes the moment a panel stops being drawn at all. And `_draw_minimap`
## returns before its first `_panel()` when the sim or the colour callable is unbound (`hud.gd`'s `if sim == null or not minimap_color.is_valid()`).
## A map that never drew collides with nothing. So the subject is proved PRESENT first, and the stand-down
## is asserted as its own property rather than inferred from a quiet sweep.
func _check_big_map(bare: Array[Rect2], big: Array[Rect2]) -> void:
	# A. THE SUBJECT EXISTS, and it is the LARGE form. "Bigger than the corner map's own box" is the
	#    cheapest statement that cannot be satisfied by the corner map, by an empty state, or by a probe
	#    that returned nothing.
	var map := Rect2()
	for r: Rect2 in big:
		if r.get_area() > map.get_area():
			map = r
	_check(map.size.x > Hud.MINI_W and map.size.y > Hud.MINI_H,
		"the big-map state drew the LARGE map: %.0fx%.0f, past the %.0fx%.0f corner box"
			% [map.size.x, map.size.y, Hud.MINI_W, Hud.MINI_H])

	# B. THE COLLISION ITSELF.
	var buried: Array[String] = []
	for r: Rect2 in big:
		if r == map or r.size.x < MIN_PANEL or r.size.y < MIN_PANEL:
			continue
		var over: Rect2 = r.intersection(map)
		if over.size.x > TOUCH and over.size.y > TOUCH:
			buried.append("%s (overlap %.0fx%.0f)" % [r, over.size.x, over.size.y])
	_check(buried.is_empty(), "the big map has nothing buried under it%s"
		% ["" if buried.is_empty() else " — " + "; ".join(buried)])

	# C. NON-VACUITY FOR B, AND THE STAND-DOWN AS A PROPERTY. B passes trivially if the bar simply never
	#    drew, so the bar is proved present on the bare screen and then proved GONE here. Asserting the
	#    absence alone would go green on a HUD with no hotbar at all.
	var bar: Rect2 = _bottom_panel(bare)
	_check(bar.size.y >= MIN_PANEL and bar.position.y > Hud.CANVAS.y * 0.5,
		"the bare screen drew the pack bar along the bottom (%s) — there was something to stand down" % bar)
	var still_there: Rect2 = _bottom_panel(big)
	_check(still_there.position.y <= Hud.CANVAS.y * 0.5,
		"the pack bar stands down while the big map is up (found %s)" % still_there)

	# D. THE GOAL PLATE STANDS DOWN (`hud.gd`). That guard has never once executed under test:
	#    `minimap_large` comes only from `_minimap_mode == 2` (`main.gd`) and no fixture reached a 2, so
	#    deleting it would have been invisible. Proved by DIFFERENCE in both directions; absence alone
	#    proves nothing, because the plate legitimately hides itself when the chain is finished
	#    (`hud.gd`) or once `goal_a` has decayed.
	var plate: Rect2 = _goal_plate(bare)
	_check(plate.size.y >= MIN_PANEL,
		"the bare screen drew the goal plate at top-centre (%s) — there was something to suppress" % plate)
	var survivor: Rect2 = _goal_plate(big)
	_check(survivor.size.y < MIN_PANEL,
		"the big map suppresses the goal plate (found %s)" % survivor)


## THE MACHINE INSPECTOR: the panel this matrix has claimed to judge since it was written, and never has.
##
## Two rows carry `"hover": true`. Both were inert: they set `_main._hover_latch`, which `main.gd`
## overwrites from `_aim` every frame. So the inspector was never drawn under test, and what WAS drawn
## depended on the operator's real mouse. `_snapshot` now warps the cursor onto the probe machine instead,
## and this proves the warp WORKED, because a hover fixture that silently fails to hover is the same
## vacuity one level up, and it would make the collision below look fixed.
func _check_hover(bare: Array[Rect2], hover: Array[Rect2], big_hover: Array[Rect2]) -> void:
	# THE FIXTURE DID ITS JOB. The inspector is right-anchored with a 218px width floor (`hud.gd`'s `HOVER_MIN_W`), so
	# it is the panel hugging the right edge that the bare screen does not have. If this fails, the warp
	# did not take and every verdict below is void; reported as a FIXTURE failure, not as a HUD verdict.
	_check(hover.size() > bare.size(),
		"hovering a machine drew MORE panels than the bare screen (%d vs %d) — the cursor reached it"
			% [hover.size(), bare.size()])
	var panel: Rect2 = _right_edge_panel(hover)
	_check(panel.size.x >= Hud.HOVER_MIN_W - TOUCH,
		"...and the extra panel is the inspector, at its %.0fpx floor or wider (%s)"
			% [Hud.HOVER_MIN_W, panel])

	# THE COLLISION. `hud.gd` claims the large map is centred and off this column, so the inspector never
	# collides. The inspector's left edge is at most CANVAS.x - HOVER_MIN_W - 12 = 410; the large map runs
	# to x=459. The prose asserted the impossibility of the thing the code caused.
	var map := Rect2()
	for r: Rect2 in big_hover:
		if r.get_area() > map.get_area():
			map = r
	_check(map.size.x > Hud.MINI_W and map.size.y > Hud.MINI_H,
		"the big-map-plus-hover state drew the LARGE map (%.0fx%.0f)" % [map.size.x, map.size.y])
	var over_map: Array[String] = []
	for r: Rect2 in big_hover:
		if r == map or r.size.x < MIN_PANEL or r.size.y < MIN_PANEL:
			continue
		var over: Rect2 = r.intersection(map)
		if over.size.x > TOUCH and over.size.y > TOUCH:
			over_map.append("%s (overlap %.0fx%.0f)" % [r, over.size.x, over.size.y])
	_check(over_map.is_empty(), "the inspector stands down under the big map%s"
		% ["" if over_map.is_empty() else " — " + "; ".join(over_map)])


## A state's screen, reduced to something comparable: every panel it drew, sorted, so two states that drew
## the same boxes in a different ORDER still read as the same screen. Order is a draw-sequence detail; the
## claim being tested is about what is on screen.
func _signature(rects: Array[Rect2]) -> String:
	var parts: Array[String] = []
	for r: Rect2 in rects:
		parts.append("%.0f,%.0f,%.0f,%.0f" % [r.position.x, r.position.y, r.size.x, r.size.y])
	parts.sort()
	return "|".join(parts)


## The panel hugging the canvas's right edge, which is the inspector's anchor (`hud.gd`). `Rect2()` if
## no panel reaches it.
func _right_edge_panel(rects: Array[Rect2]) -> Rect2:
	var out := Rect2()
	for r: Rect2 in rects:
		if r.size.x >= MIN_PANEL and r.size.y >= MIN_PANEL \
				and absf(r.end.x - (Hud.CANVAS.x - 12.0)) <= TOUCH and r.size.x > out.size.x:
			out = r
	return out


## The lowest box a state drew, ignoring rules and separators. `Rect2()` if there is none.
func _bottom_panel(rects: Array[Rect2]) -> Rect2:
	var out := Rect2()
	for r: Rect2 in rects:
		if r.size.x >= MIN_PANEL and r.size.y >= MIN_PANEL and r.end.y > out.end.y:
			out = r
	return out


## The objective plate: the ONE panel centred on the canvas at y=8 (`hud.gd`). The depth chip is
## left-anchored at x=10 (`:477`), FORGED is right-anchored (`:623`), the fast-forward chip sits at y=34
## (`:602`) and PAUSED at y=50 (`:283`). So the anchor identifies it and nothing else does. Deliberately
## BLIND TO HEIGHT: the plate is 24px or 37px depending on `step_age` (`hud.gd`), and that is the exact
## timing dependence that made the last collision here intermittent.
func _goal_plate(rects: Array[Rect2]) -> Rect2:
	for r: Rect2 in rects:
		if r.size.x >= MIN_PANEL and r.size.y >= MIN_PANEL \
				and absf(r.position.y - 8.0) <= TOUCH \
				and absf(r.get_center().x - Hud.CANVAS.x * 0.5) <= TOUCH:
			return r
	return Rect2()


## Put the HUD in one state, let it draw, and hand back the boxes it drew. State is reset each time so a
## flag set by an earlier row cannot leak into a later one and quietly make the matrix one long state.
func _snapshot(hud: Hud, st: Dictionary) -> Array[Rect2]:
	# STATE IS SET ON MAINVIEW, NOT ON THE HUD, and that is not a style choice. MainView re-syncs every one
	# of these fields into the HUD each frame (`main.gd`), so assigning `hud.inventory_open` directly
	# is overwritten before the frame draws; the first version of this layer did exactly that and every
	# modal state silently reported the bare screen's furniture, with the overlays never drawn at all. The
	# clipping bug in the help overlay disappeared from the results the moment the capture got tighter,
	# which is the tell: a fix that makes a finding vanish without touching the subject is not a fix.
	_main._paused = false
	_main._inventory_open = false
	_main._minimap_mode = 0
	_main._show_help = false
	_main._show_dashboard = false
	_main._settings_open = false
	_main._time_scale_idx = 0
	_main._hover_latch = Vector2i(-9999, -9999)
	for k: Variant in (st["set"] as Dictionary):
		_main.set(String(k), (st["set"] as Dictionary)[k])
	# THE CURSOR IS THE INPUT; THE LATCH IS ONLY EVER AN ECHO OF IT.
	#
	# This used to read `_main._hover_latch = _probe_cell`, with a comment claiming the inspector was
	# therefore built "exactly as it is in play". It was not built at all. `main.gd` recomputes
	# `_hover_latch` from `_aim` on every frame, and `_update_mining` refreshes `_aim` from the real OS
	# mouse on every `_process`, unconditionally, pause included (`main.gd`). So the assignment was
	# discarded before the frame drew, and BOTH "hover" rows in the matrix have never once drawn the
	# inspector they exist to judge.
	#
	# The second half is worse than the first. With the latch overwritten, where the aim landed was
	# wherever the operator's mouse happened to be sitting. So those rows did not merely test nothing,
	# they tested something DIFFERENT on every run, on a machine nobody controls. Warping fixes both: the
	# hover rows drive the real aim path, and every other row is pinned to a corner so a stray cursor
	# cannot quietly add an inspector to a state that is supposed to be bare.

	# EXACTLY ONE FRAME. The first version armed the probe and then awaited twice, so the HUD drew twice
	# and every panel was recorded two or three times, which the overlap test dutifully reported as each
	# panel colliding with ITSELF, a screenful of failures that were entirely the instrument.
	for _i: int in 3:
		await RenderingServer.frame_post_draw       # let MainView push the new state into the HUD

	# THE CEREMONY IS SET AFTER THE SETTLE, NOT BEFORE, and that ordering is the whole point.
	# `_arrival_life` is HUD-owned and decays in `Hud._process`, but MainView ANNOUNCES on its own during
	# those settle frames whenever the body crosses a stratum line (`main.gd`'s `_note_stratum`). Clearing before the
	# settle therefore cleared nothing: the plate reappeared on rows that never asked for it, and the bare
	# screen silently gained a sixth panel. That is the same defect as the uncontrolled mouse, a row
	# whose content depends on something the fixture does not own, and it surfaced the moment
	# `_draw_arrival` started registering, having been invisible before.
	# THE CURSOR IS WARPED HERE TOO, AFTER THE SETTLE, FOR THE SAME REASON AND IT WAS NOT ALWAYS.
	# Warping before the settle frames let the body drift under them (at `_time_scale_idx: 3` the sim
	# advances further per frame), so the camera moved after the cursor was placed and the aim no longer
	# landed on the probe machine. That row then drew no inspector and came out byte-identical to the
	# plain fast-forward row, INTERMITTENTLY: it passed on one run and failed on the next, which is worse
	# than a steady failure because the green looks like the answer. Placing the cursor last removes the
	# window in which anything can move underneath it.
	# AND IT IS POSED, NOT WARPED. `warp_mouse` moves the REAL cursor on the REAL desk, so both branches
	# below used to be a request to the windowing system that a human hand could overrule. And this layer
	# is registered `add_gl`, so it runs in a real window on a machine somebody uses. Both directions were
	# live: a hand off the probe machine in the one frame below cost the hover row its inspector, which the
	# assertion at `_check_hover` correctly calls "the warp did not take and every verdict below is void";
	# a hand ONTO a machine during a bare row added an inspector to a state that is supposed to have none,
	# which shows up as two innocent rows colliding.
	#
	# The comment above is about the CAMERA moving under a placed cursor. This is the same failure with a
	# second mover, and the fix for both is to stop naming a SCREEN pixel: a posed world point cannot be
	# overruled by a hand and does not change meaning when the camera moves.
	#
	# The park branch keeps its exact old meaning, the world point currently under viewport (2,2), taken
	# through the engine's own transform rather than a hand-rolled inverse.
	var vp: Viewport = _main.get_viewport()
	if bool(st.get("hover", false)):
		Controls.pose_pointer(_main._cell_center(_probe_cell))
	else:
		Controls.pose_pointer(vp.get_canvas_transform().affine_inverse() * Vector2(2.0, 2.0))
	hud._arrival_life = 0.0
	if bool(st.get("announce", false)):
		# ARRIVAL_HOLD is 3.4s against one drawn frame, so the plate is at full life when the probe fires.
		hud.announce("THE DEEPSLATE", "120 METRES DOWN", Color(0.56, 0.50, 0.78))
	await RenderingServer.frame_post_draw            # one frame for the new aim to reach `hover_info`
	Hud.probing = true
	Hud.panel_probe = ([] as Array[Rect2])
	Hud.hotbar_probe = {}
	await RenderingServer.frame_post_draw
	var out: Array[Rect2] = Hud.panel_probe.duplicate()
	Hud.probing = false
	Hud.panel_probe = ([] as Array[Rect2])
	Hud.hotbar_probe = {}
	return out


## A CONTROL YOU CANNOT SEE IS A CONTROL YOU CANNOT PRESS.
##
## Every assertion above judges PANELS, because `panel_probe` collects what `_panel()` drew. The claim at
## the top of this file is larger than that population: "the HUD must not print off the edge of the
## screen". A row of text and a chip drawn INSIDE a perfectly legal panel, past its floor, is invisible to
## all of it. And the settings page has been drawing the last two of its twenty-two key bindings below
## the panel, one of them below the SCREEN, for as long as the remap list has had that many rows:
##
##   panel   Rect2(90, 14, 460, 332)   floor y = 346, canvas is 360 tall
##   rows    y = 74 + i * 13.8
##   quickload        y = 350.0   below the plate
##   clear dig plan   y = 363.8   below the screen
##
## "settings open" is IN the matrix above and has been green throughout, which is the point: the layer was
## never wrong, it was answering about panels while its name promised the HUD.
##
## The HUD already publishes the right population, for a different reason. `_settings_hits`, `_knob_hits`
## and `_alert_hits` are the rects `settings_click` / `hover_click` / `alert_click` route a real press
## through. Judging THOSE cannot drift from what is clickable, because they are what is clickable; the
## same reason this file probes the drawn panels instead of re-deriving where they ought to be.
##
## Two claims, and the second is the one with teeth:
##   ON SCREEN     no registered control may leave the canvas. You cannot press what was never drawn.
##   ON ITS PLATE  a modal's controls must sit on the modal's own panel. A chip four pixels past the
##                 plate is still on screen and still clickable, and it reads as a rendering fault.
##
## The REJECTION CONTROL is not decoration. Both claims pass perfectly against an empty hit list, which is
## exactly what a state that failed to open would produce, so the same predicate is run once more over the
## same rects with one of them displaced off the canvas, and is required to catch it.
const CONTROL_SLOP: float = 1.0
## PER CATEGORY, because the page now shows one at a time.
##
## This floor used to be a single 26 ("sliders, chips, the mute, the reset, and one per binding") over a
## page that drew all of that at once. `MNU-26` ended that: one category is open and the panel is only as
## tall as that category needs. A single total would now be satisfied by CONTROLS alone while AUDIO and
## FEEL went unvisited, which is the shape of a floor that has stopped measuring its subject.
##
## So the floor is split and the layer visits all three faces. **The teeth are unchanged and land where
## they always did**: CONTROLS still has to register every one of the twenty-two bindings plus its reset,
## still all on screen, still all on the plate; that was the defect this assertion was written for and it
## is asserted against the same population, at the same strength. The other two faces are coverage the
## old single-screen check never had, because they were never separately addressable.
const SETTINGS_CAT_MIN: Array[int] = [8, 25, 6]     # AUDIO: rail+mute+4 levels. CONTROLS: rail+22. FEEL: rail+3.
const SETTINGS_CAT_NAMES: Array[String] = ["AUDIO", "CONTROLS", "FEEL"]
## Frames a category change is allowed before its panel has to have stopped moving. The page eases its
## height toward the open category (`Hud._set_h`), and a rect read mid-lerp is a measurement of how many
## frames elapsed before the shutter, not of the layout; this project has paid for that lesson twice.
const SETTLE_FRAMES: int = 150


func _check_controls_reachable() -> void:
	var total: int = 0
	for cat: int in SETTINGS_CAT_MIN.size():
		var shot: Dictionary = await _controls_shot({"_settings_open": true}, cat)
		var hits: Array[Rect2] = shot["hits"]
		var plate: Rect2 = shot["plate"]
		var name: String = SETTINGS_CAT_NAMES[cat]
		total += hits.size()

		_check(bool(shot["settled"]), "%s settled before it was measured (%.2fpx from its target height)"
			% [name, float(shot["drift"])])
		_check(hits.size() >= SETTINGS_CAT_MIN[cat],
			"settings %s registered %d clickable controls (at least %d, or it never opened)"
				% [name, hits.size(), SETTINGS_CAT_MIN[cat]])

		var off: Array[String] = _outside_canvas(hits)
		_check(off.is_empty(), "settings %s: all %d clickable controls are on screen%s"
			% [name, hits.size(), "" if off.is_empty() else " — OFF: " + ", ".join(off)])

		var spilled: Array[String] = []
		for r: Rect2 in hits:
			if not plate.grow(CONTROL_SLOP).encloses(r):
				spilled.append("%s" % r)
		_check(spilled.is_empty(),
			"...and every one sits on the %.0fx%.0f plate that owns them%s"
				% [plate.size.x, plate.size.y, "" if spilled.is_empty() else " — OFF THE PLATE: "
					+ ", ".join(spilled)])

		# The control: the same predicate, the same rects, one of them moved off the bottom of the canvas.
		# It is stated as a DIFFERENCE from the live count and not as "catches exactly one", because the
		# first version was written expecting the page to be clean and reported `caught 2` the moment the
		# page was not; the control failing for the same reason as the subject, and saying nothing about
		# the predicate. Run per category: a control that only ever ran on one face is a control that
		# vouches for two faces it never saw.
		var planted: Array[Rect2] = hits.duplicate()
		if not planted.is_empty():
			planted[0] = Rect2(planted[0].position + Vector2(0.0, Hud.CANVAS.y), planted[0].size)
		var caught: int = _outside_canvas(planted).size()
		_check(caught == off.size() + 1,
			"settings %s: the same check catches one more once one is pushed off the bottom (%d -> %d)"
				% [name, off.size(), caught])

	# NOT A FLOOR: a ledger. The three faces together must still offer at least what the one crowded page
	# did, so a category quietly losing its controls in some future rearrangement cannot pass by being
	# short in a place no single assertion is looking.
	_check(total >= 39, "the three faces register %d controls between them (the old single page: 26)"
		% total)

	_main._settings_open = false
	await RenderingServer.frame_post_draw


## The rects that leave the canvas, described. Shared by the claim and by its rejection control, so the
## control cannot pass by testing a second, gentler copy of the predicate.
func _outside_canvas(rects: Array[Rect2]) -> Array[String]:
	var out: Array[String] = []
	for r: Rect2 in rects:
		if r.position.x < -CONTROL_SLOP or r.position.y < -CONTROL_SLOP \
				or r.end.x > Hud.CANVAS.x + CONTROL_SLOP or r.end.y > Hud.CANVAS.y + CONTROL_SLOP:
			out.append("%s" % r)
	return out


## One state, one drawn frame, and the two things it registered: every clickable rect, and the biggest
## panel, which for a modal state is the modal's own plate.
## `cat` >= 0 selects a settings category before the shot and WAITS FOR THE PANEL TO STOP MOVING.
##
## The category is set through `Hud.set_settings_cat`, on the HUD, because that is where the page keeps it;
## `main.gd` asks for the change and never pushes the field. That distinction is not pedantry: this
## project has a probe that posed `hud.inventory_open` and photographed a field its owner overwrote before
## the first frame, and reported the resulting nothing as a measurement.
func _controls_shot(set_flags: Dictionary, cat: int = -1) -> Dictionary:
	_main._paused = false
	_main._inventory_open = false
	_main._minimap_mode = 0
	_main._show_help = false
	_main._show_dashboard = false
	_main._settings_open = false
	for k: Variant in set_flags:
		_main.set(String(k), set_flags[k])
	var hud0: Hud = _main._hud
	if cat >= 0:
		hud0.set_settings_cat(cat)
	for _i: int in 3:
		await RenderingServer.frame_post_draw
	# Wait for the height to arrive rather than assuming a fixed number of frames is enough. Reported, not
	# just waited on: if it never settles the layer says so instead of quietly measuring a lerp.
	var drift: float = 0.0
	var settled: bool = true
	if cat >= 0:
		settled = false
		for _i: int in SETTLE_FRAMES:
			drift = absf(hud0._set_h - hud0._settings_wanted_h())
			if drift < 0.5:
				settled = true
				break
			await RenderingServer.frame_post_draw
		drift = absf(hud0._set_h - hud0._settings_wanted_h())
	Hud.probing = true
	Hud.panel_probe = ([] as Array[Rect2])
	await RenderingServer.frame_post_draw
	var panels: Array[Rect2] = Hud.panel_probe.duplicate()
	Hud.probing = false
	Hud.panel_probe = ([] as Array[Rect2])
	var hud: Hud = _main._hud
	var hits: Array[Rect2] = []
	for src: Array in [hud._settings_hits, hud._knob_hits, hud._alert_hits]:
		for h: Dictionary in src:
			hits.append(h["rect"] as Rect2)
	var plate := Rect2()
	for pr: Rect2 in panels:
		if pr.size.x * pr.size.y > plate.size.x * plate.size.y:
			plate = pr
	return {"hits": hits, "plate": plate, "settled": settled, "drift": drift}


## THE TEXT, WHICH A PANEL-RECT TEST CANNOT SEE.
##
## Splitting the CONTROLS card into two columns turned up something the box measurements never could: the
## longest line is ~450px of glyphs at size 11, and the card was 244px wide. That text has ALWAYS spilled
## outside its own panel, over the darkened world behind it. And the panel it overflowed reported a
## perfectly legal rectangle the whole time, which is why every geometry assertion above stayed green
## through it. Two columns would have made it collide with the column beside it.
##
## So the card's lines are held to the column they are drawn in, measured with the same font, the same
## size and the same width constant the drawing code uses, not a copy of them.
func _check_help_text() -> void:
	var font: Font = ThemeDB.fallback_font
	var budget: float = Hud.HELP_COL_W - 8.0
	var over: Array[String] = []
	var widest: float = 0.0
	for ln: String in Hud.HELP_LINES:
		var w: float = font.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, Hud.HELP_TEXT_SIZE).x
		widest = maxf(widest, w)
		if w > budget:
			over.append("%.0fpx: \"%s\"" % [w, ln])
	_check(over.is_empty(), "every CONTROLS line fits its %.0fpx column (widest %.0fpx)%s"
		% [budget, widest, "" if over.is_empty() else " — OVER: " + "; ".join(over)])
	# Non-vacuity: an empty or trivially short list would satisfy the above perfectly.
	_check(Hud.HELP_LINES.size() >= 12 and widest > budget * 0.5,
		"the card carries %d lines and the widest uses %.0f%% of its column — there was text to measure"
			% [Hud.HELP_LINES.size(), 100.0 * widest / budget])


## THE HOTBAR IS A WINDOW, AND A WINDOW THAT LOSES THE SELECTION IS WORSE THAN A SHORT LIST.
##
## `FactorySim.inventory_slots()` has NO CAP: one entry per item type, and the universe is twenty machine
## types plus sixteen materials plus the crafted intermediates. The bar draws ten. Nothing in the suite
## had ever put an eleventh type in the pack, so nothing had ever seen what the eleventh does, and the
## answer was: nothing at all, silently, in a bar whose own comment promises it "grows/shrinks with your
## pack". Reachable on frame one of a dev start: the kit is ten types and the starter pickaxe is an
## eleventh, seeded by a different function.
##
## Three cases, and the middle one is the POSITIVE CONTROL. A test that only ever asserts the overflowing
## pack cannot distinguish "the window works" from "the probe reports ten no matter what", so the small
## pack is measured with the same instrument first and has to come back DIFFERENT.
func _check_pack_window() -> void:
	var saved: Dictionary = _main.sim.inventory.duplicate()
	var saved_sel: int = _main._inv_selected

	# A control pack that FITS. Everything about the bar should be ordinary here.
	var small: Dictionary = await _pack_shot(5, 3)
	_check(int(small.get("carried", -1)) == 5,
		"the fixture put 5 item types in the pack and the bar saw 5 (got %s)"
			% [small.get("carried", "?")])
	_check(_wells_are_sane(small),
		"a pack of 5 draws wells that are whole, disjoint and inside their own backing%s"
			% [_wells_report(small)])
	_check(bool(small.get("sel_lit", false)),
		"...and the selected well is lit")
	# Deliberately NOT `backing.encloses(plate)`: the plate is centred on its slot and is routinely wider
	# than one, so enclosure is false for legitimate layouts and the assertion would be testing the wrong
	# property. What is being claimed here is only that the plate exists at all in the ordinary case.
	_check((small.get("label", Rect2()) as Rect2).size.x > 0.0,
		"...and the name plate was drawn (%s)" % [small.get("label", Rect2())])

	# The same pack overflowing. The SETUP is that the bar now shows fewer wells than the pack holds; that
	# is `clampi(13, 1, 10)` and asserting it would be asserting arithmetic, so it is stated and not
	# checked. What is checked is that the wells stay whole and on their backing once the window is short.
	var big_pack: Dictionary = await _pack_shot(13, 3)
	_check(int(big_pack.get("carried", -1)) == 13,
		"a pack of 13 types reports 13 carried (got %s)" % [big_pack.get("carried", "?")])
	_check(_wells_are_sane(big_pack),
		"...and a short window still draws whole, disjoint wells inside their backing%s"
			% [_wells_report(big_pack)])

	# ...AND THE SELECTION PAST THE END, which is what the wheel reaches and what used to vanish. The LAST
	# type is chosen deliberately rather than an arbitrary high index: `inventory` is insertion-ordered, so
	# a type you have just picked up for the first time appends at the end. "The item you just found" is
	# the common case, not the corner one.
	var far: Dictionary = await _pack_shot(15, 14)
	_check(bool(far.get("sel_lit", false)),
		"selecting the 15th of 15 types still lights a DRAWN well (window starts at %s)"
			% [far.get("window", "?")])
	_check(int(far.get("window", 0)) > 0,
		"...because the window scrolled to contain it (starts at %s)" % [far.get("window", "?")])
	var plate: Rect2 = far.get("label", Rect2()) as Rect2
	var back: Rect2 = far.get("backing", Rect2()) as Rect2
	_check(plate.size.x > 0.0 and plate.position.x >= back.position.x - 40.0
			and plate.position.x + plate.size.x <= back.position.x + back.size.x + 40.0,
		"...and its name plate sits over the bar, not off the end of it (plate %s vs bar %s)"
			% [plate, back])
	_check(plate.position.x >= -TOUCH and plate.position.x + plate.size.x <= Hud.CANVAS.x + TOUCH,
		"...and on the canvas (plate %s)" % [plate])
	_check(_wells_are_sane(far),
		"...and a SCROLLED window's wells are still whole, disjoint and on their backing%s"
			% [_wells_report(far)])

	_main.sim.inventory = saved
	_main._inv_selected = saved_sel


## Stuff the pack with `types` distinct item types, select `sel`, and draw ONE probed frame. The ids are
## real ones: the bar looks up sprites and labels by id, and a made-up id would exercise a drawing path
## no player ever sees.
func _pack_shot(types: int, sel: int) -> Dictionary:
	const IDS: Array[StringName] = [&"ore", &"ingot", &"wood", &"coal", &"conduit", &"rope", &"torch",
		&"sapling", &"stone", &"iron", &"gravel", &"shale", &"rich_ore", &"processor", &"splitter"]
	var pack: Dictionary = {}
	for i: int in mini(types, IDS.size()):
		pack[IDS[i]] = i + 1
	_main.sim.inventory = pack
	_main._paused = false
	_main._inventory_open = false
	_main._minimap_mode = 0
	_main._show_help = false
	_main._show_dashboard = false
	_main._settings_open = false
	_main._inv_selected = sel
	for _i: int in 2:
		await RenderingServer.frame_post_draw
	# The selection is re-set immediately before the probed frame: MainView owns nothing here, but the
	# settle frames run real input handling and a stray wheel event would move it.
	_main._inv_selected = sel
	Hud.probing = true
	Hud.hotbar_probe = {}
	await RenderingServer.frame_post_draw
	var out: Dictionary = Hud.hotbar_probe.duplicate()
	Hud.probing = false
	Hud.hotbar_probe = {}
	return out


## THE INSTRUMENT MUST BE OFF WHEN NOBODY IS LOOKING, AND THIS IS THE ASSERTION THAT SAYS SO.
##
## `Hud.panel_probe` was guarded by `if panel_probe != null:` with a comment promising it was "left null in
## play". A `static var panel_probe: Array[Rect2]` initialises to `[]`, and `[] != null` is TRUE in
## GDScript, verified against 4.6.2 rather than assumed. So the guard fell open on every frame of every
## real session and the array grew forever, in a static nothing clears. The fix is a real flag; this is
## what stops it falling open again.
##
## The order matters. Asserting "the probe is empty" ALONE passes on a HUD that draws nothing, on a broken
## flag, on a deleted probe. So the flag is turned back ON afterwards and the probe has to FILL. Absence
## is only evidence once the instrument has proved it can detect presence.
## THE ANNOUNCE CHANNEL HAS ONE OCCUPANT AT A TIME: `P1`'s only structural rule, and the matrix above
## could not see either half of it.
##
## **The matrix row that looks like it covers this covers the opposite case.** `"a stratum arrival, BIG map
## up"` sets `_minimap_mode: 2` and THEN calls `announce()`, and `announce()` defers when the map is
## already open. So that row exercises the direction that was already guarded, gets a deferral, and is
## correctly declared a twin of the plain big-map row. **The unguarded direction is the other order:
## ceremony up FIRST, map opened second**, which `_draw_arrival` (drawn after `_draw_minimap`) rendered
## straight over the map. `docs/media/baseline/_moment_map.png` is that frame.
##
## *A guard that handles one direction of a two-directional collision is not half a guard, it is a guard
## with a hole, and the hole is invisible because the covered direction is the one anybody tests.*
##
## Every assertion below is paired with the control that makes it capable of failing: the freeze is only
## meaningful against a run of the same length that does NOT freeze, and "the plate is absent" is only
## meaningful if the same probe finds it present when it should be.
const CEREMONY_BAND_TOP: float = Hud.CANVAS.y * 0.26 - 40.0
const CEREMONY_BAND_BOT: float = Hud.CANVAS.y * 0.26 + 25.0

func _check_announce_channel() -> void:
	var hud: Hud = _main._hud
	_main._inventory_open = false
	_main._show_help = false
	_main._show_dashboard = false
	_main._settings_open = false

	# ---- the plate under the LARGE map -------------------------------------------------------------
	_main._minimap_mode = 0
	hud._arrival_life = 0.0
	await RenderingServer.frame_post_draw
	hud.announce("THE DEEPSLATE", "120 METRES DOWN", Color(0.56, 0.50, 0.78))
	var lit: Array[Rect2] = await _probe_frames(2)
	var life_open: float = hud._arrival_life
	_check(_in_ceremony_band(lit).size() == 1,
		"CONTROL: with the map closed, the arrival plate registers exactly one panel in its band (%d)"
			% _in_ceremony_band(lit).size())
	_check(life_open < Hud.ARRIVAL_HOLD,
		"CONTROL: with the map closed the plate's clock RUNS (%.3f of %.1f used)"
			% [Hud.ARRIVAL_HOLD - life_open, Hud.ARRIVAL_HOLD])

	_main._minimap_mode = 2                       # ...and NOW the map opens, under a live ceremony
	var held: Array[Rect2] = await _probe_frames(4)
	var life_held: float = hud._arrival_life
	_check(_in_ceremony_band(held).is_empty(),
		"the arrival plate draws NOTHING once the big map opens under it (%d panels in its band)"
			% _in_ceremony_band(held).size())
	_check(is_equal_approx(life_held, life_open),
		"...and it is HELD, not spent: %.3f s left before the map opened, %.3f s after four frames"
			% [life_open, life_held])

	_main._minimap_mode = 0                       # the map closes; the announcement is still owed
	var back: Array[Rect2] = await _probe_frames(2)
	_check(_in_ceremony_band(back).size() == 1,
		"...and it comes back when the map closes, with its remaining life intact (%.3f s)"
			% hud._arrival_life)

	# ---- the lesson under the plate ----------------------------------------------------------------
	#
	# EVERY WAIT BELOW IS A DRAWN FRAME AND NOT A PHYSICS STEP, WHICH IS THE WHOLE OF THIS SECTION'S FIX.
	# `Hints` is clocked from `_process`: `main.gd`'s `_hints.refresh(delta)` call, and the line above it, is the
	# only writer of `_ceremony`. A fixture that advances the game with `physics_frame` is winding a clock
	# this subject never reads. On a 60fps desktop the two ticks interleave 1:1 and the mistake is
	# invisible; CI draws this game at 6-9 fps under a software rasteriser
	# (`.github/workflows/harness.yml:30-33`) while Godot's unoverridden defaults allow eight physics steps
	# per drawn frame (`physics_ticks_per_second` 60, `max_physics_steps_per_frame` 8; `project.godot`
	# sets neither), so a six-await physics loop finished with ZERO `_process` calls behind it. The lesson's
	# clock reported 7.664 -> 7.664 and `active_alpha()` short-circuited to 0.00.
	#
	# THE CLOCK WAS HEALTHY THROUGHOUT, which is what makes this a fixture defect and not a product one:
	# `SHOW_SECONDS` is 9.0 (`hints.gd`) and the layer read 7.664, so 1.336 s had already burned in the
	# arming loop below: the same kind of loop, just long enough to span a drawn frame by accident.
	# **A wait that works only because it is long enough to accidentally contain the tick you meant is not
	# the tick you meant**, and it stops working the moment the box gets slower.
	var hints: Hints = _main._hints
	hud._arrival_life = 0.0
	_main.sim.inventory[&"rope"] = int(_main.sim.inventory.get(&"rope", 0)) + 1
	var armed: bool = false
	for _i: int in 30:
		await RenderingServer.frame_post_draw
		if hints.active_alpha() > 0.9:
			armed = true
			break
	_check(armed, "CONTROL: a lesson reaches full opacity with the announce channel free")
	if not armed:
		return
	var taught: String = hints.active_text()
	var life_before: float = hints._life
	for _i: int in 6:
		await RenderingServer.frame_post_draw
	_check(hints._life < life_before,
		"CONTROL: with no ceremony up, the lesson's clock RUNS (%.3f -> %.3f)"
			% [life_before, hints._life])

	hud.announce("THE CLAYBAND", "10 METRES DOWN", Color(0.7, 0.6, 0.4))
	await RenderingServer.frame_post_draw           # one frame for note_ceremony to reach Hints
	var life_under: float = hints._life
	# THE SAME SIX FRAMES the control above burned, so the freeze is judged against a run of equal length
	# rather than against a shorter one that could not have shown the clock moving anyway.
	for _i: int in 6:
		await RenderingServer.frame_post_draw
	# THE PREMISE OF THE FOUR ASSERTIONS BELOW, ASSERTED. On the render clock this window costs real wall
	# seconds, and the ceremony it is measured under only lives `ARRIVAL_HOLD` = 3.4 of them (`hud.gd`,
	# spent in `hud.gd`). Seven drawn frames is under a second at the 8 fps end of the CI range; the
	# 1.336 s the arming loop burns over a handful of frames says the slowest frame here can cost a third
	# of a second, which puts this window near 2.3 s; inside 3.4, with less room than anything should rely
	# on silently. A plate that expired mid-window would fail all four below for a reason that has nothing
	# to do with the property they are about, so the window reports whether it was valid.
	_check(hud.announcing(),
		"CONTROL: the ceremony is still up at the end of the window measured under it (%.3f s of %.1f left)"
			% [hud._arrival_life, Hud.ARRIVAL_HOLD])
	_check(hints.active_alpha() == 0.0,
		"a lesson draws nothing while the ceremony owns the channel (alpha %.2f)" % hints.active_alpha())
	_check(hints.active_text() == taught,
		"...and it is HELD rather than dropped: the same lesson is still the active one")
	# THIS ONE PASSED VACUOUSLY UNTIL THE AWAITS ABOVE MOVED TO THE RENDER CLOCK. It claims the clock is
	# STOPPED, and it was satisfied by nothing having happened at all: the identical zero `_process` calls
	# that failed its two neighbours. Nothing about it changed here except that it can now fail: it is a
	# live test of `hints.gd`, whose `not _ceremony` guard wraps `_lingered` and `_life` together, over
	# six real `_process` ticks. If it goes red, that guard is the thing to read, not this line.
	_check(is_equal_approx(hints._life, life_under),
		"...with its clock stopped, not burning down unseen (%.3f -> %.3f)" % [life_under, hints._life])

	hud._arrival_life = 0.0                         # the ceremony ends
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_check(hints.active_alpha() > 0.9 and hints.active_text() == taught,
		"...and the same lesson returns at full opacity once the channel is free (alpha %.2f)"
			% hints.active_alpha())


## UI-06: NO LESSON MAY GROW. A RATCHET, SET FROM MEASUREMENT AND NEVER FROM TASTE.
##
## The ticket asks for *"a capture-reviewed max height/coverage for non-modal lessons"* and guards it with
## *"do not treat panel area alone as an aesthetic score"*. So this caps the bubble and claims nothing
## about whether the bubble is good. It is a floor under a regression, not a verdict on a design.
##
## **61px is three drawn lines at size 11, and it is where the game already is**, measured across all
## nineteen lessons after the UI-05 cuts, worst case `rope`/`torch`/`generator` at exactly 61.0. A fourth
## line is 77px, so this fails the moment any lesson grows one. It was 77, then 61; it is 52 now. Every
## move has been DOWNWARD and every one followed the subject: this time the bubble dropped to 8pt over a
## 176px wrap and the lessons were rewritten to one line each, which took the tallest from 61px to a
## measured 47px and canvas coverage to 3.92%. A ceiling is lowered by measurement and never raised to
## buy green; raising it is the change that made the tutorial bigger, wearing a calibration's costume.
##
## **WIDTH IS NOT ASSERTED, DELIBERATELY.** `hint_box` clamps to `HINT_WRAP + 16`, so every lesson at or
## near the cap reports that number by construction and a width assertion could not fail for any string;
## it would be a guard written in a quantity that cannot exceed its own bound. Height is the axis the text
## can actually push on.
##
## This paragraph used to say `HINT_WRAP + 20` and `250.0`, which was 230 + 20: both halves were transcribed
## as literals when the wrap was 230 and the pad was 20, and neither followed when the bubble was rebuilt at
## 176 + 16. The reasoning survived the change and the arithmetic did not, which is the failure mode of any
## number written into prose instead of derived: quote the CONSTANTS, not their product.
const LESSON_MAX_H: float = 52.0

func _check_lesson_footprint() -> void:
	var font: Font = ThemeDB.fallback_font
	var hints: Hints = _main._hints
	if hints == null:
		_check(false, "there is a hint system whose lessons can be measured")
		return
	var texts: Array[Array] = []
	for d: Dictionary in hints._defs:
		texts.append([String(d["id"]), String(d["text"])])
	for m: Dictionary in hints._moments:
		texts.append([String(m["id"]), String(m["text"])])
	_check(texts.size() >= 15,
		"there are %d lessons to measure (if this collapses, everything below passes empty)" % texts.size())
	var over: Array[String] = []
	var tallest: float = 0.0
	var widest_cover: float = 0.0
	var worst_id: String = ""
	for t: Array in texts:
		var box: Vector2 = Hud.hint_box(font, String(t[1]))
		var cover: float = box.x * box.y / (Hud.CANVAS.x * Hud.CANVAS.y)
		if box.y > tallest:
			tallest = box.y
		if cover > widest_cover:
			widest_cover = cover
			worst_id = String(t[0])
		if box.y > LESSON_MAX_H:
			over.append("%s %.0fpx" % [t[0], box.y])
	print("    lessons: %d measured, tallest %.0fpx (ceiling %.0f), largest %.2f%% of canvas (%s)"
		% [texts.size(), tallest, LESSON_MAX_H, widest_cover * 100.0, worst_id])
	_check(over.is_empty(), "every lesson fits the %.0fpx tutorial ceiling%s"
		% [LESSON_MAX_H, "" if over.is_empty() else " — OVER: " + ", ".join(over)])
	# THE CONTROL. Without it the line above is a claim that the strings are short, dressed as a claim that
	# the measurement works. A fourth line must be visible to the same function that judges the real ones.
	var stretched: String = String(texts[0][1]) + " And then a further sentence, long enough that this "
	stretched += "cannot possibly fit in the same three lines the real lessons fit in."
	_check(Hud.hint_box(font, stretched).y > LESSON_MAX_H,
		"CONTROL: a deliberately over-long lesson measures %.0fpx and would fail this ceiling"
			% Hud.hint_box(font, stretched).y)
	_check(tallest <= LESSON_MAX_H and Hud.hint_box(font, "x").y < LESSON_MAX_H,
		"CONTROL: a one-word lesson measures %.0fpx, so the ceiling is not simply above everything"
			% Hud.hint_box(font, "x").y)


## UI-07: THE HELPER INVENTORY HAS TO BE TOTAL OR IT IS DECORATION.
##
## `Hud.HELPER_TAGS` classifies every surface as critical/active/discoverable/ambient (or `internal` for a
## drawing helper that is not a screen). A tag table that the code can drift away from is worth nothing, so
## this asserts BOTH directions against the live method list: every `_draw*` the class actually has is
## classified, and every name in the table still exists. **Adding a surface without deciding what kind of
## thing it is fails here rather than quietly becoming the eighth thing on the screen.**
func _check_helper_registry() -> void:
	var hud: Hud = _main._hud
	var found: Array[String] = []
	# The Hud AND every page object it delegates drawing to. A surface does not stop being a surface by
	# moving to its own file, and a hand-written list of those files is the wrong instrument: it has to be
	# edited on the same commit that would otherwise be caught, so it fails exactly when it is needed. The
	# list is derived instead, from whatever the Hud is holding, so a page added tomorrow is enumerated
	# without anyone remembering to come back here.
	var surfaces: Array = [hud]
	# Walk transitively, because a page may now hold a page: the research ladder is a `BazaarBench` held
	# by the `BazaarPage` held by the Hud, and a one-level sweep stops one short of it. Appending to the
	# array being walked is the whole trick — each surface found is itself searched — and `has` does
	# double duty as the de-duplicator and the cycle break.
	var at: int = 0
	while at < surfaces.size():
		var owner_obj: Object = surfaces[at]
		at += 1
		for prop: Dictionary in owner_obj.get_property_list():
			if int(prop["type"]) != TYPE_OBJECT:
				continue
			var held: Object = owner_obj.get(String(prop["name"])) as Object
			# Script-backed only. Every RefCounted one of these holds includes its `Font`, and engine
			# resources carry private `_draw_rect`-shaped methods of their own that nobody here should be
			# classifying. A page is one of ours, and one of ours has a script.
			if held != null and held is RefCounted and held.get_script() != null and not surfaces.has(held):
				surfaces.append(held)
	for obj: Object in surfaces:
		for m: Dictionary in obj.get_method_list():
			var n: String = String(m["name"])
			if n.begins_with("_draw") and not found.has(n):
				found.append(n)
	_check(found.size() >= 20,
		"the HUD reports %d _draw* methods to classify (if this collapses, everything below passes empty)"
			% found.size())
	var untagged: Array[String] = []
	for n: String in found:
		if not Hud.HELPER_TAGS.has(n):
			untagged.append(n)
	_check(untagged.is_empty(), "every drawing surface is classified by UI-07%s"
		% ("" if untagged.is_empty() else " — UNTAGGED: " + ", ".join(untagged)))
	var stale: Array[String] = []
	for k: Variant in Hud.HELPER_TAGS.keys():
		if not found.has(String(k)):
			stale.append(String(k))
	_check(stale.is_empty(), "...and the table names nothing that has been deleted%s"
		% ("" if stale.is_empty() else " — STALE: " + ", ".join(stale)))
	var tally: Dictionary = {}
	for k: Variant in Hud.HELPER_TAGS.keys():
		var t: String = String(Hud.HELPER_TAGS[k])
		tally[t] = int(tally.get(t, 0)) + 1
	var parts: Array[String] = []
	for t: Variant in ["critical", "active", "discoverable", "ambient", "internal"]:
		parts.append("%s %d" % [t, int(tally.get(t, 0))])
	print("    helpers: " + " · ".join(parts))
	_check(int(tally.get("critical", 0)) >= 3 and int(tally.get("ambient", 0)) >= 3,
		"CONTROL: the tags are actually distributed, not all one bucket (%s)" % " ".join(parts))
	# THE ONE RULE UI-07 ACTUALLY STATES, checked where it can be checked from constants: the PAUSED chip
	# and the arrival plate are both `critical` and both aim at the upper-middle strip. The matrix row
	# "PAUSED during a stratum arrival" is the empirical form of this; this is the arithmetic form, and it
	# fails the moment either constant is nudged back into the other.
	var chip: Rect2 = Hud.PAUSED_CHIP
	var plate_top: float = Hud.CANVAS.y * 0.26 - Hud.SCRIM_ABOVE
	var plate_bot: float = Hud.CANVAS.y * 0.26 + Hud.SCRIM_BELOW
	# THE PLATE IS CENTRED AND ITS WIDTH IS ITS TEXT, so the box is built from the WIDEST BAND NAME THE
	# GAME CAN ANNOUNCE, measured with the HUD's own `_tracked_w` at the HUD's own constants. The first
	# version of this used "nearly the whole centre column" as a generous bound (600px wide) and failed a
	# chip sitting at x 10..114, in a column the plate cannot reach at any text length. **A bound invented
	# to be safe is not conservative, it is wrong in a direction that feels responsible**, and it condemns
	# real estate that was never contested.
	var widest: float = 0.0
	var widest_name: String = ""
	for b: Dictionary in Strata.BANDS:
		var w: float = hud._tracked_w(String(b["name"]), Hud.ARRIVAL_SIZE, Hud.ARRIVAL_TRACK)
		if w > widest:
			widest = w
			widest_name = String(b["name"])
	var core_half: float = widest * 0.5 + Hud.SCRIM_PAD
	var plate := Rect2(Hud.CANVAS.x * 0.5 - core_half, plate_top, core_half * 2.0, plate_bot - plate_top)
	print("    widest arrival plate: \"%s\" -> %.0fpx of text, core %s" % [widest_name, widest, plate])
	_check(widest > 40.0, "CONTROL: the widest band name measures %.0fpx (a zero here empties the check)"
		% widest)
	_check(not chip.intersects(plate),
		"the PAUSED chip %s clears the arrival plate's widest possible core %s — two criticals, one strip"
			% [chip, plate])


## Panels whose centre sits in the band the arrival plate occupies. The objective line is top-centre too
## but ends around y 48, well above `CANVAS.y * 0.26 - 40`, so the band contains the ceremony and nothing
## else on any state this function drives.
func _in_ceremony_band(rects: Array[Rect2]) -> Array[Rect2]:
	var hit: Array[Rect2] = []
	for r: Rect2 in rects:
		var cy: float = r.position.y + r.size.y * 0.5
		if cy >= CEREMONY_BAND_TOP and cy <= CEREMONY_BAND_BOT:
			hit.append(r)
	return hit


## Draw `n` frames with the probe armed and return what the last one registered.
func _probe_frames(n: int) -> Array[Rect2]:
	Hud.probing = true
	Hud.panel_probe = ([] as Array[Rect2])
	for i: int in n:
		if i == n - 1:
			Hud.panel_probe = ([] as Array[Rect2])
		await RenderingServer.frame_post_draw
	var out: Array[Rect2] = Hud.panel_probe.duplicate()
	Hud.probing = false
	Hud.panel_probe = ([] as Array[Rect2])
	return out


func _check_probe_is_off() -> void:
	_check(not Hud.probing, "the probe flag is off once the matrix has finished with it")
	Hud.panel_probe = ([] as Array[Rect2])
	Hud.hotbar_probe = {}
	for _i: int in 3:
		await RenderingServer.frame_post_draw
	var leaked: int = Hud.panel_probe.size()
	var leaked_bar: bool = not Hud.hotbar_probe.is_empty()

	# POSITIVE CONTROL: the same three frames with the flag on.
	Hud.probing = true
	Hud.panel_probe = ([] as Array[Rect2])
	Hud.hotbar_probe = {}
	for _i: int in 3:
		await RenderingServer.frame_post_draw
	var recorded: int = Hud.panel_probe.size()
	var recorded_bar: bool = not Hud.hotbar_probe.is_empty()
	Hud.probing = false
	Hud.panel_probe = ([] as Array[Rect2])
	Hud.hotbar_probe = {}

	_check(recorded > 0 and recorded_bar,
		"the probe records while it is on — %d panels, hotbar %s (if this fails the check below means nothing)"
			% [recorded, "yes" if recorded_bar else "no"])
	_check(leaked == 0 and not leaked_bar,
		"...and records NOTHING while it is off — %d panels, hotbar %s"
			% [leaked, "yes" if leaked_bar else "no"])


## GEOMETRY, BECAUSE A COUNT WAS WORTH NOTHING. The probe used to report how many wells the loop drew, and
## the loop drew one per iteration unconditionally, so the number was `n` restated, decided by `clampi`
## before a pixel moved. The failure this is really guarding against is positional: derive each well's `sx`
## from the PACK index instead of the WINDOW slot (one character, and the same mistake the name plate
## actually shipped with) and the wells march off their own backing and off the canvas while every count
## in the file stays exactly right.
func _wells_are_sane(probe: Dictionary) -> bool:
	var wells: Array = probe.get("wells", []) as Array
	var back: Rect2 = (probe.get("backing", Rect2()) as Rect2).grow(TOUCH)
	if wells.is_empty():
		return false
	for i: int in wells.size():
		var a: Rect2 = wells[i] as Rect2
		if a.size.x <= 0.0 or a.size.y <= 0.0:
			return false
		if not back.encloses(a):
			return false
		if a.position.x < -TOUCH or a.position.x + a.size.x > Hud.CANVAS.x + TOUCH:
			return false
		for j: int in range(i + 1, wells.size()):
			var over: Rect2 = a.intersection(wells[j] as Rect2)
			if over.size.x > TOUCH and over.size.y > TOUCH:
				return false
	return true


## What went wrong, said in numbers, so a failure does not need a debugger to read.
func _wells_report(probe: Dictionary) -> String:
	var wells: Array = probe.get("wells", []) as Array
	if wells.is_empty():
		return " — NO WELLS DRAWN"
	var first: Rect2 = wells[0] as Rect2
	var last: Rect2 = wells[wells.size() - 1] as Rect2
	return " — %d wells, x %.0f..%.0f, backing %s" % [wells.size(), first.position.x,
		last.position.x + last.size.x, probe.get("backing", Rect2())]


## HOW MUCH OF THE SCREEN THE HUD IS ON, so that "subtraction" stops being an adjective.
##
## T2.1 opens with *"the HUD is currently the art director; ~85-90% of the interface floats above the
## world"* and three of its four lines have now shipped, and **nobody can say whether the HUD got
## smaller.** That is not a small gap in a ticket whose entire verb is *subtract*.
##
## READ THE BOUNDARY BEFORE READING THE NUMBER, because they are not the same claim. `panel_probe` sees
## `_panel()`, `_round_rect()` and the arrival scrim. It does not see bare `draw_rect`/`draw_string`:
## chips, legends, glyphs and text drawn outside any panel. So this measures **the share of the canvas
## covered by HUD PANELS**, which is a LOWER BOUND on the HUD's footprint and is not the ~85-90% figure at
## all: that one is about the composition of the interface (how much of it is screen-space rather than
## diegetic), a different population, and it came from a subjective audit rather than a measurement.
## Nothing here confirms or refutes it. What this gives is a baseline the same instrument can re-measure.
##
## Union area, not summed area; overlapping panels must not be counted twice, and the modal states
## overlap by design. Rasterised at 1px on the 640x360 canvas, so it is exact rather than sampled.
func _covered_fraction(rects: Array[Rect2]) -> float:
	var w: int = int(Hud.CANVAS.x)
	var h: int = int(Hud.CANVAS.y)
	var mask := PackedByteArray()
	mask.resize(w * h)
	for r: Rect2 in rects:
		var x0: int = clampi(int(floor(r.position.x)), 0, w)
		var x1: int = clampi(int(ceil(r.position.x + r.size.x)), 0, w)
		var y0: int = clampi(int(floor(r.position.y)), 0, h)
		var y1: int = clampi(int(ceil(r.position.y + r.size.y)), 0, h)
		for y: int in range(y0, y1):
			var row: int = y * w
			for x: int in range(x0, x1):
				mask[row + x] = 1
	var on: int = 0
	for i: int in mask.size():
		on += mask[i]
	return float(on) / float(w * h)


## THE RATCHET, and it is a ratchet on purpose.
##
## The floor below is not a guess about what a good HUD costs; this project has been wrong four times
## running guessing a threshold before playing the thing. It is the footprint MEASURED on the day the
## three shipped subtractions landed, written down so that the next change has to say which direction it
## went. It may be LOWERED by measurement after a real subtraction. It must never be raised to buy green:
## raising it is the change that made the HUD bigger, wearing the costume of a calibration.
##
## Only the bare screen is held. The modal states are supposed to cover the screen (that is what a modal
## is) and ratcheting them would be asserting that the Bazaar must not grow, which is not a thing anyone
## has decided.
##
## THE NUMBER: measured 7.83% on three consecutive runs, identical to the digit. The ceiling is 8.0%, and
## the 0.17pp of headroom is for ONE stated reason: the goal plate and the inspector size themselves to
## their TEXT, so a machine whose fallback font metrics differ by a pixel moves this without anything
## having changed. It is not slack for a new panel: the smallest panel in the bare screen is worth more
## than 0.17pp on its own, so anything added still fails.
const BARE_FOOTPRINT_CEILING: float = 0.080


func _report_footprint(names: Array[String], fracs: Array[float]) -> void:
	# THE BOUNDARY PRINTS BESIDE THE NUMBERS, not only in this file. A lower bound that
	# appears next to a subjective composition claim gets read as measuring it however carefully the comment
	# is written, and nobody who reads a harness log is holding the source.
	print("    footprint = union area of HUD PANELS / canvas. Panels only — bare draw_rect/draw_string")
	print("    (chips, legends, glyphs, loose text) are NOT counted, so each figure is a LOWER BOUND.")
	print("    NOT a test of \"~85-90% of the interface floats above the world\": that is composition")
	print("    (screen-space vs diegetic), a different population, from a subjective audit.")
	for i: int in names.size():
		print("    footprint  %6.2f%%  %s" % [fracs[i] * 100.0, names[i]])
	var bare: float = -1.0
	for i: int in names.size():
		if names[i] == "the bare screen":
			bare = fracs[i]
	_check(bare >= 0.0, "the bare screen was measured for footprint")
	# POSITIVE CONTROL. A ceiling is satisfied perfectly by a probe that recorded nothing.
	_check(bare > 0.0, "...and it is not zero (%.1f%% of the canvas is HUD panel)" % [bare * 100.0])
	# ...AND THE INSTRUMENT SEPARATES ONE SCREEN FROM ANOTHER, which the ceiling alone cannot show. A
	# modal is DEFINED as an overlay that covers the furniture, so every modal must cover more canvas than
	# the bare screen. That is a definitional property rather than a tuned one: no number to calibrate,
	# and it fails the moment the probe stops seeing a modal or starts reporting the same rects for
	# everything. Without it, a probe frozen on one state would satisfy every other assertion here.
	var quiet: Array[String] = []
	for i: int in names.size():
		if names[i].begins_with("the Bazaar") or names[i].begins_with("the dashboard") \
				or names[i].begins_with("the help") or names[i].begins_with("settings"):
			if fracs[i] <= bare:
				quiet.append("%s at %.2f%%" % [names[i], fracs[i] * 100.0])
	_check(quiet.is_empty(), "...and every modal covers more than the bare screen%s"
		% ["" if quiet.is_empty() else " — NOT: " + ", ".join(quiet)])
	_check(bare <= BARE_FOOTPRINT_CEILING,
		"...and no larger than the day the T2.1 subtractions landed (%.2f%% vs ceiling %.2f%%)"
			% [bare * 100.0, BARE_FOOTPRINT_CEILING * 100.0])



## A MODAL IS ALLOWED TO COVER THE FURNITURE. IT IS NOT ALLOWED TO COVER ITSELF.
##
## The sweep in `_run` skips overlap on every row marked `modal`, and the reason it gives is sound as far
## as it goes: an overlay that did not sit over the depth chip and the pack bar would not be an overlay.
## But the exemption is written at the STATE level while the thing it excuses is a RELATIONSHIP (overlay
## against furniture), so it also excuses the overlay against its own parts, which nothing excuses. The
## largest panel in the game has therefore been exempt from the only assertion this file is named for.
##
## What was hiding there is in the counter's left rail. Each tab draws a 38x38 tile, a word under it, and
## the key that selects it as a cap at `y + 51`; the cap is 14 tall, so it ends at `y + 65`, and the next
## tile begins at `y + pitch`. `_rail_slots` caps the pitch at 58. The cap of every slot therefore lands
## inside the footprint of the slot below it at EVERY panel height the counter has, and the only reason
## the screen does not always show it is that an unselected tile draws no fill. Select BENCH and the lit
## tile paints over the bottom half of the `2` that selects WORKS: measured here at 14x7 of a 14x14 cap.
## Select WORKS and the same 14x7 comes off the `1`. On the short PACK page the pitch falls to 40 and a
## cap sits WHOLLY inside the tile beneath it, which a rect probe cannot see because that tile is unlit.
##
## THE POPULATION WAS NEVER THE PROBLEM, which is worth saying because it is the diagnosis that would have
## sent a fix to the wrong place. `_round_rect` registers with `panel_probe` (`hud.gd`) and the rail's
## tiles and caps are all `_round_rect`, so every rect named above was in the array the matrix collected
## and the matrix simply never compared them. The second half of the blindness is the fixture rather than
## the predicate: the matrix opens the counter and never touches `bazaar_tab`, so it only ever photographs
## PACK, the one tab of three whose lit tile is the topmost and has no cap above it to slice.
##
## WHAT THIS CHECKS AND WHAT IT CANNOT. It judges the rail COLUMN, `BAZAAR_RAIL` wide off the counter's own
## left edge, on all three tabs, and it judges the rects the HUD drew rather than a second copy of
## `_rail_slots`; a layout test that recomputes the layout agrees with itself no matter where the pixels
## went, and the counter has already paid for that once. Two things it cannot see, stated so nobody reads
## the green as wider than it is. It cannot see an unlit tile, so the PACK row can only ever report the
## caps against each other and passes today with the same geometry fault present. And the SETTINGS rail,
## the other caller of `_rail_slots` and the one that passes a pitch floor, draws its number inside its
## word instead of as a cap, so its column holds one rect and the same check over it would be vacuous.
##
## The drop shadow is the one overlap here that is not a defect: `_keycap` draws the cap twice, once a
## pixel lower in black. Same size, one pixel apart, and nothing else in this column is, so it is excused
## by that description rather than by a containment rule: a cap swallowed WHOLE by the tile below it is
## the worst form of this bug and a containment rule would wave it through.
##
## The column is the counter's own left band and it is bounded by the counter, which has a consequence the
## census below is written to expose: a slot pushed past the bottom edge of the panel leaves the column
## rather than colliding inside it, so it arrives as a SHORT COUNT and not as a quiet pass. That is not a
## hypothetical reading of the guard. Raising the pitch far enough to clear the caps is what does it: the
## rail then asks for more height than the counter has on its shortest page, and the census is the line
## that says so.
const SHADOW_SLOP: float = 1.5
## Three tiles, three caps, three cap shadows, minus the two tiles the selected tab does not light. It is
## the rail's census and not a floor picked to be survivable: a redesign that changes what a slot is made
## of has to come back here and re-derive it, because a number lowered to whatever the new rail happens to
## draw would be agreeing with the rail instead of measuring it.
const RAIL_MIN_RECTS: int = 7


func _check_bazaar_rail() -> void:
	for tab: int in Hud.TAB_NAMES.size():
		var name: String = Hud.TAB_NAMES[tab]
		var shot: Dictionary = await _bazaar_shot(tab)
		var rects: Array[Rect2] = shot["rects"]
		var plate := Rect2()
		for r: Rect2 in rects:
			if r.get_area() > plate.get_area():
				plate = r
		var column := Rect2(plate.position, Vector2(Hud.BAZAAR_RAIL, plate.size.y))
		var rail: Array[Rect2] = []
		for r: Rect2 in rects:
			if column.grow(TOUCH).encloses(r):
				rail.append(r)

		_check(bool(shot["settled"]),
			"the %s counter stopped moving before it was measured (%.2fpx from its asking height)"
				% [name, float(shot["drift"])])
		# NON-VACUITY. Everything below is perfectly true of an empty column, which is what a counter that
		# failed to open, a probe that was never armed, and a rail that stopped drawing all produce.
		_check(rail.size() >= RAIL_MIN_RECTS,
			"the %s rail drew %d boxes in the counter's %.0fpx left column (at least %d — short means the"
				% [name, rail.size(), Hud.BAZAAR_RAIL, RAIL_MIN_RECTS]
				+ " counter never opened, or a slot has been pushed off the bottom of it)")

		# ...AND THE SUBJECT IS PRESENT. The collision needs a LIT tile, and lighting is the one thing in
		# this column that varies. Stated as "one box is bigger than every other" rather than against a
		# size, because the caps are all identical to each other: with nothing lit the largest box in the
		# column ties, and with a tile lit it does not.
		var lit := Rect2()
		var runner_up: float = 0.0
		for r: Rect2 in rail:
			if r.get_area() > lit.get_area():
				runner_up = lit.get_area()
				lit = r
			elif r.get_area() > runner_up:
				runner_up = r.get_area()
		_check(lit.get_area() > runner_up,
			"...and %s is the lit tab, so one box in the column is larger than the rest (%s)"
				% [name, lit])

		var hits: Array[String] = _rail_slices(rail)
		_check(hits.is_empty(), "the %s rail's %d boxes do not print over each other%s"
			% [name, rail.size(), "" if hits.is_empty() else " — " + "; ".join(hits)])

		# THE REJECTION CONTROL, and it ADDS a box rather than moving one. Displacing a rect can delete a
		# collision it was already in as it creates a new one, which nets to zero and reads as a control
		# that could not catch anything; this file has that mistake written into it one function up. A
		# cap-sized box on the lit tile's centre lands clear of the caps above and below it, so the count
		# must go up by exactly one, on the clean tabs and the dirty ones alike.
		var cap := Vector2(lit.size)
		for r: Rect2 in rail:
			if r.get_area() < cap.x * cap.y:
				cap = r.size
		var planted: Array[Rect2] = rail.duplicate()
		planted.append(Rect2(lit.get_center() - cap * 0.5, cap))
		var caught: int = _rail_slices(planted).size()
		_check(caught == hits.size() + 1,
			"...and the same sweep catches one more once a %.0fx%.0f box is dropped on the tile (%d -> %d)"
				% [cap.x, cap.y, hits.size(), caught])

	_main._inventory_open = false
	_main._hud.set_bazaar_tab(Hud.TAB_PACK)
	await RenderingServer.frame_post_draw


## Every pair in a rail column that shares more than a border, described. The cap's own drop shadow is the
## single legitimate overlap and it is recognised by what it IS (the same box, within a pixel), so no
## other overlap can arrive under its cover.
func _rail_slices(rail: Array[Rect2]) -> Array[String]:
	var out: Array[String] = []
	for i: int in rail.size():
		for j: int in range(i + 1, rail.size()):
			var a: Rect2 = rail[i]
			var b: Rect2 = rail[j]
			var over: Rect2 = a.intersection(b)
			if over.size.x <= TOUCH or over.size.y <= TOUCH:
				continue
			if a.size.is_equal_approx(b.size) \
					and a.position.distance_to(b.position) <= SHADOW_SLOP:
				continue
			out.append("%s x %s (overlap %.0fx%.0f)" % [a, b, over.size.x, over.size.y])
	return out


## The counter open on one tab, settled, and the boxes one drawn frame of it registered.
##
## The tab is set on the HUD and not on MainView because that is where it lives: main.gd calls
## `set_bazaar_tab` from the key handler and never pushes the field back, so posing it here is posing the
## real thing rather than a value its owner overwrites. The height is WAITED FOR rather than counted out
## in frames: `_bazaar_h` eases toward whatever the open tab asks for, the rail's pitch is bought out of
## that height, and a rail read mid-ease is a measurement of the shutter speed and not of the layout.
func _bazaar_shot(tab: int) -> Dictionary:
	_main._paused = false
	_main._inventory_open = true
	_main._minimap_mode = 0
	_main._show_help = false
	_main._show_dashboard = false
	_main._settings_open = false
	var hud: Hud = _main._hud
	hud.set_bazaar_tab(tab)
	for _i: int in 3:
		await RenderingServer.frame_post_draw
	# Re-set after the settle frames: those run real input handling, and a stray key or wheel event on a
	# machine somebody is using would move the tab out from under the shot.
	hud.set_bazaar_tab(tab)
	var settled: bool = false
	var drift: float = 0.0
	for _i: int in SETTLE_FRAMES:
		drift = absf(hud._bazaar_h - hud._bazaar_wanted_h())
		if drift < 0.5:
			settled = true
			break
		await RenderingServer.frame_post_draw
	drift = absf(hud._bazaar_h - hud._bazaar_wanted_h())
	# The pointer is parked off the counter for the same reason `_snapshot` parks it: this layer runs in a
	# real window, and a hand resting over the rail would light a tile the fixture did not ask for.
	Controls.pose_pointer(_main.get_viewport().get_canvas_transform().affine_inverse()
		* Vector2(2.0, 2.0))
	Hud.probing = true
	Hud.panel_probe = ([] as Array[Rect2])
	await RenderingServer.frame_post_draw
	var out: Array[Rect2] = Hud.panel_probe.duplicate()
	Hud.probing = false
	Hud.panel_probe = ([] as Array[Rect2])
	return {"rects": out, "settled": settled, "drift": drift}
