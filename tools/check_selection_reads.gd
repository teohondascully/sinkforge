extends "res://tools/check_base.gd"

## CAN YOU TELL WHAT IS SELECTED WITH THE COLOUR TAKEN AWAY?
##
##   godot --path . --script res://tools/check_selection_reads.gd
##
## `MNU-32` asks that accessibility be a visual requirement rather than a footnote, and this layer exists
## because of a change that made the requirement sharper. `MNU-06` concentrated "this is the thing you can
## act on" into a single colour and stripped that colour off the seven surfaces wearing it as trim — the
## right rule, and one that puts the game's whole affordance signal into one channel. **If that channel is
## hue, a player who cannot see the hue has lost the affordance, and the tidying made it worse.**
##
## THE MEASUREMENT NEEDS NO ELEMENT-FINDING, which is the reason to prefer it over locating "the selected
## row" in a frame. Locating it means re-deriving the layout inside the instrument, and a layout copy is
## wrong the day the layout moves — this repository has already paid for that once, in a name plate drawn
## at a selection's arithmetic position while the wells were drawn at a clamped one.
##
## Instead: **move the selection, and ask which channels notice.**
##
##   `|B - A|` in RGB    the whole cue
##   `|B - A|` in LUMA   the part of the cue that survives greyscale
##   `|A - A'|`          the floor: the same standing twice, so anything here is the instrument
##
## A cue carried by hue alone collapses to the floor in luminance while staying large in RGB. A cue that is
## also a value change keeps both.
##
## THE CLOCK IS STOPPED ACROSS ALL THREE CAPTURES, not inside each one. The first version froze inside the
## shutter and ran the frames BETWEEN shots at full speed: the floor came back at 117,800 px against a
## signal of 120,608 on the bare screen and the whole arm voided itself. Freezing the shutter does nothing
## about the interval, and the interval is what a floor measures.
##
## AND EACH SURFACE IS MEASURED TWICE, because the unrestricted figure answers a different question than it
## looks like. Moving the counter's cursor also rewrites the DETAIL PLATE — a different name, a different
## sentence, a different icon — and moving the hotbar's rewrites the NAME PLATE. Those are enormous and
## purely luminous, and they swamp the mark on the row itself. **That is not a confound to apologise for: a
## plate that names the selected thing is a better non-colour cue than a spine is.** But it is a different
## claim, so the clipped arm reports the mark alone and the assertion is made on that one.
##
## Measured before the bound was set, six arms, on this build: **99–100% of every cue survives luminance,
## at a peak step near 150 of 255.** The bound is 90%, which is under every observation and far above what
## a hue-only mark would produce.

const SCENE: String = "res://scenes/main.tscn"
const SETTLE: int = 50
const EPS: float = 3.0 / 255.0

## How much of the cue must survive the loss of colour. Set from six measurements at 99–100%, not guessed
## before them — the distinction matters in this repository, where four bounds invented in advance were all
## wrong. A hue-only mark scores near zero here; there is no near-miss region between that and 90%.
const KEEP_MIN: float = 0.90

## The move has to actually move something, or "the cue survives greyscale" is a statement about two
## identical frames. Set well above the floors observed (0–53 px) and well below the smallest real cue
## (6,696 px on the hotbar wells).
const CUE_MIN: int = 800
const FLOOR_MAX: int = 400

var _skipped: bool = false


func _initialize() -> void:
	print("== the selection, with the colour taken away ==")
	await _run()
	if _skipped:
		return
	_verdict("check_selection_reads", "every selection mark is a value change, not only a hue")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_skipped = true
		_skip_layer("check_selection_reads", "no display; moving a cursor between two blank frames "
			+ "changes nothing in either channel, which this layer would read as a cue that is not there")
		return
	MainView.dev_start = false
	MainView.boot_skip_title = true
	var main: MainView = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(main)
	for _i: int in SETTLE:
		await physics_frame

	# Enough carried types that a cursor has somewhere to go. Inventory is sim state and nothing recomputes
	# it per frame, so this pose survives to the draw — unlike `_hud.inventory_open`, which `main.gd`
	# overwrites every `_process`, and which silently defeated an earlier probe of this same panel.
	main.sim.inventory[&"stone"] = 40
	main.sim.inventory[&"coal"] = 12
	main.sim.inventory[&"iron"] = 9
	main.sim.inventory[&"wood"] = 30
	for _i: int in 20:
		await physics_frame

	print("  %-32s %10s %10s %9s %8s" % ["surface", "RGB px", "LUMA px", "peak dY", "kept"])
	await _hotbar(main)
	await _counter(main, Hud.TAB_WORKS, "a WORKS row")
	await _counter(main, Hud.TAB_PACK, "a PACK well")


## The hotbar's lit slot, moved through `MainView._cycle_inventory` — the call the number keys and the
## mouse wheel both land on, rather than a field poked from outside.
func _hotbar(main: MainView) -> void:
	Hud.probing = true          # fills `hotbar_probe`, which is where the clip comes from
	for _i: int in 4:
		await physics_frame
	Engine.time_scale = 0.0
	var a: Image = await _shot()
	main._cycle_inventory(1)
	for _i: int in 4:
		await physics_frame
	var b: Image = await _shot()
	main._cycle_inventory(-1)
	for _i: int in 4:
		await physics_frame
	var c: Image = await _shot()
	Engine.time_scale = 1.0
	var hp: Dictionary = main._hud.hotbar_probe
	Hud.probing = false         # asserted false by default elsewhere: the probe arrays leak otherwise
	_report("the hotbar, whole", a, b, c, Rect2i(), false)
	_check(hp.has("backing"), "the hotbar reported its own geometry, so the wells could be isolated")
	if hp.has("backing"):
		_report("  the lit well alone", a, b, c, _clip(a, hp["backing"] as Rect2), true)


## A counter row, moved through `Hud.bazaar_move` — the method the arrow keys call. `bazaar_row` is HUD
## state and nothing re-pushes it; `_inventory_open` is NOT, so the panel is opened through MainView.
func _counter(main: MainView, tab: int, label: String) -> void:
	main._inventory_open = true
	main._hud.set_bazaar_tab(tab)
	for _i: int in 40:
		await physics_frame
	Engine.time_scale = 0.0
	var a: Image = await _shot()
	main._hud.bazaar_move(0, 1)
	for _i: int in 4:
		await physics_frame
	var b: Image = await _shot()
	main._hud.bazaar_move(0, -1)
	for _i: int in 4:
		await physics_frame
	var c: Image = await _shot()
	Engine.time_scale = 1.0
	_report("the counter, " + label, a, b, c, Rect2i(), false)
	_report("  the mark alone", a, b, c,
		_clip(a, main._hud._bazaar_geometry()["content"] as Rect2), true)
	main._inventory_open = false
	for _i: int in 20:
		await physics_frame


func _report(label: String, a: Image, b: Image, c: Image, clip: Rect2i, assert_it: bool) -> void:
	var moved: Dictionary = _delta(a, b, clip)
	var floor_d: Dictionary = _delta(a, c, clip)
	var rgb: int = int(moved["rgb"])
	var luma: int = int(moved["luma"])
	var kept: float = float(luma) / maxf(float(rgb), 1.0)
	print("  %-32s %10d %10d %9.1f %7.0f%%" % [label, rgb, luma, float(moved["maxy"]) * 255.0, kept * 100.0])
	if not assert_it:
		return
	_check(int(floor_d["rgb"]) <= FLOOR_MAX,
		"%s — the same standing twice is still (%d px changed, cap %d)" % [label, floor_d["rgb"], FLOOR_MAX])
	_check(rgb >= CUE_MIN,
		"%s — moving the cursor drew a different picture (%d px, floor %d)" % [label, rgb, CUE_MIN])
	_check(kept >= KEEP_MIN,
		"%s — the mark survives the loss of colour (%.0f%% of it is luminance, floor %.0f%%)"
			% [label, kept * 100.0, KEEP_MIN * 100.0])


## Everything the move changed, in both channels. A pixel counts as changed in RGB if any channel moved;
## as changed in LUMA only if the perceived brightness did. A mark that swaps one hue for another of the
## same value scores high on the first and at the floor on the second, which is the whole point.
func _delta(a: Image, b: Image, clip: Rect2i) -> Dictionary:
	var rgb: int = 0
	var luma: int = 0
	var maxy: float = 0.0
	var x0: int = 0
	var y0: int = 0
	var x1: int = a.get_width()
	var y1: int = a.get_height()
	if clip.size.x > 0 and clip.size.y > 0:
		x0 = maxi(0, clip.position.x)
		y0 = maxi(0, clip.position.y)
		x1 = mini(x1, clip.position.x + clip.size.x)
		y1 = mini(y1, clip.position.y + clip.size.y)
	for y: int in range(y0, y1):
		for x: int in range(x0, x1):
			var p: Color = a.get_pixel(x, y)
			var q: Color = b.get_pixel(x, y)
			if absf(p.r - q.r) > EPS or absf(p.g - q.g) > EPS or absf(p.b - q.b) > EPS:
				rgb += 1
			var dy: float = absf((0.2126 * p.r + 0.7152 * p.g + 0.0722 * p.b)
				- (0.2126 * q.r + 0.7152 * q.g + 0.0722 * q.b))
			if dy > EPS:
				luma += 1
			maxy = maxf(maxy, dy)
	return {"rgb": rgb, "luma": luma, "maxy": maxy}


## Canvas rect to image rect. The HUD is authored on 640x360 and the framebuffer is whatever the window is;
## the ratio is read off the capture rather than assumed, so a different window cannot silently move a clip.
func _clip(img: Image, r: Rect2) -> Rect2i:
	var s: float = float(img.get_height()) / 360.0
	return Rect2i(int(r.position.x * s), int(r.position.y * s), int(r.size.x * s), int(r.size.y * s))


## The caller owns the freeze; this only shutters.
func _shot() -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return get_root().get_texture().get_image()
