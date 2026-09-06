class_name SeatHud
extends RefCounted

## THE SHELL'S KEYS ON THE HUD (D0411), split from `shell/main.gd` at the file cap: what the seat writes
## into the view's HUD that the view may not reach for itself -- the bindings' labels for every lesson's
## `[TOKEN]` (`BindingLabels`), and the two session keys that ride beside the sim's envelope: the lessons
## the hints have taught (`Main.KEY_HINTS`, since 6h) and now the ladder's latched rungs (`KEY_OBJECTIVES`),
## because objectives lived only in the HUD and a returning player was put back on "Mine 4 ore".

const KEY_HINTS: String = "hints"
const KEY_OBJECTIVES: String = "objectives"


## Every bound action's label into the HUD's table: at boot, and after any settings interaction.
static func push_bindings() -> void:
	var labels: Dictionary = {}
	for action: StringName in Controls.defaults():
		labels[action] = SettingsBindings.binding_label(action)
	BindingLabels.labels = labels


static func capture(stack: ViewStack, env: Dictionary) -> void:
	if stack == null:
		return
	if stack.hints != null:
		env[KEY_HINTS] = stack.hints.taught_ids()
	if stack.objectives != null:
		env[KEY_OBJECTIVES] = stack.objectives.done_ids()


static func restore(stack: ViewStack, env: Dictionary) -> void:
	if stack == null or env.is_empty():
		return
	if stack.hints != null and env.get(KEY_HINTS) is Array:
		stack.hints.restore_taught(env[KEY_HINTS])
	if stack.objectives != null and env.get(KEY_OBJECTIVES) is Array:
		stack.objectives.restore_done(env[KEY_OBJECTIVES])
