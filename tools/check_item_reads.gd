extends "res://tools/check_base.gd"

## CAN YOU TELL WHAT YOU ARE HOLDING?
##
## check_voice asks whether two sounds can be told apart and refuses to let any pair sit on top of another.
## Nothing asked the same question of the icons, and the answer was no in a place that costs a gallery:
## earth, stone, shale, deepslate and sealrock all rendered through ONE cube differing only by tint, four of
## those tints sit within dE 8 of a neighbour in CIELab, and gravel had no glyph at all: it fell through
## draw_item's default branch to a flat coloured square.
##
## That last one is not cosmetic. Gravel is the only material that PACKS: a gallery backfilled with the
## stone you dug out of it is a sieve, and the same gallery packed with crushed gravel is a bulkhead. Which
## grey square is in your hand decides whether the water comes through.
##
## So this RENDERS every item's icon the way the hotbar does and compares them as a player's eye would:
##
##   SHAPE.   The alpha silhouette, compared by intersection-over-union. Two icons with IoU above SAME_SHAPE
##            occupy the same outline; whatever is drawn inside them, they read as the same object at
##            hotbar size.
##   COLOUR.  The mean colour over the covered pixels, in CIELab. Below SAME_TINT is a difference a person
##            will not reliably call at 40px against a moving background.
##
## The rule is a DISJUNCTION, and that is the design thesis stated as an assertion: two items may share an
## outline if their colours separate, and may share a colour if their outlines separate. What is forbidden
## is sharing both. A pair that does is not "similar", it is the same icon with two names.
##
## NEEDS A REAL WINDOW: it renders. Registered with add_gl, and it skips rather than lies if it finds no
## rendering device, because an all-blank comparison would pass this test perfectly.
##
##   godot --path . --script res://tools/check_item_reads.gd

## Every item draw_item is expected to have a real glyph for. The carried ground is the reason this layer
## exists; the metal chain is here because ingot/rich_ore and iron/iron_ingot/plate/iron_pickaxe are the
## other colour-close families and they should be held to the same rule.
##
## THIS LIST IS HAND-MAINTAINED, WHICH IS A LIABILITY, and `_check_vocabulary` below is what keeps it from
## becoming one. An item added to the game and not added here is never rendered by this layer and never
## compared against anything, so it can wear another item's exact icon and the suite stays green, which is
## the failure mode this layer was written to end. A list that has to be remembered protects nothing.
const ITEMS: Array[StringName] = [
	&"earth", &"stone", &"gravel", &"shale", &"deepslate", &"sealrock",
	&"ore", &"rich_ore", &"iron", &"ingot", &"iron_ingot", &"plate", &"gear",
	&"coal", &"wood", &"scanner", &"sapling", &"rope", &"torch",
	&"wood_pickaxe", &"stone_pickaxe", &"iron_pickaxe", &"wood_axe",
	&"broad_bit", &"sinker_bit", &"lance_bit", &"wedge_bit",
]

const CANVAS: int = 64          ## px per icon render
## THE SIZE THIS LAYER MEASURES AT IS NOT THE SIZE THE GAME DRAWS AT, and the comment that used to sit here
## said otherwise. It read "roughly a hotbar cell". It is roughly FOUR of them. Every `Visuals.draw_item`
## call site in `scenes/`: **13.0** through most of the HUD (carried-count chips, pack rows, detail chips,
## the legend), **12.0** at `hud.gd:2785`, **9.0** for an item lying in the world
## (`world_renderer.gd:2321`), and the detail plate at 40 or a well's own height; the only large ones.
##
## **So a cue that exists at 48 and dies at 13 is invisible to every number below.** That is not
## hypothetical: a glyph detail at `size * 0.035` is 1.7px here and 0.46px in the hotbar. The general form,
## which is worth more than this instance: **a spatial metric should take its window from the transform
## rather than from a number**; the terrain layers already do (`check_rock_reads:442` derives its patch from
## the live viewport basis). Icons have no transform to read, because the size is chosen by each caller, so
## the honest substitute is to make the size ASKABLE and to say what the callers use.
##
## The default is deliberately UNCHANGED at 48. Moving it would alter a floor and surface defects in the same
## motion, and then neither could be attributed. `SF_ICON_PX=13` runs it where the player actually is; what
## falls out of that is a finding about the icons, to be reported before anything here is re-pitched.
const ICON: float = 48.0
## The size the HUD actually asks for, at almost every call site (`hud.gd:2315`, `:2535`, `:3547`, `:3658`,
## `:3984`). The second pass below runs here and REPORTS, so a pair that collides where the player is cannot
## sit unseen behind a comfortable margin measured somewhere they never look.
const HOTBAR_PX: float = 13.0
const SAME_SHAPE: float = 0.90  ## silhouette IoU at or above which two icons share an outline
const SAME_TINT: float = 10.0   ## CIELab dE below which two icons share a colour

var _skipped: bool = false
var _icon_px: float = ICON
## The render target scales WITH the icon, because `_coverage` divides by the image area and the blank
## test is an absolute 0.02 of it. Hold the canvas at 64 while asking for a 13px glyph and the largest
## possible coverage is (13/64)^2 = 4%, so thin glyphs read as BLANK and the layer reports 17 empty icons
## that are drawn perfectly well. That is a defect in the harness, not in the art, and it is what the
## first run at SF_ICON_PX=13 actually said. Scaling by the same ratio keeps every threshold meaning what
## it meant, and at the default it is 64 exactly, so the shipped measurement does not move.
var _canvas: int = CANVAS


## An inner class is its own scope and cannot see this script's constants, so the geometry is handed to it
## rather than read from CANVAS/ICON directly, which would not compile.
class Glyph extends Node2D:
	var item: StringName
	var at: Vector2
	var icon: float

	func _draw() -> void:
		Visuals.draw_item(self, at, icon, item)

func _initialize() -> void:
	var raw: String = str(OS.get_environment("SF_ICON_PX"))
	if raw.is_valid_float():
		_icon_px = float(raw)
		_canvas = maxi(8, int(round(float(CANVAS) * _icon_px / ICON)))
	print("== can you tell what you are holding ==")
	if not is_equal_approx(_icon_px, ICON):
		print("  NOTE: rendering at %.0f px, not the default %.0f (SF_ICON_PX)" % [_icon_px, ICON])
	await _run()
	# quit() sets the exit code and leaves at the end of the frame, so a SECOND quit overwrites the first.
	# Without this guard the skip below returned 0, and the runner reads the exact code, so a layer that
	# announced "did not run" in its own output was counted as a PASS, which is the precise defect the
	# three-state runner exists to prevent. Caught by expecting 42 and getting 0.
	if _skipped:
		return
	if _failures == 0:
		print("check_item_reads: PASS — no two items wear the same icon")
		quit(0)
	else:
		printerr("check_item_reads: FAIL (%d)" % _failures)
		quit(1)


func _run() -> void:
	# THE VOCABULARY CHECK RUNS FIRST AND WITHOUT A DISPLAY, because it is the one assertion here a headless
	# CI can still make. Everything below it needs pixels; this needs a source file.
	_check_vocabulary()
	_check_pack_vocabulary()
	if DisplayServer.get_name() == "headless":
		# AND IF IT FAILED, THIS IS A FAILURE AND NOT A SKIP. Reporting 42 here would hand the runner "did
		# not run" while holding a real failure in _failures: a broken build filed under "not attempted",
		# which is the precise defect the three-state protocol exists to prevent. The honest report is: the
		# pixel half could not run, and the half that could run failed.
		if _failures > 0:
			printerr("check_item_reads: FAIL (%d) — no display, but the vocabulary check does not need one"
				% _failures)
			_skipped = true
			quit(1)
			return
		print("check_item_reads: SKIP — no rendering device, and comparing blank images would pass.")
		_skipped = true
		quit(SKIP)
		return

	var shots: Dictionary = {}
	for item: StringName in ITEMS:
		shots[item] = await _render(item)

	# --- every icon is actually drawn (a blank one would compare equal to every other blank one) ---
	var blank: Array[String] = []
	for item: StringName in ITEMS:
		if _coverage(shots[item]) < 0.02:
			blank.append(String(item))
	_check(blank.is_empty(),
		"every item draws something (%d blank: %s)" % [blank.size(), ", ".join(blank)])
	if not blank.is_empty():
		return                      # the comparisons below are meaningless over blanks

	# --- ...and no two of them read the same ---
	var worst_iou: float = 0.0
	var worst_pair: String = ""
	var clashes: Array[String] = []
	for i: int in ITEMS.size():
		for j: int in range(i + 1, ITEMS.size()):
			var a: StringName = ITEMS[i]
			var b: StringName = ITEMS[j]
			var iou: float = _iou(shots[a], shots[b])
			var de: float = _de(_mean_lab(shots[a]), _mean_lab(shots[b]))
			if iou > worst_iou:
				worst_iou = iou
				worst_pair = "%s/%s" % [a, b]
			if iou >= SAME_SHAPE and de < SAME_TINT:
				clashes.append("%s/%s (IoU %.2f, dE %.1f)" % [a, b, iou, de])
	print("  %d items, %d pairs; the most alike outlines are %s at IoU %.2f"
		% [ITEMS.size(), ITEMS.size() * (ITEMS.size() - 1) / 2, worst_pair, worst_iou])
	# AND THE SAME RANKING BY SHAPE, FOR THE REASON THE TINT RANKING BELOW ALREADY GIVES: read symmetrically.
	# The line above reports ONE outline pair, chosen by `iou > worst_iou`, which is a STRICT comparison: when
	# several pairs sit at the same worst value the first one found keeps the slot and the rest are never
	# printed. That is not hypothetical. `stone/sealrock`, `ingot/iron_ingot` and `ore/iron` were ALL at IoU
	# 1.00 (three pairs drawn from one polygon apiece), and this line could only ever name one of them.
	# `ore/iron` is the one it did not name, and it is the pair T3.4 was about: iron was `_item_ore`'s polygon
	# byte for byte, so its matrix value had to separate it from ore AND from deepslate at once, and it lost
	# against deepslate at dE 1.0. **The suite ranked six colours and one shape, so the shape half of the
	# defect could not reach the output anyone reads.** Six lines, no new assertion, same argument as below:
	# a floor here would be a threshold nobody has looked at a screen to set.
	var by_shape: Array[Dictionary] = []
	for i: int in ITEMS.size():
		for j: int in range(i + 1, ITEMS.size()):
			by_shape.append({"iou": _iou(shots[ITEMS[i]], shots[ITEMS[j]]),
				"de": _de(_mean_lab(shots[ITEMS[i]]), _mean_lab(shots[ITEMS[j]])),
				"pair": "%s/%s" % [ITEMS[i], ITEMS[j]]})
	by_shape.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["iou"]) > float(y["iou"]))
	print("  the six most alike OUTLINES (IoU on the drawn icon; the clash floor is dE %.0f + IoU %.2f):"
		% [SAME_TINT, SAME_SHAPE])
	for k: int in mini(6, by_shape.size()):
		print("    IoU %.2f  dE %5.1f  %s" % [float(by_shape[k]["iou"]), float(by_shape[k]["de"]),
			str(by_shape[k]["pair"])])
	# THE CLOSEST PAIRS BY COLOUR, REPORTED AND NOT ASSERTED. `T3.4` says the hotbar has two identical grey
	# icons and asks for re-verification against current art rather than for spending on it, and this layer
	# was answering a narrower question: it prints the worst OUTLINE and then asserts on the CONJUNCTION of
	# outline and tint. A pair that is separated by shape and nearly identical in colour is invisible in
	# both of those numbers, and at a 16px hotbar slot against a dark moving background it is exactly what
	# the ticket is describing. Six lines, no new assertion: the ranking is the evidence the ticket asked
	# for, and turning it into a floor would be inventing a threshold nobody has looked at a screen to set.
	var by_tint: Array[Dictionary] = []
	for i: int in ITEMS.size():
		for j: int in range(i + 1, ITEMS.size()):
			by_tint.append({"de": _de(_mean_lab(shots[ITEMS[i]]), _mean_lab(shots[ITEMS[j]])),
				"iou": _iou(shots[ITEMS[i]], shots[ITEMS[j]]),
				"pair": "%s/%s" % [ITEMS[i], ITEMS[j]]})
	by_tint.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["de"]) < float(y["de"]))
	print("  the six most alike COLOURS (dE on the drawn icon; the clash floor is dE %.0f + IoU %.2f):"
		% [SAME_TINT, SAME_SHAPE])
	for k: int in mini(6, by_tint.size()):
		print("    dE %5.1f  IoU %.2f  %s" % [float(by_tint[k]["de"]), float(by_tint[k]["iou"]),
			str(by_tint[k]["pair"])])
	for c: String in clashes:
		printerr("    %s" % c)
	_check(clashes.is_empty(),
		"no pair shares BOTH an outline and a colour (%d pair(s) do)" % clashes.size())

	# --- the carried ground specifically: it is what this layer was written for ---
	# NOT "these six no longer share a silhouette": that would be the wrong claim and it would fail on a
	# pair that is working as designed. sealrock KEEPS the cube, deliberately: it is a block, and its colour
	# already separates it from stone by dE 24. What must hold is the narrower, true thing: where COLOUR
	# cannot tell two carried materials apart, SHAPE has to, because tint is the half that dies first at
	# hotbar size against a dark moving background.
	var ground: Array[StringName] = [&"earth", &"stone", &"gravel", &"shale", &"deepslate", &"sealrock"]
	var unseparated: Array[String] = []
	var close_pairs: int = 0
	for i: int in ground.size():
		for j: int in range(i + 1, ground.size()):
			var a: StringName = ground[i]
			var b: StringName = ground[j]
			if _de(_mean_lab(shots[a]), _mean_lab(shots[b])) >= SAME_TINT:
				continue                                    # colour already separates these two
			close_pairs += 1
			var iou: float = _iou(shots[a], shots[b])
			if iou >= SAME_SHAPE:
				unseparated.append("%s/%s (IoU %.2f)" % [a, b, iou])
	# Non-vacuity: if no carried pair is colour-close, the loop above asserts nothing at all. The palette
	# genuinely has several such pairs, so zero here means the measurement broke, not that the art is good.
	_check(close_pairs > 0,
		"the carried ground still contains colour-close pairs to judge (%d) — else this asserts nothing"
			% close_pairs)
	_check(unseparated.is_empty(),
		"...and every one of them is separated by SHAPE instead (%d not: %s)"
			% [unseparated.size(), ", ".join(unseparated)])

	# --- and gravel in particular, against the block it decides a flood against ---
	var gs: float = _iou(shots[&"gravel"], shots[&"stone"])
	_check(gs < 0.75,
		"gravel and stone are plainly different objects (IoU %.2f) — the sieve/bulkhead choice reads" % gs)

	await _report_at_hotbar_size()



## THE SAME COMPARISON AT THE SIZE THE PLAYER ACTUALLY SEES: REPORTED, NEVER ASSERTED.
##
## Everything above runs at `ICON` = 48. The HUD asks for 13. That gap is not a rounding difference: detail
## which separates two glyphs at 48 can be gone at 13, so a margin measured up there is not a margin the
## player has. Measured on the set as shipped, `ore`/`coal` goes 0.89 -> 0.92 and `earth`/`ore` 0.85 -> 0.90,
## both crossing the outline floor that neither crosses at 48, and the closest COLOUR pair is not even the
## same pair (`gravel`/`iron_pickaxe` at dE 1.5, absent from the top six at 48).
##
## It reports rather than asserts, deliberately. Turning this into a second floor would be inventing a
## threshold at a size nobody has reviewed a screen at, and the disjunction this layer is built on (share an
## outline OR a colour, never both) was calibrated at 48. What it DOES do is make a hotbar-size collision
## impossible to miss: a pair sharing both axes down here prints as a WOULD-CLASH, which is the evidence a
## floor would need before anyone argues for one.
func _report_at_hotbar_size() -> void:
	if not is_equal_approx(_icon_px, ICON):
		return              # already running at an asked-for size; a second pass would just repeat it
	var keep_px: float = _icon_px
	var keep_canvas: int = _canvas
	_icon_px = HOTBAR_PX
	# Scaled by the same ratio, because `_coverage` and every threshold are relative to the image area.
	_canvas = maxi(8, int(round(float(CANVAS) * HOTBAR_PX / ICON)))
	var small: Dictionary = {}
	for item: StringName in ITEMS:
		small[item] = await _render(item)
	var rows: Array[Dictionary] = []
	var would_clash: Array[String] = []
	for i: int in ITEMS.size():
		for j: int in range(i + 1, ITEMS.size()):
			var iou: float = _iou(small[ITEMS[i]], small[ITEMS[j]])
			var de: float = _de(_mean_lab(small[ITEMS[i]]), _mean_lab(small[ITEMS[j]]))
			var pair: String = "%s/%s" % [ITEMS[i], ITEMS[j]]
			rows.append({"iou": iou, "de": de, "pair": pair})
			if iou >= SAME_SHAPE and de < SAME_TINT:
				would_clash.append("%s (IoU %.2f, dE %.1f)" % [pair, iou, de])
	rows.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["de"]) < float(y["de"]))
	print("  AT HOTBAR SIZE (%.0f px, what the HUD asks for) the three closest COLOURS are:" % HOTBAR_PX)
	for k: int in mini(3, rows.size()):
		print("    dE %5.1f  IoU %.2f  %s" % [float(rows[k]["de"]), float(rows[k]["iou"]), str(rows[k]["pair"])])
	rows.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["iou"]) > float(y["iou"]))
	print("  ...and the three closest OUTLINES:")
	for k: int in mini(3, rows.size()):
		print("    IoU %.2f  dE %5.1f  %s" % [float(rows[k]["iou"]), float(rows[k]["de"]), str(rows[k]["pair"])])
	if would_clash.is_empty():
		print("  no pair shares both an outline and a colour at hotbar size either")
	else:
		print("  WOULD-CLASH AT HOTBAR SIZE (not visible in any number above): %s" % ", ".join(would_clash))
	_icon_px = keep_px
	_canvas = keep_canvas

# --- rendering + comparison ---------------------------------------------------------------------------

func _render(item: StringName) -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i(_canvas, _canvas)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var g := Glyph.new()
	g.item = item
	g.at = Vector2(_canvas, _canvas) * 0.5
	g.icon = _icon_px
	vp.add_child(g)
	get_root().add_child(vp)
	await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	vp.queue_free()
	return img


## Fraction of the canvas the icon covers: the silhouette, as a number.
func _coverage(img: Image) -> float:
	var n: int = 0
	for y: int in img.get_height():
		for x: int in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				n += 1
	return float(n) / float(img.get_width() * img.get_height())


## Intersection over union of two alpha silhouettes: 1.0 = the same outline, 0.0 = no overlap at all.
func _iou(a: Image, b: Image) -> float:
	var inter: int = 0
	var uni: int = 0
	for y: int in a.get_height():
		for x: int in a.get_width():
			var pa: bool = a.get_pixel(x, y).a > 0.5
			var pb: bool = b.get_pixel(x, y).a > 0.5
			if pa and pb:
				inter += 1
			if pa or pb:
				uni += 1
	return float(inter) / float(maxi(uni, 1))


## Mean colour over the covered pixels only: the background must not dilute the reading.
func _mean_lab(img: Image) -> Vector3:
	var r: float = 0.0
	var g: float = 0.0
	var b: float = 0.0
	var n: int = 0
	for y: int in img.get_height():
		for x: int in img.get_width():
			var p: Color = img.get_pixel(x, y)
			if p.a <= 0.5:
				continue
			r += p.r
			g += p.g
			b += p.b
			n += 1
	if n == 0:
		return Vector3.ZERO
	return _lab(Color(r / float(n), g / float(n), b / float(n)))


## EVERY ITEM THE VIEW CLAIMS TO KNOW MUST BE PROVEN LEGIBLE.
##
## `Visuals.item_color` is an if-ladder ending in `return Color.WHITE`, and its own comment records the day
## that fallback shipped: the carried ground had no entries, so earth, stone and shale all drew as blank
## white squares in the hotbar and it looked like missing art, because it was. The ladder was fixed. The
## thing that let it happen (a vocabulary defined by whoever last edited a function, checked against a list
## somebody has to remember to update) was not.
##
## So the list above is held to `visuals.gd` by reading it. Give an item a look and this goes red until the
## item is also being compared against every other icon, which is the right dependency: drawing something
## specifically is a promise that it is identifiable, and this layer is where that promise is tested.
##
## WHAT COUNTS AS "KNOWN" TOOK A CORRECTION, and it is worth leaving written down. The first version scanned
## `item_color` alone and reported the four bits as stale, on the reasoning that an item compared here ought
## to have a colour. It does not: `_item_bit` hardcodes its own steel, edge and brass and never calls
## `item_color`, so the bits are drawn deliberately and specifically while having no entry in the ladder at
## all. That premise was simply wrong: an item_color entry is one way the view knows an item, not
## the only way. The vocabulary is the UNION of the two places a look can be declared.
##
## THE CHECK IS SET EQUALITY, NOT CONTAINMENT, and that is deliberate. Containment in either direction alone
## can be satisfied by a scanner that silently matches nothing; the cleanest vacuous pass there is, and one
## this project has already been bitten by. Requiring both directions means a broken regex produces
## twenty-five items "the view does not know" and fails instantly rather than passing on an empty set.
func _check_vocabulary() -> void:
	var known: Array[StringName] = _items_the_view_knows()
	var missing: Array[String] = []       # drawn deliberately, but nobody checks it reads
	for item: StringName in known:
		if not ITEMS.has(item):
			missing.append(String(item))
	var stale: Array[String] = []         # compared here, but the view no longer draws it specifically
	for item: StringName in ITEMS:
		if not known.has(item):
			stale.append(String(item))

	_check(missing.is_empty(),
		"every item the view draws specifically is compared against the others%s"
			% ["" if missing.is_empty() else " — UNCHECKED: " + ", ".join(missing)])
	_check(stale.is_empty(),
		"every item compared here is still one the view knows%s"
			% ["" if stale.is_empty() else " — STALE: " + ", ".join(stale)])
	# NON-VACUITY: both assertions above are perfectly satisfied by an empty scan and an empty list.
	_check(known.size() >= 20, "the scan read %d items out of visuals.gd" % known.size())


## THE THIRD DIRECTION: EVERY ID THE GAME CAN ACTUALLY HAND A PLAYER.
##
## `_check_vocabulary` above closes the drift between the hand-kept ITEMS list and what visuals.gd draws,
## in both directions, with a non-vacuity floor. It is a good guard and it cannot see the failure it most
## needs to. Its universe is `_items_the_view_knows()`, read out of visuals.gd, so an id the GAME can put
## in a pack and the VIEW has never heard of is absent from BOTH sides of the comparison, and passes by
## construction. The list agrees with the code; nobody asked whether either agrees with the game.
##
## What that blindness costs is not subtle. `draw_item`'s default arm fills a flat rect with
## `item_color`, whose last line is `return Color.WHITE`, so an unknown id renders as the brightest,
## highest-contrast mark available on a dark screen, wearing no name and looking entirely deliberate.
##
## So this population comes from the DATA, by the rule the pack is actually filled:
##
##   materials   every `.tres` whose `layer` is not `&"wall"` (the wall plane is dug THROUGH, never
##               carried) minus `leaves`, which `FactorySim.mine`'s foliage branch turns into a SAPLING
##               or into nothing; the leaf block itself is never pocketed.
##   recipes     every input and every output of every recipe on disk.
##   tools       `MainView.CRAFT_TOOLS`, plus the pickaxe you start holding and the sapling you plant.
##
## MACHINES ARE DELIBERATELY OUT. A carried machine draws through `Hud.machine_icons`, not through
## `draw_item`, and whether that registry is complete is `check_craftable_registry`'s question. Widening
## this population to machines would be asserting someone else's contract through the wrong instrument.
##
## THE COST OF NOT HAVING THIS, stated because it is the reason it exists: a menu capture built from every
## `.tres` on disk showed six white squares, and they read as a shipped defect (mechanism confirmed in
## source, screenshot in hand, then independently confirmed a second time) for most of an hour. Every
## one of the six was an id the game cannot give you. A mechanism confirmed twice over says nothing about
## whether the population is real.
func _check_pack_vocabulary() -> void:
	var known: Array[StringName] = _items_the_view_knows()
	var pack: Array[StringName] = _ids_the_pack_can_hold()
	var unknown: Array[String] = []
	for id: StringName in pack:
		if not known.has(id):
			unknown.append(String(id))
	_check(unknown.is_empty(),
		"every one of the %d ids the game can put in a pack is one the view draws%s"
			% [pack.size(), "" if unknown.is_empty() else " — NO GLYPH (draws as a white square): "
				+ ", ".join(unknown)])
	# NON-VACUITY: the assertion above is perfectly satisfied by an empty population, which is what a
	# broken DirAccess or a renamed directory produces.
	_check(pack.size() >= 18, "the pack universe read %d ids off disk" % pack.size())
	# CONTROL: the same comparison, with one id the view certainly does not know.
	var planted: Array[StringName] = pack.duplicate()
	planted.append(&"not_a_real_item")
	var caught: int = 0
	for id: StringName in planted:
		if not known.has(id):
			caught += 1
	_check(caught == unknown.size() + 1,
		"the same comparison catches one more once an unknown id is planted (%d -> %d)"
			% [unknown.size(), caught])


## The ids `FactorySim.inventory` can hold, derived from the data the way the pack is filled. See the
## header above `_check_pack_vocabulary` for why each exclusion is there: every one of them is a state
## the game cannot reach, and reaching it in a fixture manufactures defects rather than finding them.
func _ids_the_pack_can_hold() -> Array[StringName]:
	var out: Array[StringName] = []
	var d: DirAccess = DirAccess.open("res://src/data/materials")
	if d != null:
		for f: String in d.get_files():
			if not f.ends_with(".tres"):
				continue
			var mat: MaterialDef = load("res://src/data/materials/%s" % f) as MaterialDef
			# sealrock is `REQUIRED_TIER: 99`, un-hand-mineable by any pick, forever, because the L1->L2
			# gate is a throughput wall and only a fed Descent Engine breaches it. `mine()` would pocket it
			# if it were ever reached; it never is.
			if mat == null or mat.layer == &"wall" or mat.id == &"leaves" or mat.id == &"sealrock":
				continue
			_add(out, mat.id)
	var r: DirAccess = DirAccess.open("res://src/data/recipes")
	if r != null:
		for f: String in r.get_files():
			if not f.ends_with(".tres"):
				continue
			var rec: RecipeDef = load("res://src/data/recipes/%s" % f) as RecipeDef
			if rec == null:
				continue
			for side: Dictionary in [rec.inputs, rec.outputs]:
				for id: Variant in side:
					_add(out, StringName(id))
	for t: Dictionary in MainView.CRAFT_TOOLS:
		_add(out, t["id"])
	_add(out, &"wood_pickaxe")
	_add(out, &"sapling")
	out.sort()
	return out


## Every item `visuals.gd` declares a look for: a branch in the `item_color` ladder, or a `match` arm in
## `draw_item`'s glyph dispatch. There is no runtime way to ask a function which values it treats specially,
## and a hand-kept mirror of either would be one more list to drift: the exact problem this is here to
## solve.
func _items_the_view_knows() -> Array[StringName]:
	var f: FileAccess = FileAccess.open("res://scenes/visuals.gd", FileAccess.READ)
	if f == null:
		_check(false, "visuals.gd is readable")
		return ([] as Array[StringName])
	var out: Array[StringName] = []
	var in_color: bool = false
	var in_draw: bool = false
	var ladder := RegEx.new()
	ladder.compile("item == &\"([a-z_]+)\"")
	# A match arm is one or more quoted names and then a colon: `&"ore":` or `&"broad_bit", &"sinker_bit":`
	var arm := RegEx.new()
	arm.compile("^\\s+(&\"[a-z_]+\"(,\\s*&\"[a-z_]+\")*)\\s*:\\s*$")
	var name := RegEx.new()
	name.compile("&\"([a-z_]+)\"")
	while not f.eof_reached():
		var line: String = f.get_line()
		if line.begins_with("static func "):
			in_color = line.begins_with("static func item_color")
			in_draw = line.begins_with("static func draw_item")
			continue
		if in_color:
			for m: RegExMatch in ladder.search_all(line):
				_add(out, StringName(m.get_string(1)))
		elif in_draw:
			var hit: RegExMatch = arm.search(line)
			if hit != null:
				for m: RegExMatch in name.search_all(hit.get_string(1)):
					_add(out, StringName(m.get_string(1)))
	f.close()
	return out


func _add(into: Array[StringName], s: StringName) -> void:
	if not into.has(s):
		into.append(s)


func _lab(c: Color) -> Vector3:
	var lr: float = _linear(c.r)
	var lg: float = _linear(c.g)
	var lb: float = _linear(c.b)
	var x: float = (lr * 0.4124 + lg * 0.3576 + lb * 0.1805) / 0.95047
	var y: float = lr * 0.2126 + lg * 0.7152 + lb * 0.0722
	var z: float = (lr * 0.0193 + lg * 0.1192 + lb * 0.9505) / 1.08883
	return Vector3(116.0 * _f(y) - 16.0, 500.0 * (_f(x) - _f(y)), 200.0 * (_f(y) - _f(z)))


func _f(t: float) -> float:
	return pow(t, 1.0 / 3.0) if t > 0.008856 else (7.787 * t + 16.0 / 116.0)


func _linear(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)


func _de(a: Vector3, b: Vector3) -> float:
	return (a - b).length()
