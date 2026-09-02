class_name VeilFieldCache
extends RefCounted

## THE OPENNESS FIELD, HELD BETWEEN FRAMES. Split out of `view/visuals/veil_painter.gd` (D0340) when that
## file reached 403 lines against `docs/QUALITY.md` §2's 400 cap — a seam, not a trim, for the reason that
## section records: `sim/body/body.gd` sat at exactly 400 for three commits running.
##
## **RE-BAKING EVERY FRAME IS NOT AFFORDABLE, AND LEGACY SAYS SO IN ITS SIGNATURE.** `_bake_openness` takes
## `dug_from`/`dug_to` and returns the band it actually refreshed: it keeps the field and re-bakes only the
## columns whose solidity changed. Ported without that, this measured **3.63 ms per bake on a 68x46 window
## — 21.8% of a 16.67 ms frame** — for a field that is usually identical to last frame's.
##
## The field is a pure function of (window rect, solidity inside it), so the cache is keyed on exactly
## those two: the rect, and `hash(materials)`, which is one native pass over the plane against two blur
## passes plus a fill. A miss costs what it always cost; a hit costs the hash.
##
## Keyed on the MATERIALS HASH rather than on a dug-cell count or a tick number, because those answer a
## different question. A count is equal across a dig that removed one cell and added another, and a tick
## number re-bakes on every tick whether or not anything moved — the first is wrong and the second is the
## thing being fixed.
##
## **A CHEAPER KEY EXISTS AND IS NOT USED HERE YET.** D0340 gave `TileGrid` a `terrain_version` token and
## `Interface.observe` keys its own plane cache on it, which is O(1) where this hash is O(window). Routing
## it onto the `Observation` and keying this on it too is the obvious follow-up; it is not done in the same
## change that moved the file, because a cache whose key changes and a cache that moves files are two
## claims and doing both at once verifies neither.

var _field: PackedFloat32Array = PackedFloat32Array()
var _rect: Rect2i = Rect2i()
var _hash: int = 0
var _valid: bool = false


## The field for this observation's window, from the cache when nothing that feeds it has changed.
## `build` is called as `build.call(obs, rect) -> PackedFloat32Array` on a miss.
func field_for(obs: Interface.Observation, build: Callable) -> PackedFloat32Array:
	var h: int = hash(obs.materials)
	if _valid and _rect == obs.window and _hash == h:
		return _field
	_field = build.call(obs, obs.window)
	_rect = obs.window
	_hash = h
	_valid = true
	return _field
