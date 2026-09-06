class_name SeatEffects
extends RefCounted

## THE SEAT'S PER-TICK EFFECTS, split from `shell/main.gd` at the file cap (D0410): the particles a tick
## spawns off the observation -- debris and dust on a break (D0403, V31), a chip per blow, the landing's
## dust (V37), the drips -- and now the SHAKE those same moments kick the camera with, when the FEEL page's
## toggle says so. The shake had a row on the settings page and no consumer anywhere (the new-player
## review, rank 2); legacy decayed `_shake` and offset the camera by a random fraction of it, and the
## trigger it was waiting on (`docs/LEGACY_GAP.md` T1 #9) is the landing this file already sees.

const LAND_DUST_SPEED: int = 120   ## px/s of fall below which a landing raises no dust
const SHAKE_BREAK_PX: float = 1.6  ## a broken cell, at world px: a knock, not a quake
const SHAKE_LAND_PX: float = 2.4   ## the hardest landing; scaled down by how hard
const SHAKE_LAND_FULL: int = 420   ## px/s of fall that earns the full landing shake

var _was_on_floor: bool = true
var _fall_speed: int = 0
var shake_px: float = 0.0          ## what this tick asks of the camera; the rig decays it


## One tick: advance the pool, spawn off the observation, hand the frame to the audio.
func tick(frame: Frame, particles: Particles, look: MaterialLook, falling: FallingItems, view_rect: Rect2,
		delta: float, shake_on: bool) -> void:
	shake_px = 0.0
	particles.advance(delta)
	if frame != null and frame.obs != null:
		_mining(frame.obs, particles, look)
		_landing(frame.obs, particles, look, shake_on)
		WaterDrips.spawn(frame.obs, particles, view_rect, delta)
	var landings: Dictionary = falling.take_landings()
	for cell: Vector2i in landings:
		particles.pop(landings[cell]["pos"], landings[cell]["color"])
	if not shake_on:
		shake_px = 0.0


func _mining(o: Interface.Observation, particles: Particles, look: MaterialLook) -> void:
	if o.mining_broke:
		# A break is debris AND a settling puff, not three flecks (D0403, V31): the cell vanished and
		# nothing said so at play zoom. The colour is the broken material's own.
		for cell: Vector2i in o.mining_broke_cells:
			var at: Vector2 = (Vector2(cell) + Vector2(0.5, 0.5)) * float(o.cell_px)
			var col: Color = look.cell_color(o.mining_broke_material, cell.x, cell.y)
			particles.debris(at, col, atan2(float(o.mining_swing_dir.y), float(o.mining_swing_dir.x)) + PI)
			particles.dust(at, col, 5)
		shake_px = maxf(shake_px, SHAKE_BREAK_PX)
	elif o.mining_swing and o.aim_cell != Vector2i(-1, -1) and o.solid_at(o.aim_cell):
		# A blow that did not break the cell still chips it: a fleck per swing off the struck face.
		var struck: Vector2 = (Vector2(o.aim_cell) + Vector2(0.5, 0.5)) * float(o.cell_px)
		particles.chip(struck, look.cell_color(o.material_at(o.aim_cell), o.aim_cell.x, o.aim_cell.y), atan2(float(o.mining_swing_dir.y), float(o.mining_swing_dir.x)) + PI)


## A hard landing raises the floor's dust at the feet (D0403, V37) and knocks the camera in proportion:
## the on-floor edge after a fall.
func _landing(o: Interface.Observation, particles: Particles, look: MaterialLook, shake_on: bool) -> void:
	if o.on_floor and not _was_on_floor and _fall_speed > LAND_DUST_SPEED:
		var feet: Vector2 = Vector2(float(o.left_x + o.right_x) * 0.5, float(o.bottom_y)) / float(Fx.SCALE)
		var ground: Vector2i = Vector2i(floori(feet.x / float(o.cell_px)), floori(feet.y / float(o.cell_px)))
		particles.dust(feet, look.cell_color(o.material_at(ground), ground.x, ground.y), mini(14, 6 + _fall_speed / 40))
		if shake_on:
			shake_px = maxf(shake_px, SHAKE_LAND_PX * clampf(float(_fall_speed) / float(SHAKE_LAND_FULL), 0.0, 1.0))
	_was_on_floor = o.on_floor
	_fall_speed = o.vel_y / Fx.SCALE if not o.on_floor else 0
