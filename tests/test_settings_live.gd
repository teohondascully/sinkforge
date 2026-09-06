extends "res://tests/test_base.gd"

## EVERY SETTING HAS A CONSUMER (D0410, the new-player review's rank 2: "settings look more finished than
## their behaviour"). `tests/test_settings_page.gd` proves the page stores what it is told and
## `tests/test_main_boot.gd` that the bridge writes the fields; both would stay green if every consumer were
## deleted, and until this round four of them did not exist. This suite asserts the CONSUMER moved: the
## zoom the camera reads, the three audio layers' injected levels, the score being in the tree at all, the
## shake the rig applies and decays, and the large map deafening the hands the way the settings page does.


func _initialize() -> void:
	_test_the_audio_levels_reach_their_layers_and_the_score_is_mounted()
	_test_the_shake_is_asked_for_kicked_and_decayed()
	await _test_zoom_and_the_map_modal_reach_the_seat()
	_finish("settings_live")


func _test_the_audio_levels_reach_their_layers_and_the_score_is_mounted() -> void:
	var audio: SceneAudio = SceneAudio.new()
	root.add_child(audio)
	audio.setup(7)
	_check(audio.score != null and audio.score.get_parent() == audio and audio.sfx.get_parent() == audio, "the score is a node of the rig, mounted beside the effects and the beds")
	audio.set_levels(-6.0, -12.0, -18.0)
	_check(audio.sfx.sound_db == -6.0 and audio.beds.ambience_db == -12.0 and audio.score.music_db == -18.0,
		"the three sliders land on the three layers' injected levels (%.0f / %.0f / %.0f dB)" % [audio.sfx.sound_db, audio.beds.ambience_db, audio.score.music_db])
	_check(is_equal_approx(Settings.sound_db(), linear_to_db(clampf(Settings.sound, 0.001, 1.0))), "and the shell's level is the dB the layer adds")
	var o: Interface.Observation = Interface.Observation.new()
	o.map_cells = Vector2i(64, 276)
	o.cell = Vector2i(0, Interface.Observation.SKY_ROWS + 128 * MaterialLook.CELLS_PER_METRE)
	_check(is_equal_approx(SceneAudio.depth_fraction(o), 0.5), "the score's one input: 128 m down a 256 m world is 0.5 (%.3f)" % SceneAudio.depth_fraction(o))
	o.cell.y = Interface.Observation.SKY_ROWS - 40
	_check(SceneAudio.depth_fraction(o) == 0.0, "...and the sky clamps to 0")
	audio.queue_free()


func _test_the_shake_is_asked_for_kicked_and_decayed() -> void:
	var fx: SeatEffects = SeatEffects.new()
	var particles: Particles = Particles.new()
	var look: MaterialLook = MaterialLook.new()
	var falling: FallingItems = FallingItems.new()
	var frame: Frame = Frame.new()
	var o: Interface.Observation = Interface.Observation.new()
	o.cell_px = 4
	o.on_floor = false
	o.vel_y = 500 * Fx.SCALE
	frame.obs = o
	fx.tick(frame, particles, look, falling, Rect2(), 1.0 / 60.0, true)   # falling: arms the landing edge
	o.on_floor = true
	o.vel_y = 0
	fx.tick(frame, particles, look, falling, Rect2(), 1.0 / 60.0, true)
	_check(fx.shake_px > 0.0 and fx.shake_px <= SeatEffects.SHAKE_LAND_PX, "a hard landing asks for a shake (%.2f px)" % fx.shake_px)
	var off: SeatEffects = SeatEffects.new()
	o.on_floor = false
	o.vel_y = 500 * Fx.SCALE
	off.tick(frame, particles, look, falling, Rect2(), 1.0 / 60.0, false)
	o.on_floor = true
	o.vel_y = 0
	off.tick(frame, particles, look, falling, Rect2(), 1.0 / 60.0, false)
	_check(off.shake_px == 0.0, "control: with the FEEL toggle off the same landing asks for none")
	var rig: CameraRig = CameraRig.new()
	var still: Vector2 = rig.step(Vector2(100, 100), Vector2.ZERO, 2.0, 1280.0, 1.0 / 60.0)
	rig.kick(2.0)
	var shaken: Vector2 = rig.step(Vector2(100, 100), Vector2.ZERO, 2.0, 1280.0, 1.0 / 60.0)
	_check(shaken.distance_to(still) <= 2.0 * sqrt(2.0) + 0.001, "the kicked rig offsets the camera by at most the kick (%.2f px)" % shaken.distance_to(still))
	var settled: Vector2 = Vector2.ZERO
	for _i: int in 30:
		settled = rig.step(Vector2(100, 100), Vector2.ZERO, 2.0, 1280.0, 1.0 / 60.0)
	_check(settled == still and rig.shake_offset() == Vector2.ZERO, "and half a second later the shake has decayed to exactly nothing")


## The seat itself, headless: a zoom cycle on the FEEL page changes the zoom the rig reads on the next tick,
## and the large map deafens the hands the way the settings page does -- a held RIGHT moves the body with
## the map closed and not with it open.
func _test_zoom_and_the_map_modal_reach_the_seat() -> void:
	var main: Main = Main.new()
	main.autoboot = false
	root.add_child(main)
	await process_frame
	if not main.boot(false):
		_check(false, "the seat boots headless")
		return
	var before: float = main.zoom
	var page: SettingsPage = main.stack.settings
	main._game_verb(HudBridge.apply({"cycle": "zoom"}, page, -1.0))
	_check(main.zoom != before and main.zoom == CameraRig.ZOOM_LEVELS[Settings.zoom_idx], "a zoom cycle reaches the seat's zoom at once: %.2f -> %.2f" % [before, main.zoom])
	for _i: int in CameraRig.ZOOM_LEVELS.size() - 1:
		main._game_verb(HudBridge.apply({"cycle": "zoom"}, page, -1.0))
	_check(main.zoom == before, "...and cycling round restores it")
	var body: Body = main.door.services()["body"]
	var x0: int = body.pos_x
	Input.action_press(Controls.RIGHT)
	for _t: int in 6:
		main._physics_process(1.0 / 60.0)
	var walked: int = body.pos_x - x0
	main.stack.minimap.large = true
	for _coast: int in 30:   # the body coasts to a stop once the hand goes deaf
		main._physics_process(1.0 / 60.0)
	var x1: int = body.pos_x
	for _t2: int in 10:
		main._physics_process(1.0 / 60.0)
	var under_map: int = body.pos_x - x1
	Input.action_release(Controls.RIGHT)
	main.stack.minimap.large = false
	_check(walked > 0, "control: with the map closed a held RIGHT walks the body (%d Fx in 6 ticks)" % walked)
	_check(under_map == 0, "with the large map open the same held RIGHT moves nothing once the body has stopped: the map is a modal (%d Fx in 10 ticks)" % under_map)
	main.queue_free()
	await process_frame
