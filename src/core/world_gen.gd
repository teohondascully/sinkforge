class_name WorldGen
extends RefCounted

## Abstract generator interface: (cols, rows, seed) -> WorldData. Concrete generators override
## `generate`. The sim and the renderer consume only WorldData plus material ids.
##
## Contract: `generate` must be deterministic in (cols, rows, seed). Use a seeded
## RandomNumberGenerator, never the global RNG.

func generate(cols: int, rows: int, seed: int) -> WorldData:
	push_error("WorldGen.generate is abstract — use a concrete generator")
	return null
