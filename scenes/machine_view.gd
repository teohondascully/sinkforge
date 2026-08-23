class_name MachineView
extends RefCounted

## EVERYTHING THE WORLD DRAWS ABOUT A MACHINE: casing, construction animation, status chrome, nameplate,
## input and output marks, and load gauge. Extracted from `world_renderer.gd` along a seam that was
## measured before it was cut.
##
## WHY THIS BLOCK AND NOT THE OBVIOUS ONE. Four candidate boundaries were compared on three axes: what the
## candidate still needs from its parent, how wide an interface the parent needs back, and how much
## MUTABLE STATE crosses the line.
##
##     candidate        lines   outbound   inbound   vars read   consts   written BOTH sides
##     lighting/veil      639          8         5          23       35                    2
##     machines           460          1         4          11       17                    0
##     water              214          1         3           3       19                    0
##     terrain bake       223          1         9          12       12                    1
##
## THOSE NUMBERS ARE THE SECOND SET, and the first set is why this comment says so. The original table
## was produced by the same span rule that nearly broke this extraction: a function ended at the next
## `func`, so every measurement absorbed the declarations sitting between functions. It reported 955
## lines and 68 variables for lighting/veil against a true 639 and 23, and inflated every row. The
## ranking and the decision are unchanged, because lighting/veil is still worst on all four axes, but a
## measurement that is wrong by three times is worth correcting even when the conclusion survives it.
##
## The largest and most contiguous candidate is the worst one. Lighting and veil run nearly a thousand
## almost unbroken lines, which is exactly what makes them look extractable; they read 68 of the file's
## mutable variables and write two dirty-flags the parent also writes. Moving them relocates 955 lines and
## leaves the coupling where it was. Counting CALLS alone would have ranked them second best. Only the
## shared-state axis exposed them, and that is the transferable part: a seam analysis that counts calls
## and not state measures the shape of the code rather than the cost of moving it.
##
## WHAT CROSSES THE LINE, enumerated rather than estimated:
##
##   * one function, `r._cell_center`, and it is pure geometry
##   * nine renderer fields, every one read here and written only there
##   * six renderer constants, reached as `WorldRenderer.X` so each still has one definition
##
## Eleven further constants came WITH the block, because they are used by nothing else: the label
## geometry, the wedge geometry, the well inset and alpha, the work-animation rate. `WEDGE_JUT` is
## derived from `WEDGE_HALF`, so splitting the pair would have left a constant in one class computed
## from a constant in another; both moved, and `world_renderer` reaches back for `MachineView.WEDGE_JUT`
## at the two sites that draw an out-arrow.
##
## TWO MEASUREMENT ERRORS ARE RECORDED HERE because both would have shipped silently.
##
## A first pass reported three outbound functions. Two of them appear only inside COMMENTS in this block:
## a token scan finds names in prose, a call scan finds calls. The call scan was right about functions and
## blind to all seventeen constants, so neither instrument alone described the boundary.
##
## The first extraction ended each function at the next `func`, which quietly swallowed the twelve
## declarations sitting BETWEEN these functions, deleted them from the parent, and rewrote
## `const WEDGE_HALF` into `const WorldRenderer.WEDGE_HALF`. The equivalence check missed it because it
## used the same span rule on both sides, so both carried the same stolen lines and compared equal. A
## body now ends at the first non-indented line, doc comments included, and the ranges are asserted
## non-overlapping before anything is written.
##
## TWO CHECK LAYERS REACH THROUGH THIS SEAM, deliberately. `check_machine_state` asks `_machine_active`
## whether a machine reads as working; `check_nameplate_truth` drives `_plan_machine_labels` and reads
## `_label_plan` back. Both go through `renderer._machines`. Forwarding methods on `WorldRenderer` would
## have left those layers untouched and would also have meant this moved lines without moving a boundary.

var _wr: WorldRenderer


func _init(renderer: WorldRenderer) -> void:
	_wr = renderer


## Is a machine visibly working this tick? Behavior-aware, so the glyph animates truthfully: a generator
## burns only while fueled, a lift stirs while powered or holding goods, and others while a cycle runs or
## they hold product. Shared by the glyph draw and the light pool so the two never disagree.
func _machine_active(machine: MachineState) -> bool:
	match machine.def.behavior:
		&"generator":
			return machine.fuel > 0
		&"lift":
			return machine.power_factor > 0.05 or not machine.input_buffer.is_empty()
		_:
			return _held(machine) > 0 or machine.progress > 0.0


## How fast the 2-frame working cycle chugs. One shared cadence, so a bank of machines reads as one factory
## rather than as a zoo of tempos; the lift's frames ride its surged clock, so power still visibly speeds it
## up.
const WORK_ANIM_FPS: float = 4.0


## The sprite for a machine's current state, or null for the code-drawn casing and glyph. Fallback chain per
## frame: working with work_0 and work_1 present cycles them; working with only work_0 alternates it with
## idle, giving a 2-frame chug from one extra PNG; idle, or no work frames, gives the static machine_<id>.
## Partial sets degrade gracefully, so frames can land one at a time.
func _machine_sprite(machine: MachineState, active: bool, clock: float) -> Texture2D:
	var base: String = "machine_" + String(machine.def.id)
	var idle: Texture2D = Art.tex(base)
	if idle == null:
		return null
	if active:
		var work_0: Texture2D = Art.tex(base + "_work_0")
		if work_0 != null:
			if int(clock * WORK_ANIM_FPS) % 2 == 1:
				var work_1: Texture2D = Art.tex(base + "_work_1")
				return work_1 if work_1 != null else idle
			return work_0
	return idle


## Should this machine's text decorations draw? Yes when zoomed in enough to read them, or when it is the
## machine the player is aiming at, so pointing at any box reads its label and status even zoomed out.
##
## This is a legibility test and only that: it answers "would 8px type survive at this scale", which is a
## necessary condition for drawing a plate and not a sufficient one. It still gates the held-count badge and
## the stalled need bubble, both of which are per-machine state that the player wants wherever the machine
## is. The nameplate wants something stricter and asks `_label_visible` instead.
func _text_visible(cell: Vector2i) -> bool:
	if cell == _wr._aim:
		return true
	return _wr._zoom >= WorldRenderer.TEXT_ZOOM


## How near the body has to be, in cells, before a machine says its own name unasked.
##
## Derived rather than picked. `MainView.REACH_CELLS` (scenes/main.gd:20) is 3.2, the distance at which the
## body can act on a cell at all, so twice it is the ring you are about to be able to touch: near enough
## that which box is which is a live question, far enough that walking toward a machine names it before you
## arrive. At the default 1.00x zoom the view is 40x22 cells (scenes/main.gd:41), so this labels a
## neighbourhood rather than a screen.
const LABEL_NEAR_CELLS: float = MainView.REACH_CELLS * 2.0


## Should this machine draw its nameplate? Aimed at, or standing near it.
##
## The plate used to ride `_text_visible` alone, which made it a pure zoom gate, and the zoom that gate
## permitted was every zoom the game ships at except the two most distant: `TEXT_ZOOM` is 0.65 and
## `MainView.ZOOM_LEVELS[0]`, the default the game boots at, is 1.00 (scenes/main.gd:49-50). So the
## condition was true for every machine on screen from the first frame and stayed true, and a base of any
## size wore a permanent band of text across it. A legibility threshold had been asked to answer a relevance
## question, which it cannot: whether 8px type resolves says nothing about whether this box's name is worth
## the player's attention right now.
##
## Relevance is proximity or intent. The zoom term is kept, as an `and` rather than an `or`, because it is still
## true and still necessary: at 0.33x the plate is a few pixels tall and unreadable however close you stand.
## The aim exemption stays an `or` and stays first, because pointing at a thing is the question being asked,
## and it is the one case where a plate too small to read is still better than no answer.
func _label_visible(cell: Vector2i) -> bool:
	if cell == _wr._aim:
		return true
	if _wr._zoom < WorldRenderer.TEXT_ZOOM or _wr.player == null:
		return false
	return _wr._cell_center(cell).distance_to(_wr.player.position) <= LABEL_NEAR_CELLS * float(WorldRenderer.CELL)


## Is this machine bolted to the wall rather than standing in the cell? True for a Head, meaning a drill
## standing on a lode and boring into the back wall rather than down through rock, and for every Spur. Both
## are frames hung on a face, neither may hide the vein it is eating, and both therefore skip the opaque
## casing and the contact shadow every other machine gets. One machine has two mounts while the bridge
## lasts (`docs/LODE_PLAN.md` §3); once that bridge is retired there is only the Head.
func _is_head(machine: MachineState) -> bool:
	return machine.def.behavior == &"spur" \
		or (machine.def.behavior == &"drill" and _wr.sim.lode.has(machine.cell))


## Height of the craft-progress bar along the foot of a machine's face. Named because the belly gauge's
## floor is derived from it: two cues sharing a body have to be related by something in the code, not by
## two numbers that happen to miss each other. No machine wears both today, because none of the three the
## sim caps a belly on carries a timed recipe, and that is a fact about the current registry rather than a
## property of anything here.
const PROGRESS_BAR_H: float = 3.0


func _draw_machine(machine: MachineState) -> void:
	var pos: Vector2 = Vector2(machine.cell) * float(WorldRenderer.CELL)
	var recipe: RecipeDef = machine.def.recipe
	var center: Vector2 = pos + Vector2(WorldRenderer.CELL, WorldRenderer.CELL) * 0.5
	# Everything drawn on a machine (glyph, badge, progress bar, ports, status lamp) is positioned against
	# the face, not the cell. Against the cell is correct only while every machine fills its cell; with
	# per-machine profiles the Forge's input port hung in the air above its chimney and the Ore Vent's
	# progress bar ran across the rock beside its foot. `machine_face` is where the body actually is, and
	# `check_casing_light` asserts the decoration stays on one of the body's own parts.
	var face_u: Rect2 = Visuals.machine_face(Visuals.machine_kind(machine.def))
	var face := Rect2(pos + face_u.position * float(WorldRenderer.CELL), face_u.size * float(WorldRenderer.CELL))
	if _is_head(machine):
		# A Head is bolted to the wall, so it gets no contact shadow at its feet: it is not standing on
		# anything. Instead it casts a shadow onto the plane behind it, offset down-right, which is the
		# cheapest way to say that this object is in front of that surface.
		_wr.draw_rect(Rect2(pos + Vector2(3.0, 3.0), Vector2(WorldRenderer.CELL - 4.0, WorldRenderer.CELL - 4.0)),
			Color(0.0, 0.0, 0.0, 0.34))
	else:
		# Contact shadow: grounds the machine on the floor it sits on.
		_wr.draw_set_transform(pos + Vector2(float(WorldRenderer.CELL) * 0.5, float(WorldRenderer.CELL) - 1.0), 0.0, Vector2(1.0, 0.26))
		_wr.draw_circle(Vector2.ZERO, float(WorldRenderer.CELL) * 0.46, Color(0.0, 0.0, 0.0, 0.30))
		_wr.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# A machine reads as alive while it is working, and a powered lift marches faster.
	var active: bool = _machine_active(machine)
	var clock: float = _wr._anim_time
	if machine.def.behavior == &"lift":
		clock = _wr._anim_time * (1.0 + machine.power_factor)   # the chevrons surge when powered
	# Sprite-ready: a machine_<id>.png replaces the code-drawn casing and glyph, and while working the
	# 2-frame machine_<id>_work_0/1 cycle plays. The badge, progress bar and I/O ports below still overlay
	# it. With no sprite present, the code-drawn look is used.
	var spr: Texture2D = _machine_sprite(machine, active, clock)
	if spr != null:
		if machine.facing < 0:   # directional machines (the Borer) mirror when facing left, like glyphs
			_wr.draw_set_transform(center, 0.0, Vector2(-1.0, 1.0))
			_wr.draw_texture_rect(spr, Rect2(Vector2(WorldRenderer.CELL, WorldRenderer.CELL) * -0.5, Vector2(WorldRenderer.CELL, WorldRenderer.CELL)), false)
			_wr.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			_wr.draw_texture_rect(spr, Rect2(pos, Vector2(WorldRenderer.CELL, WorldRenderer.CELL)), false)
	elif _is_head(machine):
		# A Head is a frame, not a fill (`docs/LODE.md` §5). Every other machine gets an opaque casing filling
		# its cell, which is right for a box that processes things and wrong for one bolted onto the thing it
		# is eating: it would hide the vein completely, and the vein is the only reason the machine is there.
		# So the casing is dropped and the glyph's own rails carry the body, and the flecks thin through the
		# machine, which makes the Head a gauge without adding a gauge.
		Visuals.draw_machine_glyph(_wr, center,
			"spur" if machine.def.behavior == &"spur" else "collar", 1.0, active, clock, false,
			_wr.sim.lode_fraction(machine.cell))
	else:
		Visuals.draw_machine_casing(_wr, pos, float(WorldRenderer.CELL),
			WorldRenderer.SILHOUETTE_GREY if WorldRenderer.SILHOUETTE_ONLY else Visuals.machine_color(machine.def),
			active, _wr._zoom >= WorldRenderer.DETAIL_ZOOM, Visuals.machine_kind(machine.def))
		if not WorldRenderer.SILHOUETTE_ONLY:
			# Scaled to the face it is stamped on, never larger than 1.0, because a glyph that overhangs its
			# own casing reads as a sticker, which is what the recessed faceplate exists to defeat. The
			# scaling only bites where a face is genuinely small; every shipped profile's face is the
			# full-width body, and a 0.8x gear at 16 screen pixels is not a smaller gear, it is a smudge.
			Visuals.draw_machine_glyph(_wr, face.get_center(), Visuals.machine_kind(machine.def),
				clampf(minf(face.size.x, face.size.y) / float(WorldRenderer.CELL) + 0.24, 0.6, 1.0), active, clock,
				machine.facing < 0)   # directional machines (the Borer) draw mirrored when facing left

	# What the machine is carrying, carried by the machine. Drawn over the casing and under everything that
	# is stamped on it, because contents sit inside a body and the lamp, the ports and the plate are bolted
	# to the outside of one.
	if not WorldRenderer.BARE_MACHINES:
		_draw_load_gauge(machine, face)

	# Text decorations are gated, for both cost and clutter: the held-count badge and the stalled need bubble
	# are drawn only when the text is readable, meaning zoomed in past TEXT_ZOOM, or when this is the hovered
	# or aimed machine. At 0.50x and below those labels are a few px tall, and draw_string is the priciest
	# per-call here, so on a mature base the non-hovered machines drop their text. The information is not
	# lost: the HUD hover inspector shows a machine's full details regardless.
	#
	# The nameplate is gated harder, on `_label_visible`: a name is worth reading once and then never again,
	# so it is spent on the machine you are pointing at or walking up to rather than on all of them forever.
	var show_text: bool = _text_visible(machine.cell) and not WorldRenderer.BARE_MACHINES
	if _label_visible(machine.cell) and not WorldRenderer.BARE_MACHINES:
		_draw_machine_label(machine, pos)

	var held: int = _held(machine)
	if show_text and held > 0:
		# The badge is sized to its number. A fixed 10px box is exactly one digit wide, and a Head sitting on
		# a fat vein counts into the hundreds, so `889` painted across the machine and was clipped by its
		# neighbour's plate. A count that outgrows its box is a count you cannot trust.
		var tag: String = str(held)
		var tw: float = _wr._font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 3.0
		var badge := Vector2(face.end.x - 2.0 - tw, face.position.y + 2.0)
		_wr.draw_rect(Rect2(badge, Vector2(tw, 11.0)), Color(0.04, 0.04, 0.06, 0.85))
		# CHROME, not white: a count is a standing quantity rather than something that just happened, and it
		# sits on its own near-black plate, so it keeps every bit of its contrast at the lower value.
		_wr.draw_string(_wr._font, badge + Vector2(1.5, 9.0), tag,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, WorldRenderer.CHROME)

	if recipe != null and recipe.time > 0.0:
		var bar_y: float = face.end.y - PROGRESS_BAR_H
		_wr.draw_rect(Rect2(face.position.x, bar_y, face.size.x, PROGRESS_BAR_H), Color(0.0, 0.0, 0.0, 0.35))
		var frac: float = clampf(machine.progress / recipe.time, 0.0, 1.0)
		_wr.draw_rect(Rect2(face.position.x, bar_y, face.size.x * frac, PROGRESS_BAR_H),
			Color(0.40, 0.90, 0.45))

	# A PORT IS NOT A BODY. The wedges are item-tinted cosmetics bolted onto the casing, and they sat
	# inside the silhouette capture for as long as it existed: check_machine_identity announces "with
	# the icons off" and was reading the Lift's teal up-spout as part of the Lift's shape. A machine
	# whose outline is told apart by its output arrow has not got a distinct outline.
	if not WorldRenderer.SILHOUETTE_ONLY:
		_draw_machine_io(machine, pos, face)
	if not WorldRenderer.BARE_MACHINES:
		_draw_machine_status(machine, face, show_text)
	if _wr._construct.has(machine.cell):     # the one-shot assemble overlay, on top of the finished draw
		_draw_construct(pos, clampf(float(_wr._construct[machine.cell]) / WorldRenderer.CONSTRUCT_DUR, 0.0, 1.0))


## The one-shot assemble overlay for a just-placed machine: a settling flash that fades, a bright scan line
## running up the casing so the frame prints upward, and corner brackets snapping inward to lock the frame.
## All overlay, so it never hides the terrain. `t` runs 0 to 1.
func _draw_construct(pos: Vector2, t: float) -> void:
	var c: float = float(WorldRenderer.CELL)
	var e: float = 1.0 - t
	_wr.draw_rect(Rect2(pos, Vector2(c, c)), Color(1.0, 0.94, 0.78, 0.45 * e * e))       # settling bloom
	var ly: float = pos.y + c * (1.0 - t)                                            # scan line, bottom to top
	_wr.draw_rect(Rect2(pos.x, ly - 1.0, c, 2.0), Color(0.82, 0.95, 1.0, 0.85 * sin(t * PI)))
	var off: float = e * 5.0                                                         # brackets snap inward
	var bl: float = 5.0
	var bc := Color(0.96, 0.86, 0.52, 0.35 + 0.55 * e)
	for cn: Array in [
			[Vector2(-off, -off), Vector2(1.0, 0.0), Vector2(0.0, 1.0)],
			[Vector2(c + off, -off), Vector2(-1.0, 0.0), Vector2(0.0, 1.0)],
			[Vector2(-off, c + off), Vector2(1.0, 0.0), Vector2(0.0, -1.0)],
			[Vector2(c + off, c + off), Vector2(-1.0, 0.0), Vector2(0.0, -1.0)]]:
		var p: Vector2 = pos + (cn[0] as Vector2)
		_wr.draw_line(p, p + (cn[1] as Vector2) * bl, bc, 1.5)
		_wr.draw_line(p, p + (cn[2] as Vector2) * bl, bc, 1.5)


## Is the current objective already pointing at this cell? Cheap to ask: `MainView._guide_targets` returns
## at most one target per step (scenes/main.gd:2648-2673, one `out.append` per branch), so this is a scan of
## a list of one, and the loop is written for the list rather than for today's length.
func _guided(cell: Vector2i) -> bool:
	for t: Dictionary in _wr._guide_targets:
		if Vector2i(t["cell"]) == cell:
			return true
	return false


## A small status lamp on every machine, plus a blinking floating need bubble carrying the missing item's
## glyph when a machine is stalled on one (no fuel means coal, starved means its input). Reads
## FactorySim.machine_status, which is the sim's own run-gates, so it cannot lie. Pure cosmetic, drawn as
## glyphs, so the answer to "why has my drill gone quiet?" is on the machine.
##
## The look of each status lives in `Visuals.STATUS_LOOK` rather than in a match here, and that is a fix
## rather than a tidy-up: a match knew five of the sim's ten statuses and swept the other five into the grey
## that means nothing is wrong. See the table for the full set.
func _draw_machine_status(machine: MachineState, face: Rect2, show_bubble: bool = true) -> void:
	var pos: Vector2 = face.position   # the lamp rides the machine's own corner, not the cell's
	var status: StringName = _wr.sim.machine_status(machine)
	var look: Dictionary = Visuals.status_look(status)
	var lamp: Color = look["color"]
	# Status lamp: a rimmed mark in the machine's top-left corner.
	#
	# It grows as you zoom out. At the 0.70 inspect zoom this is the plain dot; at the 0.33 survey zoom the
	# same world-space dot covers about one screen pixel, so machine states become colour-only out there. A
	# lamp that shrinks with the machine only answers the question at the zoom where you were already close
	# enough to read the machine itself. So the mark holds roughly its screen size instead, capped so it never
	# eats the casing it sits on.
	var k: float = clampf(1.0 / maxf(_wr._zoom, 0.2), 1.0, 1.8)
	var r: float = 3.1 * k
	var lamp_c: Vector2 = pos + Vector2(2.4 + r, 2.4 + r)
	_wr.draw_circle(lamp_c, 4.2 * k, Color(0.03, 0.03, 0.05, 0.9))
	Visuals.draw_status_mark(_wr, lamp_c, r, look["mark"], lamp)
	# Nothing to raise an alarm about: running, resting or finished. `fix` is the sim's word for what the
	# player would have to do, so "none" is exactly the set that needs no floating anything, and a status
	# added later inherits the right behaviour from its table entry rather than from a list of names here.
	if StringName(look["fix"]) == &"none" or status == &"spent":
		return
	if not show_bubble:
		# The bubble is gone at this zoom, and a stall is the one thing that must still reach the player.
		# Zoomed out, the need bubble is dropped as unreadable clutter and the machine falls back on a
		# coloured dot roughly a pixel across. So the alarm moves to the only scale that survives out here,
		# the whole cell, and to the one channel that needs no resolution at all: motion. A stalled machine
		# breathes a ring around itself and a working one does nothing, because "no alarm" has to stay the
		# quiet state or a mature base becomes a light show.
		#
		# This branch is deliberately taken before the guidance check below. It is the only alarm a machine has
		# left out here, and it is not the thing that check exists to stop: it sits on the cell instead of
		# floating in the column above it, so it does not stack under the chevron the way the bubble does.
		#
		# It is also the one other breathing outline in the file, which is a real tension with the cursor
		# owning that shape (`_draw_interact_pulse`). It is left alone because it is not chrome: it is the
		# machine's own state, in the status colour, on its own 2.6 rad/s clock, and it only exists below
		# TEXT_ZOOM. Taking it away to tidy the grammar would take the alarm with it.
		var alarm: float = 0.40 + 0.60 * absf(sin(_wr._anim_time * 2.6))
		_wr.draw_rect(Rect2(face.position - Vector2(1.5, 1.5), face.size + Vector2(3.0, 3.0)),
			Color(lamp.r, lamp.g, lamp.b, 0.80 * alarm), false, 2.0)
		return
	# One floating mark per cell. If guidance is already pointing at this machine there is a chevron bobbing
	# in the air above it on a tether down onto its roof, and the bubble hangs in that same column, bobbing on
	# its own clock, saying a version of the same sentence: this box is the one you have to deal with. Reaching
	# this line at all means the machine is stalled and the step is still open, which is nearly always the same
	# problem told twice.
	#
	# Guidance keeps the airspace because it ends: a step resolves, the chevron leaves, and the bubble comes
	# straight back for whatever is still wrong. Nothing is silently lost meanwhile, either. The status lamp
	# above is drawn before this returns, so the machine still carries its state in its own corner, and the HUD
	# hover inspector still reads the whole thing out.
	if _guided(machine.cell):
		return
	var pulse: float = 0.62 + 0.38 * sin(_wr._anim_time * 6.5)
	var bob: float = sin(_wr._anim_time * 3.0) * 1.5
	var bc: Vector2 = Vector2(face.get_center().x, face.position.y - 24.0 + bob)
	var br: float = 9.0                       # the bubble's radius, named once because the stem hangs off it
	# A stem down onto the roof, because this bubble is the only mark in the file that floated free of the
	# thing it meant, and guidance's chevron is supposed to be the only one that does. In a lit room the
	# machine underneath carried the attachment on its own. In an unlit one it does not: what is left on
	# screen is a thin ring with a bolt struck through it, hanging in rock, and a ring with a diagonal
	# through it is a sign forbidding something in every language there is. Planted on a roof it is a label
	# instead, and a label cannot be misread as a sign.
	#
	# No head at either end. A filled head pointing down into a machine is the drop column's sentence
	# (`_out_arrow`), and this mark is not about anything moving. A foot where the stem lands says which
	# roof, which is all it has to say.
	var foot: Vector2 = Vector2(bc.x, face.position.y)
	var stem := Color(lamp.r, lamp.g, lamp.b, 0.55 * pulse)
	_wr.draw_line(bc + Vector2(0.0, br), foot, stem, 1.5)
	_wr.draw_line(foot - Vector2(br * 0.4, 0.0), foot + Vector2(br * 0.4, 0.0), stem, 1.5)
	_wr.draw_circle(bc, br, Color(0.05, 0.04, 0.06, 0.82 * pulse))
	_wr.draw_arc(bc, br, 0.0, TAU, 20, Color(lamp.r, lamp.g, lamp.b, pulse), 1.6)

	# The bubble holds up what the player would go and do about it, which for two statuses is an item to
	# fetch and for three is a job to perform. Drawing items only meant the jam, dead-power and unwired states
	# floated an ore icon over all three, telling the player to feed a machine that was not hungry. Silencing
	# them was true but quiet: the lamp names the kind of problem and the bubble is where the specific one
	# belongs. Each job now has its own glyph and the bubble speaks for all five, with none of them borrowing
	# another's answer.
	if not bool(look["feeds"]):
		Visuals.draw_fix_glyph(_wr, bc, 11.0, look["fix"], Color(lamp.r, lamp.g, lamp.b, 0.55 + 0.45 * pulse))
		return
	var need: StringName = &"ore"
	if status == &"no_fuel":
		need = &"coal"
	elif machine.def.behavior == &"descent":
		need = FactorySim.DESCENT_EATS              # the gate eats ingots, not ore
	elif machine.def.recipe != null and not machine.def.recipe.inputs.is_empty():
		need = machine.def.recipe.inputs.keys()[0]
	Visuals.draw_item(_wr, bc, 11.0, need)


## A small name plate centred just above the machine (FORGE, DRILL, LIFT, GENERATOR), so a new player can
## read what each box is at a glance. A dark pill backing keeps it legible over any terrain; uppercased and
## tight so it reads as a label rather than as prose. Pure cosmetic.
##
## The plates are laid out for the whole frame rather than one machine at a time, in `_plan_machine_labels`.
## Three plates centred on adjacent 32px cells with ~45px of text each overlap into garbage: a bank of three
## generators rendered as `GENER/ GENER/ GENERATOR`. A machine cannot see its neighbours, so no amount of
## per-machine logic fixes that; something has to look at all of them at once.
const LABEL_FS: int = 8


const LABEL_H: float = 11.0


## How many rows of plates may stack above a machine before the rest are dropped. Two and not more: the third
## row would start colliding with the machine one cell up, which trades a text collision for a worse one.
## Run-collapsing below makes deep stacks rare enough that two is generous.
const LABEL_SHELVES: int = 2


const LABEL_SHELF_H: float = 12.0


## cell -> {text, shelf, cx, w} for every nameplate that will actually be drawn this frame.
var _label_plan: Dictionary = {}


## Lay out this frame's machine nameplates, in two passes.
##
## Runs collapse: a row of contiguous machines with the same name is labelled once, as `SPUR x5`. This
## started as collision avoidance and is the better read anyway. Five identical plates say "five things",
## which is the wrong sentence about a chain that is one Head plus its reach; one plate with a count says
## the truth in less ink.
##
## Contiguous is the whole of it, and that is not an oversight to be fixed here. Two forges at opposite ends
## of a base are two plates because they are two boxes in two places, and a merged plate would have to sit
## on one of them and lie about the other. What stops that pair from being drawn at once is the gate rather
## than the collapse: `_label_visible` wants the body near, and a body cannot be near both.
##
## What is left is then shelf-packed left to right, dropping to a second row when a plate would land on the
## one before it. The aimed machine is packed first, so that pointing at something always names it: that is
## the promise `_label_visible` makes when it exempts the aimed cell from the zoom gate, and a packer that
## silently dropped that plate would break it.
##
## The plan and the draw must ask the same question or the packer reserves shelf space for plates that never
## appear, and a plate that is drawn gets pushed to a second row to clear a gap. So both call
## `_label_visible` and neither has its own copy of the rule.
func _plan_machine_labels(mview: Rect2) -> void:
	_label_plan.clear()
	# How many machines there are is not how many you are standing near. The run used to be counted over a
	# `named` already filtered by `mview` and `_label_visible`, and `_label_visible` is a radius around the
	# player, so the number printed on the plate was a statement about where the body happened to be. Three
	# generators in a row read GENERATOR ×2 from one step too far back, with the third machine drawn, lit
	# and plainly on screen next to the plate undercounting it; walking two cells changed the number while
	# nothing in the world changed. A run straddling that radius came out worse than wrong: the middle
	# machine dropping out of `named` broke the westward test, so one run of three published two separate
	# plates, each reading GENERATOR and neither carrying a count.
	#
	# So the run is measured over every named machine in the factory, which is the thing the count claims to
	# be about, and visibility decides only where a plate is drawn. Those were always two questions and one
	# test was answering both.
	var named: Dictionary = {}
	var shown: Dictionary = {}
	for m: MachineState in _wr.sim.machines:
		if m.def.display_name.is_empty():
			continue
		named[m.cell] = m.def.display_name.to_upper()
		if mview.has_point(Vector2(m.cell) * float(WorldRenderer.CELL)) and _label_visible(m.cell):
			shown[m.cell] = true
	var runs: Array[Dictionary] = []
	for key: Variant in named:
		var c: Vector2i = key
		var west: Vector2i = c - Vector2i(1, 0)
		if named.get(west, "") == named[c]:
			continue                          # mid-run: the westmost machine owns the plate for the run
		var n: int = 1
		while named.get(c + Vector2i(n, 0), "") == named[c]:
			n += 1
		# The plate hangs over the part of the run you can actually see. Centring it over the whole run would
		# push it off the edge for a row that leaves the view, and a run with nothing visible in it wants no
		# plate at all. That is the one thing the earlier visibility filter was getting right.
		var lo: int = -1
		var hi: int = -1
		for k: int in n:
			if shown.has(Vector2i(c.x + k, c.y)):
				if lo < 0:
					lo = c.x + k
				hi = c.x + k
		if lo < 0:
			continue
		var text: String = named[c] if n == 1 else "%s ×%d" % [named[c], n]
		var w: float = _wr._font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FS).x + 6.0
		runs.append({"cell": Vector2i(lo, c.y), "row": c.y, "x0": c.x, "span": n, "text": text, "w": w,
			"lo": lo, "hi": hi,
			"aimed": 0 if (_wr._aim.y == c.y and _wr._aim.x >= c.x and _wr._aim.x < c.x + n) else 1})
	runs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["aimed"]) != int(b["aimed"]):
			return int(a["aimed"]) < int(b["aimed"])
		if int(a["row"]) != int(b["row"]):
			return int(a["row"]) < int(b["row"])
		return int(a["x0"]) < int(b["x0"]))
	var claimed: Dictionary = {}              # "row:shelf" -> the x this shelf is occupied up to
	for r: Dictionary in runs:
		var w2: float = float(r["w"])
		var cx: float = (float(int(r["lo"])) + float(int(r["hi"]) - int(r["lo"]) + 1) * 0.5) * float(WorldRenderer.CELL)
		for shelf: int in LABEL_SHELVES:
			var slot: String = "%d:%d" % [int(r["row"]), shelf]
			if cx - w2 * 0.5 < float(claimed.get(slot, -1.0e9)):
				continue
			claimed[slot] = cx + w2 * 0.5 + 2.0
			_label_plan[r["cell"]] = {"text": r["text"], "shelf": shelf, "cx": cx, "w": w2}
			break


func _draw_machine_label(machine: MachineState, pos: Vector2) -> void:
	if not _label_plan.has(machine.cell):
		return                                # collapsed into a neighbour's plate, or packed out
	var plan: Dictionary = _label_plan[machine.cell]
	var w: float = float(plan["w"])
	var left: float = float(plan["cx"]) - w * 0.5
	var top: float = pos.y - LABEL_H - float(int(plan["shelf"])) * LABEL_SHELF_H
	_wr.draw_rect(Rect2(left, top, w, LABEL_H), Color(0.04, 0.05, 0.08, 0.82))
	_wr.draw_string(_wr._font, Vector2(left + 3.0, top + 8.5), String(plan["text"]),
		HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FS, Color(0.86, 0.90, 0.98))


## Small item-tinted ports on a machine's edges: where it eats (the input mouth, on top, pointing in) and
## where it spits (the output spout, in the flow direction: down for a recipe-runner or source, down and
## right for a splitter, up for a lift). Tinted by the item, so orange goes in here and yellow comes out
## there reads at a glance. Pure cosmetic.
##
## Stemless arrows, in the vocabulary above: the goods are not travelling a distance to get here, they are
## crossing a boundary, so the mark is a bare head sitting on the boundary it names.
func _draw_machine_io(machine: MachineState, pos: Vector2, face: Rect2) -> void:
	var recipe: RecipeDef = machine.def.recipe
	var c: float = float(WorldRenderer.CELL)
	# The mouth sits on the machine; the spout sits on the cell. Goods fall in from above and land on the
	# body, so the input wedge belongs on the face's top edge, over the chimney's shoulder for a Forge rather
	# than floating where the chimney is not. Output makes the opposite claim: it says which neighbouring
	# cell the goods leave into, and every profile in the set keeps a flat foot at the cell line for that
	# reason. Both stay on the face's centre column so they read as one throughput line.
	var mid: float = face.get_center().x
	if recipe != null and not recipe.inputs.is_empty():
		var in_item: StringName = recipe.inputs.keys()[0]
		_matter_wedge(Vector2(mid, face.position.y), Vector2(0, 1), _item_ink(in_item))
	var out_col := Color(0.80, 0.86, 0.94)                                                # neutral "routes"
	if recipe != null and not recipe.outputs.is_empty():
		out_col = _item_ink(recipe.outputs.keys()[0])
	match machine.def.behavior:
		&"lift":
			_matter_wedge(Vector2(mid, face.position.y), Vector2(0, -1), Color(0.5, 1.0, 0.92))   # spouts up
		&"splitter":
			_matter_wedge(Vector2(mid, pos.y + c), Vector2(0, 1), out_col)                        # down
			_matter_wedge(Vector2(pos.x + c, face.get_center().y), Vector2(1, 0), out_col)        # + right
		_:
			# The Borer belongs in this default arm and is not an oversight: it bores sideways, but
			# `_destinations_h_drill` returns the cell below and nothing else, so one downward spout is the
			# whole of its routing. A machine that works sideways does not thereby ship sideways.
			_matter_wedge(Vector2(mid, pos.y + c), Vector2(0, 1), out_col)                        # spouts down


## Half-width of the matter wedge, and how far its apex stands off from its base. Both were literals
## inside the one function that drew the shape, which was fine while there was one caller; `_out_arrow`
## now ends on the same head, so the two callers have to be looking at one number rather than at two that
## happen to agree today.
const WEDGE_HALF: float = 4.5


const WEDGE_JUT: float = WEDGE_HALF + 2.5


## The matter wedge, the one solid head in this file, and the whole of the arrow half of the vocabulary
## above. `_draw_machine_io` sets it on a casing edge to say goods cross here; `_out_arrow` sets it on the
## end of a stem to say goods fall to there. Both are the same sentence about the same kind of thing, so
## they are one call and not two shapes to keep in step.
##
## The base sits on the edge at `base` and the apex juts out along `dir`. The dark line across the base is
## what separates the head from whatever it is standing on, casing or stem.
func _matter_wedge(base: Vector2, dir: Vector2, color: Color) -> void:
	var perp := Vector2(dir.y, -dir.x) * WEDGE_HALF
	var apex := base + dir * WEDGE_JUT
	var p1 := base + perp
	var p2 := base - perp
	_wr.draw_colored_polygon(PackedVector2Array([apex, p1, p2]), Color(color.r, color.g, color.b, 0.95))
	_wr.draw_line(p1, p2, Color(0.04, 0.04, 0.06, 0.55), 1.0)


func _held(machine: MachineState) -> int:
	return _buffer_total(machine.input_buffer) + _buffer_total(machine.output_buffer)


## Everything in one buffer, counted the way the sim counts it when it asks whether that belly is full.
func _buffer_total(buffer: Dictionary) -> int:
	var n: int = 0
	for v: int in buffer.values():
		n += v
	return n


## The ink a mark wears when it speaks for an item, which is the item's own colour unless it has none.
##
## `Visuals.item_color` answers `Color.WHITE` for an item it has no table entry for, and white is the one
## colour a mark drawn into the world may not be: it belongs to things that have just happened (see CHROME
## above). An item added to a recipe and not to that table would take the brightest mark the screen has,
## permanently, by falling off the end of a list. Chrome is the honest answer there anyway, being what a
## mark wears when it has nothing of its own to say.
##
## Nothing shipped reaches the fallback today. This is for the item after the ones that exist.
func _item_ink(item: StringName) -> Color:
	var col: Color = Visuals.item_color(item)
	return WorldRenderer.CHROME if col == Color.WHITE else col


## The item a buffer mostly holds, which is the colour its well is drawn in, or &"" for an empty one.
## Largest stack wins and a tie goes to whichever the dictionary yields first: a belly split evenly between
## two items is a mixed colour whichever of them is chosen, and the well is a level rather than a manifest.
func _bulk_item(buffer: Dictionary) -> StringName:
	var best: StringName = &""
	var most: int = 0
	for item: StringName in buffer:
		var n: int = int(buffer[item])
		if n > most:
			most = n
			best = item
	return best


## How full the belly is, on the machine, so a base says where it is backing up without a number stamped
## on every box.
##
## A held-count badge answers the question the player is actually asking, which is "is this one jamming?",
## only after they have read 9px type and compared it against a capacity nobody ever told them. The casing
## can say it directly: the contents show through the body and rise as the machine fills, and the well
## reaches the top at the same instant `machine_status` turns and the lamp beside it goes red.
##
## Three behaviours and not all of them, and the boundary is the sim's rather than a taste call. These are
## the only machines whose buffer the sim caps, so they are the only ones where a fraction exists to draw
## at all. A Forge holding two ore is not two percent of anything, and a well over it would be an invented
## denominator dressed as a measurement.
##
##   Borer      output_buffer total   vs H_DRILL_BELLY_TOTAL  (src/core/factory_sim.gd:55, 2288-2294)
##   Drift Rig  each stream's total   vs DRIFT_BELLY, twice   (src/core/factory_sim.gd:76, 2408-2412)
##   Crusher    output_buffer gravel  vs CRUSH_BELLY          (src/core/factory_sim.gd:85, 2578-2585)
##
## Each numerator is read off the same buffer the sim's own jam gate reads, which is the part that is easy
## to get wrong. `_held` sums input and output together, and the Borer's cap governs its output alone, so a
## well fed by `_held` would have counted the coal in its fuel bunker toward a limit the coal cannot reach:
## a gauge that overflows before its machine does. The Crusher is the same trap from the other side, its
## cap counting gravel alone while pay passes straight through the same buffer without ever jamming it
## (`_run_crush`). Numerator and denominator have to measure one set or the well is decoration.
##
## The badge is left exactly as it was. This adds a channel rather than moving one: the badge is the exact
## number, it is the only channel the seventeen uncapped kinds have, and nothing here can replace it.
func _draw_load_gauge(machine: MachineState, face: Rect2) -> void:
	match machine.def.behavior:
		&"h_drill":
			_load_well(face, 0.0, 1.0, _buffer_total(machine.output_buffer),
				FactorySim.H_DRILL_BELLY_TOTAL, machine.output_buffer)
		&"drift":
			# Two wells, because the rig jams its two hauls independently and the sim has a separate status
			# for each (`blocked_pay`, `blocked_spoil`). Spoil is the one with a side: it drops down the
			# column behind the rig, so its well takes the half of the body facing that way and pay takes
			# what is left. Pay falls down the rig's own column and has no side of its own, so putting it
			# opposite the spoil is what makes the pair readable rather than a claim about where it goes.
			# `_held` does not count `spoil_buffer` at all, so until now the spoil half of a Drift Rig had
			# no channel anywhere in the world view.
			var back: float = 0.0 if machine.facing > 0 else 0.5
			_load_well(face, back, 0.5, _buffer_total(machine.spoil_buffer),
				FactorySim.DRIFT_BELLY, machine.spoil_buffer)
			_load_well(face, 0.5 - back, 0.5, _buffer_total(machine.output_buffer),
				FactorySim.DRIFT_BELLY, machine.output_buffer)
		&"crush":
			var gravel: int = int(machine.output_buffer.get(&"gravel", 0))
			_load_well(face, 0.0, 1.0, gravel, FactorySim.CRUSH_BELLY, {&"gravel": gravel})


## The well has to clear the casing's own lit edge on both sides, or the level paints over the one trick
## that sells a flat square as hardware. Read off `Visuals.CASING_INSET` rather than eyeballed or copied,
## so a retuned casing cannot quietly leave the glass sitting on top of it; the two move together or
## neither does.
const WELL_INSET: float = Visuals.CASING_INSET * 2.0


## How much of the body the contents tint. Low, because this is a level seen through a casing and not a
## panel painted on one: the glyph, the rivets and the lit edge all have to survive it.
const WELL_ALPHA: float = 0.34


## One well: contents rising inside the casing under a brighter line at their surface. `u0` and `uw` are
## the fraction of the face's width this well takes, so a machine with two independent bellies gets two
## side by side and a machine with one gets the whole body.
##
## The surface line is the contents lightened and never white. A level is a standing quantity rather than
## something that just happened, which is the CHROME rule, and it is also the practical answer: at this
## alpha a dark item against a dark casing is a level you can only find by its edge.
func _load_well(face: Rect2, u0: float, uw: float, held: int, cap: int, contents: Dictionary) -> void:
	if held <= 0 or cap <= 0:
		return
	var item: StringName = _bulk_item(contents)
	if item == &"":
		return
	var x: float = face.position.x + face.size.x * u0 + WELL_INSET
	var w: float = face.size.x * uw - WELL_INSET * 2.0
	var floor_y: float = face.end.y - PROGRESS_BAR_H
	var ceil_y: float = face.position.y + WELL_INSET
	var h: float = (floor_y - ceil_y) * clampf(float(held) / float(cap), 0.0, 1.0)
	if w <= 0.0 or h <= 0.0:
		return
	var col: Color = _item_ink(item)
	_wr.draw_rect(Rect2(x, floor_y - h, w, h), Color(col.r, col.g, col.b, WELL_ALPHA))
	var lit: Color = col.lightened(0.35)
	_wr.draw_rect(Rect2(x, floor_y - h, w, minf(1.5, h)), Color(lit.r, lit.g, lit.b, 0.90))
