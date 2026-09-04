class_name GramMap
extends RefCounted

## THE GRAMMAR MAP: one byte per terrain cell -- 0 clastic, 1 bedded, 2 massive (`RockTone`'s enum), 0 for
## air -- on the same world rect as the terrain bake, so `rock_tooth.gdshader` samples it with the bake's
## own UV and stretches its hash cell per material. A' step 6p (D0379); `docs/PORT_ORDER.md` V3 named the
## need: "this build has no equivalent yet."
##
## An `Image` the bake fills chunk by chunk as it paints (`TerrainBake._paint_chunk`) and refills on the
## same dig path, uploaded to one `ImageTexture` updated in place -- so the tooth's uniform keeps pointing
## at the same texture across every rebake. Not a SubViewport: the data changes only when the terrain does,
## and a byte per cell is exact where a rendered target would be a blended read.

const MAX_SIDE: int = 16384

var _img: Image = null
var _tex: ImageTexture = null
var _size: Vector2i = Vector2i.ZERO
var _dirty: bool = false


## Allocates the map for a world of `world_cells`; false when the world is too large for one image.
func setup(world_cells: Vector2i) -> bool:
	if world_cells.x <= 0 or world_cells.y <= 0 or world_cells.x > MAX_SIDE or world_cells.y > MAX_SIDE:
		return false
	_size = world_cells
	_img = Image.create_empty(world_cells.x, world_cells.y, false, Image.FORMAT_R8)
	_tex = null
	_dirty = true
	return true


func size() -> Vector2i:
	return _size


## Writes the grammar of every cell of `cells` (a rect in terrain cells) from the observation: the
## material's grammar for a solid cell, 0 for air, 0 outside the observation's window.
func fill_rect(obs: Interface.Observation, cells: Rect2i, look: MaterialLook) -> void:
	if _img == null or obs == null or look == null:
		return
	var r: Rect2i = cells.intersection(Rect2i(Vector2i.ZERO, _size))
	for row: int in range(r.position.y, r.end.y):
		for col: int in range(r.position.x, r.end.x):
			var material: StringName = obs.material_at(Vector2i(col, row))
			var g: int = look.grammar_of(material) if material != &"" else 0
			_img.set_pixel(col, row, Color8(g, 0, 0))
	_dirty = true


## The grammar written at one cell, for a test to read the map's OWN output.
func grammar_at(cell: Vector2i) -> int:
	if _img == null or cell.x < 0 or cell.y < 0 or cell.x >= _size.x or cell.y >= _size.y:
		return -1
	return _img.get_pixel(cell.x, cell.y).r8


## The texture, created once and updated in place when the image has changed since the last call.
func texture() -> ImageTexture:
	if _img == null:
		return null
	if _tex == null:
		_tex = ImageTexture.create_from_image(_img)
		_dirty = false
	elif _dirty:
		_tex.update(_img)
		_dirty = false
	return _tex
