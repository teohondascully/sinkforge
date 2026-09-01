class_name CrumblePainter
extends RefCounted

## ROCK SHATTERING WHEN IT BREAKS. Ported from `legacy/scenes/world_renderer.gd:2471-2502`
## (`note_mined`, `_draw_crumble`) — the other half of `docs/LEGACY_GAP.md` T1 #5, held back at D0275
## because it needs a clock and there was none until D0277.
##
## Four chunks per broken cell, thrown outward on a gravity arc, shrinking and fading over
## `CRUMBLE_DUR`, with a brief warm break-flash at the instant of impact.
##
## **IT KEEPS STATE, WHICH NO OTHER PAINTER HERE DOES, and that is inherent rather than a shortcut.** A
## crumble outlives the tick that caused it: the break is one event, the animation is fifteen frames. So
## this is an instance with a list, and `paint` is a bound method rather than a `static` Callable —
## `PaintLayer.bind_to` takes a `Callable`, so a bound method drops straight in.
##
## **IT SPAWNS FROM THE FRAME RATHER THAN BEING POKED.** Legacy has `MainView` call `note_mined()`. Here
## `obs.mining_broke_cells` already arrives through the L2 door (D0274), so the painter reads what broke
## instead of needing a second path that could disagree with the first. The guard that makes this safe is
## `_last_tick`: Godot redraws a canvas for reasons the coordinator did not initiate — a resize, a focus
## change, a window regaining focus — and without it every such redraw would re-spawn the same debris.
## Spawning is gated on the observation's TICK advancing, not on the draw happening.
##
## **AGE IS DERIVED, NOT ACCUMULATED.** Legacy stores a mutable `age` and adds `delta` to it every frame.
## This stores the spawn TIME and subtracts, so there is no per-frame ageing pass to forget to call, a
## redraw cannot advance the animation, and the whole thing stays a pure function of
## `(spawned list, anim_time)`. That last property is what makes it assertable at all.
##
## **SIZES ARE FRACTIONS OF THE CELL, never legacy's pixels.** Legacy's `t * 5.0` spread and `t * t *
## 11.0` fall were written against a 32px cell; copied literally onto a 4px cell they would throw debris
## eight cells clear of the hole it came from. Divided out, they are 0.156 and 0.344 of a cell — carried
## as those fractions, so this file is correct at either denomination and survives whatever
## `docs/LEGACY_GAP.md` WG-4 is ruled to be. Same approach as `view/visuals/crack_painter.gd`.

const DUR: float = 0.24          ## legacy CRUMBLE_DUR, in seconds
const MAX_ALIVE: int = 48        ## legacy CRUMBLE_MAX: a rapid dig drops the oldest rather than growing without bound

## Legacy's pixel offsets over its own 32px cell, kept as the fractions they were.
const SPREAD_PER_CELL: float = 5.0 / 32.0     ## outward throw at full age
const FALL_PER_CELL: float = 11.0 / 32.0      ## gravity drop, applied as t squared
const CHUNK_MIN_SCALE: float = 0.14           ## a chunk shrinks toward this, not to nothing
const CHUNK_SHRINK: float = 0.86

## The break flash: a quick warm burst inset from the cell's edges, so it reads as a POP rather than as
## the tile lighting up. Legacy's `0.16 + t` inset and its 0.28-of-duration window.
const FLASH_UNTIL: float = 0.28
const FLASH_INSET_BASE: float = 0.16
const FLASH_COLOR: Color = Color(1.0, 0.92, 0.72, 1.0)
const FLASH_ALPHA_GAIN: float = 1.1

const RIM: Color = Color(0.03, 0.03, 0.05, 1.0)   ## dark rim, for definition against the hole behind it
const RIM_ALPHA: float = 0.5

var _alive: Array[Dictionary] = []
var _last_tick: int = -1


## How far through its life a crumble spawned at `spawned_at` is, in 0..1. Public because it is the one
## number every visual property is a function of, and asserting it directly is cheaper and clearer than
## inferring it from a rect.
static func progress(spawned_at: float, now: float) -> float:
	return clampf((now - spawned_at) / DUR, 0.0, 1.0)


## Notes what broke this tick. Idempotent per tick BY DESIGN — see the `_last_tick` note in the header.
## Returns true when it actually spawned, so a test can tell "nothing broke" from "the guard suppressed
## it", which are the same picture and very different bugs.
func note_frame(frame: Frame) -> bool:
	if frame == null or frame.obs == null or frame.look == null:
		return false
	if frame.obs.tick == _last_tick:
		return false
	_last_tick = frame.obs.tick
	var cells: Array[Vector2i] = frame.obs.mining_broke_cells
	if cells.is_empty():
		return false
	for cell: Vector2i in cells:
		_alive.append({
			"cell": cell,
			"colour": frame.look.cell_color(frame.obs.mining_broke_material, cell.x, cell.y),
			"at": frame.anim_time,
		})
	# Oldest first, so a rapid dig drops the debris nobody is looking at any more rather than refusing to
	# spawn the one the player just caused.
	while _alive.size() > MAX_ALIVE:
		_alive.pop_front()
	return true


## Drops everything already finished. Called from `paint` rather than from a tick, so a scene that stops
## rendering does not accumulate; there is nothing to accumulate while nothing draws.
func _retire(now: float) -> void:
	var keep: Array[Dictionary] = []
	for c: Dictionary in _alive:
		if progress(float(c["at"]), now) < 1.0:
			keep.append(c)
	_alive = keep


func alive_count() -> int:
	return _alive.size()


## SPAWN AND RETIRE, WITHOUT DRAWING. Split out of `paint` because Godot refuses `draw_rect` outside a
## node's own `_draw()` — so a lifecycle test that went through `paint` would have to mount a real scene,
## and the masked-crash detector rightly failed the first version of that test with
## "Drawing is only allowed inside this node's `_draw()`".
##
## It is also the better split on its own terms, and the same one `view/hud/depth_chip.gd` makes: the
## lifecycle is the part that can be WRONG (spawning per redraw, never retiring, dropping the newest),
## while the drawing below is a transcription of numbers this function already settled.
func advance(frame: Frame) -> void:
	note_frame(frame)
	if frame != null:
		_retire(frame.anim_time)


func paint(frame: Frame, ci: CanvasItem) -> void:
	if frame == null or frame.obs == null or frame.obs.cell_px <= 0:
		return
	advance(frame)
	var now: float = frame.anim_time
	var cell_px: float = float(frame.obs.cell_px)
	var half: float = cell_px * 0.5
	for c: Dictionary in _alive:
		var pos: Vector2 = Vector2(c["cell"] as Vector2i) * cell_px
		var t: float = progress(float(c["at"]), now)
		if t < FLASH_UNTIL:
			var inset: float = cell_px * (FLASH_INSET_BASE + t)
			ci.draw_rect(Rect2(pos + Vector2(inset, inset), Vector2(cell_px - inset * 2.0, cell_px - inset * 2.0)),
				Color(FLASH_COLOR.r, FLASH_COLOR.g, FLASH_COLOR.b, (FLASH_UNTIL - t) * FLASH_ALPHA_GAIN))
		var col: Color = c["colour"]
		for qx: int in 2:
			for qy: int in 2:
				var centre: Vector2 = pos + Vector2((float(qx) + 0.5) * half, (float(qy) + 0.5) * half)
				var outward: Vector2 = Vector2(float(qx) - 0.5, float(qy) - 0.5).normalized()
				var off: Vector2 = outward * (t * SPREAD_PER_CELL * cell_px) \
					+ Vector2(0.0, t * t * FALL_PER_CELL * cell_px)
				var size: float = half * ((1.0 - t) * CHUNK_SHRINK + CHUNK_MIN_SCALE)
				var r := Rect2(centre + off - Vector2(size, size) * 0.5, Vector2(size, size))
				ci.draw_rect(r, Color(col.r, col.g, col.b, 1.0 - t))
				ci.draw_rect(r, Color(RIM.r, RIM.g, RIM.b, (1.0 - t) * RIM_ALPHA), false, 1.0)
