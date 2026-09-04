class_name CarryLook
extends RefCounted

## How full the pack READS, 0..1 (A' step 5d, D0361; legacy `player.gd`'s `_carry_load`). There is no
## carry cap in the sim -- mass is counts and slots, not a weight system -- so this saturates on the
## total item count rather than on a fraction of some capacity: a single stack reads as a light load, a
## dozen as a heavy one, and nothing ever reads as "full". Representation only: the lean, the sprite
## frame, a HUD gauge. Never a sim input.

const SATURATION: float = 10.0


static func load(total_items: int) -> float:
	if total_items <= 0:
		return 0.0
	return 1.0 - exp(-float(total_items) / SATURATION)
