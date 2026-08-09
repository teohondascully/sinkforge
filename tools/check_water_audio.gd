extends SceneTree

## HEADLESS WIRING CHECK — the L3 water/pump audio (representation-only). Proves, WITHOUT an audio device
## (the harness runs on the Dummy driver), that: the two new synthesized beds exist as real loopable
## AudioStreamWAVs; Sfx.set_water is a callable driver that raises the pour/pump levels when fed activity
## and lets them decay to silence; and the whole path is headless-safe (Sfx._muted swallows playback, so no
## voice is left alive to trip the ObjectDB leak warning at quit). It validates the WIRING, not the sound.

func _init() -> void:
	var fails: int = 0
	var sfx: Sfx = Sfx.new()
	root.add_child(sfx)
	# In a SceneTree `_init` the tree isn't live yet, so _ready() on a just-added child is deferred; drive
	# it explicitly so the beds are synthesized before we assert (in the real scene _ready fires normally).
	sfx._ready()

	# 1. Headless guard is engaged (the harness must never open an audio device).
	if not sfx._muted:
		push_error("check_water_audio: expected _muted under the headless driver")
		fails += 1

	# 2. The two new bed players exist and carry a valid, LOOPING stream (so a near-water/pumping level
	#    actually has something to fade in). A missing generator or loop_mode would break the feature.
	for pair: Array in [["_pour_player", sfx._pour_player], ["_pump_player", sfx._pump_player]]:
		var who: String = pair[0]
		var pl: AudioStreamPlayer = pair[1]
		if pl == null:
			push_error("check_water_audio: %s is null (bed not created)" % who)
			fails += 1
			continue
		var w: AudioStreamWAV = pl.stream
		if w == null or w.data.size() < 1000:
			push_error("check_water_audio: %s has no synthesized data" % who)
			fails += 1
		elif w.loop_mode != AudioStreamWAV.LOOP_FORWARD:
			push_error("check_water_audio: %s bed is not looping" % who)
			fails += 1

	# 3. set_water DRIVES the levels: full activity swells both toward audible; then zero activity fades
	#    both back toward silence. This is the exact trigger MainView._update_juice calls each frame.
	sfx._pour_level = 0.0
	sfx._pump_level = 0.0
	for _i: int in 40:
		sfx.set_water(1.0, 1.0, 0.05)                  # ~2s of "lots of water pouring + a pump draining"
	if sfx._pour_level < 0.8 or sfx._pump_level < 0.8:
		push_error("check_water_audio: levels did not swell under activity (pour=%f pump=%f)"
			% [sfx._pour_level, sfx._pump_level])
		fails += 1
	# The louder level must map to a louder (higher dB) bed than silence would — proves the gain wiring.
	if sfx._pour_player.volume_db <= -55.0 or sfx._pump_player.volume_db <= -55.0:
		push_error("check_water_audio: driven beds did not raise volume")
		fails += 1
	for _i: int in 60:
		sfx.set_water(0.0, 0.0, 0.05)                  # nothing near → fade to silence
	if sfx._pour_level > 0.05 or sfx._pump_level > 0.05:
		push_error("check_water_audio: levels did not decay to silence (pour=%f pump=%f)"
			% [sfx._pour_level, sfx._pump_level])
		fails += 1

	sfx.free()                                          # teardown must be clean (no live voice at quit)

	if fails == 0:
		print("check_water_audio: PASS — pour + pump beds synthesized, set_water drives + decays, headless-safe")
		quit(0)
	else:
		print("check_water_audio: FAIL (%d)" % fails)
		quit(1)
