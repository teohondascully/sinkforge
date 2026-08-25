extends "res://tools/check_base.gd"

## Harness layer: SETTINGS persistence + remap. Headless, no scene — the Settings
## class is pure statics over ConfigFile/InputMap/AudioServer, so the whole contract checks in
## milliseconds: values round-trip through the file, a rebind actually redirects the InputMap action
## (the thing every verb reads), reset restores the defaults, and the harness-isolation gate holds
## (persist=false never writes). Runs on its OWN temp file — the dev's real settings.cfg is never
## touched.
##   godot --headless --path . --script res://tools/check_settings.gd

const TEST_PATH: String = "user://settings_check.cfg"

func _key_event(code: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	return ev


func _initialize() -> void:
	DirAccess.remove_absolute(TEST_PATH)
	Controls.register()

	# --- THE SHIPPED DEFAULT ---
	# The only assertion in this file about what a PLAYER gets rather than how the mechanism works, and it
	# has to come first, before any line below sets a level for its own purposes. A clean profile — no
	# settings.cfg, nothing chosen — must boot AUDIBLE.
	#
	# It is pinned because the opposite shipped and the entire suite never saw it: every other audio check
	# here assigns `muted` before observing it, so the default was the one audio fact nothing in the project
	# actually read. A test that sets the value it is about cannot report on the value that ships.
	_check(not Settings.muted, "a first boot, with no settings file, starts with SOUND ON")

	Settings.path = TEST_PATH

	# --- the harness-isolation gate: persist OFF (the default) never writes a file ---
	Settings.master = 0.25
	Settings.save_settings()
	_check(not FileAccess.file_exists(TEST_PATH), "persist=false writes nothing (fixture isolation)")

	# --- defaults bind as registered: Q drives DROP, J does not ---
	Settings.persist = true
	_check(InputMap.event_is_action(_key_event(KEY_Q), Controls.DROP), "default: Q -> drop")
	_check(not InputMap.event_is_action(_key_event(KEY_J), Controls.DROP), "default: J is unbound")
	_check(Settings.binding_label(Controls.JUMP) == "SPACE", "binding label reads SPACE for jump")
	_check(Settings.binding_label(Controls.MINE) == "LMB", "binding label reads LMB for mine")

	# --- rebind redirects the ACTION (what every verb/agent reads) and persists ---
	Settings.rebind(Controls.DROP, {"key": KEY_J})
	_check(InputMap.event_is_action(_key_event(KEY_J), Controls.DROP), "rebind: J now fires drop")
	_check(not InputMap.event_is_action(_key_event(KEY_Q), Controls.DROP), "rebind: Q no longer fires drop")
	_check(FileAccess.file_exists(TEST_PATH), "rebind persisted to the config file")

	# --- values + overrides round-trip through the file ---
	Settings.master = 0.5
	Settings.sound = 0.75
	Settings.screen_shake = false
	Settings.zoom_idx = 2
	Settings.save_settings()
	Settings.master = 1.0
	Settings.sound = 1.0
	Settings.screen_shake = true
	Settings.zoom_idx = 0
	Settings.bindings = {}
	Settings.apply_bindings()
	Settings._apply_action(Controls.DROP, Controls.defaults()[Controls.DROP])  # wipe the live rebind too
	Settings.load_settings()
	_check(is_equal_approx(Settings.master, 0.5) and is_equal_approx(Settings.sound, 0.75),
		"audio levels round-trip (master=%.2f sound=%.2f)" % [Settings.master, Settings.sound])
	_check(Settings.screen_shake == false, "screen-shake toggle round-trips")
	_check(Settings.zoom_idx == 2, "zoom index round-trips")
	_check(InputMap.event_is_action(_key_event(KEY_J), Controls.DROP),
		"binding override survives a reload (J -> drop after load)")

	# --- the mute is a switch over the mix rather than a level pinned to zero ---
	_check(bool(Controls.defaults()[Controls.MUTE].size()) and not Settings.bindings.has(Controls.MUTE),
		"mute has a default key, so it is reachable before anyone opens the settings page")
	Settings.muted = true
	Settings.apply_audio()
	_check(AudioServer.is_bus_mute(0), "muted: the Master bus is silenced")
	var kept: float = Settings.master
	_check(Settings.toggle_mute() == false and not AudioServer.is_bus_mute(0),
		"…one toggle turns it back on")
	_check(is_equal_approx(Settings.master, kept),
		"…and the levels are exactly where they were — unmuting gives back the mix, not a zeroed one")
	Settings.toggle_mute()
	Settings.muted = false
	Settings.load_settings()
	_check(Settings.muted, "mute round-trips through the config file like every other preference")
	Settings.muted = false

	# --- the master slider drives the Master bus ---
	Settings.apply_audio()
	_check(absf(AudioServer.get_bus_volume_db(0) - linear_to_db(0.5)) < 0.01,
		"master 50%% lands on the Master bus (%.1f dB)" % AudioServer.get_bus_volume_db(0))
	_check(Settings.sound_db() < -2.0 and Settings.sound_db() > -3.0,
		"sound 75%% offsets ~-2.5 dB (%.2f)" % Settings.sound_db())

	# --- reset restores every default and persists the clean slate ---
	Settings.reset_bindings()
	_check(InputMap.event_is_action(_key_event(KEY_Q), Controls.DROP)
		and not InputMap.event_is_action(_key_event(KEY_J), Controls.DROP),
		"reset: Q -> drop again, J unbound")
	Settings.load_settings()
	_check(Settings.bindings.is_empty(), "reset persisted (no overrides after reload)")

	# restore pristine statics for any later in-process user (and drop the temp file)
	DirAccess.remove_absolute(TEST_PATH)
	Settings.persist = false
	Settings.path = "user://settings.cfg"
	Settings.muted = true
	Settings.master = 1.0
	Settings.sound = 1.0
	Settings.ambience = 1.0
	Settings.screen_shake = true
	Settings.zoom_idx = 0
	Settings.apply_audio()

	_verdict("check_settings")
