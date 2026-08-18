class_name Visuals
extends RefCounted

## Shared VISUAL VOCABULARY — the one place that maps game data to its on-screen look, so the world
## renderer and the HUD never drift apart (they used to each re-draw the same machine glyphs + item
## colours by hand). Pure presentation helpers: a machine's KIND/COLOUR, its silhouette GLYPH drawn on
## any canvas at any scale, and an item's COLOUR. No state, no sim writes — static functions only.

# --- machines ----------------------------------------------------------------

## THE MACHINE STYLE REGISTRY — the representation-side twin of FactorySim._BEHAVIORS: the ONE
## table wiring a behavior tag to its LOOK (glyph kind + casing colour), replacing two parallel
## if-ladders that had to be extended in lock-step. A def with no entry falls back on its recipe:
## a no-input source reads as a furnace, anything else as a gear (the generic runner). Adding a
## machine = one entry here (+ a drawer in draw_machine_glyph if its kind is genuinely new).
const MACHINE_STYLE: Dictionary = {
	&"drill": {"kind": "drill", "color": Color(0.72, 0.56, 0.30)},        # steel-amber — ore-extraction tech
	&"lift": {"kind": "lift", "color": Color(0.26, 0.66, 0.62)},          # teal — anti-gravity tech
	&"splitter": {"kind": "fork", "color": Color(0.58, 0.42, 0.78)},
	&"generator": {"kind": "generator", "color": Color(0.80, 0.66, 0.26)},# electric gold — burns fuel → power
	&"conduit": {"kind": "conduit", "color": Color(0.66, 0.47, 0.30)},    # copper — the power-tube material
	&"hopper": {"kind": "hopper", "color": Color(0.40, 0.44, 0.52)},      # cool gunmetal — a storage bin
	&"rope": {"kind": "rope", "color": Color(0.62, 0.50, 0.32)},          # hemp tan — the placeable climb
	&"torch": {"kind": "torch", "color": Color(0.86, 0.60, 0.26)},        # flame amber — placeable light
	&"descent": {"kind": "descent", "color": Color(0.38, 0.26, 0.44)},   # seal-purple bronze — the gate-breacher
	# The L2 crafter modules: recipe-runners wearing their OWN faces — the behavior
	# tags have no _BEHAVIORS entry (they fall through to the recipe runner), they exist so each module
	# visibly announces its one product (per-item legibility, the modules' whole point).
	&"iron_forge": {"kind": "furnace", "color": Color(0.40, 0.48, 0.62)}, # steel-blue furnace — smelts iron
	&"blast_furnace": {"kind": "furnace", "color": Color(0.82, 0.60, 0.28)}, # white-gold heat — 1 rich ore → 2 ingots (#48)
	&"plate_press": {"kind": "press", "color": Color(0.52, 0.57, 0.68)},  # slab-grey — presses plates
	&"gear_mill": {"kind": "gear", "color": Color(0.72, 0.56, 0.26)},     # bronze — mills gears
	&"h_drill": {"kind": "h_drill", "color": Color(0.56, 0.46, 0.32)},    # earth-steel — the sideways Borer
	&"pump": {"kind": "pump", "color": Color(0.30, 0.52, 0.68)},          # water-blue — the powered flood-drain (L3)
	&"drift": {"kind": "drift", "color": Color(0.29, 0.36, 0.38)},        # dark gunmetal-teal — powered, heavy
	&"crush": {"kind": "crush", "color": Color(0.38, 0.33, 0.30)},        # crusher iron — spoil in, gravel out
	&"spur": {"kind": "spur", "color": Color(0.66, 0.53, 0.32)},          # the Head's own amber — it IS the Head
}


## THE STATUS VOCABULARY — what each of `FactorySim.machine_status`'s answers looks like on the machine.
##
## THIS EXISTS BECAUSE THE RENDERER ONLY KNEW HALF OF THEM. The sim returns ten statuses; the status lamp
## matched on five and let the rest fall through to the grey "idle" default. So a drill whose ore had no
## drain below it, a rig with a jammed spoil column, an unpowered crusher and a Spur wired to nothing all
## displayed the one colour that means "nothing is wrong here" — and then fell through to the need bubble,
## which defaults to ore, and told you to feed ore to a machine whose actual problem was that it had no
## power. A silent wrong state is worse than a missing one: it sends you to fix something that isn't broken.
##
## COLOUR ALONE WAS NEVER ENOUGH ANYWAY (audit 195). Green working against red no-fuel is the single most
## common colour confusion there is, with amber starved joining them; for a deuteranope those three lamps
## were one lamp. So every status carries a MARK as well as a colour, and either channel alone answers it.
##
##   mark   the silhouette drawn in the lamp. Chosen to differ in OUTLINE rather than in detail, because
##          detail is the first thing a four-pixel mark loses.
##   fix    what the player would have to DO about it. This is the field with a rule attached: two statuses
##          calling for different fixes must never share a mark, or the lamp sends you to the wrong job.
##          Two statuses calling for the SAME fix are welcome to share one — `no_fuel` and `no_input` are
##          both "put something in", and which something is what the need bubble is for.
##   feeds  whether the floating need bubble — which can only draw an ITEM — is capable of telling the
##          truth about this status. False for power, jams and wiring, where it would have to invent one.
##
## The three `blocked*` states deliberately look identical: the lamp's job is to name the KIND of problem,
## and "a column behind this machine is jammed, dig it out" is one problem. Which column is the hover
## inspector's answer, not a four-pixel dot's.
const STATUS_LOOK: Dictionary = {
	&"working":       {"color": Color(0.35, 0.92, 0.42), "mark": &"disc",  "fix": &"none",     "feeds": false},
	&"idle":          {"color": Color(0.52, 0.55, 0.62), "mark": &"bar",   "fix": &"none",     "feeds": false},
	&"spent":         {"color": Color(0.46, 0.58, 0.78), "mark": &"ring",  "fix": &"relocate", "feeds": false},
	&"no_fuel":       {"color": Color(0.96, 0.26, 0.20), "mark": &"feed",  "fix": &"feed",     "feeds": true},
	&"no_input":      {"color": Color(0.97, 0.72, 0.22), "mark": &"feed",  "fix": &"feed",     "feeds": true},
	&"no_power":      {"color": Color(0.36, 0.84, 0.98), "mark": &"power", "fix": &"power",    "feeds": false},
	&"blocked":       {"color": Color(0.95, 0.45, 0.18), "mark": &"clear", "fix": &"clear",    "feeds": false},
	&"blocked_pay":   {"color": Color(0.95, 0.45, 0.18), "mark": &"clear", "fix": &"clear",    "feeds": false},
	&"blocked_spoil": {"color": Color(0.95, 0.45, 0.18), "mark": &"clear", "fix": &"clear",    "feeds": false},
	&"unlinked":      {"color": Color(0.86, 0.40, 0.92), "mark": &"link",  "fix": &"link",     "feeds": false},
}

## The look of a status, falling back on idle's neutral bar for anything the table has not heard of. The
## fallback is a safety net and not a licence: `check_status_reads` walks the sim's own source and fails if
## any status it can return is missing here, so a new one is caught at the harness rather than in play.
static func status_look(status: StringName) -> Dictionary:
	return STATUS_LOOK.get(status, STATUS_LOOK[&"idle"])


## Draw a status lamp's MARK — the geometry half of the redundant coding, centred at `c` with radius `r`.
##
##   ● disc    a full disc — complete and running
##   ▬ bar     a bar at rest
##   ○ ring    hollow, because the machine is fine and the vein is empty
##   ▲ feed    pointing UP, at the need bubble it is asking for
##   ◆ power   a diamond — the power motif, and the one mark that is neither round nor square
##   ■ clear   a hard stop: something behind this machine is jammed
##   ✕ link    a cross — placed, but joined to nothing
static func draw_status_mark(canvas: CanvasItem, c: Vector2, r: float, mark: StringName,
		col: Color) -> void:
	match mark:
		&"feed":
			canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -r),
				c + Vector2(r * 0.95, r * 0.72), c + Vector2(-r * 0.95, r * 0.72)]), col)
		&"clear":
			canvas.draw_rect(Rect2(c - Vector2(r, r) * 0.84, Vector2(r, r) * 1.68), col)
		&"ring":
			canvas.draw_arc(c, r * 0.78, 0.0, TAU, 14, col, maxf(1.0, r * 0.44))
		&"power":
			canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -r), c + Vector2(r, 0.0),
				c + Vector2(0.0, r), c + Vector2(-r, 0.0)]), col)
		&"link":
			var a: float = r * 0.82
			var w: float = maxf(1.2, r * 0.40)
			canvas.draw_line(c + Vector2(-a, -a), c + Vector2(a, a), col, w)
			canvas.draw_line(c + Vector2(-a, a), c + Vector2(a, -a), col, w)
		&"bar":
			canvas.draw_rect(Rect2(c - Vector2(r * 0.92, r * 0.32), Vector2(r * 1.84, r * 0.64)), col)
		_:
			canvas.draw_circle(c, r, col)


## THE NEED BUBBLE'S OTHER VOCABULARY — what to draw when the answer is not an item.
##
## The bubble floats above a stalled machine holding up WHAT IT NEEDS, and it could only ever draw an item
## glyph. That is fine for the two statuses whose answer is a thing you carry, and useless for the three
## whose answer is a job: no power, a jammed column, a Spur wired to nothing. Those used to reach the bubble
## anyway and float an ORE icon over all of them, which is why they now stop at the lamp — correct, and
## quieter than they should be, because the lamp names the KIND of problem and the bubble is where the
## specific one belongs.
##
## So the three jobs get glyphs. They are deliberately not items: an item glyph says "fetch me this" and
## these say "go do this", and the difference has to survive being 11px across.
##
##   power   a bolt — the same motif as the lamp's diamond and the conduit's channel
##   clear   a chevron driving DOWN into a bar: the drain is dug below the machine, which is where a jam is
##           always cleared from. It points at the answer's location, not just at its existence.
##   link    two links with a gap between them — the one shape that means "connected" when it is closed
static func draw_fix_glyph(canvas: CanvasItem, c: Vector2, size: float, fix: StringName,
		col: Color) -> void:
	var u: float = size * 0.5
	match fix:
		&"power":
			canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(u * 0.22, -u * 0.95), c + Vector2(-u * 0.62, u * 0.12),
				c + Vector2(-u * 0.06, u * 0.12), c + Vector2(-u * 0.22, u * 0.95),
				c + Vector2(u * 0.62, -u * 0.12), c + Vector2(u * 0.06, -u * 0.12)]), col)
		&"clear":
			canvas.draw_rect(Rect2(c + Vector2(-u * 0.78, u * 0.52), Vector2(u * 1.56, u * 0.30)), col)
			canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(0.0, u * 0.30), c + Vector2(-u * 0.66, -u * 0.42),
				c + Vector2(-u * 0.30, -u * 0.42), c + Vector2(0.0, -u * 0.10),
				c + Vector2(u * 0.30, -u * 0.42), c + Vector2(u * 0.66, -u * 0.42)]), col)
		&"link":
			var w: float = maxf(1.4, u * 0.26)
			canvas.draw_arc(c + Vector2(-u * 0.46, 0.0), u * 0.44, -PI * 0.45, PI * 0.45, 10, col, w)
			canvas.draw_arc(c + Vector2(-u * 0.46, 0.0), u * 0.44, PI * 0.55, PI * 1.45, 10, col, w)
			canvas.draw_arc(c + Vector2(u * 0.46, 0.0), u * 0.44, PI * 0.55, PI * 1.45, 10, col, w)
			canvas.draw_arc(c + Vector2(u * 0.46, 0.0), u * 0.44, -PI * 0.45, PI * 0.45, 10, col, w)


## The icon "kind" of a machine: its style entry, else furnace (no-input source) / gear (runner).
static func machine_kind(def: MachineDef) -> String:
	if MACHINE_STYLE.has(def.behavior):
		return (MACHINE_STYLE[def.behavior] as Dictionary)["kind"]
	# The base Forge (processor) SMELTS ore→ingot — it's a furnace with fire, not a generic cool runner.
	# (Classing it "gear" made it glow cold cyan and spill over the starter ore — the blind-playtest bug.)
	if def.id == &"processor" or (def.recipe != null and def.recipe.inputs.is_empty()):
		return "furnace"
	return "gear"


## The casing colour of a machine (the riveted body the glyph sits on).
static func machine_color(def: MachineDef) -> Color:
	if MACHINE_STYLE.has(def.behavior):
		return (MACHINE_STYLE[def.behavior] as Dictionary)["color"]
	var recipe: RecipeDef = def.recipe
	if def.id == &"processor" or (recipe != null and recipe.inputs.is_empty()):
		return Color(0.28, 0.23, 0.20)   # dark sooty IRON — a furnace is a dark machine; the heat is in the
		#                                  glowing MOUTH (see _furnace), lit only while smelting. The old
		#                                  ember-orange body out-shouted the avatar + ore (blind-playtest).
	return Color(0.30, 0.55, 0.75)       # steel-blue — the generic processor


## THE CASING — the body a machine is built out of, as opposed to the glyph painted on its front.
##
## COMPREHENSIVE_AUDIT §194 says the machines read as UI rather than hardware, and the casing is the whole
## reason. It was a flat `draw_rect` of one colour, a dark 1.5px border, and four black dots for bolts —
## which is, exactly and not approximately, how you draw a BUTTON. Every machine in the game was the same
## 30x30 flat square in a different hue with an icon on it. Hue and icon are how a toolbar distinguishes its
## entries; they are not how a world distinguishes its objects.
##
## What separates a drawn object from a drawn control is LIGHT. The world has a sun somewhere above it, and
## every rock in it is shaded accordingly; the machines were lit from nowhere, so they sat on top of the
## scene instead of in it. So this is a lighting model and almost nothing else:
##
##   TOP-LIT BODY.   A pale wash across the top third, a heavier shadow across the bottom quarter. Painted
##                   as white/black at low alpha rather than by computing new colours, so every machine in
##                   the registry keeps its own hue exactly and gets the same light for free.
##   BEVEL.          One pixel of near-white on the top edge, one pixel of near-black on the bottom and
##                   right. This is the entire trick behind why a lit cube reads as a cube: two edges catch
##                   the light, two edges do not. It costs four rects.
##   PLINTH.         A darker band across the foot, so the machine is BOLTED DOWN to the floor rather than
##                   pasted onto it. Paired with the contact shadow the renderer already drew.
##
## WHY THE DETAIL TIER EXISTS. Rivets, vents and a recessed faceplate are what actually sell sheet metal —
## and at the locked 0.50x play zoom a 32px cell is 16 screen pixels, where a 1px rivet is half a pixel of
## grey mush and a vent slot is nothing at all. Detail below the pixel grid is not subtle, it is a cost with
## no image attached. So the fine work draws only when it is resolvable, and the cheap tier carries the
## whole load at play zoom, which is right on both counts: shading and silhouette are what read when small,
## and they are also the part that fits in the frame budget on a mature base.
## COLD IRON — how far an idle machine falls away from its working colour. `PC-05`: *"give installed
## machines a visible active/idle distinction"*, guarded by *"causality survives labels hidden and
## grayscale."*
##
## **THE DISTINCTION IS SUBTRACTED FROM IDLE RATHER THAN ADDED TO WORKING, and that direction is the whole
## design.** The obvious move is to brighten a running machine — and this file already records that A/B
## being decisive against it: a broad pale wash lifted the body's mid-value until it met the glyph painted
## on top of it, and the Drift Rig's white rails stopped separating from their own casing. *"Legibility
## outranks the look, and the glyph is the part that has to be read."* Taking value AWAY from the idle
## state leaves the working state — the one a player spends their time looking at, and the one every
## glyph in the vocabulary was drawn against — **byte-identical**.
##
## MEASURED, NOT CHOSEN BY EYE. `check_machine_state` photographs each machine working and stopped with
## its label, badge and status lamp suppressed, converts to Rec.709 luma, and separates the state
## difference from what the animation contributes on its own. Before this, the Drill's state difference
## was 14.4 levels against a 7.6-level motion baseline — **a still frame of a running drill and a stopped
## one were the same picture with the gear at a different angle.**
const COLD_DARKEN: float = 0.22       ## how much value an idle casing gives up
const COLD_DESAT: float = 0.18        ## ...and how far it drifts toward grey, so it reads cold not shadowed

static func draw_machine_casing(canvas: CanvasItem, pos: Vector2, cell_px: float, col_in: Color,
		active: bool, detail: bool) -> void:
	var col: Color = col_in if active else _cold_iron(col_in)
	var c: float = cell_px
	var body := Rect2(pos + Vector2(1.0, 1.0), Vector2(c - 2.0, c - 2.0))
	canvas.draw_rect(body, col)

	# --- the light: A THIN CATCH AND A DEEP SHADOW, not a wash --------------------
	# The first version of this lit the top THIRD with a broad pale wash, and the A/B was decisive against
	# it: the body's mid-value climbed until it met the glyph painted on top of it, and the Drift Rig's white
	# rails stopped separating from their own casing. Under a torch — where the world light is already
	# multiplying everything — it read as a blown-out cream tile, which is a worse UI tile than the flat one
	# it replaced. LEGIBILITY OUTRANKS THE LOOK, and the glyph is the part that has to be read.
	#
	# So the light is where light actually is on a 32px object: a couple of pixels catching it along the top,
	# and a real shadow across the foot. The body keeps its registry colour in the middle, which is the value
	# every glyph in the vocabulary was drawn against.
	canvas.draw_rect(Rect2(body.position, Vector2(body.size.x, 3.0)), Color(1.0, 0.98, 0.92, 0.07))
	canvas.draw_rect(Rect2(body.position + Vector2(0.0, body.size.y - c * 0.30),
		Vector2(body.size.x, c * 0.30)), Color(0.0, 0.0, 0.02, 0.30))

	# --- the bevel: two edges catch it, two do not --------------------------------
	# A WORKING machine takes its top light warm. This is the only emissive the casing has, and it is
	# deliberately one pixel: the glyphs already animate, and a body that pulses too would give every
	# powered machine on screen its own heartbeat competing with the avatar.
	var top: Color = col.lightened(0.34) if not active else col.lightened(0.34).lerp(Color(1.0, 0.86, 0.58), 0.30)
	canvas.draw_rect(Rect2(body.position, Vector2(body.size.x, 1.0)), top)
	canvas.draw_rect(Rect2(body.position, Vector2(1.0, body.size.y)), col.lightened(0.16))
	canvas.draw_rect(Rect2(body.position + Vector2(0.0, body.size.y - 1.0), Vector2(body.size.x, 1.0)),
		col.darkened(0.50))
	canvas.draw_rect(Rect2(body.position + Vector2(body.size.x - 1.0, 0.0), Vector2(1.0, body.size.y)),
		col.darkened(0.42))

	# --- the plinth: this thing is bolted to the floor ----------------------------
	canvas.draw_rect(Rect2(pos.x + 2.0, pos.y + c - 4.0, c - 4.0, 3.0), Color(0.05, 0.05, 0.07, 0.55))
	# and the hard outline that keeps it off the rock behind it
	canvas.draw_rect(Rect2(pos, Vector2(c, c)), Color(0.03, 0.03, 0.05, 0.85), false, 1.0)

	if not detail:
		return

	# --- the tier that only exists when you can see it ----------------------------
	# A RECESSED FACEPLATE: the glyph sits in a panel sunk into the body, which is why it reads as stamped
	# into the machine instead of stickered onto it. The bevel runs the OTHER WAY here — dark on top, light
	# on the bottom — because that inversion is the only thing that distinguishes a hole from a bump.
	#
	# The plate also does legibility work, and it is the reason the number here is 0.26 and not the 0.20 it
	# started at: sinking the panel DARKENS the ground the glyph is drawn on, so every glyph in the
	# vocabulary gains contrast against its own machine. The recess and the readability want the same thing.
	var face := Rect2(pos + Vector2(5.0, 5.0), Vector2(c - 10.0, c - 10.0))
	canvas.draw_rect(face, Color(0.0, 0.0, 0.02, 0.26))
	canvas.draw_rect(Rect2(face.position, Vector2(face.size.x, 1.0)), Color(0.0, 0.0, 0.02, 0.38))
	canvas.draw_rect(Rect2(face.position + Vector2(0.0, face.size.y - 1.0), Vector2(face.size.x, 1.0)),
		col.lightened(0.22))

	# VENTS: three slots cut in the lower body. Sheet metal with a hole in it is unmistakably manufactured,
	# and this is the cheapest manufactured thing to draw.
	for i: int in 3:
		canvas.draw_rect(Rect2(pos.x + 6.0 + float(i) * 4.0, pos.y + c - 8.0, 2.0, 3.0),
			Color(0.0, 0.0, 0.02, 0.42))

	# RIVETS: a dark seat with a lit crown offset up-left, toward the same sun the bevel assumes. A rivet
	# drawn as a single black dot — which is what shipped — is a hole, not a fastener.
	for corner: Vector2 in [Vector2(4.0, 4.0), Vector2(c - 4.0, 4.0), Vector2(4.0, c - 4.0),
			Vector2(c - 4.0, c - 4.0)]:
		canvas.draw_circle(pos + corner, 1.4, Color(0.0, 0.0, 0.02, 0.55))
		canvas.draw_circle(pos + corner - Vector2(0.4, 0.4), 0.7, col.lightened(0.40))


## An idle casing: value gone and the hue pulled toward grey. Both, because darkening alone reads as a
## machine standing in shadow — which is a fact about the lighting, not about the machine — while
## desaturation alone reads as a different material. Together they read as switched off.
static func _cold_iron(c: Color) -> Color:
	var grey: float = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
	return c.lerp(Color(grey, grey, grey), COLD_DESAT).darkened(COLD_DARKEN)


## Draw a machine's silhouette glyph centred at `center`, scaled by `s` (1.0 = full 32px world icon,
## smaller for HUD chips). `active` + `t` (a free-running clock) drive the WORKING animation — a gear
## that spins, an ember that breathes, lift chevrons that march up; pass active=false for a still icon.
## `flip` mirrors DIRECTIONAL glyphs (the Borer bores left when its machine faces -1); others ignore it.
static func draw_machine_glyph(canvas: CanvasItem, center: Vector2, kind: String, s: float,
		active: bool, t: float, flip: bool = false, fill: float = 1.0) -> void:
	match kind:
		"collar":
			_collar(canvas, center, s, active, t, fill)
		"spur":
			_spur(canvas, center, s, active, t, fill)
		"furnace":
			_furnace(canvas, center, s, active, t)
		"gear":
			_gear(canvas, center, s, active, t)
		"lift":
			_lift(canvas, center, s, active, t)
		"fork":
			_fork(canvas, center, s)
		"drill":
			_drill(canvas, center, s, active, t)
		"generator":
			_generator(canvas, center, s, active, t)
		"conduit":
			_conduit(canvas, center, s, active, t)
		"hopper":
			_hopper(canvas, center, s, active, t)
		"rope":
			_rope(canvas, center, s)
		"torch":
			_torch(canvas, center, s, active, t)
		"press":
			_press(canvas, center, s, active, t)
		"h_drill":
			_h_drill(canvas, center, s, active, t, flip)
		"drift":
			_drift(canvas, center, s, active, t, flip)
		"crush":
			_crusher(canvas, center, s, active, t)
		"descent":
			_descent(canvas, center, s, active, t)
		"pump":
			_pump(canvas, center, s, active, t)


## Furnace (ore source / forge): a dark mouth with a glowing ember + lintel. The ember BREATHES while burning.
static func _furnace(canvas: CanvasItem, c: Vector2, s: float, active: bool, t: float) -> void:
	canvas.draw_rect(Rect2(c.x - 8.0 * s, c.y - 9.0 * s, 16.0 * s, 2.5 * s), Color(0.05, 0.05, 0.07))
	canvas.draw_rect(Rect2(c.x - 6.5 * s, c.y - 4.0 * s, 13.0 * s, 10.0 * s), Color(0.12, 0.08, 0.05))
	var ember := c + Vector2(0.0, 2.5 * s)
	if active:
		var p: float = 0.78 + 0.22 * sin(t * 6.5)          # the ember BREATHES while burning
		canvas.draw_circle(ember, 3.4 * s * (0.85 + 0.25 * p), Color(1.0, 0.55, 0.18).lightened(0.18 * p))
		canvas.draw_circle(ember, 1.7 * s * (0.85 + 0.25 * p), Color(1.0, 0.90, 0.55))
	else:
		# COLD: a dead dark coal bed in the mouth — no glow, so an UNLIT forge reads as an off machine
		# (light = working). The idle spawn forges no longer out-shout the avatar + ore.
		canvas.draw_circle(ember, 2.8 * s, Color(0.30, 0.15, 0.11))
		canvas.draw_circle(ember, 1.3 * s, Color(0.40, 0.21, 0.15))


## Gear (processor): a cogged dark disc with a bright hub. ROTATES while running — the "machine is on" read.
static func _gear(canvas: CanvasItem, c: Vector2, s: float, active: bool, t: float) -> void:
	var gear := Color(0.10, 0.13, 0.18)
	var spin: float = t * 2.6 if active else 0.0
	canvas.draw_circle(c, 6.2 * s, gear)
	for i: int in 8:
		var a: float = TAU * float(i) / 8.0 + spin
		canvas.draw_circle(c + Vector2(cos(a), sin(a)) * 6.8 * s, 1.7 * s, gear)
	var hub := Color(0.55, 0.78, 0.98)
	canvas.draw_circle(c, 2.6 * s, hub.lightened(0.25) if active else hub)


## Lift: stacked UP-chevrons. They MARCH upward while carrying — the goods-go-up read.
static func _lift(canvas: CanvasItem, c: Vector2, s: float, active: bool, t: float) -> void:
	var up := Color(0.85, 1.0, 0.95)
	var rise: float = (fmod(t * 9.0, 7.0) if active else 0.0) * s
	for k: int in 2:
		var oy: float = float(k) * 7.0 * s - 2.0 * s - rise
		var a: float = 1.0 if not active else clampf(1.0 - (float(k) * 7.0 * s - rise) / (9.0 * s), 0.35, 1.0)
		var col := Color(up.r, up.g, up.b, a)
		canvas.draw_line(c + Vector2(-6.0 * s, oy + 4.0 * s), c + Vector2(0.0, oy - 2.0 * s), col, 2.0)
		canvas.draw_line(c + Vector2(0.0, oy - 2.0 * s), c + Vector2(6.0 * s, oy + 4.0 * s), col, 2.0)


## Drill: a boxy housing over a downward-pointing bit with helical flutes. The bit BOBS down and the
## flutes MARCH while boring — the "it's chewing into the rock below" read (mirrors what _run_drill does).
static func _drill(canvas: CanvasItem, c: Vector2, s: float, active: bool, t: float) -> void:
	var steel := Color(0.16, 0.18, 0.22)
	var edge := Color(0.78, 0.66, 0.40)
	var bob: float = (sin(t * 14.0) * 0.9 if active else 0.0) * s   # the hammer-judder of drilling
	# Housing (the motor block up top).
	canvas.draw_rect(Rect2(c.x - 6.5 * s, c.y - 8.0 * s, 13.0 * s, 6.0 * s), steel)
	canvas.draw_rect(Rect2(c.x - 6.5 * s, c.y - 8.0 * s, 13.0 * s, 1.5 * s), edge)
	# Bit: a tapering shaft to a point, with flute ticks that scroll downward while active.
	var tip := Vector2(c.x, c.y + 9.0 * s + bob)
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - 4.0 * s, c.y - 2.0 * s), Vector2(c.x + 4.0 * s, c.y - 2.0 * s), tip]), steel)
	var march: float = fmod(t * 16.0, 4.0) * s if active else 0.0
	for k: int in 3:
		var fy: float = c.y - 1.0 * s + float(k) * 3.2 * s + march + bob
		if fy < c.y + 7.5 * s:
			canvas.draw_line(Vector2(c.x - 3.0 * s, fy), Vector2(c.x + 3.0 * s, fy - 1.4 * s), edge, 1.0)


## THE COLLAR — a Drill Head bolted to the rock, boring INTO THE BACKGROUND (`docs/LODE.md` §5).
##
## This machine works along an axis the game does not have. Sinkforge is a side view: X and Y are the whole
## world, and a Head bores along Z, into the screen. The old drill glyph — a motor block with a tapering bit
## pointing DOWN and flutes marching downward — said "I bore downward through solid rock" as clearly as a
## glyph can, and once ore moved to the background plane that became a lie the player would believe.
##
## Four cues, all flat, none of them a perspective axis borrowed from a different game:
##   FORESHORTENING.  A bit pointing at you is a CIRCLE, not a shaft. The bore reads as a dark socket with a
##                    lit rim — the universal "hole going away from you".
##   SCALE, NOT BOB.  The judder pulses the socket's SIZE. Things moving toward the viewer grow; things
##                    moving along the plane slide. Swapping translation for scale is the whole axis flip.
##   RADIAL SPOIL.    Dust leaves the hole in every direction rather than falling one way — it is coming OUT
##                    at you, which only makes sense if the hole faces you.
##   A FRAME, NOT A FILL. Rails and a bracket, open in the middle, so the vein it is eating shows straight
##                    through the machine. A machine that sits on a resource must never hide it — and since
##                    the fleck field thins as the deposit drains, the Head becomes a gauge for free.
##
## And the socket WIDENS as the vein goes (`fill` 1 → 0), so the machine and the flecks tell the same story
## from opposite ends: the metal thins out while the hole eats outward.
## THE SPUR — the Collar's smaller sibling, and drawn to say so.
##
## It reads as the same machine wearing less of it: the same amber frame, the same dark bore, the same
## inverted value relationship that lets a frame survive being seen against dark rock. What it does NOT have
## is a chute, and that absence is the whole sentence — a Spur's haul does not leave here, it leaves at the
## Head. What it has instead is a LINK ARM reaching out of one side toward whatever it is chained to, so a
## line of them reads as one machine with several mouths rather than as several machines that happen to be
## adjacent. Unlinked, the arm reaches into nothing and the bore goes cold, which is what being unlinked is.
static func _spur(canvas: CanvasItem, c: Vector2, s: float, active: bool, t: float, fill: float) -> void:
	var steel := Color(0.66, 0.53, 0.32)
	var edge := Color(0.90, 0.80, 0.56)
	var shade := Color(0.10, 0.09, 0.12)
	var left: float = c.x - 5.4 * s
	canvas.draw_rect(Rect2(left, c.y - 7.2 * s, 10.8 * s, 3.6 * s), steel)       # the mount, shorter
	canvas.draw_rect(Rect2(left, c.y - 7.2 * s, 10.8 * s, 1.1 * s), edge)
	canvas.draw_rect(Rect2(left, c.y - 3.9 * s, 10.8 * s, 0.8 * s), shade)
	for rx: float in [left, c.x + 3.6 * s]:                                       # two short rails
		canvas.draw_rect(Rect2(rx, c.y - 3.6 * s, 1.8 * s, 7.4 * s), steel)
		canvas.draw_rect(Rect2(rx, c.y - 3.6 * s, 0.7 * s, 7.4 * s), edge)
	# THE LINK ARM: it belongs to something. Drawn low and wide so it reads as reaching sideways, not down.
	var arm: Color = edge if active else Color(steel, 0.55)
	canvas.draw_rect(Rect2(c.x - 9.5 * s, c.y + 3.4 * s, 19.0 * s, 1.5 * s), arm)
	var bore := Vector2(c.x, c.y + 0.2 * s)
	var pulse: float = (1.0 + 0.08 * sin(t * 18.0)) if active else 1.0
	var r: float = (2.4 + 2.0 * (1.0 - clampf(fill, 0.0, 1.0))) * s * pulse
	canvas.draw_circle(bore, r + 1.0 * s, Color(0.0, 0.0, 0.0, 0.42))
	canvas.draw_circle(bore, r, Color(0.03, 0.03, 0.05, 0.94))
	canvas.draw_arc(bore, r, 0.0, TAU, 16, edge, 1.2 * s)
	if not active:
		return
	canvas.draw_arc(bore, r, PI * 0.85, PI * 1.55, 8, Color(1.0, 0.93, 0.74, 0.9), 1.4 * s)
	for k: int in 3:
		var ang: float = float(k) * TAU / 3.0 + t * 0.7
		var phase: float = fmod(t * 1.9 + float(k) * 0.3, 1.0)
		canvas.draw_circle(bore + Vector2(cos(ang), sin(ang)) * (r + phase * 4.0 * s),
			(1.2 - phase) * s, Color(0.72, 0.66, 0.56, 0.5 * (1.0 - phase)))


static func _collar(canvas: CanvasItem, c: Vector2, s: float, active: bool, t: float, fill: float) -> void:
	# THE FRAME CARRIES ITS OWN CONTRAST. Every other machine draws near-black steel on top of an opaque
	# machine-coloured casing, and the casing is what makes the dark glyph read. Dropping the casing to show
	# the vein through it (which is the whole point) also dropped that contrast, and the first cut of this
	# vanished into dark rock entirely — only the bore ring survived. So the value relationship inverts: the
	# frame is the LIGHT part now, and the bore is the dark one.
	var steel := Color(0.66, 0.53, 0.32)
	var edge := Color(0.90, 0.80, 0.56)
	var shade := Color(0.10, 0.09, 0.12)
	var left: float = c.x - 7.0 * s
	# The mount: a bracket and motor housing across the TOP, so it reads as hung off the face rather than
	# standing on the floor. Everything else in this game sits on something; this one is bolted to a wall.
	canvas.draw_rect(Rect2(left, c.y - 9.0 * s, 14.0 * s, 5.0 * s), steel)
	canvas.draw_rect(Rect2(left, c.y - 9.0 * s, 14.0 * s, 1.3 * s), edge)
	canvas.draw_rect(Rect2(left, c.y - 4.4 * s, 14.0 * s, 0.9 * s), shade)      # the housing's under-lip
	for bx: float in [left + 2.0 * s, c.x + 5.0 * s]:
		canvas.draw_circle(Vector2(bx, c.y - 6.5 * s), 0.9 * s, Color(shade, 0.75))   # bolts
	# The rails: the frame's two legs. The middle is deliberately EMPTY.
	for rx: float in [left, c.x + 4.8 * s]:
		canvas.draw_rect(Rect2(rx, c.y - 4.0 * s, 2.2 * s, 10.0 * s), steel)
		canvas.draw_rect(Rect2(rx, c.y - 4.0 * s, 0.8 * s, 10.0 * s), edge)
	# The BORE, head-on. Scale-pulsed while cutting; wider the more of the vein it has taken.
	var bore := Vector2(c.x, c.y + 0.5 * s)
	var pulse: float = (1.0 + 0.08 * sin(t * 18.0)) if active else 1.0
	var r: float = (3.2 + 2.8 * (1.0 - clampf(fill, 0.0, 1.0))) * s * pulse
	canvas.draw_circle(bore, r + 1.2 * s, Color(0.0, 0.0, 0.0, 0.45))       # the shadow it casts inward
	canvas.draw_circle(bore, r, Color(0.03, 0.03, 0.05, 0.94))
	canvas.draw_arc(bore, r, 0.0, TAU, 20, edge, 1.4 * s)
	canvas.draw_arc(bore, r, PI * 0.85, PI * 1.55, 8, Color(1.0, 0.93, 0.74, 0.9), 1.6 * s)  # the lit lip
	# The chute: where the haul leaves, downward, on the hook.
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - 3.6 * s, c.y + 5.8 * s), Vector2(c.x + 3.6 * s, c.y + 5.8 * s),
		Vector2(c.x + 2.1 * s, c.y + 8.8 * s), Vector2(c.x - 2.1 * s, c.y + 8.8 * s)]), steel)
	canvas.draw_line(Vector2(c.x - 2.1 * s, c.y + 8.8 * s), Vector2(c.x + 2.1 * s, c.y + 8.8 * s),
		shade, 1.4 * s)                                        # the open mouth of the chute, in shadow
	if not active:
		return
	# Spoil, thrown OUT of the hole in every direction — the cue that the hole faces the viewer.
	for k: int in 5:
		var ang: float = float(k) * TAU / 5.0 + t * 0.7
		var phase: float = fmod(t * 1.9 + float(k) * 0.2, 1.0)
		var d: float = r + phase * 5.0 * s
		canvas.draw_circle(bore + Vector2(cos(ang), sin(ang)) * d, (1.5 - phase) * s,
			Color(0.72, 0.66, 0.56, 0.55 * (1.0 - phase)))


## The Borer (horizontal drill): the vertical drill's cousin turned on its side — a motor block with a
## tapering bit pointing along its FACING (flip mirrors it), flutes scrolling forward + a judder while
## it chews, and a little coal-fire dot for its self-feeding bunker.
static func _h_drill(canvas: CanvasItem, c: Vector2, s: float, active: bool, t: float, flip: bool) -> void:
	var f: float = -1.0 if flip else 1.0
	var steel := Color(0.16, 0.18, 0.22)
	var edge := Color(0.72, 0.60, 0.38)
	var bob: float = (sin(t * 14.0) * 0.9 if active else 0.0) * s        # forward judder while boring
	# The motor block sits on the REAR side (opposite the bit); a lit strip marks its back plate.
	var bx: float = (c.x - 8.0 * s) if f > 0.0 else (c.x - 2.0 * s)
	canvas.draw_rect(Rect2(bx, c.y - 6.5 * s, 10.0 * s, 13.0 * s), steel)
	canvas.draw_rect(Rect2(bx if f > 0.0 else bx + 8.5 * s, c.y - 6.5 * s, 1.5 * s, 13.0 * s), edge)
	# The bit: a tapering shaft to a point along the facing, flutes scrolling forward while it chews.
	var tip := Vector2(c.x + (9.0 * s + bob) * f, c.y)
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(c.x + 2.0 * s * f, c.y - 4.0 * s), Vector2(c.x + 2.0 * s * f, c.y + 4.0 * s), tip]), steel)
	var march: float = fmod(t * 16.0, 4.0) * s if active else 0.0
	for k: int in 3:
		var fx: float = c.x + (1.0 * s + float(k) * 3.2 * s + march) * f
		if absf(fx - c.x) < 7.5 * s:
			canvas.draw_line(Vector2(fx, c.y - 3.0 * s), Vector2(fx - 1.4 * s * f, c.y + 3.0 * s), edge, 1.0)
	var fire: float = (0.7 + 0.3 * sin(t * 7.0)) if active else 0.3     # the coal bunker's fire dot
	canvas.draw_circle(c + Vector2(-4.5 * s * f, 4.0 * s), 1.6 * s, Color(1.0, 0.55, 0.18, 0.4 + 0.5 * fire))


## THE DRIFT RIG: a squat powered gallery machine. It reads as the Borer's bigger sibling on purpose — same
## facing, same forward judder — but with the two things that make it a different machine drawn where you can
## see them: a TWO-HIGH cutting head (the walkable gallery it leaves) and a SORTER — two chutes under the
## body, one pointing down for pay and one pointing back for spoil, with a divider between them. Its power is
## an arc across the head rather than a fire, because it eats a network and not a coal box.
static func _drift(canvas: CanvasItem, c: Vector2, s: float, active: bool, t: float, flip: bool) -> void:
	var f: float = -1.0 if flip else 1.0
	var steel := Color(0.10, 0.12, 0.14)
	var edge := Color(0.78, 0.84, 0.82)
	var pay := Color(0.92, 0.74, 0.30)      # the ore chute wears ORE's colour...
	var spoil := Color(0.60, 0.60, 0.62)    # ...and the rock chute wears ROCK's. That IS the machine.
	var bob: float = (sin(t * 11.0) * 1.2 if active else 0.0) * s
	# The body: one dark block with its mass to the rear, so the bright bar at the face has something to
	# read against. At 32 world pixels a machine gets two shapes and a colour — no more.
	var bx: float = (c.x - 10.0 * s) if f > 0.0 else (c.x - 2.0 * s)
	canvas.draw_rect(Rect2(bx, c.y - 8.0 * s, 12.0 * s, 17.0 * s), steel)
	# THE CUTTER BAR: ONE bright bar spanning the full height of the face, with four teeth biting forward
	# off it. Two small drums read as a single arrow at world scale — the full-height bar is the only way
	# "it cuts two cells high" survives to 32 pixels, and the teeth are what make it a cutter not a mast.
	var bar: float = c.x + (5.0 * s + bob) * f
	canvas.draw_line(Vector2(bar, c.y - 11.0 * s), Vector2(bar, c.y + 10.0 * s), edge, 3.2 * s)
	var march: float = (fmod(t * 9.0, 6.0) if active else 0.0) * s
	for k: int in 4:
		var ty: float = c.y + (-9.5 + 6.0 * float(k)) * s + march
		if ty > c.y + 10.0 * s:
			ty -= 21.0 * s
		canvas.draw_colored_polygon(PackedVector2Array([
			Vector2(bar, ty - 1.8 * s), Vector2(bar, ty + 1.8 * s),
			Vector2(bar + 4.2 * s * f, ty)]), edge)
	# THE SORTER: two chutes under the belly, each in the colour of what falls out of it — pay straight
	# down its own column, spoil back down the one behind. They are the machine's whole reason to exist,
	# so they are drawn as material, not as plumbing.
	var pay_x: float = c.x - 2.0 * s * f
	var spoil_x: float = c.x - 7.5 * s * f
	canvas.draw_line(Vector2(pay_x, c.y + 6.0 * s), Vector2(pay_x, c.y + 12.0 * s), pay, 3.0 * s)
	canvas.draw_line(Vector2(spoil_x, c.y + 6.0 * s), Vector2(spoil_x - 3.5 * s * f, c.y + 12.0 * s),
		spoil, 3.0 * s)
	# The power tell: an arc across the roof of the body — bright while it cuts, a dim filament while it
	# waits on the network. It eats a network, not a coal box, so it never shows fire.
	var arc: float = (0.6 + 0.4 * sin(t * 19.0)) if active else 0.20
	var spark := Color(0.62, 0.88, 1.0, 0.30 + 0.65 * arc)
	canvas.draw_line(c + Vector2(-8.0 * s * f, -9.5 * s), c + Vector2(-2.0 * s * f, -9.5 * s), spark, 1.6)


## THE CRUSHER (docs/DRIFT.md §4): two counter-rotating toothed ROLLERS with rock going in the top and
## gravel coming out the bottom. The read has to be "this eats what falls into it and something smaller
## comes out", so the rollers turn OPPOSITE ways while it works and the spill below is drawn in gravel's
## own colour — the same trick the Drift Rig's chutes use, and for the same reason.
static func _crusher(canvas: CanvasItem, c: Vector2, s: float, active: bool, t: float) -> void:
	var steel := Color(0.11, 0.12, 0.13)
	var edge := Color(0.74, 0.76, 0.78)
	var grit := Color(0.46, 0.48, 0.51)
	# The hopper mouth: a funnel at the top, wide open, so it reads as a thing you POUR into.
	canvas.draw_colored_polygon(PackedVector2Array([
		c + Vector2(-10.0 * s, -11.0 * s), c + Vector2(10.0 * s, -11.0 * s),
		c + Vector2(4.5 * s, -4.0 * s), c + Vector2(-4.5 * s, -4.0 * s)]), steel)
	# The two rollers, turning against each other while it runs.
	var spin: float = (t * 4.5) if active else 0.0
	for k: int in 2:
		var dir: float = 1.0 if k == 0 else -1.0
		var r := Vector2(c.x + dir * 4.6 * s, c.y + 0.5 * s)
		canvas.draw_circle(r, 4.2 * s, steel)
		for i: int in 5:
			var a: float = spin * dir + float(i) * TAU / 5.0
			canvas.draw_line(r + Vector2(cos(a), sin(a)) * 2.0 * s,
				r + Vector2(cos(a), sin(a)) * 5.2 * s, edge, 1.3)
	# The spill: crushed grit falling out of the nip, in gravel's colour.
	var fall: float = (fmod(t * 14.0, 6.0) if active else 2.0) * s
	for k2: int in 3:
		var gy: float = c.y + 6.0 * s + fall + float(k2) * 2.6 * s
		if gy > c.y + 12.0 * s:
			gy -= 7.8 * s
		canvas.draw_circle(Vector2(c.x + (-1.6 + 1.6 * float(k2)) * s, gy), 1.3 * s, grit)


## Generator (coal burner → power): a steel housing with a coal-fire at its base that BREATHES while
## fueled, and a bright lightning bolt that flares when it's pouring power. The fire + bolt go dim/still
## when it runs dry — the "is it making power?" read (mirrors _run_generator's fuel state).
static func _generator(canvas: CanvasItem, c: Vector2, s: float, active: bool, t: float) -> void:
	var steel := Color(0.15, 0.16, 0.20)
	canvas.draw_rect(Rect2(c.x - 7.0 * s, c.y - 7.5 * s, 14.0 * s, 15.0 * s), steel)
	# Coal fire glowing in the firebox at the base — breathes while burning.
	var p: float = (0.72 + 0.28 * sin(t * 7.0)) if active else 0.32
	var fire := c + Vector2(0.0, 5.0 * s)
	canvas.draw_circle(fire, 4.2 * s * (0.8 + 0.3 * p), Color(1.0, 0.5, 0.15, 0.55 + 0.4 * p))
	canvas.draw_circle(fire, 2.0 * s, Color(1.0, 0.85, 0.45, 0.6 + 0.4 * p))
	# Lightning bolt up top — the power output, bright when active.
	var bolt := Color(1.0, 0.92, 0.45).lightened(0.2 * p) if active else Color(0.55, 0.52, 0.34)
	var w: float = 2.2 if active else 1.6
	var pts := PackedVector2Array([
		c + Vector2(1.5 * s, -7.0 * s), c + Vector2(-2.0 * s, -1.5 * s),
		c + Vector2(0.8 * s, -1.5 * s), c + Vector2(-1.8 * s, 4.5 * s)])
	for i: int in pts.size() - 1:
		canvas.draw_line(pts[i], pts[i + 1], bolt, w)


## Conduit (power tube): a copper pipe with end couplings + an inner channel that GLOWS and a spark that
## travels DOWN it while power flows (active) — the "power pours down this tube" read. Used for the hotbar
## icon; the in-world tube is drawn by WorldRenderer (it knows orientation + the live power level).
static func _conduit(canvas: CanvasItem, c: Vector2, s: float, active: bool, t: float) -> void:
	var copper := Color(0.46, 0.32, 0.20)
	canvas.draw_rect(Rect2(c.x - 3.5 * s, c.y - 8.0 * s, 7.0 * s, 16.0 * s), copper)
	canvas.draw_rect(Rect2(c.x - 5.0 * s, c.y - 8.0 * s, 10.0 * s, 2.2 * s), copper)   # top coupling
	canvas.draw_rect(Rect2(c.x - 5.0 * s, c.y + 5.8 * s, 10.0 * s, 2.2 * s), copper)   # bottom coupling
	var glow := Color(1.0, 0.85, 0.40, 0.85) if active else Color(0.30, 0.26, 0.20, 0.7)
	canvas.draw_rect(Rect2(c.x - 1.4 * s, c.y - 7.0 * s, 2.8 * s, 14.0 * s), glow)     # inner channel
	if active:                                                                          # a spark falling down it
		var sy: float = c.y - 6.0 * s + fmod(t * 26.0, 12.0) * s
		canvas.draw_circle(Vector2(c.x, sy), 1.7 * s, Color(1.0, 0.96, 0.7))


## Hopper (storage bin): an inverted funnel mouth over a bin that holds a MOUND of stockpiled goods, with a
## chute at the base metering a bit DOWN while feeding (active). The mound + the falling nub read "it banks
## what pours in and trickles it out" — the chest of the gravity factory.
static func _hopper(canvas: CanvasItem, c: Vector2, s: float, active: bool, t: float) -> void:
	var steel := Color(0.30, 0.34, 0.42)
	var lip := Color(0.52, 0.57, 0.66)
	# Funnel mouth (wide top tapering in) — the catch.
	canvas.draw_colored_polygon(PackedVector2Array([
		c + Vector2(-8.0 * s, -8.0 * s), c + Vector2(8.0 * s, -8.0 * s),
		c + Vector2(4.5 * s, -2.0 * s), c + Vector2(-4.5 * s, -2.0 * s)]), steel)
	canvas.draw_line(c + Vector2(-8.0 * s, -8.0 * s), c + Vector2(8.0 * s, -8.0 * s), lip, 1.6)
	# Bin body holding a heaped mound of goods.
	canvas.draw_rect(Rect2(c.x - 4.5 * s, c.y - 2.0 * s, 9.0 * s, 8.0 * s), steel.darkened(0.15))
	var gold := Color(0.86, 0.66, 0.30)
	canvas.draw_colored_polygon(PackedVector2Array([
		c + Vector2(-4.0 * s, 5.0 * s), c + Vector2(-1.0 * s, 0.5 * s),
		c + Vector2(1.5 * s, 2.0 * s), c + Vector2(4.0 * s, 5.0 * s)]), gold)  # the stockpile mound
	# Chute at the base + a nub of goods trickling out while feeding.
	canvas.draw_rect(Rect2(c.x - 1.6 * s, c.y + 5.5 * s, 3.2 * s, 2.5 * s), steel)
	if active:
		var fy: float = c.y + 8.0 * s + fmod(t * 18.0, 5.0) * s
		canvas.draw_circle(Vector2(c.x, fy), 1.5 * s, gold.lightened(0.2))


## Descent Engine (the L1→L2 gate-breacher): a heavy cross-braced housing over a massive down-RAM that
## POUNDS while it's eating goods — the "it's hammering the seal open" read. A pale progress core glows
## in the housing as the quota fills (the view scales it via the machine's fed fraction elsewhere; the
## glyph itself just breathes).
static func _descent(canvas: CanvasItem, c: Vector2, s: float, active: bool, t: float) -> void:
	var housing := Color(0.16, 0.12, 0.20)
	var brace := Color(0.55, 0.42, 0.62)
	var pound: float = (absf(sin(t * 10.0)) * 2.2 if active else 0.0) * s
	canvas.draw_rect(Rect2(c.x - 8.0 * s, c.y - 9.0 * s, 16.0 * s, 7.0 * s), housing)
	canvas.draw_line(c + Vector2(-8.0 * s, -9.0 * s), c + Vector2(8.0 * s, -2.0 * s), brace, 1.4)
	canvas.draw_line(c + Vector2(8.0 * s, -9.0 * s), c + Vector2(-8.0 * s, -2.0 * s), brace, 1.4)
	# The RAM: a thick shaft into a broad wedge head, driven downward while pounding.
	canvas.draw_rect(Rect2(c.x - 2.2 * s, c.y - 2.0 * s, 4.4 * s, 5.0 * s + pound), housing.lightened(0.15))
	canvas.draw_colored_polygon(PackedVector2Array([
		c + Vector2(-6.5 * s, 3.0 * s + pound), c + Vector2(6.5 * s, 3.0 * s + pound),
		c + Vector2(0.0, 8.5 * s + pound)]), brace)
	var core: float = 0.9 if active else 0.4
	canvas.draw_circle(c + Vector2(0.0, -5.5 * s), 2.0 * s, Color(0.85, 0.70, 1.0, core))  # the quota core


## Pump (the powered flood-drain, L3): a steel housing with a curved down-SPOUT drawing water UP and OUT —
## a rising water column inside the body + a bright droplet climbing the spout while it's draining (active),
## and a piston knob up top that bobs on the clock. The "it sucks the flood out, on power" read; still + dim
## when unpowered (nothing to pump / no power).
static func _pump(canvas: CanvasItem, c: Vector2, s: float, active: bool, t: float) -> void:
	var steel := Color(0.16, 0.20, 0.26)
	var water := Color(0.34, 0.62, 0.86)
	# Housing.
	canvas.draw_rect(Rect2(c.x - 6.0 * s, c.y - 6.0 * s, 12.0 * s, 13.0 * s), steel)
	# The intake water column drawn up inside the body — rises while pumping.
	var rise: float = (0.55 + 0.35 * (0.5 + 0.5 * sin(t * 6.0))) if active else 0.4
	var col_h: float = 9.0 * s * rise
	canvas.draw_rect(Rect2(c.x - 3.0 * s, c.y + 6.0 * s - col_h, 6.0 * s, col_h),
		Color(water.r, water.g, water.b, 0.55 + 0.35 * (1.0 if active else 0.0)))
	# The curved out-spout arcing over the right lip.
	canvas.draw_line(c + Vector2(0.0, -3.0 * s), c + Vector2(7.5 * s, -3.0 * s), steel.lightened(0.2), 2.6 * s)
	canvas.draw_line(c + Vector2(7.5 * s, -3.0 * s), c + Vector2(7.5 * s, 1.0 * s), steel.lightened(0.2), 2.6 * s)
	# The piston knob up top — bobs while working.
	var bob: float = (sin(t * 8.0) * 1.2 if active else 0.0) * s
	canvas.draw_rect(Rect2(c.x - 1.4 * s, c.y - 9.0 * s + bob, 2.8 * s, 3.5 * s), steel.lightened(0.25))
	# A droplet climbing the spout + spilling out while draining.
	if active:
		var dy: float = -3.0 * s - 3.0 * s * (0.5 + 0.5 * sin(t * 5.0))
		canvas.draw_circle(c + Vector2(7.5 * s, dy), 1.6 * s, water.lightened(0.25))
		var spill: float = c.y + 2.0 * s + fmod(t * 20.0, 5.0) * s
		canvas.draw_circle(c + Vector2(7.5 * s, spill), 1.3 * s, water)


## Rope (the placeable climb): a hanging line with rung KNOTS + a coiled spare at the top — reads as
## "this unrolls down a shaft". Static (a rope doesn't animate); the in-world hang is drawn by
## WorldRenderer per cell, this glyph is the hotbar/craft-panel icon.
static func _rope(canvas: CanvasItem, c: Vector2, s: float) -> void:
	var hemp := Color(0.78, 0.66, 0.44)
	canvas.draw_arc(c + Vector2(0.0, -5.5 * s), 3.4 * s, 0.0, TAU, 14, hemp, 2.0)      # the coil
	canvas.draw_line(c + Vector2(0.0, -2.2 * s), c + Vector2(0.0, 8.5 * s), hemp, 1.8)  # the hanging line
	for k: int in 3:
		var ky: float = 0.5 * s + float(k) * 3.2 * s
		canvas.draw_line(c + Vector2(-1.8 * s, ky), c + Vector2(1.8 * s, ky), hemp.darkened(0.18), 1.6)


## Press (the plate press): a heavy frame over a piston RAM that strokes down onto a glowing slab
## while working — the "it stamps plates" read (mirrors what its recipe does).
static func _press(canvas: CanvasItem, c: Vector2, s: float, active: bool, t: float) -> void:
	var frame := Color(0.13, 0.15, 0.20)
	canvas.draw_rect(Rect2(c.x - 7.5 * s, c.y - 9.0 * s, 15.0 * s, 3.0 * s), frame)     # the head beam
	canvas.draw_rect(Rect2(c.x - 7.5 * s, c.y - 9.0 * s, 2.5 * s, 16.0 * s), frame)     # posts
	canvas.draw_rect(Rect2(c.x + 5.0 * s, c.y - 9.0 * s, 2.5 * s, 16.0 * s), frame)
	var stroke: float = (0.5 + 0.5 * sin(t * 5.0)) if active else 0.15                  # the ram's travel
	var ram_y: float = c.y - 6.0 * s + stroke * 6.5 * s
	canvas.draw_rect(Rect2(c.x - 1.6 * s, c.y - 7.0 * s, 3.2 * s, ram_y - (c.y - 7.0 * s)), Color(0.42, 0.46, 0.55))
	canvas.draw_rect(Rect2(c.x - 4.5 * s, ram_y, 9.0 * s, 2.4 * s), Color(0.60, 0.65, 0.75))  # the die
	var slab := Color(0.85, 0.62, 0.35).lightened(0.2 * stroke) if active else Color(0.45, 0.48, 0.56)
	canvas.draw_rect(Rect2(c.x - 5.5 * s, c.y + 5.2 * s, 11.0 * s, 1.8 * s), slab)      # the worked sheet


## Torch (placeable light): a leaning stick with a live FLAME that gutters on the clock — the in-world
## mount and the hotbar icon share it. `active` full flame; still icons burn steady + small.
static func _torch(canvas: CanvasItem, c: Vector2, s: float, active: bool, t: float) -> void:
	var stick := Color(0.46, 0.32, 0.18)
	var tip := c + Vector2(1.2 * s, -3.5 * s)
	canvas.draw_line(c + Vector2(-1.8 * s, 7.5 * s), tip, stick, 2.4 * maxf(s, 0.6))
	canvas.draw_line(c + Vector2(-1.8 * s, 7.5 * s), tip, stick.lightened(0.18), 1.0 * maxf(s, 0.6))
	var gutter: float = (0.82 + 0.18 * sin(t * 9.0 + c.x * 0.13) + 0.06 * sin(t * 23.0)) if active else 0.9
	var flame := tip + Vector2(0.0, -1.6 * s)
	canvas.draw_circle(flame, 3.0 * s * gutter, Color(1.0, 0.55, 0.16, 0.85))       # outer lick
	canvas.draw_circle(flame + Vector2(0.0, -0.8 * s), 1.6 * s * gutter, Color(1.0, 0.86, 0.42))  # hot core
	canvas.draw_circle(tip, 1.3 * s, Color(0.16, 0.10, 0.06))                        # the charred wrap


## Fork (splitter): a stem that splits DOWN and to the RIGHT — mirrors its 50/50 routing.
static func _fork(canvas: CanvasItem, c: Vector2, s: float) -> void:
	var fork := Color(0.93, 0.88, 1.0)
	canvas.draw_line(c + Vector2(0.0, -6.5 * s), c, fork, 2.0)
	canvas.draw_line(c, c + Vector2(0.0, 7.0 * s), fork, 2.0)
	canvas.draw_line(c, c + Vector2(7.0 * s, 4.0 * s), fork, 2.0)


# --- items -------------------------------------------------------------------

## The colour of a carried/falling/resting item (ore amber, ingot gold).
static func item_color(item: StringName) -> Color:
	if item == &"ore":
		return Color(0.88, 0.52, 0.24)
	if item == &"ingot":
		return Color(0.97, 0.85, 0.42)
	if item == &"wood":
		return Color(0.55, 0.38, 0.22)
	if item == &"coal":
		return Color(0.24, 0.25, 0.29)        # dark slate-black — the generator's fuel
	if item == &"wood_pickaxe":
		return Color(0.62, 0.46, 0.30)        # starter tools — a wood-handle brown
	if item == &"wood_axe":
		return Color(0.70, 0.52, 0.32)
	if item == &"stone_pickaxe":
		return Color(0.56, 0.60, 0.66)        # the tier-2 upgrade — cold stone-grey (unlocks deepslate)
	if item == &"iron_pickaxe":
		return Color(0.78, 0.82, 0.92)        # the tier-3 upgrade — bright steel (the L2 chain's edge)
	if item == &"rope":
		return Color(0.78, 0.66, 0.44)        # hemp — the placeable climb
	if item == &"torch":
		return Color(1.0, 0.76, 0.36)         # flame amber — placeable light
	if item == &"scanner":
		return Color(0.45, 0.85, 0.95)        # sonar cyan — the prospecting handheld
	if item == &"sapling":
		return Color(0.44, 0.66, 0.30)        # young leaf-green — the renewable-wood seed (#38)
	if item == &"rich_ore":
		return Color(1.0, 0.86, 0.46)         # white-gold — the high-grade vein's chunk (#48)
	if item == &"iron":
		return Color(0.72, 0.76, 0.85)        # pale steel — L2's signature ore
	if item == &"iron_ingot":
		return Color(0.80, 0.84, 0.92)        # refined steel bar — the L2 chain's base good
	if item == &"plate":
		return Color(0.66, 0.71, 0.80)        # rolled sheet — the press's product
	if item == &"gear":
		return Color(0.82, 0.68, 0.34)        # bronze-toothed cog — the mill's product
	# THE CARRIED GROUND. Terraria-style dig-and-carry means the pack routinely fills with the plain
	# terrain you cut — and those had no entry here, so every one of them fell through to WHITE and
	# drew as a blank square. Three identical white blanks in the hotbar is the single most illegible
	# thing on the screen; it looks like missing art, which is exactly what it was.
	if item == &"earth":
		return Color(0.46, 0.33, 0.21)
	if item == &"stone":
		return Color(0.48, 0.49, 0.53)
	if item == &"shale":
		return Color(0.34, 0.36, 0.42)
	if item == &"deepslate":
		return Color(0.28, 0.31, 0.40)
	if item == &"sealrock":
		return Color(0.30, 0.26, 0.34)
	if item == &"gravel":
		return Color(0.40, 0.42, 0.45)       # crushed rock — cooler and flatter than the stone it came from
	return Color.WHITE


## Draw an item icon centred at `center`, `size` px square. Sprite-ready: an item_<id>.png
## replaces the procedural glyph the moment it exists; absent → a drawn glyph that
## actually READS as the thing (a pickaxe looks like a pickaxe, an ingot like a bar). One helper so ground
## piles, the hotbar, the craft screen, and anything else share the same look + the same sprite swap.
static func draw_item(canvas: CanvasItem, center: Vector2, size: float, item: StringName) -> void:
	var tex: Texture2D = Art.tex("item_" + String(item))
	if tex != null:
		canvas.draw_texture_rect(tex, Rect2(center - Vector2(size, size) * 0.5, Vector2(size, size)), false)
		return
	match item:
		&"ore":
			_item_ore(canvas, center, size)
		&"rich_ore":
			_item_rich_ore(canvas, center, size)
		&"iron":
			_item_iron(canvas, center, size)
		&"ingot":
			_item_ingot(canvas, center, size)
		&"iron_ingot":
			_item_iron_ingot(canvas, center, size)
		&"plate":
			_item_plate(canvas, center, size)
		&"gear":
			_item_gear(canvas, center, size)
		&"coal":
			_item_coal(canvas, center, size)
		&"wood":
			_item_wood(canvas, center, size)
		&"scanner":
			_item_scanner(canvas, center, size)
		&"sapling":
			_item_sapling(canvas, center, size)
		&"wood_pickaxe":
			_item_pickaxe(canvas, center, size, Color(0.55, 0.40, 0.24), Color(0.74, 0.63, 0.47), 0)
		&"stone_pickaxe":
			_item_pickaxe(canvas, center, size, Color(0.50, 0.37, 0.23), Color(0.60, 0.64, 0.71), 1)
		&"iron_pickaxe":
			_item_pickaxe(canvas, center, size, Color(0.42, 0.32, 0.22), Color(0.80, 0.84, 0.94), 2)
		&"wood_axe":
			_item_axe(canvas, center, size, Color(0.55, 0.40, 0.24), Color(0.64, 0.67, 0.73))
		&"broad_bit", &"sinker_bit", &"lance_bit", &"wedge_bit":
			_item_bit(canvas, center, size, item)
		&"stone":
			_item_block(canvas, center, size, item_color(item))
		&"earth":
			_item_clod(canvas, center, size)
		&"gravel":
			_item_gravel(canvas, center, size)
		&"shale":
			_item_shale(canvas, center, size)
		&"deepslate":
			_item_deepslate(canvas, center, size)
		&"sealrock":
			_item_sealrock(canvas, center, size)
		_:
			canvas.draw_rect(Rect2(center - Vector2(size, size) * 0.5, Vector2(size, size)), item_color(item))


## A CUTTING BIT — and its SILHOUETTE IS ITS CUT, which is the entire design of `BitRules` made visible.
## The bits differ in shape rather than in speed, so four identical steel lumps with four different names
## would throw away the one thing the icons could have said. A Broad is a wide blunt head, a Sinker is a
## downward spike, a Lance is a long horizontal point, a Wedge is a splitting triangle: you can tell what a
## bit does to rock by looking at what it is, before you have read a single price.
##
## All four share the same brass socket so they read as a SET of interchangeable heads for one drive, rather
## than as four unrelated tools — which is also the progression thesis (chassis plus modules) drawn.
static func _item_bit(canvas: CanvasItem, c: Vector2, size: float, kind: StringName) -> void:
	var u: float = size * 0.5
	var steel := Color(0.72, 0.76, 0.84)
	var edge := Color(0.90, 0.94, 1.0)
	var brass := Color(0.72, 0.56, 0.28)
	# the socket every bit fits: a short collar at the bottom, the drive's end of the joint
	canvas.draw_rect(Rect2(c + Vector2(-u * 0.34, u * 0.42), Vector2(u * 0.68, u * 0.52)), brass)
	match kind:
		&"broad_bit":
			canvas.draw_rect(Rect2(c + Vector2(-u * 0.92, -u * 0.70), Vector2(u * 1.84, u * 1.04)), steel)
			canvas.draw_rect(Rect2(c + Vector2(-u * 0.92, -u * 0.70), Vector2(u * 1.84, u * 0.22)), edge)
		&"sinker_bit":
			canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-u * 0.40, -u * 0.86), c + Vector2(u * 0.40, -u * 0.86),
				c + Vector2(u * 0.14, u * 0.42), c + Vector2(-u * 0.14, u * 0.42)]), steel)
			canvas.draw_rect(Rect2(c + Vector2(-u * 0.40, -u * 0.86), Vector2(u * 0.80, u * 0.20)), edge)
		&"lance_bit":
			canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-u * 0.86, -u * 0.30), c + Vector2(u * 0.50, -u * 0.30),
				c + Vector2(u * 0.94, 0.0), c + Vector2(u * 0.50, u * 0.30),
				c + Vector2(-u * 0.86, u * 0.30)]), steel)
			canvas.draw_line(c + Vector2(-u * 0.86, -u * 0.18), c + Vector2(u * 0.62, -u * 0.18), edge, 1.5)
		_:
			canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(0.0, -u * 0.88), c + Vector2(u * 0.86, u * 0.44),
				c + Vector2(-u * 0.86, u * 0.44)]), steel)
			canvas.draw_line(c + Vector2(0.0, -u * 0.88), c + Vector2(-u * 0.50, u * 0.10), edge, 1.5)


## THE CARRIED GROUND, and each one's SILHOUETTE IS WHAT IT DOES — the same argument _item_bit makes for
## cutting heads, applied to the stock you dig, carry and backfill with.
##
## All six of these used to share this one cube and differ only by tint, and four of those tints sit within
## dE 8 of a neighbour in CIELab, which at hotbar size is a coin-flip. Gravel was worse than that: it had no
## entry at all and fell through to a flat coloured square. That is the material the whole Drift Rig
## contract turns on — a gallery backfilled with the stone you dug out of it is a SIEVE, and the same
## gallery packed with crushed gravel is a BULKHEAD (FactorySim, `## gravel packs`). Deciding whether your
## gallery floods was a matter of telling two grey squares apart.
##
## So stone keeps the cube and is the reference every other one reads against; the rest are shaped.
static func _item_block(canvas: CanvasItem, c: Vector2, size: float, col: Color) -> void:
	var h: float = size * 0.40
	canvas.draw_rect(Rect2(c - Vector2(h, h), Vector2(h, h) * 2.0), col)
	canvas.draw_rect(Rect2(c - Vector2(h, h), Vector2(h * 2.0, h * 0.34)), col.lightened(0.24))
	canvas.draw_rect(Rect2(c + Vector2(-h, h * 0.62), Vector2(h * 2.0, h * 0.38)), col.darkened(0.34))
	for g: Vector2 in [Vector2(-0.42, 0.10), Vector2(0.22, -0.14), Vector2(0.06, 0.34)]:
		canvas.draw_rect(Rect2(c + g * size, Vector2(size * 0.10, size * 0.10)), col.darkened(0.22))


## GRAVEL — a heap of loose pebbles, and pointedly NOT a block. It is aggregate: the one material that
## PACKS, and the one you reach for when a gallery has to hold water back. Its outline is lumpy where every
## other carried material's is straight, so it separates from stone by shape at any size, which is the only
## thing that survives being 40px wide in a hotbar.
static func _item_gravel(canvas: CanvasItem, c: Vector2, size: float) -> void:
	var col: Color = item_color(&"gravel")
	for s: Array in [[-0.30, 0.16, 0.115], [0.02, 0.06, 0.145], [0.29, 0.17, 0.105],
			[-0.14, -0.15, 0.100], [0.16, -0.14, 0.090]]:
		var pc: Vector2 = c + Vector2(float(s[0]), float(s[1])) * size
		var r: float = size * float(s[2])
		canvas.draw_circle(pc, r, col)
		canvas.draw_circle(pc - Vector2(size * 0.028, size * 0.034), r * 0.46, col.lightened(0.26))


## SHALE — fissile rock, so it reads as a STACK OF THIN PLATES. That is also exactly what it does when you
## hit it in the world: it splits along its partings rather than crumbling.
static func _item_shale(canvas: CanvasItem, c: Vector2, size: float) -> void:
	var col: Color = item_color(&"shale")
	var w: float = size * 0.42
	for i: int in 4:
		var inset: float = absf(float(i) - 1.5) * size * 0.038          # the stack tapers off its middle
		var plate := Rect2(c + Vector2(-w + inset, (float(i) - 2.0) * size * 0.158),
			Vector2((w - inset) * 2.0, size * 0.118))
		canvas.draw_rect(plate, col if i % 2 == 0 else col.darkened(0.13))
		canvas.draw_rect(Rect2(plate.position, Vector2(plate.size.x, size * 0.030)), col.lightened(0.28))


## DEEPSLATE — a tall faceted shard. It is harder than stone and breaks to an edge instead of a rubble, so
## the silhouette says "this came from further down" before the colour has to carry it.
static func _item_deepslate(canvas: CanvasItem, c: Vector2, size: float) -> void:
	var col: Color = item_color(&"deepslate")
	_poly(canvas, c, size, [Vector2(-0.12, -0.46), Vector2(0.20, -0.34), Vector2(0.30, 0.12),
		Vector2(0.10, 0.44), Vector2(-0.22, 0.34), Vector2(-0.30, -0.10)], col)
	canvas.draw_colored_polygon(PackedVector2Array([                     # one lit facet down the shard
		c + Vector2(-0.12, -0.46) * size, c + Vector2(0.20, -0.34) * size,
		c + Vector2(0.04, 0.08) * size, c + Vector2(-0.16, -0.02) * size]), col.lightened(0.30))


## SEALROCK — this one KEEPS the block, because it genuinely is one: it is what the Seal is built of, the
## floor of a layer. It is marked instead, with a bright parting across the face — the line the descent has
## to break. Shape says "block"; the seam says "not ordinary".
static func _item_sealrock(canvas: CanvasItem, c: Vector2, size: float) -> void:
	var col: Color = item_color(&"sealrock")
	_item_block(canvas, c, size, col)
	var h: float = size * 0.40
	var seam := Color(0.87, 0.79, 1.0)
	canvas.draw_line(c + Vector2(-h, h * 0.20), c + Vector2(h, -h * 0.24),
		Color(seam.r, seam.g, seam.b, 0.85), maxf(1.0, size * 0.045))
	canvas.draw_line(c + Vector2(-h * 0.22, h * 0.64), c + Vector2(h * 0.44, h * 0.04),
		Color(seam.r, seam.g, seam.b, 0.48), maxf(1.0, size * 0.030))


## EARTH — a rounded clod with crumbs off it: loose ground, not masonry.
##
## Earth is the one carried material that is already safe on colour (the only warm one in the set, dE 30+
## from every other). It is shaped anyway, because if it kept the cube while the rest were given
## silhouettes, the cube would come to mean "earth" by elimination — and that is a deduction, not a read.
static func _item_clod(canvas: CanvasItem, c: Vector2, size: float) -> void:
	var col: Color = item_color(&"earth")
	_poly(canvas, c, size, [Vector2(-0.36, 0.04), Vector2(-0.24, -0.28), Vector2(0.10, -0.36),
		Vector2(0.34, -0.14), Vector2(0.32, 0.20), Vector2(0.02, 0.36), Vector2(-0.26, 0.28)], col)
	canvas.draw_circle(c + Vector2(-0.10, -0.16) * size, size * 0.070, col.lightened(0.22))
	for crumb: Vector2 in [Vector2(0.40, 0.30), Vector2(-0.42, 0.26)]:
		canvas.draw_circle(c + crumb * size, size * 0.045, col.darkened(0.18))


## RICH ORE (#48) — a nugget the ore has CRYSTALLISED out of, spurs breaking the outline.
##
## This used to be "the same rough nugget, crowded with brighter flecks: quality READS." It did not read.
## check_item_reads measured ore against rich_ore at IoU 1.00 and dE 4.4 — the identical silhouette in an
## indistinguishable colour, because both used this exact polygon and the flecks are interior detail that
## a hotbar cell throws away. Rich ore is the only quality axis in the game (1 rich → 2 ingots against
## ore's 2 → 1, a fourfold difference), so it is worth a shape of its own: the same body, with crystal
## spurs growing off it, which breaks the outline where more flecks could not.
static func _item_rich_ore(canvas: CanvasItem, c: Vector2, size: float) -> void:
	_poly(canvas, c, size, [
		Vector2(-0.34, 0.02), Vector2(-0.22, -0.16), Vector2(-0.30, -0.46),   # spur, up and left
		Vector2(-0.06, -0.22), Vector2(0.10, -0.48),                          # the tall one
		Vector2(0.22, -0.18), Vector2(0.42, -0.04), Vector2(0.30, 0.16),
		Vector2(0.34, 0.36), Vector2(0.08, 0.26), Vector2(-0.18, 0.32)], Color(0.40, 0.40, 0.46))
	for f: Vector2 in [Vector2(-0.14, 0.00), Vector2(0.10, -0.14), Vector2(0.20, 0.10),
			Vector2(-0.02, 0.20), Vector2(-0.04, -0.20)]:
		canvas.draw_circle(c + f * size, size * 0.06, Color(1.0, 0.86, 0.46))
		canvas.draw_circle(c + f * size - Vector2(size * 0.02, size * 0.02), size * 0.025, Color(1.0, 0.97, 0.80))


## SAPLING (#38) — a sprout in a root ball: two young leaves on a stem, the seed of a new tree.
static func _item_sapling(canvas: CanvasItem, c: Vector2, size: float) -> void:
	var stem := Color(0.48, 0.36, 0.22)
	var leaf := Color(0.44, 0.66, 0.30)
	canvas.draw_circle(c + Vector2(0.0, size * 0.24), size * 0.16, stem.darkened(0.25))   # root ball
	canvas.draw_rect(Rect2(c + Vector2(-size * 0.03, -size * 0.10), Vector2(size * 0.06, size * 0.36)), stem)
	_poly(canvas, c, size, [Vector2(0.0, -0.08), Vector2(-0.26, -0.22), Vector2(-0.10, -0.34)], leaf)
	_poly(canvas, c, size, [Vector2(0.0, -0.14), Vector2(0.24, -0.30), Vector2(0.30, -0.12)], leaf.lightened(0.12))


## Polygon helper: points given as size-fractions from the centre (y+ down), filled `fill` with a crisp
## darker outline so a glyph reads at small hotbar scale. Keeps the item drawers terse + consistent.
static func _poly(canvas: CanvasItem, c: Vector2, size: float, frac: Array, fill: Color) -> void:
	var pts := PackedVector2Array()
	for f: Vector2 in frac:
		pts.append(c + f * size)
	canvas.draw_colored_polygon(pts, fill)
	canvas.draw_polyline(pts + PackedVector2Array([pts[0]]), fill.darkened(0.45), maxf(1.0, size * 0.03), true)


## ORE — a rough rock nugget with bright amber ore flecks embedded (reads as "metal IN rock").
static func _item_ore(canvas: CanvasItem, c: Vector2, size: float) -> void:
	_poly(canvas, c, size, [Vector2(-0.34, -0.06), Vector2(-0.10, -0.34), Vector2(0.28, -0.24),
		Vector2(0.36, 0.14), Vector2(0.06, 0.34), Vector2(-0.30, 0.22)], Color(0.44, 0.46, 0.52))
	for f: Vector2 in [Vector2(-0.10, 0.02), Vector2(0.14, -0.10), Vector2(-0.02, 0.18)]:
		canvas.draw_circle(c + f * size, size * 0.06, Color(0.90, 0.56, 0.24))
		canvas.draw_circle(c + f * size - Vector2(size * 0.02, size * 0.02), size * 0.025, Color(1.0, 0.82, 0.5))


## IRON INGOT — the ingot-bar silhouette in cold refined steel (visibly kin to the copper ingot,
## visibly the L2 metal).
static func _item_iron_ingot(canvas: CanvasItem, c: Vector2, size: float) -> void:
	var steel := Color(0.74, 0.79, 0.88)
	_poly(canvas, c, size, [Vector2(-0.26, -0.16), Vector2(0.26, -0.16), Vector2(0.40, 0.18),
		Vector2(-0.40, 0.18)], steel)
	_poly(canvas, c, size, [Vector2(-0.26, -0.16), Vector2(0.26, -0.16), Vector2(0.20, -0.06),
		Vector2(-0.20, -0.06)], steel.lightened(0.25))   # lit top face


## PLATE — a rolled steel sheet lying at a slight skew, a lit edge on top (reads flat + manufactured).
static func _item_plate(canvas: CanvasItem, c: Vector2, size: float) -> void:
	var sheet := Color(0.62, 0.67, 0.77)
	_poly(canvas, c, size, [Vector2(-0.38, -0.10), Vector2(0.30, -0.24), Vector2(0.38, 0.10),
		Vector2(-0.30, 0.24)], sheet)
	canvas.draw_line(c + Vector2(-0.38, -0.10) * size, c + Vector2(0.30, -0.24) * size,
		sheet.lightened(0.30), maxf(1.0, size * 0.05))


## GEAR — a toothed cog with a punched hub (the mill's product; also the generic-machine motif).
## The SCANNER: a dark handheld with a cyan screen, a stub antenna, and sonar arcs —
## reads as "a device that listens" at hotbar size.
static func _item_scanner(canvas: CanvasItem, c: Vector2, size: float) -> void:
	var s: float = size * 0.5
	var body := Color(0.20, 0.24, 0.30)
	var glow := Color(0.45, 0.85, 0.95)
	canvas.draw_rect(Rect2(c + Vector2(-s * 0.42, -s * 0.30), Vector2(s * 0.84, s * 1.05)), body)
	canvas.draw_rect(Rect2(c + Vector2(-s * 0.42, -s * 0.30), Vector2(s * 0.84, s * 1.05)),
		Color(0.0, 0.0, 0.0, 0.4), false, 1.0)
	canvas.draw_rect(Rect2(c + Vector2(-s * 0.28, -s * 0.14), Vector2(s * 0.56, s * 0.44)),
		Color(glow.r, glow.g, glow.b, 0.85))                                    # the screen
	canvas.draw_circle(c + Vector2(0.0, s * 0.52), s * 0.10, glow)              # the blink lamp
	canvas.draw_line(c + Vector2(s * 0.22, -s * 0.30), c + Vector2(s * 0.38, -s * 0.72), body, 2.0)
	canvas.draw_circle(c + Vector2(s * 0.38, -s * 0.72), s * 0.09, glow)        # antenna tip
	for i: int in 2:                                                            # sonar arcs off the antenna
		canvas.draw_arc(c + Vector2(s * 0.38, -s * 0.72), s * (0.28 + 0.22 * float(i)),
			-PI * 0.55, PI * 0.05, 8, Color(glow.r, glow.g, glow.b, 0.7 - 0.25 * float(i)), 1.2)


static func _item_gear(canvas: CanvasItem, c: Vector2, size: float) -> void:
	var bronze := Color(0.80, 0.64, 0.30)
	canvas.draw_circle(c, size * 0.26, bronze)
	for i: int in 7:
		var a: float = TAU * float(i) / 7.0
		canvas.draw_circle(c + Vector2(cos(a), sin(a)) * size * 0.30, size * 0.08, bronze)
	canvas.draw_circle(c, size * 0.24, bronze.darkened(0.12))
	canvas.draw_circle(c, size * 0.10, Color(0.16, 0.13, 0.08))   # the punched hub


## IRON — the ore nugget silhouette in cold deepslate tones with pale steel flecks (L2's new find —
## visibly kin to ore, visibly NOT copper).
static func _item_iron(canvas: CanvasItem, c: Vector2, size: float) -> void:
	_poly(canvas, c, size, [Vector2(-0.34, -0.06), Vector2(-0.10, -0.34), Vector2(0.28, -0.24),
		Vector2(0.36, 0.14), Vector2(0.06, 0.34), Vector2(-0.30, 0.22)], Color(0.30, 0.33, 0.42))
	for f: Vector2 in [Vector2(-0.10, 0.02), Vector2(0.14, -0.10), Vector2(-0.02, 0.18)]:
		canvas.draw_circle(c + f * size, size * 0.06, Color(0.78, 0.82, 0.92))
		canvas.draw_circle(c + f * size - Vector2(size * 0.02, size * 0.02), size * 0.025, Color(0.95, 0.97, 1.0))


## INGOT — a trapezoidal cast metal bar with a bright top face (the classic ingot silhouette).
static func _item_ingot(canvas: CanvasItem, c: Vector2, size: float) -> void:
	var gold := Color(0.93, 0.78, 0.36)
	_poly(canvas, c, size, [Vector2(-0.26, -0.16), Vector2(0.26, -0.16), Vector2(0.40, 0.18),
		Vector2(-0.40, 0.18)], gold)
	_poly(canvas, c, size, [Vector2(-0.26, -0.16), Vector2(0.26, -0.16), Vector2(0.20, -0.06),
		Vector2(-0.20, -0.06)], gold.lightened(0.28))   # lit top face


## COAL — a dark faceted lump with a cool sheen highlight (distinct from the rounded ore nugget).
static func _item_coal(canvas: CanvasItem, c: Vector2, size: float) -> void:
	_poly(canvas, c, size, [Vector2(-0.30, -0.10), Vector2(-0.06, -0.32), Vector2(0.30, -0.18),
		Vector2(0.34, 0.16), Vector2(0.02, 0.34), Vector2(-0.32, 0.16)], Color(0.20, 0.21, 0.25))
	_poly(canvas, c, size, [Vector2(-0.06, -0.32), Vector2(0.14, -0.06), Vector2(-0.10, 0.00)],
		Color(0.34, 0.36, 0.42))   # a lit facet


## WOOD — a short LOG: a brown bar capped by round ends, with concentric end-grain rings on the left face.
static func _item_wood(canvas: CanvasItem, c: Vector2, size: float) -> void:
	var bark := Color(0.52, 0.36, 0.20)
	canvas.draw_rect(Rect2(c - Vector2(size * 0.30, size * 0.16), Vector2(size * 0.60, size * 0.32)), bark)
	canvas.draw_circle(c + Vector2(size * 0.30, 0.0), size * 0.16, bark)
	canvas.draw_circle(c - Vector2(size * 0.30, 0.0), size * 0.16, bark.lightened(0.10))   # left end face
	canvas.draw_arc(c - Vector2(size * 0.30, 0.0), size * 0.10, 0.0, TAU, 12, bark.darkened(0.25), maxf(1.0, size * 0.03))
	canvas.draw_circle(c - Vector2(size * 0.30, 0.0), size * 0.035, bark.darkened(0.30))


## PICKAXE — a wood handle with a curved double-pointed head at the top (points sweeping down-and-out).
## `handle`/`head` colours let one drawer serve the wood pick and the grey stone pick.
## `tier` shapes the HEAD, and it has to, because the three pickaxes were one silhouette in three tints and
## two of those tints are dE 8.6 apart — check_item_reads found stone/iron at IoU 1.00. A tool tier is not
## decoration: the iron head is what lets you into deepslate, and "which pick am I holding" was being
## answered by a grey that is a coin-flip at hotbar size. So the head grows with the tier — a wooden pick is
## barely more than a wedge lashed on, stone is broad and blunt, iron is long and swept and comes to points
## that rise above the shoulder.
static func _item_pickaxe(canvas: CanvasItem, c: Vector2, size: float, handle: Color, head: Color,
		tier: int = 1) -> void:
	canvas.draw_line(c + Vector2(size * 0.10, size * 0.42), c + Vector2(-0.02 * size, -0.16 * size),
		handle, maxf(1.5, size * 0.12))                              # the shaft
	var pts: Array
	match tier:
		0:                                                           # WOOD — a short blunt head
			pts = [Vector2(-0.30, -0.02), Vector2(-0.12, -0.26), Vector2(0.12, -0.26),
				Vector2(0.30, -0.02), Vector2(0.10, -0.14), Vector2(-0.10, -0.14)]
		2:                                                           # IRON — long, swept, pointed
			pts = [Vector2(-0.52, -0.20), Vector2(-0.22, -0.36), Vector2(0.22, -0.36),
				Vector2(0.52, -0.20), Vector2(0.38, -0.04), Vector2(0.12, -0.20),
				Vector2(-0.12, -0.20), Vector2(-0.38, -0.04)]
		_:                                                           # STONE — broad and chunky
			pts = [Vector2(-0.44, -0.04), Vector2(-0.16, -0.30), Vector2(0.16, -0.30),
				Vector2(0.44, -0.04), Vector2(0.12, -0.16), Vector2(-0.12, -0.16)]
	_poly(canvas, c, size, pts, head)


## AXE — a wood handle with a fanned blade on the upper right + a bright cutting edge.
static func _item_axe(canvas: CanvasItem, c: Vector2, size: float, handle: Color, blade: Color) -> void:
	canvas.draw_line(c + Vector2(size * 0.06, size * 0.42), c + Vector2(-0.10 * size, -0.34 * size),
		handle, maxf(1.5, size * 0.12))                              # the shaft
	_poly(canvas, c, size, [Vector2(-0.14, -0.34), Vector2(0.30, -0.36), Vector2(0.40, -0.02),
		Vector2(-0.06, -0.02)], blade)                              # the blade fanning right
	canvas.draw_line(c + Vector2(0.30 * size, -0.36 * size), c + Vector2(0.40 * size, -0.02 * size),
		blade.lightened(0.4), maxf(1.0, size * 0.04))              # honed cutting edge


## Debris/dust colour for a mined terrain material (juice particles) — roughly its rock tone.
static func terrain_dust(material: StringName) -> Color:
	if material == &"stone":
		return Color(0.34, 0.37, 0.44)
	if material == &"iron":
		return Color(0.55, 0.58, 0.68)
	if material == &"deepslate":
		return Color(0.24, 0.27, 0.36)
	if material == &"ore":
		return Color(0.62, 0.45, 0.26)
	if material == &"wood":
		return Color(0.45, 0.30, 0.17)        # woodchips
	if material == &"leaves":
		return Color(0.28, 0.44, 0.22)        # leaf flecks
	return Color(0.40, 0.30, 0.20)            # earth (default)
