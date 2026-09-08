class_name Result
extends RefCounted

## `apply()`'s answer. `reason` is empty exactly when `ok` is true, and `docs/ARCHITECTURE.md` §5 makes
## it telemetry rather than a debugging aid: "a command is submitted, validated, and either applied or
## rejected with a reason. Rejection reasons are part of the telemetry." So the reasons are a closed
## vocabulary of `StringName`s a counter can be keyed on, not free prose.
##
## SPLIT OUT OF `interface/interface.gd` (D0513) when that file stood at its 400-line cap and the drop's
## refusal needed room, as `Envelope` was at D0294: a seam, not a trim. It is still reached as
## `Interface.Result` through a `const` in that file, so no call site moved. It carries a `class_name`
## for the reason `Envelope` does -- the factories below name their own return type, and a script with
## no global name cannot. `Interface.Result` remains the name to use.

var ok: bool
var reason: StringName
## What an accepted verb did (`machine`, `picked_up`, `armed`, `dropped`, ...); on a refusal, the word a
## HUD reads (`short`: a drop with its eater in sight but out of reach, D0513). Empty otherwise.
var detail: StringName = &""


static func accepted() -> Result:
	var r: Result = Result.new()
	r.ok = true
	r.reason = &""
	return r


static func rejected(why: StringName) -> Result:
	var r: Result = Result.new()
	r.ok = false
	r.reason = why
	return r
