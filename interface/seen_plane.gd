class_name SeenPlane
extends RefCounted

## WHAT THE PLAYER HAS SEEN, one byte per logic cell (D0400, the director's T015 ruling): the corner map
## marks ore the player has already been near and never ore they have not, so the map rewards memory and
## leaves the reason to explore in place. "Seen" is within `RADIUS_M` of the body on a hub tick -- the
## lamp's reach, near enough: what was lit while you stood there. Marked by `Interface` from the body's
## position over the replay, so it is deterministic and carried by the save (`Session` adds the key),
## and OUTSIDE every signature: it changes nothing the sim decides, only what the map admits to.

const RADIUS_M: int = 8

var width: int
var height: int
var seen: PackedByteArray = PackedByteArray()
var version: int = 0
## The cell indices the LAST `mark` turned, so a consumer holding the previous version can update in place
## rather than rebuild: the minimap rebuilt its whole image on every hub tick while the body walked (D0403:
## 40-55 ms a frame, the round's one perf regression), where the disc turns a few dozen cells at a time.
var recent: PackedInt32Array = PackedInt32Array()


func _init(cells: Vector2i) -> void:
	width = maxi(cells.x, 0)
	height = maxi(cells.y, 0)
	seen.resize(width * height)


func is_seen(logic_cell: Vector2i) -> bool:
	if logic_cell.x < 0 or logic_cell.y < 0 or logic_cell.x >= width or logic_cell.y >= height:
		return false
	return seen[logic_cell.y * width + logic_cell.x] != 0


## Mark the disc of `RADIUS_M` metres about a logic cell. Bumps `version` only when a cell turned.
func mark(logic_cell: Vector2i, radius: int = RADIUS_M) -> void:
	var changed: bool = false
	var r2: int = radius * radius
	var turned: PackedInt32Array = PackedInt32Array()
	for dy: int in range(-radius, radius + 1):
		var y: int = logic_cell.y + dy
		if y < 0 or y >= height:
			continue
		for dx: int in range(-radius, radius + 1):
			var x: int = logic_cell.x + dx
			if x < 0 or x >= width or dx * dx + dy * dy > r2:
				continue
			var i: int = y * width + x
			if seen[i] == 0:
				seen[i] = 1
				turned.append(i)
				changed = true
	if changed:
		version += 1
		recent = turned


func count() -> int:
	return seen.count(1)


## The save's shape: the dimensions and the bytes. `restore` accepts only a plane of its own size.
func capture() -> Dictionary:
	return {"cells": [width, height], "seen": seen}


func restore(d: Dictionary) -> bool:
	var cells: Array = d.get("cells", [])
	if cells.size() != 2 or int(cells[0]) != width or int(cells[1]) != height or not (d.get("seen") is PackedByteArray):
		return false
	var bytes: PackedByteArray = d["seen"]
	if bytes.size() != width * height:
		return false
	seen = bytes.duplicate()
	version += 1
	recent = PackedInt32Array()   # a restore is not a step: consumers rebuild
	return true
