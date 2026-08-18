extends "res://tools/check_base.gd"

## WHAT THE GAME TELLS YOU ABOUT A TOOL MUST BE TRUE OF THE TOOL.
##
## COMPREHENSIVE_AUDIT §199: "player-facing tool/binding text has drifted from current mechanics". It had,
## and the drift is worth stating exactly, because it is the same defect this project has now found three
## times in one day in three different disguises.
##
## `#S32` DELETED THE SPEED AXIS. Every pick cuts at 1.0 and the ladder means one thing only: what you may
## bite. `MiningRules.TOOLS` says so — 1.0, 1.0, 1.0 — and the comment above it says so at length, calling
## the old 1.0/1.7/2.6 ladder a treadmill and explaining why flattening it had to wait for the bits. What
## the player was told, in `Hud.ITEM_PURPOSE`, was:
##
##   stone_pickaxe   "tier-2 pick — opens deepslate and iron, and DIGS FASTER"
##   iron_pickaxe    "tier-3 pick — THE FASTEST MADE; keyed for what waits under L2"
##
## Two sentences promising a stat the game had deliberately removed, sitting eleven lines from the table
## that disproves them. Nothing was broken. Every test passed. The tooltip rendered beautifully. A player
## crafting the Stone Pickaxe for the speed would simply not get it, and would have no way to know the game
## had told them wrong — which is worse than a bug, because a bug is visible from inside the game.
##
## THIS IS THE WIRING FAMILY AGAIN. A fact defined in `src/data/mining_rules.gd` and a sentence written in
## `scenes/hud.gd`, with every test in the suite reading one file or the other. `check_status_reads` caught
## the same shape between the sim's status vocabulary and the renderer's match; `check_item_reads` caught it
## between the item vocabulary and a hand-kept list. Prose is simply the hardest end to hold, because prose
## cannot be enumerated — so this layer does not try to understand the sentences. It checks the three claims
## a tool blurb can make that ARE mechanically decidable:
##
##   TIER.      "tier-N" must be the tool's actual tier in TOOLS.
##   REACH.     A material named in a tool's blurb must be one that tool can actually break — right class,
##              and its REQUIRED_TIER at or below the tool's. Re-tier deepslate and the wood pick's list
##              becomes a lie the same afternoon.
##   SPEED.     If every tool of a class cuts at the same rate, no blurb for that class may promise a
##              speed difference. This is the assertion that would have caught #S32's leftovers, and it is
##              deliberately keyed off the DATA — when a future tool genuinely does cut faster, the speeds
##              stop being equal, the rule stops applying, and the blurbs may say so again. It is not a ban
##              on the word "fast". It is a ban on claiming a difference that does not exist.
##
## Runs headless: two dictionaries and some string matching.
##
##   godot --headless --path . --script res://tools/check_tool_text.gd

## Words that promise a rate rather than a capability. Matched case-insensitively against a blurb.
const SPEED_WORDS: Array[String] = ["faster", "fastest", "quicker", "quickest", "slower", "slowest",
	"speedier", "digs quick", "cuts quick"]


func _initialize() -> void:
	print("== what the game says about a tool is true of the tool ==")
	_run()
	_verdict("check_tool_text", "every mechanically-decidable claim in a tool tooltip holds")


func _run() -> void:
	var tiers_claimed: int = 0
	var materials_named: int = 0
	var blurbs: int = 0

	for id: Variant in MiningRules.TOOLS:
		var tool_id := StringName(id)
		if not Hud.ITEM_PURPOSE.has(tool_id):
			continue
		var blurb: String = Hud.ITEM_PURPOSE[tool_id]
		var spec: Dictionary = MiningRules.TOOLS[tool_id]
		var tier: int = int(spec[&"tier"])
		var cls := StringName(spec[&"class"])
		blurbs += 1

		# --- TIER: the number in the sentence is the number in the table ---
		var re := RegEx.new()
		re.compile("tier-([0-9]+)")
		var hit: RegExMatch = re.search(blurb.to_lower())
		if hit != null:
			tiers_claimed += 1
			_check(int(hit.get_string(1)) == tier,
				"%s says tier-%s and is tier %d" % [tool_id, hit.get_string(1), tier])

		# --- REACH: every material it names, it can actually break ---
		for mat: Variant in MiningRules.HARDNESS:
			var m := StringName(mat)
			if not _names(blurb, String(m)):
				continue
			materials_named += 1
			var want_cls: StringName = MiningRules.required_tool(m)
			var want_tier: int = MiningRules.required_tier(m)
			var reachable: bool = want_cls == &"" or (want_cls == cls and tier >= want_tier)
			_check(reachable,
				"%s names %s, and can break it (needs %s tier %d; this is %s tier %d)"
					% [tool_id, m, want_cls if want_cls != &"" else &"nothing", want_tier, cls, tier])

		# --- SPEED: no promising a difference the data does not have ---
		if _class_is_flat(cls):
			var promised: Array[String] = []
			for w: String in SPEED_WORDS:
				if blurb.to_lower().contains(w):
					promised.append(w)
			_check(promised.is_empty(),
				"%s promises no speed advantage, because every %s cuts at the same rate%s"
					% [tool_id, cls, "" if promised.is_empty() else " — SAYS: " + ", ".join(promised)])

	# NON-VACUITY, and each of the three assertions above needs its own, because each is skipped by a
	# `continue` or an `if` and a skipped assertion is indistinguishable from a passing one in the tally.
	# A blurb table with no tool entries, or blurbs that name no materials and claim no tiers, satisfies
	# every line above perfectly while checking nothing whatsoever.
	_check(blurbs >= 3, "%d tools have a tooltip to check" % blurbs)
	_check(tiers_claimed >= 2, "%d of those tooltips claim a tier, so the tier rule had work to do"
		% tiers_claimed)
	_check(materials_named >= 3, "%d material claims were checked against the tier gates" % materials_named)

	# AND THE PREMISE OF THE SPEED RULE, which is the one that can rot without anybody noticing. If a future
	# tool genuinely cuts faster the rule correctly stops applying — but then it is silently inert, and this
	# file would go on looking like it was guarding something. Assert the premise out loud instead.
	_check(_class_is_flat(&"pick"),
		"every pick still cuts at the same rate, so the speed rule above is live and not merely inert")
	_check_every_selectable_says_something()


## Does `blurb` name material `m` as a word? Substring alone would let "ore" match "before", so the match is
## bounded by non-letters on both sides. Underscores in ids are matched as spaces too, because prose writes
## "rich ore" where the data writes `rich_ore`.
##
## KNOWN AND ACCEPTED: "rich ore" therefore matches BOTH `rich_ore` and `ore`, so a blurb naming the one is
## checked against the other as well. The consequence is a blurb could fail for a material it only mentioned
## inside a longer name — an over-strict result, never a permissive one, and over-strict is the correct
## direction for a guard on what the game promises a player. Tightening it would mean ranking overlapping
## names by length, which is more machinery than a five-row table is worth.
## ...AND IT MUST TELL YOU SOMETHING AT ALL, which is the half above this one cannot see.
##
## Everything above judges the CONTENT of a tooltip against the rules it describes: if a blurb claims a
## tier, the tier table must agree. Its population is "ids that have a blurb". An id with NO blurb makes no
## claim, contradicts no table, and passes every assertion in this file by making itself absent from them.
##
## `Hud._draw_bazaar_detail` does `blurb = ITEM_PURPOSE.get(id, "—")`, so the detail plate — the one surface
## in the game whose entire job is explaining the selected thing — prints a lone em-dash and looks
## deliberate. Eight ids were in that state when this was written, including ALL FOUR cutting bits, whose
## icons are drawn as their cut on purpose (`Visuals._item_bit`: "you can tell what a bit does to rock by
## looking at what it is") and whose plate said nothing. The silhouette carried the design thesis and the
## sentence carried an em-dash.
##
## The population is every id the Bazaar can put ON that plate: the machines `_craftable` sells, the tools
## on the Rack, and everything the pack can hold — derived from the data rather than listed here, for the
## same reason `_items_the_view_knows` scans visuals.gd instead of mirroring it.
func _check_every_selectable_says_something() -> void:
	var ids: Array[StringName] = []
	for f: String in ["res://src/data/materials", "res://src/data/recipes"]:
		var d: DirAccess = DirAccess.open(f)
		if d == null:
			continue
		for n: String in d.get_files():
			if not n.ends_with(".tres"):
				continue
			if f.ends_with("materials"):
				var mat: MaterialDef = load("%s/%s" % [f, n]) as MaterialDef
				# Wall-plane rock is never carried; leaves chop into a sapling; the seal is REQUIRED_TIER 99
				# and no pick has ever broken one. None of the three can reach the plate.
				if mat == null or mat.layer == &"wall" or mat.id == &"leaves" or mat.id == &"sealrock":
					continue
				_add_id(ids, mat.id)
			else:
				var rec: RecipeDef = load("%s/%s" % [f, n]) as RecipeDef
				if rec == null:
					continue
				for side: Dictionary in [rec.inputs, rec.outputs]:
					for k: Variant in side:
						_add_id(ids, StringName(k))
	for t: Dictionary in MainView.CRAFT_TOOLS:
		_add_id(ids, t["id"])
	_add_id(ids, &"wood_pickaxe")
	_add_id(ids, &"sapling")
	var d2: DirAccess = DirAccess.open("res://src/data/machines")
	if d2 != null:
		for n: String in d2.get_files():
			if not n.ends_with(".tres"):
				continue
			var def: MachineDef = load("res://src/data/machines/%s" % n) as MachineDef
			if def != null and ResearchRules.locking_tech(def.id) != &"" or _is_craftable(def):
				_add_id(ids, def.id)

	var silent: Array[String] = []
	for id: StringName in ids:
		var text: String = str(Hud.ITEM_PURPOSE.get(id, ""))
		if text.strip_edges() == "" or text.strip_edges() == "—":
			silent.append(String(id))
	_check(silent.is_empty(),
		"every one of the %d things the counter can put on the detail plate says what it is for%s"
			% [ids.size(), "" if silent.is_empty() else " — SILENT (the plate prints an em-dash): "
				+ ", ".join(silent)])
	# NON-VACUITY: an empty id list satisfies the above perfectly, which is what a renamed data directory
	# produces, and the failure mode of "nothing was silent" over nothing is a silent pass.
	_check(ids.size() >= 30, "the scan found %d selectable ids to check" % ids.size())
	# CONTROL: the same predicate over an id the table certainly does not carry.
	var probe: String = str(Hud.ITEM_PURPOSE.get(&"not_a_real_item", ""))
	_check(probe.strip_edges() == "", "the same lookup comes back empty for an id with no entry")


func _add_id(into: Array[StringName], id: StringName) -> void:
	if id != &"" and not into.has(id):
		into.append(id)


## A machine is on the counter if `MainView._craftable` carries it. That list is a hardcoded array built in
## `_ready`, so it is read from the source rather than from a booted scene here — this layer never boots one,
## and `check_craftable_registry` is the one that reads the LIVE list.
func _is_craftable(def: MachineDef) -> bool:
	if def == null:
		return false
	var f: FileAccess = FileAccess.open("res://scenes/main.gd", FileAccess.READ)
	if f == null:
		return false
	var body: String = f.get_as_text()
	f.close()
	return body.contains("machines/%s.tres" % String(def.id))


func _names(blurb: String, m: String) -> bool:
	var word: String = m.replace("_", "[ _]")
	var re := RegEx.new()
	re.compile("(^|[^a-z])" + word + "([^a-z]|$)")
	return re.search(blurb.to_lower()) != null


## True when every tool of this class cuts at the same rate — i.e. speed carries no information for it.
func _class_is_flat(cls: StringName) -> bool:
	var seen: float = -1.0
	for id: Variant in MiningRules.TOOLS:
		var spec: Dictionary = MiningRules.TOOLS[id]
		if StringName(spec[&"class"]) != cls:
			continue
		var s: float = float(spec[&"speed"])
		if seen < 0.0:
			seen = s
		elif not is_equal_approx(s, seen):
			return false
	return true
