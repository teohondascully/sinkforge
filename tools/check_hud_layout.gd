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
		{"name": "a machine hovered (the inspector under FORGED)", "modal": false, "set": {}, "hover": true},
		{"name": "running fast AND hovering at once", "modal": false,
			"set": {"_time_scale_idx": 3}, "hover": true},
		{"name": "the minimap up", "modal": false, "set": {"_minimap_mode": 1}},
		# ...and the LARGE form, which no state here has ever produced. `_minimap_mode` cycles
		# hidden -> corner -> LARGE (main.gd:1012) and only a 2 sets `minimap_large` (main.gd:778); this
		# matrix shipped with a 1 and nothing else in the file ever wrote a 2. NOT modal: an overlay is
		# allowed to cover furniture, and the big map's rule is the opposite — the furniture stands down
		# for IT (hud.gd:696). So it must face the same collision sweep as the bare screen.
		{"name": "the BIG map up (M twice)", "modal": false, "set": {"_minimap_mode": 2},
			"keep": "big_map"},
		{"name": "the Bazaar open", "modal": true, "set": {"_inventory_open": true}},
		{"name": "the dashboard open", "modal": true, "set": {"_show_dashboard": true}},
		{"name": "the help overlay", "modal": true, "set": {"_show_help": true}},
		{"name": "settings open", "modal": true, "set": {"_settings_open": true}},
	]

	var total_panels: int = 0
	var bare: Array[Rect2] = []
	var big: Array[Rect2] = []
	for st: Dictionary in states:
		var rects: Array[Rect2] = await _snapshot(hud, st)
		match String(st.get("keep", "")):
			"bare": bare = rects
			"big_map": big = rects
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

	_check(total_panels >= states.size() * 2,
		"the matrix drew %d panels across %d states, so there was geometry to judge"
			% [total_panels, states.size()])

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
	# The inspector is pinned by cell through MainView's own latch, so `hover_info` is built by
	# HoverInfo.describe() exactly as it is in play rather than by a dictionary invented here.
	if bool(st.get("hover", false)):
		_main._hover_latch = _probe_cell

	# EXACTLY ONE FRAME. The first version armed the probe and then awaited twice, so the HUD drew twice
	# and every panel was recorded two or three times — which the overlap test dutifully reported as each
	# panel colliding with ITSELF, a screenful of failures that were entirely the instrument.
	for _i: int in 3:
		await RenderingServer.frame_post_draw       # let MainView push the new state into the HUD
	Hud.panel_probe = ([] as Array[Rect2])
	await RenderingServer.frame_post_draw
	var out: Array[Rect2] = Hud.panel_probe.duplicate()
	Hud.panel_probe = ([] as Array[Rect2])
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
