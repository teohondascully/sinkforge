extends SceneTree

## THE WALK — the body moves the way you asked it to, everywhere on the real generated surface.
##
## Born as a bug hunt for "walking and I get teleported back ~1 foot": every frame where the body moves
## BACKWARD against its own input is a snap, and a snap is logged with its surroundings so the cause is
## visible rather than guessed at. That part is unchanged and is still the headline property.
##
## WHY IT NO LONGER WALKS THE WORLD IN ONE LINE. The original drove one continuous traverse — stand at the
## far west, hold right until the far east, turn round, come back — and it never once finished. The body
## ran off the western hills, fell nine rows, and spent the remaining 3,500 frames at the foot of a bluff
## it cannot climb, jumping into the wall. It reached column 28 of 128 and the layer exited 0, because the
## only failure path was "a snap happened" and a body pinned against rock cannot snap. Its own report
## string said so out loud — "OR the body never got far" — and printed it every single run.
##
## The premise was the defect, not the body. This world HAS bluffs; `check_relief` asserts they exist,
## because a landscape you can walk end-to-end without ever meeting an obstacle is not a landscape. So a
## single traverse was never going to complete, and no amount of raising the frame budget would have fixed
## it. What the snap hunt actually wants is a lot of DIFFERENT surface under the feet, which is a sampling
## problem, not a journey.
##
## So: place the body on the surface at regular columns across the whole world, walk each one for a fixed
## burst, and accumulate. Every column band gets exercised — western hills, the flat plateau and its
## fixtures, the eastern hills — no bluff can end the run early, and the layer now covers 100% of the
## world's width instead of 22% of it.
##
## Run: godot --headless --path . --script res://tools/check_walk.gd

const SCENE: String = "res://scenes/main.tscn"
## A backward jump over this many px against input is a real teleport. Sub-pixel collision jitter runs
## ~2.5px/frame and is fine; a teleport is a tile or more.
const BACK_EPS: float = 4.0
const FIRST_COL: int = 3
const LAST_COL: int = 124
const COL_STEP: int = 6                ## 21 sample bands across a 128-wide world
const SETTLE_FRAMES: int = 6           ## let the body land and stop bouncing before the burst is judged
const WALK_FRAMES: int = 90            ## 1.5s of held input — ideal ground is 150px/s * 1.5s = 225px

var _main: MainView
var _player: Player
var _sim: FactorySim
var _frames: int = 0
var _fails: int = 0

var _cols: Array[int] = []
var _at: int = -1                      ## index into _cols; -1 until the world is up
var _phase_frame: int = 0
var _seg_start_x: float = 0.0
var _prev_x: float = 0.0

var _snaps: int = 0
var _worst: float = 0.0
var _worst_ctx: String = ""
var _total_px: float = 0.0
var _moved_bands: int = 0
var _walked_bands: int = 0


func _initialize() -> void:
	Engine.max_fps = 60
	_main = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(_main)
	print("== the walk ==")
	physics_frame.connect(_phys)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  PASS: %s" % label)
	else:
		_fails += 1
		printerr("  FAIL: %s" % label)


func _phys() -> void:
	_frames += 1
	if _frames < 30:
		return
	if _at < 0:
		_boot()
		return
	if _at >= _cols.size():
		_report()
		return
	_phase_frame += 1
	if _phase_frame <= SETTLE_FRAMES:
		_player.input_dir = 0.0
		_prev_x = _player.position.x
		_seg_start_x = _player.position.x
		return
	_player.input_dir = 1.0
	var dx: float = _player.position.x - _prev_x
	# A SNAP is moving opposite to held input by more than BACK_EPS — not merely decelerating into a wall,
	# which reads as dx≈0. This is the property the layer exists for and it is judged on every walked frame.
	if dx < -BACK_EPS:
		_snaps += 1
		var mag: float = absf(dx)
		if mag > _worst:
			_worst = mag
			_worst_ctx = _context()
		if mag > 6.0:
			printerr("  SNAP %.1fpx :: %s" % [mag, _context()])
	_prev_x = _player.position.x
	if _phase_frame >= SETTLE_FRAMES + WALK_FRAMES:
		var gained: float = _player.position.x - _seg_start_x
		_total_px += maxf(gained, 0.0)
		_walked_bands += 1
		if gained >= 32.0:
			_moved_bands += 1
		_next_band()


## Stand the body on the surface at the next sample column. Placed rather than walked to, on purpose: the
## point is to sample every band, and walking there is exactly what a bluff can prevent.
func _next_band() -> void:
	_at += 1
	_phase_frame = 0
	if _at >= _cols.size():
		return
	var col: int = _cols[_at]
	var row: int = _sim.surface_row(col)
	_player.position = _main._cell_center(Vector2i(col, row - 1))
	_player.velocity = Vector2.ZERO
	_prev_x = _player.position.x
	_seg_start_x = _player.position.x


func _boot() -> void:
	_player = _main._player
	_sim = _main.sim
	_player.auto_input = false
	# A MACHINE IN THE PATH. Machines are not in the slope authority, so the body cannot glide over a
	# one-tile machine the way it glides over a one-tile terrain step — it meets the box head-on. That was
	# the prime suspect for "walking and snapped back", so one is planted on the flat plateau's clear left
	# lane and a sample band is aimed straight at it.
	var proc: MachineDef = load("res://src/data/machines/processor.tres")
	var mcol: int = HeightmapWorldGen.FLAT_START + 4
	var pc := Vector2i(mcol, _sim.surface_row(mcol) - 1)
	_sim.place_machine(proc, pc)
	for col: int in range(FIRST_COL, LAST_COL + 1, COL_STEP):
		_cols.append(col)
	# …and a band that starts four columns short of the machine, so the burst walks into it rather than
	# past it. Without this the sampling grid would only meet the box by luck.
	_cols.append(mcol - 4)
	_cols.sort()
	print("  test machine at %s; %d sample bands from col %d to %d"
		% [pc, _cols.size(), _cols[0], _cols[_cols.size() - 1]])
	_next_band()


## What is around the body at the moment of a snap — the diagnostic payload that made this layer worth
## having in the first place.
func _context() -> String:
	var c: Vector2i = _main._cell_at(_player.position)
	var ahead: Vector2i = c + Vector2i(1, 0)
	var head_ahead: Vector2i = ahead + Vector2i(0, -1)
	return ("x=%.1f cell=%s on_floor=%s | ahead solid=%s machine=%s | head-ahead solid=%s machine=%s | surf(here=%d ahead=%d) ramp(here=%d ahead=%d)"
		% [_player.position.x, c, _player.on_floor,
		_sim.is_solid(ahead), _sim.machine_at(ahead) != null,
		_sim.is_solid(head_ahead), _sim.machine_at(head_ahead) != null,
		_sim.surface_row(c.x), _sim.surface_row(ahead.x), _sim.ramp_dir(c.x), _sim.ramp_dir(ahead.x)])


func _report() -> void:
	physics_frame.disconnect(_phys)
	var bands: int = _cols.size()
	var ideal: float = float(bands) * float(WALK_FRAMES) / 60.0 * Player.RUN_SPEED
	print("  walked %d bands · %.0fpx of an unobstructed %.0fpx (%.0f%%) · %d bands cleared a full cell"
		% [_walked_bands, _total_px, ideal, 100.0 * _total_px / ideal, _moved_bands])

	# NON-VACUITY FIRST, because the defect this rewrite fixes was precisely a layer that reported green on
	# a body that never moved. "No snaps" is trivially true of a body pinned against rock.
	_check(_walked_bands == bands, "every sample band was actually walked (%d of %d)" % [_walked_bands, bands])
	# HOW MANY BANDS MUST GO SOMEWHERE. Not all of them can, and that is the landscape working: a band that
	# lands at the foot of a bluff is legitimate, and `check_relief` asserts those bluffs exist on purpose.
	# Measured dead stable across three runs at seed 1337: 22 bands walked, 4204px of an unobstructed
	# 4950px (85%), 20 bands clearing a full cell. The floor is 18 and 55% — enough room for terrain to
	# move without a false red, and its job is to catch a body that has stopped moving, not name a target.
	_check(_moved_bands >= 18, "at least 18 bands cleared a full cell of ground (%d)" % _moved_bands)
	# …and the aggregate, which catches the other shape of the same failure: a body that creeps everywhere
	# rather than stopping dead in one place.
	_check(_total_px >= ideal * 0.55,
		"the body covered %.0f%% of unobstructed ground across the world (floor 55%%)"
			% [100.0 * _total_px / ideal])

	# THE HEADLINE PROPERTY, judged on a sample now proven real.
	if _snaps == 0:
		_check(true, "no backward snap over %.0fpx anywhere on the surface" % BACK_EPS)
	else:
		_check(false, "REPRODUCED: %d backward-snap frames, worst %.1fpx" % [_snaps, _worst])
		printerr("  context: %s" % _worst_ctx)

	if _fails == 0:
		print("WALK OK")
		quit(0)
	else:
		printerr("%d WALK FAILURE(S)" % _fails)
		quit(1)
