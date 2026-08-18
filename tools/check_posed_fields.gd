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
## `<receiver>.<field> = ...` statement lexically inside a `_process` or `_physics_process` body under
## `scenes/` and `src/`. Add a new per-frame push and this layer's population grows by itself.
##
## WHAT IT CANNOT SEE, stated because a static scan invites being trusted past its reach:
##   - mutation through a method (`hud.set_thing(x)`), or through a shared Array/Dictionary reference
##   - a field on a local declared inside the body — excluded on purpose, see `locals` below
##   - a field pushed from a timer, a signal handler, or `_ready` (`hud.objectives` is one — assigned once,
##     by reference, so a fixture that reassigns it decouples rather than loses)
##   - a receiver named differently in the two files. The match is on the PAIR — the identifier immediately
##     left of the field, with a leading underscore stripped — so `main._hud.can_craft` in a fixture meets
##     `_hud.can_craft` in the game, and `check_pack_layout`'s bare `hud` meets it too, while
##     `_player.position` never collides with `_motes.position`. A fixture that reaches the same object
##     through a differently-NAMED handle is outside this layer's reach.
##
## THE FIRST VERSION OF THIS FILE MATCHED ON THE FIELD NAME ALONE and reported fifty-eight offences, of
## which fifty-seven were `_player.position` colliding with `_motes.position`, and two were a local called
## `rmin` inside `world_renderer._process` colliding with any `.x` anywhere. A layer written to catch
## "the population is not the claim" whose own population was every field with a common name. Kept in the
## comment rather than the history because the shape is the lesson.
## It sees exactly one shape, and that shape is the one that bit us.
##
##   godot --headless --path . --script res://tools/check_posed_fields.gd

## Writes that are known-safe, each with the reason, because a bare allow-list is a place to hide a bug.
## Keyed "<tool file>:<field>". A layer whose exemption stops being true does not go green quietly — the
## reason is written next to it so the next reader can check it rather than inherit it.
const EXEMPT: Dictionary = {
	"check_pack_layout.gd:hud.can_craft":
		"operates on a bare `Hud.new()` with no MainView in the tree, so nothing recomputes anything; "
		+ "the whole layer is geometry on a detached node and the write is the only source of the field",
	"check_pack_layout.gd:hud.minimap_large":
		"same bare Hud — and this one is swept deliberately through both values to check the frame fits",
	"check_snap_frame.gd:camera.global_position":
		"MEASURED, not argued. The camera IS lerped back toward the body 12.5%/frame by main.gd:735, but "
		+ "`_shoot` awaits two frames and the drift arrives at 0.000 px: the pull is sub-pixel and "
		+ "`snap_to_pixel` rounds it away. The mechanism that makes this fixture safe is the mechanism the "
		+ "layer exists to test, which is a nice thing to have written down and a bad thing to assume",
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
	var scratch := Rect2()
	scratch.made_up_field = 5
func _ready() -> void:
	_hud.not_per_frame = 1
"""
const CONTROL_TOOL: String = """
func _initialize() -> void:
	main._hud.made_up_field = true
	main._hud.not_per_frame = 2
	_player.made_up_field = 4
"""


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
	for f: String in _gd_files(["res://tools"]):
		var name: String = f.get_file()
		for hit: Array in _scan_writes(_read(f), recomputed):
			var key: String = "%s:%s" % [name, hit[0]]
			if EXEMPT.has(key):
				exempt_seen[key] = true
				continue
			offences.append("%s:%d writes `%s`, which %s recomputes every frame"
				% [name, int(hit[1]), hit[0], str(recomputed[hit[0]])])

	_check(offences.is_empty(), "no fixture writes one%s"
		% ("" if offences.is_empty() else " — " + "; ".join(offences)))

	# THE EXEMPTIONS MUST STILL BE REACHABLE. An allow-list entry for a line that no longer exists is a
	# claim nobody is checking, and it is how an allow-list grows into a place things go to be forgotten.
	for key: String in EXEMPT:
		_check(exempt_seen.has(key), "the exemption for `%s` still describes a real write" % key)

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
	var caught: Array = _scan_writes(CONTROL_TOOL, ctl)
	# Three writes in the control tool. `_hud.made_up_field` is the offence; `_hud.not_per_frame` shares the
	# receiver and must not be caught; `_player.made_up_field` shares the FIELD and must not be caught
	# either — which is the whole reason this layer keys on the pair, and the bug the first version had.
	_check(caught.size() == 1 and str(caught[0][0]) == "hud.made_up_field",
		"CONTROL: the write is caught, and neither the field-twin nor the receiver-twin beside it is (%d hit(s))"
		% caught.size())

	_verdict("check_posed_fields",
		"%d per-frame fields in the game, %d exemptions each with a reason, and the extractor is proven to fire"
		% [recomputed.size(), EXEMPT.size()])


## Every `<recv>.<field> = ...` lexically inside a `_process`/`_physics_process` body. Godot has no
## reflection for "what does this function assign", so this is a line scan — and the body is bounded the
## way GDScript bounds it, by the next line at zero indentation that opens a declaration.
func _scan_per_frame(src: String, label: String, out: Dictionary) -> void:
	var lines: PackedStringArray = src.split("\n")
	var inside: bool = false
	# LOCALS DECLARED INSIDE THE BODY ARE NOT POSED STATE. `world_renderer._process` builds a local `rmin`
	# and assigns `rmin.x`; `profile_frame` happens to use locals of the same name, and without this the
	# layer reported it as a fixture posing a field the game recomputes. A local is not a field of a live
	# object — nothing can overwrite it between a fixture's write and a shutter, because it does not
	# survive the call.
	var locals: Dictionary = {}
	for i: int in lines.size():
		var ln: String = lines[i]
		if ln.begins_with("func "):
			inside = ln.begins_with("func _process(") or ln.begins_with("func _physics_process(")
			locals.clear()
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
		if pair != "" and locals.has(pair.substr(0, pair.find("."))):
			continue
		if pair != "" and not out.has(StringName(pair)):
			out[StringName(pair)] = "%s:%d" % [label, i + 1]


## Writes to any field in `fields`, anywhere in a tool. Returns [[field, line], ...].
func _scan_writes(src: String, fields: Dictionary) -> Array:
	var out: Array = []
	var lines: PackedStringArray = src.split("\n")
	for i: int in lines.size():
		var pair: String = _assigned_pair(lines[i])
		if pair != "" and fields.has(StringName(pair)):
			out.append([pair, i + 1])
	return out


## `receiver.field` for a `something.receiver.field = value` statement, or "". The receiver is the
## identifier immediately left of the field with any leading underscore stripped, so the game's `_hud` and a
## fixture's `main._hud` and `hud` all normalise to `hud`. Rejects comparisons, compound assignment
## (`+=` is a read-modify-write of a field the fixture did not establish, and is not this class), typed
## declarations, and anything inside a comment or a string — the last of which matters, because this file's
## own prose and `capture_moments`' four-paragraph explanation both contain the offending line as TEXT.
func _assigned_pair(raw: String) -> String:
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
	var lhs: String = ln.substr(0, eq).strip_edges()
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
