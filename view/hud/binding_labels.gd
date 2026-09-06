class_name BindingLabels
extends RefCounted

## THE BINDINGS AS THE HUD SPEAKS THEM (D0411, the new-player review's rank 3: "use current bindings
## everywhere"). A lesson used to say "hold MINE", a verb name the player had to translate through the
## bottom legend; a lesson now says `[MINE]` and this fills it with the key or button that verb is bound to
## RIGHT NOW -- `LMB`, `Space`, `Q` -- so a rebinding on the settings page rewrites every sentence at once.
##
## The view may not reach `shell/` where the bindings live, so the shell WRITES the table here (`Main` at
## boot and after every settings interaction) and every HUD text reads it; with nothing written a token
## falls back to its verb name, which is the old behaviour and never an empty bracket.

const TOKENS: Dictionary = {
	"MINE": Controls.MINE, "BUILD": Controls.BUILD, "DROP": Controls.DROP, "JUMP": Controls.JUMP,
	"GRAPPLE": Controls.GRAPPLE, "REEL": Controls.CLIMB_UP, "LOWER": Controls.CLIMB_DOWN,
	"CONFIGURE": Controls.CONFIGURE, "LINK": Controls.LINK, "MAP": Controls.MAP, "SETTINGS": Controls.SETTINGS,
	"SAVE": Controls.SAVE, "LEFT": Controls.LEFT, "RIGHT": Controls.RIGHT,
}

static var labels: Dictionary = {}   # action: StringName -> the label the shell wrote, e.g. "LMB"


## Replace every `[TOKEN]` in `text` with its bound label, e.g. "hold [MINE]" -> "hold LMB".
static func fill(text: String) -> String:
	var out: String = text
	for token: String in TOKENS:
		var needle: String = "[" + token + "]"
		if out.find(needle) < 0:
			continue
		out = out.replace(needle, label_of(TOKENS[token], token))
	return out


static func label_of(action: StringName, fallback: String) -> String:
	var l: String = String(labels.get(action, ""))
	return l if l != "" else fallback
