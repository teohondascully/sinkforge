class_name Command
extends RefCounted

## The typed command vocabulary -- `docs/ARCHITECTURE.md` §5's `apply(Command) -> Result` parameter, and
## the only way anything outside `sim/` mutates the sim. A VALUE, not behaviour: this file holds a tag
## and a payload and nothing else, because `sim/commands/MODULE.md` states the rule outright ("Commands
## are typed values (structs/enums with payloads), not behavior. Validation and application happen in
## `interface` and in each target submodule, not here"). If a method here ever needs a `TileGrid`, it has
## stopped being a command.
##
## SMALL ON PURPOSE: §5 says the vocabulary "is small enough to read in one sitting". Two verbs until A'
## step 4b (D0357) lifted legacy's situated verbs (`sim/run/verbs.gd`) and named each here: a member
## arrives with its verb, never before it, and `sim/commands/MODULE.md`'s gotcha records why (the Freight
## Winch once regrew as ad hoc verbs on the pre-pivot entry point). The mine-hold loop is NOT a member:
## it rides `MOVE`'s `InputFrame`, whose `aim_col`/`aim_row`/`mine_held` already record it per tick.
##
## `MOVE` carries a whole `InputFrame` rather than decomposing it into per-key commands. That is §5's
## "raw" action level, stated there as a first-class member of the vocabulary rather than a legacy path:
## "the same input frame a human produces... when `interface` lands, this driver becomes `observe`/
## `apply`'s raw path rather than being discarded." One command per keypress would be a second,
## incompatible input format, which §5 names as the thing not to build.

enum Kind {
	MOVE,        ## one tick of raw input -- payload `input` (the aim and the mine hold ride here)
	MINE,        ## excavate one cell directly -- payload `cell`, a terrain cell
	BUILD,       ## RMB at a metre: pick up what is there, else place what is selected -- payload `cell`
	DROP,        ## Q: drop the selected stack (into an eater, forward, or down)
	COLLECT,     ## scoop the piles within reach
	CONFIGURE,   ## R at a metre -- payload `cell`
	LINK_WINCH,  ## L at a metre: arm a head, then commit to a station -- payload `cell`
	SELECT,      ## the hotbar index -- payload `index`
	CLEAR_PLAN,  ## forget every dig mark
}

var kind: Kind
var input: InputFrame = null   ## MOVE only
var cell: Vector2i = Vector2i.ZERO  ## MINE: a terrain cell; BUILD/CONFIGURE/LINK_WINCH: a metre (logic) cell
var index: int = 0             ## SELECT only


## Named constructors rather than a public `_init` with optional arguments: a `Command.new()` with every
## payload defaulted is a command with no kind, and there is no valid one. These cannot produce that.
static func move(frame: InputFrame) -> Command:
	return _of(Kind.MOVE, frame, Vector2i.ZERO)


static func mine(target: Vector2i) -> Command:
	return _of(Kind.MINE, null, target)


static func build(logic_cell: Vector2i) -> Command:
	return _of(Kind.BUILD, null, logic_cell)


static func drop() -> Command:
	return _of(Kind.DROP, null, Vector2i.ZERO)


static func collect() -> Command:
	return _of(Kind.COLLECT, null, Vector2i.ZERO)


static func configure(logic_cell: Vector2i) -> Command:
	return _of(Kind.CONFIGURE, null, logic_cell)


static func link_winch(logic_cell: Vector2i) -> Command:
	return _of(Kind.LINK_WINCH, null, logic_cell)


static func select(hotbar_index: int) -> Command:
	var c: Command = _of(Kind.SELECT, null, Vector2i.ZERO)
	c.index = hotbar_index
	return c


static func clear_plan() -> Command:
	return _of(Kind.CLEAR_PLAN, null, Vector2i.ZERO)


## Both constructors funnel through here, which is not ceremony: written out separately they were
## byte-identical after identifier normalisation and `tools/quality_check/duplication.py` (D0099, a
## BLOCKING gate) reported them as a cluster of 2 -- correctly. Two constructors that differ only in
## which payload field they set ARE one constructor with an argument.
static func _of(k: Kind, frame: InputFrame, target: Vector2i) -> Command:
	var c: Command = Command.new()
	c.kind = k
	c.input = frame
	c.cell = target
	return c


## Reads as its own rejection reason in a log line, which is where these end up: `Result` carries the
## reason string and `docs/ARCHITECTURE.md` §5 makes rejection reasons part of the telemetry.
func _to_string() -> String:
	match kind:
		Kind.MOVE:
			return "Move(dir=%d jump=%s mantle=%s dig=%s)" % [
				input.move_dir, input.jump_pressed, input.mantle_hold, input.dig_pressed]
		Kind.MINE:
			return "Mine(%d,%d)" % [cell.x, cell.y]
		Kind.SELECT:
			return "Select(%d)" % index
	return "%s(%d,%d)" % [Kind.keys()[kind].capitalize(), cell.x, cell.y]
