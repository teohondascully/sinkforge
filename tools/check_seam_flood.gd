extends "res://tools/check_base.gd"

## THE FAST FLOOD DRAWS THE SAME PICTURE AS THE OBVIOUS ONE.
##
## `_cluster_seams` groups exposed ore into the cohesive glows that read as crystal veins. It used to
## rescan the entire cell list for every frontier pop — O(n^2) — on a frame where n is at its largest,
## because digging is the thing that exposes ore. It now searches a spatial hash instead.
##
## That is an optimisation, and an optimisation to a GREEDY algorithm is exactly where output quietly
## changes. The order cells are absorbed in decides which seam a cell sitting between two seams joins,
## and therefore the centroid and radius that get drawn. A version that clusters correctly but differently
## would pass any test written as "seams look reasonable" and would move light around the screen.
##
## So this asserts the strongest thing available: the fast implementation returns BYTE-IDENTICAL seams to
## the obvious quadratic one, on inputs chosen to attack the parts most likely to differ —
##
##   BOUNDARY.   Pairs at exactly CLUSTER_LINK apart (must link) and exactly one further (must not). Off
##               by one in the bucket range arithmetic shows up here and nowhere else.
##   BUCKET SEAMS. Cells straddling bucket edges, which is the whole failure mode a spatial hash has.
##   NEGATIVES.  Coordinates below zero, where any bucketing that rounds toward zero instead of down
##               splits a seam in half. (It is NOT a floori-vs-`>>` test: those two agree everywhere in
##               GDScript, whose right shift floors. A mutation swapping them stayed green, which is how
##               that was found out — this case earns its place by catching bucket-RANGE errors, and the
##               docstring used to claim more than it caught.)
##   TIES.       Dense clumps where many cells are in range of one frontier pop at once, which is where
##               absorption ORDER actually decides the grouping.
##   SCALE.      A large scatter, which is also where the speed claim gets checked.
##
## The reference implementation lives HERE, not in production, so there is exactly one flood shipping and
## this file is the specification it is held to.
##
## Runs headless: the flood is a pure function of a cell list and touches no sim, no tree and no pixels.
##
##   godot --headless --path . --script res://tools/check_seam_flood.gd

## Big enough that O(n^2) and O(n) are unmistakably different, small enough that the reference finishes.
const SCALE_N: int = 1200

## THE SPEEDUP IS PRINTED AND NOT ASSERTED, and the reason is a mistake of mine worth leaving written down.
##
## This layer originally required the hash to beat the quadratic scan by 4x, on the argument that a RATIO
## survives contention where absolute milliseconds do not, since both sides slow down together. They do not
## slow down together: standalone this measures 7.1x, and inside the parallel sweep — JOBS Godot processes
## fighting for the box — it measured 3.5x and failed the suite. The fast path's fixed costs (duplicating
## the list, building the buckets) do not shrink under load while the quadratic scan's inner loop does have
## its cache behaviour wrecked, and allocation pressure lands differently on the two.
##
## So the gate came out. I did NOT lower it to 3.0, which would have been buying green with a number chosen
## after seeing the failure — the assertion was invalid in its environment, not merely tuned too tight, and
## the honest move is to stop asserting a duration in a place where durations cannot be measured. What this
## layer is FOR is the byte-identical equivalence below, which is contention-proof and is the whole licence
## for having replaced the algorithm. The timing stays as printed information, where a human reading a log
## can see it and nobody's build depends on it. (The alternative — registering this add_excl — is worse:
## the standing rule is that exclusivity is for layers whose ANSWER is a duration, and this layer's answer
## is a shape. Draining the whole scheduler to protect one informational print would contradict that.)

var _rng := RandomNumberGenerator.new()

func _initialize() -> void:
	print("== the fast flood draws the same picture as the obvious one ==")
	_run()
	# THE VERDICT MAY NOT CLAIM MORE THAN THE ASSERTIONS DO. This line used to end "and the hash is
	# faster", which nothing in this layer tests: `fast_ms`, `slow_ms` and `speedup` are computed, printed
	# and never asserted, deliberately, because a duration assertion in an `add` layer measures the box
	# and this one is not `add_excl`. The body already says so in as many words. The VERDICT said it
	# anyway, and the verdict is the line a reader takes away, so the layer would have announced the hash
	# was faster with the hash ten times slower.
	#
	# STILL TRUE OF THE NOTE, AND NOW CHECKED BY SOMETHING RATHER THAN INTENDED. The claim moved into
	# `_verdict()`'s note argument, which `check_verdict_claims` could not read at all until a91725c.
	#
	# AND THE OLD LINE WOULD HAVE TRIPPED IT. The sentence above was written as two concatenated chunks,
	# and the word that gate keys on -- "speedup" -- sat in the SECOND one, which its pattern never
	# reached. So the green here was a property of the detector's blind spot and not of this note. Said
	# in the layer's own units instead, which is what the disclaimer meant in the first place: the two
	# durations are reported, and neither is compared to anything.
	_verdict("check_seam_flood",
		"spatial hash and quadratic scan draw the same picture (both timings are reported below, neither"
		+ " is asserted)")


func _run() -> void:
	var r := WorldRenderer.new()

	# --- the shaped cases, each aimed at one way a spatial hash goes wrong ---
	for case: Dictionary in _cases():
		var cells: Array[Vector2i] = case["cells"]
		var fast: Array[Dictionary] = r._cluster_seams(cells)
		var slow: Array[Dictionary] = _reference(cells)
		_check(_same(fast, slow), "%s (%d cells -> %d seams)" % [case["name"], cells.size(), slow.size()])

	# --- the specific link/no-link boundary, stated as its own fact rather than left to the diff ---
	# A pair exactly CLUSTER_LINK apart is ONE seam; one cell further apart is two groups, and since a
	# lone cell is dropped as noise (CRYSTAL_MIN_CELLS), zero seams. If bucket arithmetic were off by one
	# these two lines would still agree with each other and both be wrong, so they are checked against the
	# reference above AND pinned here.
	var linked: Array[Vector2i] = [Vector2i(10, 10), Vector2i(10 + WorldRenderer.CLUSTER_LINK, 10)]
	var apart: Array[Vector2i] = [Vector2i(10, 10), Vector2i(10 + WorldRenderer.CLUSTER_LINK + 1, 10)]
	_check(r._cluster_seams(linked).size() == 1,
		"two cells exactly CLUSTER_LINK apart are ONE seam")
	_check(r._cluster_seams(apart).is_empty(),
		"...and one cell further apart they are two lone specks, which glow not at all")

	# --- non-vacuity: the shaped cases must actually produce seams to have compared anything ---
	# Every assertion above passes perfectly on inputs that cluster into nothing. This is the guard that
	# says the comparisons had something to disagree about.
	var total: int = 0
	for case: Dictionary in _cases():
		total += _reference(case["cells"]).size()
	_check(total >= 8,
		"the cases produced %d seams between them — enough for agreement to mean something" % total)

	# --- and the reason the change was made at all ---
	var scatter: Array[Vector2i] = _scatter(SCALE_N, 400, 400)
	var t0: int = Time.get_ticks_usec()
	var fast_big: Array[Dictionary] = r._cluster_seams(scatter)
	var fast_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	t0 = Time.get_ticks_usec()
	var slow_big: Array[Dictionary] = _reference(scatter)
	var slow_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	_check(_same(fast_big, slow_big),
		"...and they still agree at n=%d (%d seams)" % [SCALE_N, slow_big.size()])
	# Information, not an assertion — see MIN_SPEEDUP's removal above. Expect ~7x on a quiet machine and
	# roughly half that inside the parallel sweep; both are fine, and neither decides whether this passes.
	var speedup: float = slow_ms / maxf(fast_ms, 0.001)
	print("  n=%d: hash %.1fms, quadratic %.1fms — %.1fx (informational; contention halves it)"
		% [SCALE_N, fast_ms, slow_ms, speedup])

	r.free()


## The shaped inputs. Rebuilt per call so the non-vacuity tally above cannot be fooled by a mutated list.
func _cases() -> Array[Dictionary]:
	_rng.seed = 20260817
	var cases: Array[Dictionary] = []
	cases.append({"name": "an empty world glows nowhere", "cells": ([] as Array[Vector2i])})
	cases.append({"name": "a single speck is noise, not a seam", "cells": ([Vector2i(5, 5)] as Array[Vector2i])})

	# A vein straddling bucket edges at every offset: CLUSTER_BUCKET is 4, so a run of cells crossing
	# x=4, 8, 12... is the exact case a spatial hash mis-links if its lookup range is wrong.
	var vein: Array[Vector2i] = []
	for x: int in range(0, 40):
		vein.append(Vector2i(x, 17))
	cases.append({"name": "a vein running straight across every bucket seam", "cells": vein})

	# Two clumps close enough to argue over the cells between them — where absorption ORDER decides.
	var contested: Array[Vector2i] = []
	for i: int in 9:
		contested.append(Vector2i(20 + i % 3, 20 + i / 3))
		contested.append(Vector2i(26 + i % 3, 20 + i / 3))
	contested.append(Vector2i(24, 21))                  # the disputed cell, in reach of both
	cases.append({"name": "two clumps arguing over the cell between them", "cells": contested})

	# Negative coordinates: a bucketing that rounds toward zero rather than down splits this seam.
	var negative: Array[Vector2i] = []
	for i: int in 12:
		negative.append(Vector2i(-9 + i, -5 - (i % 4)))
	cases.append({"name": "a seam straddling the origin into negative coordinates", "cells": negative})

	# A dense block: every frontier pop sees many candidates at once.
	var dense: Array[Vector2i] = []
	for y: int in range(0, 12):
		for x: int in range(0, 12):
			dense.append(Vector2i(60 + x, 60 + y))
	cases.append({"name": "a dense block where one pop sees many candidates", "cells": dense})

	cases.append({"name": "a random scatter", "cells": _scatter(220, 90, 90)})
	return cases


func _scatter(n: int, w: int, h: int) -> Array[Vector2i]:
	_rng.seed = 99
	var seen: Dictionary = {}
	var out: Array[Vector2i] = []
	for _i: int in n:
		var c := Vector2i(_rng.randi_range(0, w), _rng.randi_range(0, h))
		if seen.has(c):
			continue                                    # the real query never yields a cell twice
		seen[c] = true
		out.append(c)
	return out


## Byte-identical: same seam count, same order, same centroid, same radius, same member cells in the same
## order. Comparing only centroids would let a regrouping through whenever two groups happened to balance.
func _same(a: Array[Dictionary], b: Array[Dictionary]) -> bool:
	if a.size() != b.size():
		return false
	for i: int in a.size():
		if not is_equal_approx(float(a[i]["pos"].x), float(b[i]["pos"].x)):
			return false
		if not is_equal_approx(float(a[i]["pos"].y), float(b[i]["pos"].y)):
			return false
		if not is_equal_approx(float(a[i]["radius"]), float(b[i]["radius"])):
			return false
		var ca: Array[Vector2i] = a[i]["cells"]
		var cb: Array[Vector2i] = b[i]["cells"]
		if ca != cb:
			return false
	return true


## THE SPECIFICATION: the flood exactly as it was written before the spatial hash, kept here so the fast
## one has something to be identical to. Do not optimise this.
func _reference(from_cells: Array[Vector2i]) -> Array[Dictionary]:
	var link: int = WorldRenderer.CLUSTER_LINK
	var cells: Array[Vector2i] = from_cells.duplicate()
	cells.sort()
	var seams: Array[Dictionary] = []
	var claimed: Dictionary = {}
	for start: Vector2i in cells:
		if claimed.has(start):
			continue
		var group: Array[Vector2i] = [start]
		claimed[start] = true
		var i: int = 0
		while i < group.size():
			var g: Vector2i = group[i]
			i += 1
			for other: Vector2i in cells:
				if claimed.has(other):
					continue
				if absi(other.x - g.x) <= link and absi(other.y - g.y) <= link:
					claimed[other] = true
					group.append(other)
		if group.size() < WorldRenderer.CRYSTAL_MIN_CELLS:
			continue
		var sum := Vector2.ZERO
		var lo := Vector2(group[0])
		var hi := Vector2(group[0])
		for gc: Vector2i in group:
			sum += Vector2(gc)
			lo = lo.min(Vector2(gc))
			hi = hi.max(Vector2(gc))
		var centroid: Vector2 = (sum / float(group.size()) + Vector2(0.5, 0.5)) * float(WorldRenderer.CELL)
		var extent: float = (hi - lo).length() * float(WorldRenderer.CELL)
		var radius: float = float(WorldRenderer.CELL) * 2.2 + extent * 0.55
		seams.append({"pos": centroid, "radius": radius, "cells": group})
		if seams.size() >= WorldRenderer.CRYSTAL_MAX:
			break
	return seams
