extends "res://tools/check_base.gd"

## EVERY KEY THE GAME NAMES IN PROSE MUST BE A KEY THAT DOES THAT.
##
## The other half of COMPREHENSIVE_AUDIT §199. `check_tool_text` holds a tool's blurb to the mining data;
## this holds every player-facing sentence to the input map. The tooltips are full of keys:
##
##   "smeltable — a Forge turns it into ingots (toss it in, Q)"
##   "RMB above a drop — it unrolls down; W/S climbs it"
##   "routes falling items DOWN + RIGHT (aim R at it: ratio)"
##
## And nothing held any of them to `Controls.defaults()`. Bindings move more often than data tables do:
## `sf_research` alone has already moved once, and the comment recording it is still in controls.gd
## ("#S33: CONFIGURE the machine you are aiming at. Research moved to ENTER."). Every one of those moves is a
## chance to leave a sentence behind pointing at a key that now does something else, or nothing.
##
## A TOOLTIP THAT NAMES THE WRONG KEY IS WORSE THAN ONE THAT NAMES NONE. A player who reads "press Q" and
## gets nothing concludes the mechanic is broken, or that they are. There is no in-game way to discover that
## the sentence is the thing at fault, which is what makes this whole family, text against mechanics,
## worth a harness layer rather than a proofread.
##
## TWO RULES, AND THE SECOND IS THE ONE WITH TEETH:
##
##   LIVE.    Every key token in player-facing prose is currently bound to SOME action. Catches the common
##            rot: a binding is moved or removed and the sentence is left behind pointing at a dead key.
##   CORRECT. For the tokens whose meaning the prose is unambiguous about, the token must be the label of
##            the action it claims. "toss it in, Q" is a claim that Q is DROP, and if DROP moves to another
##            key while Q stays bound to something else, LIVE passes and this does not.
##
## THE SECOND RULE NEEDS A HAND-WRITTEN TABLE, which is the very thing this project keeps getting bitten by,
## so it is held from both ends: every row must be exercised by some sentence (or it is a stale row nobody
## noticed), and every token found in prose must have a row (or it is a key nothing is guarding). What the
## table maps is a WORD to an ACTION, the stable half, while the part that actually moves, the action to
## its key, is read live from Controls. A row only goes stale if the prose stops mentioning it at all.
##
## Runs headless: InputMap registration needs no display.
##
##   godot --headless --path . --script res://tools/check_binding_text.gd

## The prose token -> the action it is claiming. Only tokens whose meaning is unambiguous in context; a
## sentence that mentions a key without asserting what it does belongs in LIVE and not here.
const CLAIMS: Dictionary = {
	"LMB": &"sf_mine",
	"RMB": &"sf_build",
	"Q": &"sf_drop",
	"E": &"sf_craft",
	"R": &"sf_research",
	"M": &"sf_map",
	"H": &"sf_help",
	"P": &"sf_pause",
	"Z": &"sf_zoom",
	"T": &"sf_tech",
	"G": &"sf_dashboard",
	"F": &"sf_grapple",
	"N": &"sf_mute",
	"X": &"sf_clear_marks",
	"W": &"sf_up",
	"S": &"sf_down",
	"A": &"sf_left",
	"D": &"sf_right",
	"L": &"sf_link",
}

## Single letters are read as keys; multi-letter words are not, so the prose can shout PACKED and FUEL for
## emphasis without this layer mistaking them for bindings. These are the multi-character labels that ARE
## keys, matched explicitly.
const MULTI: Array[String] = ["LMB", "RMB", "MMB", "ESC", "SPACE", "F5", "F9"]


func _initialize() -> void:
	print("== every key the game names is a key that does that ==")
	_run()
	_verdict("check_binding_text", "the prose and the input map agree")


func _run() -> void:
	Controls.register()
	if not InputMap.has_action(&"sf_mine"):
		_check(false, "the input map registered")
		return

	# --- gather every sentence the player can read ---
	var prose: Array[String] = []
	for k: Variant in Hud.ITEM_PURPOSE:
		prose.append(String(Hud.ITEM_PURPOSE[k]))
	for ln: String in Hud.HELP_LINES:
		prose.append(ln)

	# --- find the key tokens in them ---
	var found: Dictionary = {}                # token -> the first sentence naming it, for the message
	for line: String in prose:
		for tok: String in _tokens(line):
			if not found.has(tok):
				found[tok] = line

	# --- LIVE: nothing points at a dead key ---
	var bound: Dictionary = _labels_in_use()
	var dead: Array[String] = []
	for tok: Variant in found:
		if not bound.has(String(tok)):
			dead.append("%s (\"%s\")" % [tok, found[tok]])
	_check(dead.is_empty(),
		"every key named in prose is bound to something%s"
			% ["" if dead.is_empty() else " — DEAD: " + "; ".join(dead)])

	# --- CORRECT: and to the thing the sentence says it is ---
	var wrong: Array[String] = []
	for tok: Variant in found:
		var t: String = String(tok)
		if not CLAIMS.has(t):
			continue
		var action := StringName(CLAIMS[t])
		if not _action_has_label(action, t):
			wrong.append("prose says %s is %s, but %s is %s"
				% [t, action, action, Settings.binding_label(action)])
	_check(wrong.is_empty(),
		"every key named for a job is bound to that job%s"
			% ["" if wrong.is_empty() else " — " + "; ".join(wrong)])

	# --- the table is held from both ends ---
	var unguarded: Array[String] = []
	for tok: Variant in found:
		if not CLAIMS.has(String(tok)) and not MULTI.has(String(tok)):
			unguarded.append(String(tok))
	_check(unguarded.is_empty(),
		"every key the prose names has a row saying what it should do%s"
			% ["" if unguarded.is_empty() else " — UNGUARDED: " + ", ".join(unguarded)])
	var stale: Array[String] = []
	for tok: Variant in CLAIMS:
		if not found.has(String(tok)):
			stale.append(String(tok))
	# A stale row is not a failure, since prose is allowed to stop mentioning a key, but an accumulation of
	# them means the table has drifted away from the text it claims to guard, and a table nobody exercises
	# is not a guard. Reported, and floored, rather than asserted empty.
	print("  %d of %d claim rows are exercised by prose%s"
		% [CLAIMS.size() - stale.size(), CLAIMS.size(),
			"" if stale.is_empty() else " (unmentioned: " + ", ".join(stale) + ")"])
	_check(CLAIMS.size() - stale.size() >= 6,
		"at least 6 claim rows are actually exercised (%d are)" % (CLAIMS.size() - stale.size()))

	# NON-VACUITY. Every assertion above is satisfied by prose containing no keys at all, which is exactly
	# what a broken tokeniser produces, and the LIVE and CORRECT rules would both report perfect health.
	_check(found.size() >= 6, "%d distinct keys were found in the prose" % found.size())
	_check(prose.size() >= 20, "%d player-facing sentences were read" % prose.size())


## The key tokens in one sentence. A token is a single UPPERCASE letter, or one of the known multi-character
## labels, bounded by non-alphanumerics on both sides. The bounds are what let the prose shout PACKED, FUEL
## and STAYS for emphasis without any of them reading as a binding, and what keeps "L2" from yielding L.
func _tokens(line: String) -> Array[String]:
	var out: Array[String] = []
	var re := RegEx.new()
	re.compile("(^|[^A-Za-z0-9])(" + "|".join(MULTI) + "|[A-Z])([^A-Za-z0-9]|$)")
	var at: int = 0
	while true:
		var m: RegExMatch = re.search(line, at)
		if m == null:
			break
		var t: String = m.get_string(2)
		if not out.has(t):
			out.append(t)
		# Step to just after the token itself, not past the trailing delimiter: "W/S" shares the slash
		# between the two tokens, and consuming it would hide S.
		at = m.get_end(2)
	return out


## Every label currently produced by a bound action, as a set.
func _labels_in_use() -> Dictionary:
	var out: Dictionary = {}
	for action: Variant in Controls.defaults():
		var a := StringName(action)
		if not InputMap.has_action(a):
			continue
		for ev: InputEvent in InputMap.action_get_events(a):
			out[Settings.event_label(ev)] = true
	return out


## Does `action` have ANY bound event labelled `label`? Not just its first: GRAPPLE is F and the middle
## mouse button, and a sentence naming either one is telling the truth.
func _action_has_label(action: StringName, label: String) -> bool:
	if not InputMap.has_action(action):
		return false
	for ev: InputEvent in InputMap.action_get_events(action):
		if Settings.event_label(ev) == label:
			return true
	return false
