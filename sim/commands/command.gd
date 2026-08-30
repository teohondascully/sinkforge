class_name Command
extends RefCounted

## The typed command vocabulary -- `docs/ARCHITECTURE.md` §5's `apply(Command) -> Result` parameter, and
## the only way anything outside `sim/` mutates the sim. A VALUE, not behaviour: this file holds a tag
## and a payload and nothing else, because `sim/commands/MODULE.md` states the rule outright ("Commands
## are typed values (structs/enums with payloads), not behavior. Validation and application happen in
## `interface` and in each target submodule, not here"). If a method here ever needs a `TileGrid`, it has
## stopped being a command.
##
## SMALL ON PURPOSE, and small because the game is small, not because this is a sketch. §5 says the
## vocabulary "is small enough to read in one sitting"; there are two verbs in this build -- move the body
## and mine a cell -- so there are two members. A third arrives with a third verb, not before. The
## alternative, writing the vocabulary the GDD eventually needs, would put `Place`, `Haul` and `Craft`
## here as unreachable tags that no submodule matches and no test can exercise, and
## `sim/commands/MODULE.md`'s own gotcha exists because that has already happened once in this project's
## history (the Freight Winch regrowing as ad hoc verbs on the pre-pivot entry point).
##
## `MOVE` carries a whole `InputFrame` rather than decomposing it into per-key commands. That is §5's
## "raw" action level, stated there as a first-class member of the vocabulary rather than a legacy path:
## "the same input frame a human produces... when `interface` lands, this driver becomes `observe`/
## `apply`'s raw path rather than being discarded." One command per keypress would be a second,
## incompatible input format, which §5 names as the thing not to build.

enum Kind {
	MOVE,  ## one tick of raw input -- payload `input`
	MINE,  ## excavate one cell -- payload `cell`
}

var kind: Kind
var input: InputFrame = null   ## MOVE only
var cell: Vector2i = Vector2i.ZERO  ## MINE only, terrain-cell coordinates


## Named constructors rather than a public `_init` with optional arguments: a `Command.new()` with every
## payload defaulted is a command with no kind, and there is no valid one. These cannot produce that.
static func move(frame: InputFrame) -> Command:
	var c: Command = Command.new()
	c.kind = Kind.MOVE
	c.input = frame
	return c


static func mine(target: Vector2i) -> Command:
	var c: Command = Command.new()
	c.kind = Kind.MINE
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
	return "Command(unknown kind %d)" % kind
