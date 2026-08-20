extends "res://tools/check_base.gd"

## A FIXTURE MUST NOT POSE A FIELD THE GAME RECOMPUTES EVERY FRAME.
##
## `capture_moments` set `main._hud.can_craft = true` and shuttered sixty settle frames later.
## `main.gd:793` re-derives that field from `_near_bazaar()` on every `_process`. The write was gone long
## before the picture, and ten menu captures — the whole baseline a redesign was to be judged against —
## photographed the counter as seen by somebody standing nowhere near it. The Bazaar's gold verb button was
## not in the archive at all, so the first frame ever taken of it live turned out to read `BUILDENTER`.
##
## **A fixture that writes a field the game recomputes has posed nothing. It has left a note for a frame
## that was never read.** And it fails in the worst possible direction: the picture comes out, it looks
## plausible, and a written analysis gets built on top of it.
##
## The moment-level guard for that specific field lives in `capture_moments._contamination`, where it
## belongs — it reads `can_craft` at the shutter and refuses the write. This layer is the OTHER half: it
## asks whether the class is anywhere else, and it asks statically so that a fixture nobody is running
## tonight is still covered.
##
## HOW THE POPULATION IS DERIVED, which is the only interesting decision here. Not from a list of fields
## somebody thought of — that is the failure mode `_contamination` had, whose `EXPECT` table could not even
## SPELL `can_craft` because its vocabulary was properties on `main`. It is read out of the game: every
## `<receiver>.<field> = ...` and every bare `<field> = ...` statement lexically inside a `_process` or
## `_physics_process` body under `scenes/` and `src/`. Add a new per-frame push and this layer's population
## grows by itself.
##
## THE BARE FORM WAS MISSING FOR AS LONG AS THIS FILE EXISTED, and it is the commoner of the two: a
## `_process` writing its own state needs no receiver, so `_assigned_pair` — which requires one — could not
## see it. `main.gd:737` recomputes `_cam_pos` and was invisible; `_camera.global_position`, derived from it
## on the NEXT line, was caught and then exempted on a reason that only holds at 60 fps. The layer was
## looking straight at the defect and keying on the line beneath it, which is this layer's own subject
## arriving as this layer. Turning the rule on took the population from 20 fields to 50.
##
## WHAT IT CANNOT SEE, stated because a static scan invites being trusted past its reach:
##   - mutation through a method (`hud.set_thing(x)`), or through a shared Array/Dictionary reference
##   - a field on a local declared inside the body, or a bare write to the function's own parameter — both
##     excluded on purpose, see `locals` below
##   - a field pushed from a timer, a signal handler, or `_ready` (`hud.objectives` is one — assigned once,
##     by reference, so a fixture that reassigns it decouples rather than loses)
##   - a receiver named differently in the two files. The match is on the PAIR — the identifier immediately
##     left of the field, with a leading underscore stripped — so `main._hud.can_craft` in a fixture meets
##     `_hud.can_craft` in the game, and `check_pack_layout`'s bare `hud` meets it too, while
##     `_player.position` never collides with `_motes.position`. A fixture that reaches the same object
##     through a differently-NAMED handle is outside this layer's reach. The bare form keys on the FILE's
##     name for the same reason and inherits the same hole: `main.gd`'s own `_cam_pos` is `main._cam_pos`,
##     which a fixture holding the scene as `main` or `_main` meets, and one holding it as `view` does not.
##   - whether the recompute actually RUNS. It is a lexical scan of a body, not of a control flow, so a
##     statement behind an `if` the fixture itself opened reads as an unconditional push. `GUARDED` is
##     where those are written down, one switch each, and it is verified rather than believed.
##
## THE FIRST VERSION OF THIS FILE MATCHED ON THE FIELD NAME ALONE and reported fifty-eight offences, of
## which fifty-seven were `_player.position` colliding with `_motes.position`, and two were a local called
## `rmin` inside `world_renderer._process` colliding with any `.x` anywhere. A layer written to catch
## "the population is not the claim" whose own population was every field with a common name. Kept in the
## comment rather than the history because the shape is the lesson.
## It sees exactly two shapes, and the one it could not see is the one that bit us twice.
##
## AND THE SIM HALF HAS THE SAME SHAPE, WHICH THIS EXTRACTOR CANNOT SEE. Measured by c1 rather than assumed
## by me, and recorded here because "we checked and it is not there" and "nobody looked" are two states a
## reader cannot tell apart from a green layer. Fixtures pose **13 distinct sim fields across ~129 sites**
## (`inventory[]` 37, `deposits[]` 21, `total_produced[]` 15, `torch[]` 12, `lode[]` 12, `research[]` 11,
## and the tail). `FactorySim.tick()` assigns exactly ONE field in its own body — `_seep_tick += 1` — and
## fans the rest out through `PowerFlow.compute(self)`, `WaterFlow.step(self)` and `Flora.grow(self)`,
## static helpers in other files taking the sim as a parameter, which between them write six sim fields.
## **Every one of those six is a subscript write**, `sim.water[c] = …`.
##
## Both of this file's rules exclude that subject by construction: `_assigned_pair` returns "" on any left
## side containing `[`, correct for node fields and fatal in a container-shaped state; and a lexical body
## scan finds 1 of 7 because the tick's per-frame work is a fan-out while `_process`'s is not. **A direct
## port would report a clean population and be clean because the instrument cannot register the writes** —
## which is the thing this layer exists to catch, arriving as this layer. The sim version needs a different
## extractor (subscripts) and a different population rule (the tick's transitive closure, not its body).
## Filed by c1 as a ticket in `docs/PRIORITY.md`; if that ticket is not there, the paragraph above is the
## ticket.
##
## ONE RULE HERE IS LOAD-BEARING FOR A REASON I DID NOT REASON TO. `_assigned_pair` rejects `+=`, which I
## wrote because a compound assignment is a read-modify-write of a field the fixture never established.
## c1's reading is better and is the one to keep: **`=` DESTROYS a pose, `+=` PRESERVES it as an offset.**
## `check_save_durability` poses `phase_b._seep_tick = phase_a._seep_tick + SEEP_INTERVAL / 2`, then
## advances both sims and asserts they diverge — under a naive port that is a textbook offence, and it is
## in fact one of the better fixtures in the tree, because the pose IS the subject. Both halves are written
## down because a reviewer needs the rule and the next person to port this needs the reason.
##
##   godot --headless --path . --script res://tools/check_posed_fields.gd

## Writes that are known-safe, each with the reason, because a bare allow-list is a place to hide a bug.
## Keyed "<tool file>:<field>". A layer whose exemption stops being true does not go green quietly — the
## reason is written next to it so the next reader can check it rather than inherit it.
const EXEMPT: Dictionary = {
	# THE NEXT FOUR ARE ONE ARGUMENT, and it is the one thing that distinguishes them from `can_craft`.
	# Each writes the value the recompute ITSELF produces when nothing is happening — `_arrival_life = 0.0`
	# against hud.gd:353's `maxf(0.0, _arrival_life - delta)`, `_hover_latch = Vector2i(-9999, -9999)`
	# against main.gd:794's own else-branch. A pose the recompute converges to cannot be destroyed by it;
	# `can_craft = true` was destroyed because `_near_bazaar()` said false and the picture agreed with the
	# game. Both of these are RESETS, not poses: the fixture is clearing a transient, and the only thing
	# that can overwrite the value is the game replacing it with the live truth.
	# WHAT THE ENTRY WOULD HIDE, since a key is a file and a field and not a line: all eight writes behind
	# it are literally `= 0.0` and `= Vector2i(-9999, -9999)` today. A non-zero `_arrival_life`, or a latch
	# posed at a real cell, is a genuine offence of this class and these entries would cover it silently.
	"capture_moments.gd:hud._arrival_life":
		"four writes, all `= 0.0`, each clearing the stratum plate the fixture flew in on so it is not in "
		+ "a shot about something else; hud.gd:353 decays the field toward exactly that value",
	"capture_moments.gd:main._hover_latch":
		"`_the_quiet` clears the latch to main.gd:794's own no-machine sentinel before shuttering the "
		+ "frame defined by what is NOT in it; the recompute either writes the same sentinel back or "
		+ "replaces it with the machine actually under the cursor, which is the truth the shot wants",
	"check_hud_layout.gd:hud._arrival_life":
		"four writes, all `= 0.0`, each resetting the ceremony clock before the layer announces into it "
		+ "and measures the plate — the announce is what sets the life, this only clears what was left",
	"check_hud_layout.gd:main._hover_latch":
		"the same sentinel reset, and this layer already wrote the reasoning out at check_hud_layout:424 "
		+ "when it stopped posing the latch at `_probe_cell`: the cursor is the input and the latch is only "
		+ "ever an echo of it, so the fixture poses `Controls.pose_pointer` and lets main.gd:794 derive",
	"check_pack_layout.gd:hud.can_craft":
		"operates on a bare `Hud.new()` with no MainView in the tree, so nothing recomputes anything; "
		+ "the whole layer is geometry on a detached node and the write is the only source of the field",
	"check_pack_layout.gd:hud.minimap_large":
		"same bare Hud — and this one is swept deliberately through both values to check the frame fits",
	"check_snap_frame.gd:main._cam_pos":
		"the fixture stops the world — `Engine.time_scale = 0.0` for the whole measurement — and at "
		+ "`delta == 0` main.gd:737's ease multiplier is `1.0 - exp(0)` = 0, so the recompute is arithmetic "
		+ "that cannot move the pose. The one branch the freeze does not cover is main.gd:734, which SNAPS "
		+ "rather than lerps when the pose is more than half a viewport from the body; check_snap_frame's "
		+ "largest displacement is one screen pixel. THIS ENTRY REPLACES ONE FOR `camera.global_position`, "
		+ "whose reason was wrong in a way worth keeping: it read 0.000 px of drift over four shots and "
		+ "called that an absence of drift. It was a rounding margin at 60 fps. The same fixture on CI's "
		+ "software rasterizer draws at 6-9 fps, where the identical pose decays to 0.101 px and rounds to "
		+ "nothing — and the layer's own control had been failing there on every run. A margin measured at "
		+ "one frame rate is not a property",
}


## THE GAME'S OWN LINE DOES NOT ALWAYS RUN, and a lexical body scan cannot see that. Keyed by the game
## pair, valued with the SWITCH that turns the recompute off. This is not EXEMPT wearing another name:
## EXEMPT excuses one fixture's write because of that fixture's situation, this excuses it because the
## statement that would destroy the pose is behind an `if` the fixture itself opened.
##
## All three below are player.gd:241-246, the three lines under `if auto_input:` — the switch player.gd:143
## documents as the harness's own door in ("the harness sets it false and drives input_dir / request_jump()
## directly"). Without this the bare-field rule reported 70 offences across 13 fixtures, every one of them
## a fixture using the entry point the game built for it.
##
## AND IT IS VERIFIED PER FIXTURE RATHER THAN ASSERTED ONCE. A tool is only excused if it assigns the named
## switch itself, matched on the FIELD name because the handle differs everywhere (`p`, `pl`, `_player`,
## `main._player`) and the pair key cannot travel. A fixture that pokes `input_dir` without throwing
## `auto_input` is still an offence, which is the whole point — a blanket entry here would be the
## allow-list failure this layer's own header warns about.
const GUARDED: Dictionary = {
	"player.input_dir": "auto_input",
	"player.input_climb": "auto_input",
	"player.jump_held": "auto_input",
}

## The one field this layer must find recomputed, or its scan of the game read nothing and every green
## below is vacuous. Named rather than counted: a count floor passes on any nine fields at all.
const CANARY: StringName = &"hud.can_craft"

## A synthetic source that MUST trip the extractor, run through the same two functions the real files go
## through. Without it, a scan that silently matched nothing would report a clean sweep.
const CONTROL_GAME: String = """
func _process(delta: float) -> void:
	_hud.made_up_field = _derive_it()
	_elsewhere.made_up_field = 3
	_own_made_up = 7
	var scratch := Rect2()
	scratch.made_up_field = 5
	var loose_local = 0
	loose_local = 6
	delta = 0.0
func _ready() -> void:
	_hud.not_per_frame = 1
	_own_not_per_frame = 8
"""
const CONTROL_TOOL: String = """
func _initialize() -> void:
	main._hud.made_up_field = true
	main._hud.not_per_frame = 2
	_player.made_up_field = 4
	control._own_made_up = 7
	elsewhere._own_made_up = 8
"""

## EVERY REJECTION IN `_assigned_pair`, one line each, with the verdict it is supposed to return. The
## control above proves the extractor FIRES; this proves the twelve places it declines are the twelve it
## means to decline, which nothing checked — the whole corpus above lands in none of them, so a rule could
## have been deleted or inverted and every green here would have held.
##
## Rows are `[line, expected pair]`, and the last TWO are acceptances on purpose: without them the table
## passes on a function that returns "" unconditionally, and the second of them is what shows the `(`
## rejection is about the LEFT side only — `_near_bazaar()` on the right is the real game line.
##
## THE BARE ROW IS THE ONE TO READ TWICE. `_cam_pos = target` is still a rejection HERE, and that is not
## the old behaviour surviving: the bare form moved to `_assigned_own`, which only `_scan_per_frame` calls,
## because `_scan_writes` reads whole tool files where a bare name is almost always the fixture's own local.
## The verdict that changed is asserted where it changed — `ctl.has(&"control._own_made_up")` in
## `_initialize`, which is the same line inside a per-frame body being ACCEPTED.
##
## Every row carries a `"` so that `_scan_writes`, which reads this file like any other tool, throws the
## whole table out at the quote rule rather than reporting the case data as writes.
const PAIR_CASES: Array = [
	["", ""],                                            # nothing there
	["\t# _hud.can_craft = true", ""],                   # ...and nothing left once the comment is cut
	['\tprint("_hud.can_craft = true")', ""],            # the offence as TEXT — this file is full of it
	["\t_hud.can_craft", ""],                            # no assignment at all
	["\tif _hud.can_craft == true:", ""],
	["\tif _hud.can_craft != true:", ""],
	["\tif _hud.count <= 1:", ""],
	["\tif _hud.count >= 1:", ""],
	["\t_hud.count += 1", ""],                           # `+=` PRESERVES a pose as an offset — see header
	["\t_hud.count -= 1", ""],
	["\t_hud.count *= 2", ""],
	["\t_hud.count /= 2", ""],
	["\t_hud.count := 1", ""],                           # synthetic: isolates `:=` from the space rule
	["\t_cam_pos = target", ""],                         # bare — `_assigned_own` handles it, not this
	["\t_rows.back().value = 1", ""],                    # a call result is not an object somebody poses
	["\t_rows[0].value = 1", ""],                        # subscripts are the sim's shape, not this one
	["\tvar plate: Rect2 = _hud.plate", ""],             # a typed declaration, not a write
	["\t_hud. = 1", ""],
	["\t_hud.ARRIVAL_HOLD = 1", ""],                     # a constant is not posed state
	["\t_.value = 1", ""],                               # a receiver of nothing but underscores
	["\tSettings.zoom_idx = 1", ""],                     # an autoload is not an instance somebody posed
	["\tmain._hud.can_craft = true", "hud.can_craft"],
	["\t_hud.can_craft = _near_bazaar()", "hud.can_craft"],
]


func _initialize() -> void:
	print("== no fixture poses a field the game recomputes every frame ==")

	var recomputed: Dictionary = {}      # "receiver.field" -> "file:line"
	for f: String in _gd_files(["res://scenes", "res://src"]):
		_scan_per_frame(_read(f), f.get_file(), recomputed)

	_check(recomputed.has(CANARY),
		"the scan of the game found `%s` recomputed per frame (%s) — without this the sweep below is vacuous"
		% [CANARY, str(recomputed.get(CANARY, "NOT FOUND"))])
	_check(recomputed.size() >= 8,
		"…and it found the rest of the per-frame pushes with it (%d fields)" % recomputed.size())

	var offences: Array[String] = []
	var exempt_seen: Dictionary = {}
	var guarded_seen: Dictionary = {}
	for f: String in _gd_files(["res://tools"]):
		var name: String = f.get_file()
		var src: String = _read(f)
		var thrown: Dictionary = _switches_thrown(src)
		for hit: Array in _scan_writes(src, recomputed):
			var key: String = "%s:%s" % [name, hit[0]]
			if EXEMPT.has(key):
				exempt_seen[key] = true
				continue
			if GUARDED.has(hit[0]) and thrown.has(GUARDED[hit[0]]):
				guarded_seen[hit[0]] = true
				continue
			offences.append("%s:%d writes `%s`, which %s recomputes every frame"
				% [name, int(hit[1]), hit[0], str(recomputed[hit[0]])])

	_check(offences.is_empty(), "no fixture writes one%s"
		% ("" if offences.is_empty() else " — " + "; ".join(offences)))

	# THE EXEMPTIONS MUST STILL BE REACHABLE. An allow-list entry for a line that no longer exists is a
	# claim nobody is checking, and it is how an allow-list grows into a place things go to be forgotten.
	for key: String in EXEMPT:
		_check(exempt_seen.has(key), "the exemption for `%s` still describes a real write" % key)
	# ...and so must the guards, for the same reason and one more: a guard nobody reaches is a recompute
	# somebody moved out from behind its `if`, which is the offence arriving as the excuse for it.
	for key: String in GUARDED:
		_check(guarded_seen.has(key), "the `%s` guard on `%s` still excuses a real write"
			% [str(GUARDED[key]), key])

	# THE CONTROL. Both halves, through the same extractors: the game half must yield the planted field and
	# must NOT yield the one written outside a per-frame body, and the tool half must be caught for it.
	var ctl: Dictionary = {}
	_scan_per_frame(CONTROL_GAME, "control.gd", ctl)
	_check(ctl.has(&"hud.made_up_field"), "CONTROL: the extractor finds a field assigned inside `_process`")
	_check(not ctl.has(&"hud.not_per_frame"),
		"CONTROL: …and does NOT find one assigned in `_ready` — the scan is scoped to the body, not the file")
	_check(not ctl.has(&"scratch.made_up_field"),
		"CONTROL: …and does NOT find one assigned on a LOCAL declared inside the body — a local is not "
		+ "posed state, and this is the false positive the first run produced")
	# THE BARE HALF, which is the half that was blind. `_own_made_up` has no receiver at all and is keyed
	# under the file's own name; the two negatives beside it are the two ways a bare name can be something
	# other than a field — a `var` declared in the body, and a parameter of the function itself.
	_check(ctl.has(&"control._own_made_up"),
		"CONTROL: the extractor finds a field the body assigns on ITSELF, with no receiver to key on")
	_check(not ctl.has(&"control.loose_local") and not ctl.has(&"control.delta"),
		"CONTROL: …and does not mistake a bare LOCAL or the function's own PARAMETER for one")
	_check(not ctl.has(&"control._own_not_per_frame"),
		"CONTROL: …and the bare rule is scoped to the body too, not the file")
	var caught: Array = _scan_writes(CONTROL_TOOL, ctl)
	# Five writes in the control tool, two of which must be caught. `_hud.made_up_field` is the receiver-form
	# offence; `_hud.not_per_frame` shares the receiver and `_player.made_up_field` shares the FIELD, and
	# neither may be caught — which is the whole reason this layer keys on the pair, and the bug the first
	# version had. `control._own_made_up` is the bare-form offence, matched because the fixture's handle
	# happens to be named for the file; `elsewhere._own_made_up` is the same field through a handle that is
	# not, and it is deliberately MISSED — that is this layer's oldest limitation, and the bare rule inherits
	# it rather than escaping it. It is a control so that the limitation is visible rather than only prose.
	_check(caught.size() == 2 and str(caught[0][0]) == "hud.made_up_field"
			and str(caught[1][0]) == "control._own_made_up",
		("CONTROL: both writes are caught, and neither the field-twin, the receiver-twin nor the "
		+ "differently-handled twin beside them is (%d hit(s))") % caught.size())
	var pair_bad: Array[String] = []
	for c: Array in PAIR_CASES:
		var got: String = _assigned_pair(str(c[0]))
		if got != str(c[1]):
			pair_bad.append("`%s` gave `%s`, wanted `%s`" % [str(c[0]).strip_edges(), got, str(c[1])])
	_check(pair_bad.is_empty(),
		("CONTROL: each of `_assigned_pair`'s rejections returns the verdict it exists for, and the two "
		+ "acceptances still land (%d cases%s)")
		% [PAIR_CASES.size(), "" if pair_bad.is_empty() else " — " + "; ".join(pair_bad)])

	_verdict("check_posed_fields",
		("%d per-frame fields in the game, %d exemptions and %d guards each with a reason, and the "
		+ "extractor is proven to fire on both shapes and to decline in %d places on purpose")
		% [recomputed.size(), EXEMPT.size(), GUARDED.size(), PAIR_CASES.size()])


## Every `<recv>.<field> = ...` AND every bare `<field> = ...` lexically inside a `_process`/
## `_physics_process` body. Godot has no reflection for "what does this function assign", so this is a line
## scan — and the body is bounded the way GDScript bounds it, by the next line at zero indentation that
## opens a declaration.
##
## THE BARE FORM IS THE COMMON ONE AND IT WAS THE INVISIBLE ONE, which is not a coincidence: it is what a
## `_process` does to its OWN state, and its own state is most of what a `_process` writes. `_assigned_pair`
## needs a receiver, so `main.gd:737`'s `_cam_pos = _cam_pos.lerp(...)` was outside the population while
## `_camera.global_position` one line BELOW it was inside — caught, and then exempted on a reason that only
## held at 60 fps. The layer looked at the defect and saw the line under it. Turning the rule on took the
## population from 20 fields to 50.
##
## A BARE NAME HAS NO RECEIVER, SO THE FILE IS THE RECEIVER: `_cam_pos` in `main.gd` is keyed
## `main._cam_pos`, which is what a fixture holding the scene in a variable called `main` or `_main` writes.
## That is the same normalisation the receiver form already uses (`main._hud`, `_hud` and `hud` all collapse
## to `hud`), and it inherits the same limitation — a fixture reaching `world_renderer.gd`'s own fields
## through a handle called `_renderer` is out of reach, and there is a control for that in `_initialize`.
## It holds for `main.gd`, `hud.gd` and `player.gd`, which are the three objects fixtures actually pose.
func _scan_per_frame(src: String, label: String, out: Dictionary) -> void:
	var owner: String = label.get_basename().lstrip("_")
	var lines: PackedStringArray = src.split("\n")
	var inside: bool = false
	# LOCALS DECLARED INSIDE THE BODY ARE NOT POSED STATE. `world_renderer._process` builds a local `rmin`
	# and assigns `rmin.x`; `profile_frame` happens to use locals of the same name, and without this the
	# layer reported it as a fixture posing a field the game recomputes. A local is not a field of a live
	# object — nothing can overwrite it between a fixture's write and a shutter, because it does not
	# survive the call.
	# ...and under the bare rule the function's own PARAMETERS join them, for the same reason and with more
	# at stake: `delta = 0.0` is a bare assignment to a name that is not a field at all, and keyed by file
	# it would have become `main.delta` and matched any fixture writing `main.delta`.
	var locals: Dictionary = {}
	for i: int in lines.size():
		var ln: String = lines[i]
		if ln.begins_with("func "):
			inside = ln.begins_with("func _process(") or ln.begins_with("func _physics_process(")
			locals.clear()
			if inside:
				for p: String in _params_of(ln):
					locals[p] = true
			continue
		if not ln.is_empty() and not ln.begins_with("\t") and not ln.begins_with(" "):
			inside = false      # any other top-level declaration ends the body
			continue
		if not inside:
			continue
		var decl: String = ln.strip_edges()
		if decl.begins_with("var "):
			var nm: String = decl.substr(4).strip_edges()
			for cut: String in [" ", ":", "="]:
				var at: int = nm.find(cut)
				if at > 0:
					nm = nm.substr(0, at)
			locals[nm.lstrip("_")] = true
		var pair: String = _assigned_pair(ln)
		if pair != "":
			if locals.has(pair.substr(0, pair.find("."))):
				continue
			if not out.has(StringName(pair)):
				out[StringName(pair)] = "%s:%d" % [label, i + 1]
			continue
		var own: String = _assigned_own(ln)
		if own == "" or locals.has(own.lstrip("_")):
			continue
		var key: StringName = StringName("%s.%s" % [owner, own])
		if not out.has(key):
			out[key] = "%s:%d" % [label, i + 1]


## The parameter NAMES of a `func` line, so a body's own arguments can be excluded alongside its locals.
func _params_of(func_line: String) -> Array[String]:
	var out: Array[String] = []
	var open: int = func_line.find("(")
	var close: int = func_line.rfind(")")
	if open < 0 or close <= open:
		return out
	for part: String in func_line.substr(open + 1, close - open - 1).split(","):
		var nm: String = part.strip_edges()
		for cut: String in [" ", ":", "="]:
			var at: int = nm.find(cut)
			if at > 0:
				nm = nm.substr(0, at)
		if not nm.is_empty():
			out.append(nm.lstrip("_"))
	return out


## Which FIELD names a tool assigns anywhere in itself, receiver ignored. Read by the `GUARDED` check,
## which has to ask "did this fixture throw `auto_input`" of a file that spells the handle `p`, `pl`,
## `_player` or `main._player` depending on who wrote it — so the pair key cannot answer and the field can.
func _switches_thrown(src: String) -> Dictionary:
	var out: Dictionary = {}
	for ln: String in src.split("\n"):
		var pair: String = _assigned_pair(ln)
		if pair != "":
			out[pair.substr(pair.find(".") + 1)] = true
	return out


## Writes to any field in `fields`, anywhere in a tool. Returns [[field, line], ...].
func _scan_writes(src: String, fields: Dictionary) -> Array:
	var out: Array = []
	var lines: PackedStringArray = src.split("\n")
	for i: int in lines.size():
		var pair: String = _assigned_pair(lines[i])
		if pair != "" and fields.has(StringName(pair)):
			out.append([pair, i + 1])
	return out


## The target of a plain `=` assignment on `raw`, or "". These are the four rules that are about the
## STATEMENT rather than about what it writes to, which is why both extractors below start here: a line
## that is empty once its comment is cut; a line carrying a string, which matters because this file's own
## prose and `capture_moments`' four-paragraph explanation both contain the offending line as TEXT; a line
## with no assignment on it; and a comparison or compound assignment — `+=` is a read-modify-write of a
## field the fixture did not establish, and is not this class.
func _assign_lhs(raw: String) -> String:
	var ln: String = raw
	var hash_at: int = ln.find("#")
	if hash_at >= 0:
		ln = ln.substr(0, hash_at)
	if ln.strip_edges().is_empty() or ln.count("\"") > 0:
		return ""
	var eq: int = ln.find("=")
	if eq < 1:
		return ""
	if ln[eq - 1] in ["=", "!", "<", ">", "+", "-", "*", "/", ":"] or ln.substr(eq + 1, 1) == "=":
		return ""
	return ln.substr(0, eq).strip_edges()


## `receiver.field` for a `something.receiver.field = value` statement, or "". The receiver is the
## identifier immediately left of the field with any leading underscore stripped, so the game's `_hud` and a
## fixture's `main._hud` and `hud` all normalise to `hud`. Rejects typed declarations, calls and subscripts
## on the left, and a bare name — that last one is not a gap, it is `_assigned_own`'s subject, and it stays
## a rejection HERE because `_scan_writes` reads whole tool files where a bare name is nearly always a local
## of the fixture's own.
func _assigned_pair(raw: String) -> String:
	var lhs: String = _assign_lhs(raw)
	var dot: int = lhs.rfind(".")
	if dot < 1 or lhs.contains("(") or lhs.contains("[") or lhs.contains(" "):
		return ""
	var field: String = lhs.substr(dot + 1)
	if field.is_empty() or field.to_lower() != field:
		return ""      # Constants and Types are not posed state
	var head: String = lhs.substr(0, dot)
	var recv: String = head.substr(head.rfind(".") + 1).lstrip("_")
	if recv.is_empty() or recv.to_lower() != recv:
		return ""      # `Autoload.field` / `SomeClass.field` is not an instance somebody posed
	return "%s.%s" % [recv, field]


## The bare `field = value` form — a body writing its OWN state, with no receiver to key on. Same statement
## rules as the pair form and the same rejections on the left; the difference is that a dot DISQUALIFIES
## here instead of being required. The caller supplies the receiver, and only `_scan_per_frame` may call
## this: outside a per-frame body a bare name is a local, and `locals` is what tells the two apart.
func _assigned_own(raw: String) -> String:
	var lhs: String = _assign_lhs(raw)
	if lhs.is_empty() or lhs.contains(".") or lhs.contains("(") or lhs.contains("[") or lhs.contains(" "):
		return ""
	if lhs.to_lower() != lhs:
		return ""      # a CONSTANT written at body scope is not posed state either
	return lhs


func _read(path: String) -> String:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	return "" if f == null else f.get_as_text()


func _gd_files(roots: Array) -> Array[String]:
	var out: Array[String] = []
	for root: String in roots:
		_walk(root, out)
	out.sort()
	return out


func _walk(dir_path: String, out: Array[String]) -> void:
	var d: DirAccess = DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var n: String = d.get_next()
	while n != "":
		if d.current_is_dir():
			if not n.begins_with("."):
				_walk(dir_path.path_join(n), out)
		elif n.ends_with(".gd"):
			out.append(dir_path.path_join(n))
		n = d.get_next()
	d.list_dir_end()
