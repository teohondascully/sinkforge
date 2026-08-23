extends SceneTree

## HEADLESS WIRING CHECK — the L3 water/pump audio (representation-only). Proves, WITHOUT an audio device
## (the harness runs on the Dummy driver), that: the two new synthesized beds exist as real loopable
## AudioStreamWAVs; Sfx.set_water is a callable driver that raises the pour/pump levels when fed activity
## and lets them decay to silence; and the whole path is headless-safe (Sfx._muted swallows playback, so no
## voice is left alive to trip the ObjectDB leak warning at quit). It validates the WIRING, not the sound.

## HOW MANY CLAIMS THIS LAYER MADE, so `tools/assert_floors.sh` can hold it to them. It counted only its
## failures, and zero failures is what both a layer that checked four things and a layer that checked
## nothing report. `_claim` tallies the attempt and returns the result so a caller that must stop can.
var asserted: int = 0
var fails: int = 0


func _claim(ok: bool, msg: String) -> bool:
	asserted += 1
	if not ok:
		push_error(msg)
		fails += 1
	return ok


func _init() -> void:
	var sfx: Sfx = Sfx.new()
	root.add_child(sfx)
	# In a SceneTree `_init` the tree isn't live yet, so _ready() on a just-added child is deferred; drive
	# it explicitly so the beds are synthesized before we assert (in the real scene _ready fires normally).
	sfx._ready()

	# 1. Headless guard is engaged (the harness must never open an audio device).
	_claim(sfx._muted, "check_water_audio: expected _muted under the headless driver")

	# 2. The two new bed players exist and carry a valid, LOOPING stream (so a near-water/pumping level
	#    actually has something to fade in). A missing generator or loop_mode would break the feature.
	for pair: Array in [["_pour_player", sfx._pour_player], ["_pump_player", sfx._pump_player]]:
		var who: String = pair[0]
		var pl: AudioStreamPlayer = pair[1]
		if not _claim(pl != null, "check_water_audio: %s is null (bed not created)" % who):
			continue
		var w: AudioStreamWAV = pl.stream
		if _claim(w != null and w.data.size() >= 1000,
				"check_water_audio: %s has no synthesized data" % who):
			_claim(w.loop_mode == AudioStreamWAV.LOOP_FORWARD,
				"check_water_audio: %s bed is not looping" % who)

	# 3. set_water DRIVES the levels: full activity swells both toward audible; then zero activity fades
	#    both back toward silence. This is the exact trigger MainView._update_juice calls each frame.
	sfx._pour_level = 0.0
	sfx._pump_level = 0.0
	for _i: int in 40:
		sfx.set_water(1.0, 1.0, 0.05)                  # ~2s of "lots of water pouring + a pump draining"
	_claim(sfx._pour_level >= 0.8 and sfx._pump_level >= 0.8,
		"check_water_audio: levels did not swell under activity (pour=%f pump=%f)"
			% [sfx._pour_level, sfx._pump_level])
	# The louder level must map to a louder (higher dB) bed than silence would — proves the gain wiring.
	_claim(sfx._pour_player.volume_db > -55.0 and sfx._pump_player.volume_db > -55.0,
		"check_water_audio: driven beds did not raise volume")
	for _i: int in 60:
		sfx.set_water(0.0, 0.0, 0.05)                  # nothing near → fade to silence
	_claim(sfx._pour_level <= 0.05 and sfx._pump_level <= 0.05,
		"check_water_audio: levels did not decay to silence (pour=%f pump=%f)"
			% [sfx._pour_level, sfx._pump_level])

	sfx.free()                                          # teardown must be clean (no live voice at quit)

	if fails == 0:
		print("check_water_audio: PASS (%d asserted) — pour + pump beds synthesized, set_water drives + "
			% asserted + "decays, headless-safe")
		quit(0)
	else:
		print("check_water_audio: %d FAILURE(S) of %d asserted" % [fails, asserted])
		quit(1)
