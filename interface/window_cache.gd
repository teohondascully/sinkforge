class_name WindowCache
extends RefCounted

## THE OBSERVATION'S DERIVED PLANES, REBUILT ONLY WHEN THE TERRAIN OR THE WINDOW CHANGES (D0340).
##
## **THIS IS THE LAST BIG ITEM ON THE 120 Hz PROGRAMME AND THE ONLY ONE LEGACY HAS NO CODE TO PORT FOR.**
## `WorldView.draw_cost_report` measured `Interface.observe` at **6.36 ms of a 15.9 ms tick** against a
## budget of 8.33 — the single largest cost left after D0336-D0338. Legacy never paid it: its renderer
## reads `sim.solid` / `sim.deposits` / `sim.water` DIRECTLY and builds no per-frame copy of anything
## (`legacy/scenes/world_renderer.gd:756`). `Interface.Observation` is a rewrite-only construct, so this
## bill belongs to our own layer separation and the remedy has to be ours too.
##
## It is legacy's PRINCIPLE though, and legacy states it plainly — derived data is refreshed on the event
## that can change it, never on a clock. Its whole renderer is built that way: `_veil_base` rebakes on
## terrain change, `_leaf_cells` on terrain change, `repaint_world()` from exactly one place. This file is
## that rule applied to the observation.
##
## **WHAT MAKES IT SAFE IS THE KEY.** The planes are a pure function of (window, terrain contents), and
## the key holds exactly those two: the window rect, and `TileGrid.terrain_version`, a token bumped by
## `_xor_term` — the one function every terrain mutation passes through, including any mutator added
## later, because a write that skipped it would also corrupt the state signature.
##
## Keyed on a VERSION rather than on `hash(materials)`, which is what `VeilPainter.field_for` does one
## layer up: hashing is O(window) and would reintroduce a per-cell pass to avoid a per-cell pass. A tick
## number would be wrong in the other direction — it changes every frame whether or not anything moved,
## which is the defect being fixed.
##
## **AND WHAT MAKES IT HIT IS THE SNAP.** `Envelope.covering` rounds the window outward to
## `Envelope.SNAP_CELLS`, so it holds still for eight metres of travel instead of shifting every quarter
## metre. Without that this cache would miss almost every frame and still pay for its own key.

## The key. `-1` is a version no `TileGrid` can hold (it starts at 0 and only rises), so a fresh cache
## cannot collide with a real world's first state — the "empty means valid" trap this would otherwise be.
var _window: Rect2i = Rect2i()
var _version: int = -1
## Tracked separately from `_version` because the wall plane is OPTIONAL (D0338): the per-frame path
## declines it and the bake asks for it, so a hit for materials can coexist with a miss for walls.
var _walls_version: int = -1
var _walls_window: Rect2i = Rect2i()

var materials: PackedByteArray = PackedByteArray()
var legend: PackedStringArray = PackedStringArray()
var surface_y: PackedInt32Array = PackedInt32Array()
var walls: PackedByteArray = PackedByteArray()
var wall_legend: PackedStringArray = PackedStringArray()

## Rebuild counters, for a test that must prove the cache actually SKIPS work rather than merely
## returning the right answer. A cache that recomputed every time would satisfy every correctness
## assertion in the suite and none of the reason it exists.
var builds: int = 0
var wall_builds: int = 0


## Refreshes whatever has gone stale and leaves the rest alone. `read_material` and `read_wall` are the
## grid's own getters, passed in rather than reached for, so this file needs no `TileGrid` import and the
## caller keeps deciding what a consumer is allowed to see.
func refresh(window: Rect2i, version: int, want_walls: bool,
		read_material: Callable, read_wall: Callable, surface_of: Callable) -> void:
	if _version != version or _window != window:
		var blocks: Array = WindowPlanes.of(window, read_material)
		materials = blocks[0]
		legend = blocks[1]
		surface_y = surface_of.call(window)
		_window = window
		_version = version
		builds += 1
	# The wall plane has its own key, so declining it on one call and asking for it on the next does not
	# invalidate the materials plane that is still perfectly good.
	if want_walls and (_walls_version != version or _walls_window != window):
		var background: Array = WindowPlanes.of(window, read_wall)
		walls = background[0]
		wall_legend = background[1]
		_walls_window = window
		_walls_version = version
		wall_builds += 1
