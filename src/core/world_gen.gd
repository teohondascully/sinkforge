class_name WorldGen
extends RefCounted

## THE SWAPPABLE PRODUCER (see docs/WORLDGEN.md). A generator turns a spec (size + seed) into a
## WorldData. Base interface only — concrete generators (HeightmapWorldGen, future cave/biome/
## structure generators) override `generate`. Improving generation = a NEW WorldGen; nothing in the
## sim or the renderer changes, because both speak only WorldData + material ids.
##
## Contract: generation MUST be deterministic in (cols, rows, seed) — same inputs → identical
## WorldData — to fit the sim's determinism ethos. Use a seeded RandomNumberGenerator, never the
## global RNG.

func generate(cols: int, rows: int, seed: int) -> WorldData:
	push_error("WorldGen.generate is abstract — use a concrete generator")
	return null
