class_name RockNeighborhood
extends RefCounted

## One immutable shading neighborhood per painted region. Two column sweeps share nearest-air
## distances; AO reads adjacent bytes. The halo preserves Observation's out-of-window-is-air rule.
## Codes: bits 0..3 = twice AO, 4..6 = air distance above, 7..9 = below. Distance 7 means beyond reach.
var _span: Rect2i
var _solid: PackedByteArray
var _above: PackedByteArray
var _below: PackedByteArray
var _full_solid: bool = false


func _init(obs: Interface.Observation, cells: Rect2i) -> void:
	_span = cells.grow(RockTone.FORM_REACH)
	_solid = BakeData.solid_bytes(obs, _span)
	_full_solid = _solid.count(0) == 0
	if _full_solid:
		return
	_above.resize(_solid.size())
	_below.resize(_solid.size())
	_scan(_above, false)
	_scan(_below, true)


func _scan(out: PackedByteArray, reverse: bool) -> void:
	var w: int = _span.size.x
	var h: int = _span.size.y
	for x: int in w:
		var distance: int = 7
		for row: int in h:
			var y: int = h - row - 1 if reverse else row
			var offset: int = y * w + x
			out[offset] = distance
			distance = 1 if _solid[offset] == 0 else mini(distance + 1, 7)


## Only queried within the painted region, never the halo. No world reads or function-valued probes.
func at(col: int, row: int) -> int:
	if _full_solid:
		return (7 << 4) | (7 << 7)
	var w: int = _span.size.x
	var i: int = (row - _span.position.y) * w + col - _span.position.x
	var ao: int = 2 * (int(_solid[i - 1] == 0) + int(_solid[i + 1] == 0)
		+ int(_solid[i - w] == 0) + int(_solid[i + w] == 0))
	ao += int(_solid[i - w - 1] == 0) + int(_solid[i - w + 1] == 0)
	ao += int(_solid[i + w - 1] == 0) + int(_solid[i + w + 1] == 0)
	return ao | (int(_above[i]) << 4) | (int(_below[i]) << 7)
