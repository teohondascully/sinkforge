class_name Settings
extends RefCounted

## Machine-local player preferences: audio levels, screen shake, zoom and the key bindings. All static,
## so any caller can read them without wiring, and persisted to a ConfigFile in `user://`. Kept out of a
## save deliberately. A save is a world; settings belong to this machine and person, so they survive new
## games and never travel with a save.
##
## Representation only, no sim state. Audio applies as dB offsets the audio layer adds at play time,
## shake gates one camera line, zoom is a camera index, bindings rebind InputMap actions. `persist` is
## false by default and only an interactive boot turns it on and loads the file, so a scripted run works
## from pure defaults and can never read or clobber the real settings file.
##
## Lifted from `legacy/scenes/settings.gd` (`docs/DECISIONS_LEDGER.md` D0227). **SPLIT IN TWO ON THE WAY
## OVER**, which is the one structural change: the original is 455 lines against this project's 400-line
## blocking gate, so the binding half -- rebinding, load-time collision reconciliation and keycap
## labelling -- moved to `shell/settings_bindings.gd`. The seam is the file's own: everything here is
## state, persistence and audio, and nothing here reads an InputEvent. Splitting was preferred to
## parking the lift, and to raising a size gate for one file.
##
## `music_db()` below is the real source for `view/audio/score.gd`'s injected `music_db`, which D0215
## left as a plain `0.0` because this file had not been ported yet. **Wiring the two together is a shell
## job and `shell/` has no boot yet, so they are still not connected** -- the value exists, nothing calls
## for it.

## Sound ships on: roughly half of what this game tells the player it tells by ear, and a player who never
## opens the settings page would otherwise never learn the audio is there. Mute stays one switch over the
## whole mix rather than levels pinned to zero (see `apply_audio`) and is persisted, so turning it off is
## equally a one-time act. Scripted boots silence themselves in `main.gd::_ready()`, where they also
## decline to persist, so this default describes what a new player hears.
static var muted: bool = false
static var master: float = 1.0          ## 0..1, the Master bus (everything)
static var sound: float = 1.0           ## 0..1, effect voices: the positional pool and UI dings
static var ambience: float = 1.0        ## 0..1, the beds: hum, wind, cave-air, drips
static var music: float = 1.0           ## 0..1, the Score
static var screen_shake: bool = true
static var auto_pickup: bool = true    ## walk-over auto-collect of ground items
static var zoom_idx: int = 0            ## index into MainView.ZOOM_LEVELS
## action name -> Array of event specs ({"key": physical keycode} | {"button": mouse button index}),
## the same spec shape as Controls.defaults(). Only actions that diverge live here; absent means the
## action is still on its default binding.
static var bindings: Dictionary = {}

static var persist: bool = false                     ## gate: load/save only when a real boot opts in
static var path: String = "user://settings.cfg"      ## overridable so a test can isolate its file


## Load the config, keeping defaults when the file is missing, and apply everything live.
static func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		muted = bool(cfg.get_value("audio", "muted", muted))
		master = clampf(float(cfg.get_value("audio", "master", master)), 0.0, 1.0)
		sound = clampf(float(cfg.get_value("audio", "sound", sound)), 0.0, 1.0)
		ambience = clampf(float(cfg.get_value("audio", "ambience", ambience)), 0.0, 1.0)
		music = clampf(float(cfg.get_value("audio", "music", music)), 0.0, 1.0)
		screen_shake = bool(cfg.get_value("feel", "screen_shake", screen_shake))
		auto_pickup = bool(cfg.get_value("feel", "auto_pickup", auto_pickup))
		zoom_idx = int(cfg.get_value("feel", "zoom_idx", zoom_idx))
		bindings = {}
		for key: String in cfg.get_section_keys("bindings") if cfg.has_section("bindings") else []:
			bindings[StringName(key)] = cfg.get_value("bindings", key)
	apply_audio()
	# Reconciled before it is applied (see `_reconcile_bindings`), so InputMap never holds a duplicate that
	# came in on disk, not even for the two lines between here and there.
	SettingsBindings.reconcile()
	SettingsBindings.apply()


static func save_settings() -> void:
	if not persist:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "muted", muted)
	cfg.set_value("audio", "master", master)
	cfg.set_value("audio", "sound", sound)
	cfg.set_value("audio", "ambience", ambience)
	cfg.set_value("audio", "music", music)
	cfg.set_value("feel", "screen_shake", screen_shake)
	cfg.set_value("feel", "auto_pickup", auto_pickup)
	cfg.set_value("feel", "zoom_idx", zoom_idx)
	for action: StringName in bindings:
		cfg.set_value("bindings", String(action), bindings[action])
	cfg.save(path)


## The Master bus follows the master slider; sound and ambience apply lazily as offsets, below. Mute is
## applied at the bus rather than by zeroing the levels, so it cannot be half-on and the sliders keep the
## values the player chose, which makes unmuting restore them exactly.
static func apply_audio() -> void:
	AudioServer.set_bus_mute(0, muted)
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(master, 0.0001, 1.0)))


## Flip the sound on or off and remember it. Returns the new state, for the on-screen readout.
static func toggle_mute() -> bool:
	muted = not muted
	apply_audio()
	save_settings()
	return muted


## One audio level, by name: the id the settings page draws its rows from (`Hud.AUDIO_ROWS`), resolved
## once here rather than twice at the two call sites that need it.
##
## Named rather than fetched, for the reason `Hud._audio_level` already carried: `Settings` is a class of
## STATIC vars, and a dynamic `get()` against one is a lookup that fails at runtime rather than at parse
## time. What is new is that the match lives in ONE place. It used to be the page's private copy, and the
## keyboard nudge in `MainView` needs the same four names to read a level before it can move it, so the
## alternative was a second copy of the table beside the one that writes them (`MainView._set_volume`),
## which is one rename away from a page that shows `music` while the arrows move `ambience`.
static func level(id: String) -> float:
	match id:
		"master": return master
		"sound": return sound
		"ambience": return ambience
		_: return music


## dB offsets the Sfx layer adds to its own baselines at play/frame time: 0 dB at full, about -60 (gone)
## at the bottom of the slider. Lazy application means no player-node bookkeeping here.
static func sound_db() -> float:
	return linear_to_db(clampf(sound, 0.001, 1.0))


static func ambience_db() -> float:
	return linear_to_db(clampf(ambience, 0.001, 1.0))


static func music_db() -> float:
	return linear_to_db(clampf(music, 0.001, 1.0))
