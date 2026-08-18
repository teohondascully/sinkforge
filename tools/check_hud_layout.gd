extends "res://tools/check_base.gd"

## THE HUD MUST NOT PRINT ON TOP OF ITSELF, OR OFF THE EDGE OF THE SCREEN.
##
## COMPREHENSIVE_AUDIT §413 asks for exactly this and nothing in the suite provides it: a scripted matrix
## of HUD states — title, arrival, hint, alert, hover, pause, Bazaar — with zero bounding-box overlap and
## zero clipping. Every other legibility layer we have judges PIXELS; this one judges GEOMETRY, which is
## the half that breaks silently. Two chips that collide still render, still look deliberate in a
## screenshot, and simply hide each other's text.
##
## And the risk is not hypothetical, it is structural. Reading `Hud._draw()`, three pairs are aimed at the
## same corner by design:
##
##   top-left     the depth readout AND the "▶▶ Nx" fast-forward chip
##   top-right    the FORGED counter AND the machine inspector, which is documented as sitting "under"
##                it — a relationship maintained by two independent constants
##   top-centre   the objective line AND the PAUSED chip
##
## Each of those is fine at the sizes they happen to have today. Each is one longer string from
## overlapping, and the depth chip and the FORGED chip both size themselves to their CONTENTS.
##
## HOW IT OBSERVES. The HUD is immediate-mode — no Control nodes, nothing to read off the scene tree — so
## `Hud.panel_probe` collects the rects `_panel()` actually drew. That matters more than it sounds: a
## layout test that re-derives where each chip goes is checking its own arithmetic against itself and
## would agree perfectly with a HUD that draws somewhere else entirely.
##
## WHAT IT ASSERTS, and the distinction is deliberate:
##
##   CLIPPING, in every state.   No panel may extend past the canvas, ever. A modal is allowed to cover
##                               the furniture; nothing is allowed to fall off the screen.
##   OVERLAP, only unmodal.      A Bazaar/help/settings overlay is SUPPOSED to sit over the furniture —
##                               that is what an overlay is. Asserting no-overlap there would fail the
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
	# is not judged there — see the header. Everything is judged for clipping.
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
		# hidden -> corner -> LARGE (main.gd:1012) and only a 2 sets `minimap_large` (main.gd:778); this
		# matrix shipped with a 1 and nothing else in the file ever wrote a 2. NOT modal: an overlay is
		# allowed to cover furniture, and the big map's rule is the opposite — the furniture stands down
		# for IT (hud.gd:696). So it must face the same collision sweep as the bare screen.
		{"name": "the BIG map up (M twice)", "modal": false, "set": {"_minimap_mode": 2},
			"keep": "big_map"},
		# The ceremony against the LARGE map. The corner form clears it (measured: no collision), but the
		# large form spans x 181..459 / y 41..319 and the arrival plate sits centred at y ~62..112 — so
		# this is where "zone ceremony colliding with map" would actually bite, if it bites anywhere.
		{"name": "a stratum arrival, BIG map up", "modal": false, "set": {"_minimap_mode": 2},
			"announce": true, "twin": "the BIG map up (M twice)"},
		# ...and the big map WITH a machine hovered. The inspector is right-anchored and its width has a
		# 218px floor (hud.gd:831), so its left edge is at most 640-218-12 = 410 against a large map
		# spanning x 181..459. `hud.gd:837` asserts in prose that "the large map is centred, off this
		# column — so the inspector never collides"; that is false for a 128-wide world, and this row is
		# what makes the claim answerable instead of asserted.
		# EXPECTED TWIN of the row above, and declared rather than tolerated: once the inspector stands
		# down under the large map, these two states draw the same screen BY DESIGN. That is the fix, so
		# the states-differ check is told about it here instead of being loosened for everyone.
		{"name": "the BIG map WITH a machine hovered", "modal": false, "set": {"_minimap_mode": 2},
			"hover": true, "keep": "big_hover", "twin": "the BIG map up (M twice)"},
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
	# to differ from each other too — if they all reported the same panels, the matrix would be one state
	# tested eleven times.
	_check_help_text()
	_check_big_map(bare, big)
	_check_hover(bare, hover, big_hover)
	await _check_pack_window()
	await _check_probe_is_off()

	_check(total_panels >= states.size() * 2,
		"the matrix drew %d panels across %d states, so there was geometry to judge"
			% [total_panels, states.size()])

	# ...AND THE STATES ACTUALLY DIFFER, which the paragraph above has always PROMISED and nothing has ever
	# CHECKED. "If they all reported the same panels, the matrix would be one state tested eleven times" was
	# the stated reason for the panel-count floor — but a count cannot tell one screen from eleven copies of
	# it, and ~50 panels clears a floor of 20 whether or not any state is distinct. Two of these rows were
	# in exactly that condition until this commit: both "hover" rows drew the bare screen, because the
	# latch they set was overwritten before the frame.
	# Declared identities are resolved to a GROUP rather than checked pairwise. Three states now draw the
	# same screen by design — the big map alone, with a machine hovered, and with a stratum arrival held —
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

	_main.queue_free()
	await physics_frame


## THE BIG MAP IS THE SCREEN, so nothing may be left under it — and nothing may be left HALF under it.
##
## This layer already CAUGHT this, once, and then stopped being able to. A real failing log
## (`the working notes`) named two collisions against the large map; the banner was fixed by
## standing it down at `hud.gd:699`, and the second — a 46x44 panel at (297,295), overlap 46x24 — was left
## as an open lead: *"either that panel moved, or it is state-dependent and the current fixture no longer
## samples it."* It is the second. The panel is `_draw_inventory`'s backing at ONE slot
## (`hud.gd:2292`: x0 = (640-30)/2 = 305, so Rect2(297, 295, 46, 44)), drawn unconditionally at
## `hud.gd:263`. It never moved. The matrix asked for `_minimap_mode` **1**, which is the CORNER map —
## 122x122 in the top-right, 142px clear of the bar — so the state that collides was never entered.
##
## THE FIX TO THE FIRST COLLISION IS WHAT HID THE SECOND. Once the banner stood down the sweep went green,
## and a green sweep is indistinguishable from a sweep that is no longer looking.
##
## WHY THIS IS NAMED RATHER THAN LEFT TO THE GENERIC SWEEP ABOVE. That sweep judges whatever a state
## HAPPENED to draw, so it also passes the moment a panel stops being drawn at all — and `_draw_minimap`
## returns before its first `_panel()` when the sim or the colour callable is unbound (`hud.gd:977-978`).
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

	# D. THE GOAL PLATE STANDS DOWN (`hud.gd:699-700`). That guard has never once executed under test:
	#    `minimap_large` comes only from `_minimap_mode == 2` (main.gd:778) and no fixture reached a 2, so
	#    deleting it would have been invisible. Proved by DIFFERENCE in both directions — absence alone
	#    proves nothing, because the plate legitimately hides itself when the chain is finished
	#    (`hud.gd:690`) or once `goal_a` has decayed (`hud.gd:724`, `:728`).
	var plate: Rect2 = _goal_plate(bare)
	_check(plate.size.y >= MIN_PANEL,
		"the bare screen drew the goal plate at top-centre (%s) — there was something to suppress" % plate)
	var survivor: Rect2 = _goal_plate(big)
	_check(survivor.size.y < MIN_PANEL,
		"the big map suppresses the goal plate (found %s)" % survivor)


## THE MACHINE INSPECTOR — the panel this matrix has claimed to judge since it was written, and never has.
##
## Two rows carry `"hover": true`. Both were inert: they set `_main._hover_latch`, which main.gd:770-774
## overwrites from `_aim` every frame. So the inspector was never drawn under test, and what WAS drawn
## depended on the operator's real mouse. `_snapshot` now warps the cursor onto the probe machine instead,
## and this proves the warp WORKED — because a hover fixture that silently fails to hover is the same
## vacuity one level up, and it would make the collision below look fixed.
func _check_hover(bare: Array[Rect2], hover: Array[Rect2], big_hover: Array[Rect2]) -> void:
	# THE FIXTURE DID ITS JOB. The inspector is right-anchored with a 218px width floor (hud.gd:831), so
	# it is the panel hugging the right edge that the bare screen does not have. If this fails, the warp
	# did not take and every verdict below is void — reported as a FIXTURE failure, not as a HUD verdict.
	_check(hover.size() > bare.size(),
		"hovering a machine drew MORE panels than the bare screen (%d vs %d) — the cursor reached it"
			% [hover.size(), bare.size()])
	var panel: Rect2 = _right_edge_panel(hover)
	_check(panel.size.x >= Hud.HOVER_MIN_W - TOUCH,
		"...and the extra panel is the inspector, at its %.0fpx floor or wider (%s)"
			% [Hud.HOVER_MIN_W, panel])

	# THE COLLISION. hud.gd:837 claims the large map "is centred, off this column — so the inspector never
	# collides". The inspector's left edge is at most CANVAS.x - HOVER_MIN_W - 12 = 410; the large map runs
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


## The panel hugging the canvas's right edge, which is the inspector's anchor (hud.gd:840). `Rect2()` if
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


## The objective plate: the ONE panel centred on the canvas at y=8 (`hud.gd:744`). The depth chip is
## left-anchored at x=10 (`:477`), FORGED is right-anchored (`:623`), the fast-forward chip sits at y=34
## (`:602`) and PAUSED at y=50 (`:283`) — so the anchor identifies it and nothing else does. Deliberately
## BLIND TO HEIGHT: the plate is 24px or 37px depending on `step_age` (`hud.gd:743`), and that is the exact
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
	# of these fields into the HUD each frame (main.gd:765-788), so assigning `hud.inventory_open` directly
	# is overwritten before the frame draws — the first version of this layer did exactly that and every
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
	# therefore built "exactly as it is in play". It was not built at all. main.gd:770-774 recomputes
	# `_hover_latch` from `_aim` on every frame, and `_update_mining` refreshes `_aim` from the real OS
	# mouse on every `_process` — unconditionally, pause included (main.gd:709). So the assignment was
	# discarded before the frame drew, and BOTH "hover" rows in the matrix have never once drawn the
	# inspector they exist to judge.
	#
	# The second half is worse than the first. With the latch overwritten, where the aim landed was
	# wherever the operator's mouse happened to be sitting — so those rows did not merely test nothing,
	# they tested something DIFFERENT on every run, on a machine nobody controls. Warping fixes both: the
	# hover rows drive the real aim path, and every other row is pinned to a corner so a stray cursor
	# cannot quietly add an inspector to a state that is supposed to be bare.

	# EXACTLY ONE FRAME. The first version armed the probe and then awaited twice, so the HUD drew twice
	# and every panel was recorded two or three times — which the overlap test dutifully reported as each
	# panel colliding with ITSELF, a screenful of failures that were entirely the instrument.
	for _i: int in 3:
		await RenderingServer.frame_post_draw       # let MainView push the new state into the HUD

	# THE CEREMONY IS SET AFTER THE SETTLE, NOT BEFORE, and that ordering is the whole point.
	# `_arrival_life` is HUD-owned and decays in `Hud._process`, but MainView ANNOUNCES on its own during
	# those settle frames whenever the body crosses a stratum line (main.gd:1248). Clearing before the
	# settle therefore cleared nothing: the plate reappeared on rows that never asked for it, and the bare
	# screen silently gained a sixth panel. That is the same defect as the uncontrolled mouse — a row
	# whose content depends on something the fixture does not own — and it surfaced the moment
	# `_draw_arrival` started registering, having been invisible before.
	# THE CURSOR IS WARPED HERE TOO, AFTER THE SETTLE, FOR THE SAME REASON AND IT WAS NOT ALWAYS.
	# Warping before the settle frames let the body drift under them — at `_time_scale_idx: 3` the sim
	# advances further per frame — so the camera moved after the cursor was placed and the aim no longer
	# landed on the probe machine. That row then drew no inspector and came out byte-identical to the
	# plain fast-forward row, INTERMITTENTLY: it passed on one run and failed on the next, which is worse
	# than a steady failure because the green looks like the answer. Placing the cursor last removes the
	# window in which anything can move underneath it.
	var vp: Viewport = _main.get_viewport()
	if bool(st.get("hover", false)):
		vp.warp_mouse(vp.get_canvas_transform() * _main._cell_center(_probe_cell))
	else:
		vp.warp_mouse(Vector2(2.0, 2.0))
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


## THE TEXT, WHICH A PANEL-RECT TEST CANNOT SEE.
##
## Splitting the CONTROLS card into two columns turned up something the box measurements never could: the
## longest line is ~450px of glyphs at size 11, and the card was 244px wide. That text has ALWAYS spilled
## outside its own panel, over the darkened world behind it — and the panel it overflowed reported a
## perfectly legal rectangle the whole time, which is why every geometry assertion above stayed green
## through it. Two columns would have made it collide with the column beside it.
##
## So the card's lines are held to the column they are drawn in, measured with the same font, the same
## size and the same width constant the drawing code uses — not a copy of them.
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
## `FactorySim.inventory_slots()` has NO CAP — one entry per item type, and the universe is twenty machine
## types plus sixteen materials plus the crafted intermediates. The bar draws ten. Nothing in the suite
## had ever put an eleventh type in the pack, so nothing had ever seen what the eleventh does, and the
## answer was: nothing at all, silently, in a bar whose own comment promises it "grows/shrinks with your
## pack". Reachable on frame one of a dev start — the kit is ten types and the starter pickaxe is an
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

	# The same pack overflowing. The SETUP is that the bar now shows fewer wells than the pack holds — that
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
## real ones — the bar looks up sprites and labels by id, and a made-up id would exercise a drawing path
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
## GDScript — verified against 4.6.2 rather than assumed. So the guard fell open on every frame of every
## real session and the array grew forever, in a static nothing clears. The fix is a real flag; this is
## what stops it falling open again.
##
## The order matters. Asserting "the probe is empty" ALONE passes on a HUD that draws nothing, on a broken
## flag, on a deleted probe — so the flag is turned back ON afterwards and the probe has to FILL. Absence
## is only evidence once the instrument has proved it can detect presence.
func _check_probe_is_off() -> void:
	_check(not Hud.probing, "the probe flag is off once the matrix has finished with it")
	Hud.panel_probe = ([] as Array[Rect2])
	Hud.hotbar_probe = {}
	for _i: int in 3:
		await RenderingServer.frame_post_draw
	var leaked: int = Hud.panel_probe.size()
	var leaked_bar: bool = not Hud.hotbar_probe.is_empty()

	# POSITIVE CONTROL — the same three frames with the flag on.
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
## the loop drew one per iteration unconditionally, so the number was `n` restated — decided by `clampi`
## before a pixel moved. The failure this is really guarding against is positional: derive each well's `sx`
## from the PACK index instead of the WINDOW slot — one character, and the same mistake the name plate
## actually shipped with — and the wells march off their own backing and off the canvas while every count
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
