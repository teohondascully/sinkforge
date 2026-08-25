extends SceneTree

## HOW MUCH ORE SITS AT THE EDGES OF THE MAP AGAINST HOW MUCH SITS AT SPAWN, ACROSS A SEED CORPUS.
##
## A RULER, NOT A CHECK LAYER. It asserts nothing, it is not registered in `tools/run_harness.sh`, and it
## extends `SceneTree` rather than `tools/check_base.gd` for that reason. Everything here is a number to be
## read by a person deciding what the assertion in `tests/test_worldgen.gd` should have been.
##
##   godot --headless --path . --script res://tools/frontier_corpus.gd
##
## WHY IT EXISTS. `_test_horizontal_ore_pull` fails at 1.13x against an inline 1.15 literal, and the
## question of whether that is a world-design defect cannot be answered by the assertion itself, for four
## reasons this ruler is shaped to expose:
##
##   IT IS A TOTAL, NOT A DENSITY. Two 16-column windows have the same nominal area, but rifts and
##   sinkholes both carve rock away and both have keepouts that EXCLUDE the spawn window
##   (RIFT_SPAWN_KEEPOUT covers cols 38-58, SINKHOLE_KEEPOUT covers 28-67). Carved cells hold no ore, so
##   the numerator loses rock the denominator keeps. `rockcells` below is what makes that visible.
##
##   BASE-LAYER ORE IS WEIGHTED 1 INSTEAD OF 250. `HeightmapWorldGen.generate` writes ore cells with no
##   `amounts` entry, and the documented contract is that an absent entry reads as
##   `FactorySim.DEFAULT_ORE_DEPOSIT`. The assertion passes 1 to `.get`, so roughly 76 cells worth ~19,000
##   in-game units score as ~76. `noamt` counts them and `mass250` prices them the way the game does.
##
##   THREE ORE PASSES NEVER SEE THE HORIZONTAL FIELD. `_seed_droughts`, `_mineralize` and the base vein
##   pass are all field-blind, and the drought pass is a designed NEGATIVE FEEDBACK on exactly the quantity
##   being measured: it plants a make-up vein wherever a column runs quiet, which happens more often in a
##   lean column than a rich one. A statistic that pools all passes together cannot separate "the pull
##   stopped working" from "the field-blind passes grew".
##
##   ONE SEED. The assertion hardcodes 20260807, which is not the shipping seed (1337), and the horizontal
##   noise has a feature size of about 22 columns against a 16-column window — so a window sits inside one
##   lobe and its noise term never averages out. Per-seed spread is structurally large and nobody has ever
##   looked at it.
##
## `h` is what the field ASKS for; `density` is what the world DELIVERS per unit of rock. Reading them
## against each other is the point: a field that is intact but swamped looks completely different from a
## field that no longer reaches the rock, and the failing total cannot tell them apart.

const SEEDS: Array[int] = [1337, 0, 1, 7, 42, 99999, 20260807, 314159, 2, 123456789, 555, 88888]

## Absolute rows, matching the assertion under investigation so the numbers are comparable to it. Note
## this is one of the things the assertion gets wrong: the generator's richness runs off depth below each
## column's OWN surface, and the three windows do not share a surface row.
const BAND_TOP: int = 30

const ORES: Array[StringName] = [&"ore", &"rich_ore", &"coal"]

## `mid` is the in-frame control. It sits at an intermediate ramp value, so if the horizontal field is the
## thing driving the result it must land BETWEEN spawn and right. A control that travels inside the same
## measurement is worth more than a second run of the same thing.
const WINDOWS: Array[Array] = [["spawn", 40, 56], ["left", 0, 16], ["right", 112, 128], ["mid", 24, 40]]


func _initialize() -> void:
	var gen := LayeredWorldGen.new()
	var cols: int = FactorySim.GRID_COLS
	var rows: int = FactorySim.GRID_ROWS
	var bot: int = mini(LayeredWorldGen.SEAL_TOP, rows)
	print("== frontier vs spawn ore, %d seeds, rows %d-%d ==" % [SEEDS.size(), BAND_TOP, bot - 1])
	print("seed,window,h,mass,mass250,orecells,rockcells,noamt,density")
	var mass_ratio: Array[float] = []
	var dens_ratio: Array[float] = []
	var h_ratio: Array[float] = []
	var m250_ratio: Array[float] = []
	for s: int in SEEDS:
		var w: WorldData = gen.generate(cols, rows, s)
		var hf: PackedFloat32Array = gen._horizontal_field(cols, s)
		var by_name: Dictionary = {}
		for spec: Array in WINDOWS:
			var d: Dictionary = _window(w, hf, int(spec[1]), int(spec[2]), bot)
			by_name[spec[0]] = d
			print("%d,%s,%.4f,%d,%d,%d,%d,%d,%.3f" % [s, spec[0], d["h"], d["mass"], d["mass250"],
				d["orecells"], d["rockcells"], d["noamt"], d["density"]])
		# The assertion's own quantity: max of the two edge windows over spawn, on the mass it counts.
		var sp: Dictionary = by_name["spawn"]
		var fr: Dictionary = by_name["left"] if int(by_name["left"]["mass"]) \
			> int(by_name["right"]["mass"]) else by_name["right"]
		mass_ratio.append(float(fr["mass"]) / float(maxi(1, int(sp["mass"]))))
		m250_ratio.append(float(fr["mass250"]) / float(maxi(1, int(sp["mass250"]))))
		dens_ratio.append(float(fr["density"]) / maxf(0.001, float(sp["density"])))
		h_ratio.append(float(fr["h"]) / maxf(0.001, float(sp["h"])))
	print("")
	print("== the assertion's statistic across the corpus (its floor is 1.15) ==")
	_summarise("mass ratio   (what the test scores)", mass_ratio)
	_summarise("mass250      (what the game pays) ", m250_ratio)
	_summarise("density      (per unit of rock)   ", dens_ratio)
	_summarise("h ratio      (what the field asks)", h_ratio)
	quit(0)


## One window's tally. `rockcells` is the denominator the assertion never divides by; `noamt` is the count
## of ore cells the base pass left without an `amounts` entry, which the assertion prices at 1 each.
func _window(w: WorldData, hf: PackedFloat32Array, lo: int, hi: int, bot: int) -> Dictionary:
	var mass: int = 0
	var mass250: int = 0
	var orecells: int = 0
	var rockcells: int = 0
	var noamt: int = 0
	var h: float = 0.0
	for x: int in range(lo, hi):
		h += hf[x]
		for y: int in range(BAND_TOP, bot):
			var c := Vector2i(x, y)
			if not w.blocks.has(c):
				continue                        # carved away: counts against the rock denominator
			rockcells += 1
			if not (w.blocks[c] in ORES):
				continue
			orecells += 1
			mass += int(w.amounts.get(c, 1))
			mass250 += int(w.amounts.get(c, FactorySim.DEFAULT_ORE_DEPOSIT))
			if not w.amounts.has(c):
				noamt += 1
	return {"h": h / float(hi - lo), "mass": mass, "mass250": mass250, "orecells": orecells,
		"rockcells": rockcells, "noamt": noamt,
		"density": float(mass) / float(maxi(1, rockcells))}


## Mean AND median, plus the range. A mean alone hides a bimodal corpus, and a single reading of a
## quantity with a known spread is not a result.
func _summarise(label: String, a: Array[float]) -> void:
	if a.is_empty():
		print("  %s  no data" % label)
		return
	var s: Array[float] = a.duplicate()
	s.sort()
	var total: float = 0.0
	for v: float in s:
		total += v
	var over: int = 0
	for v: float in s:
		if v >= 1.15:
			over += 1
	print("  %s  mean %.3f  median %.3f  min %.3f  max %.3f  clearing 1.15: %d/%d"
		% [label, total / float(s.size()), s[s.size() / 2], s[0], s[s.size() - 1], over, s.size()])
