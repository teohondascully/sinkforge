extends "res://tools/check_base.gd"

## RECOVERY PRIORITY #6 (docs/PRIORITY.md): "a genuine post-Forge desire... not go deeper because the
## layer is there." The tutorial chain already ends at the Seal with real, working mechanics -- research
## DESCENT, feed a Descent Engine, breach -- but both places the player actually meets that wall said
## nothing about what is on the other side: `hover_info.gd`'s Seal description was pure mechanism, and
## `objectives.gd`'s final "breach" step handed off with "then explore on your own." A wall a player is
## told only how to open, never why, reads as an obstacle rather than a destination.
##
## Investigation found the actual content already exists and is substantial: `research_rules.gd`'s
## "ironworks" tech (requires DESCENT, sample IRON) unlocks the Iron Forge, which gates plate/gear/borer
## tech in turn -- a whole tier already built, already visible (dimmed) in the Bazaar Bench's tech tree,
## just never named at the one place the player actually stands in front of the reason to go get it. This
## layer holds two now-named facts in place, both string content only: no mechanic changed.
##
## Run: godot --headless --path . --script res://tools/check_seal_desire.gd

const HoverInfo := preload("res://scenes/hover_info.gd")

func _initialize() -> void:
	print("== the seal names its destination ==")
	_seal_hover_names_the_destination()
	_breach_step_names_the_destination()
	_verdict("check_seal_desire")


func _seal_hover_names_the_destination() -> void:
	var sim := FactorySim.new()
	var aim := Vector2i(10, 10)
	sim.set_solid(aim, &"sealrock")
	var info: Dictionary = HoverInfo.describe(sim, aim, true, 1.0)
	_check(info.get("name", "") == "The Seal", "fixture: HoverInfo.describe reads a sealrock cell as The Seal")
	var mode: String = str(info.get("mode", ""))
	_check(mode.contains("DESCENT") and mode.contains("Engine"),
		"…the mechanism line still says how to breach it, unchanged")
	var rate: String = str(info.get("rate", ""))
	_check(rate != "", "…and a second line now exists at all")
	_check(rate.contains("Stonereach") and rate.contains("iron"),
		"…naming the destination (Stonereach) and the payoff (iron), not just the obstacle")


func _breach_step_names_the_destination() -> void:
	var sim := FactorySim.new()
	var obj := Objectives.new(sim)
	var breach: Dictionary = {}
	for step: Dictionary in obj.steps:
		if step["id"] == &"breach":
			breach = step
			break
	_check(not breach.is_empty(), "fixture: the 'breach' step exists in the chain")
	var label: String = str(breach.get("label", ""))
	_check(label.contains("iron"),
		"the chain's final step names the payoff (iron) rather than just handing off silently")
	_check(label.length() <= 117,
		"…and stays within the label length every other step in this chain already holds to (%d chars)"
			% label.length())
