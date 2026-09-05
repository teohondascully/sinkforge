class_name Sfx
extends Node2D

## THE VOICE POOL. Ported in shape from `legacy/scenes/sfx.gd`'s player pool and its `play()` call site
## at `legacy/scenes/main.gd:1601-1603`. `docs/LEGACY_GAP.md` T1 #6, Lane G; A' step 6f (ii), D0367.
##
## Legacy's 1,125 lines are now split by what they are: the beds in `bed_bank.gd`/`beds.gd`, the
## one-shots in `voice_bank.gd`, the ring and the strike family in `sfx_bank.gd`, the room in
## `sfx_space.gd`, the cues in `voice_cues.gd`. This file is the POOL and its three properties, verbatim
## from legacy's header: it knows what was hit (`strike_voice`, `step_voice` resolve a verb to the
## material's own voice), it knows where you are (every positional voice runs through the space bus),
## and it does not repeat (often-fired voices draw from a bank of separate renders, never twice
## running). Legacy read the sound slider off a `Settings` global; here it is INJECTED as `sound_db`.
##
## **THE MAPPING FROM READING TO PITCH AND VOLUME IS SPLIT OUT AND STATIC**, for the reason every painter
## in this build splits its decisions out: an `AudioStreamPlayer` cannot be read back, so a test written
## against `play()` can assert that it did not crash and nothing else — and not crashing is exactly what a
## broken early return does while the game stays silent. `voice_for_hollow` returns the numbers.
##
## A `Node2D` rather than a plain `Node`, because `AudioStreamPlayer2D` positions its voices in the world
## and a blow at the far edge of the screen should not be as loud as one under your feet — which is
## legacy's own reason for using the 2D player and passing `center`.

## Legacy plays into a fixed pool and takes the oldest voice when they are all busy, rather than spawning
## a player per event. Eight is enough for a mining cadence at full rhythm (a blow every 10 ticks, a voice
## every 0.26 s) with room for a breach over the top.
const VOICES: int = 8

## `legacy/scenes/main.gd:1602-1603`, unchanged. The pitch falls and the volume rises as the reading
## climbs: a bigger space answers LOWER and LOUDER, which is what a bigger space does.
const PITCH_BASE: float = 1.05
const PITCH_PER_HOLLOW: float = 0.25
const PITCH_MIN: float = 0.7
const PITCH_MAX: float = 1.15
const DB_SOLID: float = -26.0
const DB_HOLLOW: float = -9.0

## The breach is one event rather than a reading, so it plays at a fixed level — the loudest thing the
## mining verb produces, because it is the payoff the crescendo was building to.
## Material -> the strike it makes. `legacy/scenes/sfx.gd:29-35`, re-expressed in this build's own
## material ids: legacy's `earth`/`gravel` are `clay` here, its three ore ids collapse to two plus the
## reveal material, and `deepslate`/`sealrock` are `deepstone`. `hardrock` is deliberately ABSENT -- it is
## the plain fracture, `crunch`, the voice an unmapped material falls back to (6f (ii), D0367).
const STRIKE: Dictionary = {
	&"clay": &"hit_earth",
	&"coal": &"hit_coal",
	&"ore_copper": &"hit_metal", &"ore_iron": &"hit_metal", &"glimmer": &"hit_metal",
	&"deepstone": &"hit_slate",
}

const BREACH_DB: float = -7.0
const BREACH_PITCH: float = 1.0

## What the boot is standing on. Legacy's `GROUND` table named its ids; here the split it encoded is
## read off the DATA: wood is wood, anything as hard as shale is rock, the rest is soil. A footstep on
## dirt and one on rock are the same event over a different surface, so these are shades, not voices.
const WOOD_GROUND: Array[StringName] = [&"wood", &"leaves"]
const ROCK_HARDNESS: float = 1.5
## Separate renders of each frequently triggered voice: pitch jitter alone cannot hide repetition, the
## noise grain is identical every time and the ear locks onto the grain. Four streams, never twice running.
const GRAINS: int = VoiceBank.GRAINS
const POOL_DB: float = -8.0
const UI_DB: float = -10.0

var sound_db: float = 0.0                  ## the shell's sound slider, injected
var space: SfxSpace = SfxSpace.new()       ## the room every positional voice plays into
var _pool: Array[AudioStreamPlayer2D] = []
var _next: int = 0
var _streams: Dictionary = {}
var _bank: Dictionary = {}                 ## voice -> Array[AudioStreamWAV]: its GRAINS alternates
var _bank_last: Dictionary = {}            ## voice -> last grain index, so no draw repeats it
var _ui: AudioStreamPlayer = null
var _rng: SplitRng = null
var _muted: bool = DisplayServer.get_name() == "headless"


## Pitch and volume for one hollow reading, in per mille. STATIC and returning data, so the mapping is
## assertable without an audio device — see the header.
##
## Takes per mille and converts, rather than taking legacy's 0..1 float: everything crossing the L2 door
## is an integer per mille (`Interface.mining_hollow`), and converting at the boundary means the caller
## never holds a float that has to agree with the sim's integer.
static func voice_for_hollow(hollow_per_mille: int, full: int) -> Dictionary:
	var h: float = clampf(float(hollow_per_mille) / float(maxi(1, full)), 0.0, 1.0)
	return {
		"pitch": clampf(PITCH_BASE - h * PITCH_PER_HOLLOW, PITCH_MIN, PITCH_MAX),
		"db": lerpf(DB_SOLID, DB_HOLLOW, h),
	}


## Builds the pool and generates every voice. The seed is explicit so two runs sound identical, which is
## what `tests/test_sfx_bank.gd`'s spectral assertions rest on. Two halves since D0397: `synthesize` is
## pure over the seed and touches no node, so the seat runs it on a worker thread while the first frames
## draw; `attach` takes its result on the main thread. This is the synchronous composition of the two.
func setup(seed_value: int = 20260901) -> void:
	attach(synthesize(seed_value), seed_value)


## Every voice and every grain bank from the seed: {"streams": {voice: AudioStreamWAV}, "bank": {voice:
## Array[AudioStreamWAV]}}. Static and node-free, so it may run off the main thread.
static func synthesize(seed_value: int) -> Dictionary:
	var rng: SplitRng = SplitRng.new(seed_value).split("sfx")
	var streams: Dictionary = {}
	var bank: Dictionary = {}
	streams[&"hollow"] = SfxBank.to_stream(SfxBank.hollow(rng))
	streams[&"breach"] = SfxBank.to_stream(SfxBank.breach(rng))
	# Built from the BANK's own table rather than from `STRIKE`'s values, so the two dictionaries have to
	# agree and a material mapped to a voice that does not exist is a refusal from `play` rather than a
	# silent miss. `tests/test_sfx_driver.gd` asserts the agreement directly.
	for voice: StringName in SfxBank.STRIKES:
		streams[voice] = SfxBank.to_stream(SfxBank.strike(rng, voice))
		_grains(streams, bank, voice, func(r: SplitRng) -> PackedFloat32Array: return SfxBank.strike(r, voice), rng)
	for name: StringName in Ordering.ids(VoiceBank.SECONDS.keys()):
		streams[name] = SfxBank.to_stream(VoiceBank.generate(name, rng.split(String(name))))
	for name: StringName in VoiceBank.GRAINED:
		_grains(streams, bank, name, func(r: SplitRng) -> PackedFloat32Array: return VoiceBank.generate(name, r), rng)
	return {"streams": streams, "bank": bank}


## Take a `synthesize` result and build the players. The grain picker's stream is keyed off the root
## seed (`SplitRng.split` is keyed, not sequential), so it needs nothing from the synthesis's draws.
func attach(voices: Dictionary, seed_value: int) -> void:
	_rng = SplitRng.new(seed_value).split("sfx").split("grains")
	_streams = voices.get("streams", {})
	_bank = voices.get("bank", {})
	if not _muted:
		space.ensure_bus()
	for _i: int in VOICES:
		var player := AudioStreamPlayer2D.new()
		player.max_distance = 1500.0
		if space.has_bus():
			player.bus = SfxSpace.BUS
		add_child(player)
		_pool.append(player)
	# UI dings stay dry on Master: a reverbed interface sound reads as a bug.
	_ui = AudioStreamPlayer.new()
	add_child(_ui)


## True once `attach` has run: before that every `play` is a refusal, which the seat accepts for the
## half-second the synthesis takes off-thread.
func ready() -> bool:
	return not _streams.is_empty()


## Fill a voice's grain bank: `GRAINS` takes of one recipe, each off a fresh stretch of the noise stream.
## The canonical take goes in first, so the render measured offline is also one a player actually hears.
static func _grains(streams: Dictionary, bank: Dictionary, name: StringName, gen: Callable, rng: SplitRng) -> void:
	var takes: Array[AudioStreamWAV] = []
	if streams.has(name):
		takes.append(streams[name])
	while takes.size() < GRAINS:
		takes.append(SfxBank.to_stream(gen.call(rng)))
	bank[name] = takes


## Draw a grain of `voice`, never the same one twice running. Falls back to the canonical stream for
## every voice that does not fire often enough to need a bank.
func _pick(voice: StringName) -> AudioStreamWAV:
	var grains: Array = _bank.get(voice, [])
	if grains.is_empty():
		return _streams.get(voice, null)
	var last: int = int(_bank_last.get(voice, -1))
	var i: int = _rng.next_range(0, grains.size() - 1) if _rng != null else 0
	if i == last:
		i = (i + 1) % grains.size()
	_bank_last[voice] = i
	return grains[i]


## How many grains `voice` can draw from: 1 for a canonical-only voice.
func grain_count(voice: StringName) -> int:
	return maxi(1, (_bank.get(voice, []) as Array).size())


## Stop every voice on teardown and step off the space bus BEFORE it is removed, never after.
func _exit_tree() -> void:
	for p: AudioStreamPlayer2D in _pool:
		p.stop()
		p.stream = null
		p.bus = &"Master"
	if _ui != null:
		_ui.stop()
		_ui.stream = null
	space.release()


## Plays one voice at a world position. Round-robin over the pool: the oldest voice is the one taken,
## which is legacy's policy and the right one — refusing to play once the pool is full would drop exactly
## the blows landing fastest, which is when the player is paying most attention.
func play(voice: StringName, at: Vector2, pitch: float, volume_db: float, attenuation_db: float = 0.0) -> bool:
	if not _streams.has(voice) or _pool.is_empty():
		return false
	var player: AudioStreamPlayer2D = _pool[_next]
	# **REPORTING TRUE ON A PLAYBACK THE ENGINE REFUSED IS THE ONE THING THIS MUST NOT DO** (D0303).
	# `AudioStreamPlayer2D.play()` requires the node to be INSIDE the tree, and outside it emits an
	# engine-level ERROR and returns nothing -- which never changes an exit code, so the caller's `true`
	# was the only signal and it was wrong. Found by a suite that does `get_root().add_child(sfx)` in
	# `_initialize`, where `is_inside_tree()` is FALSE: the SceneTree's root is not itself in the tree
	# that early, so every `extends SceneTree` suite that parents a node there has one that is not
	# really parented. The game path is unaffected -- `reveal_scene` adds this in `_ready` -- but a
	# function that says it played when it did not is how a silent library gets shipped.
	if not player.is_inside_tree():
		return false
	_next = (_next + 1) % _pool.size()
	player.stream = _pick(voice)
	player.position = at
	player.pitch_scale = pitch
	player.volume_db = POOL_DB + volume_db + sound_db - attenuation_db
	player.play()
	return true


## A non-positional interface sound: the ignition, dry on Master.
func ui(voice: StringName, pitch: float = 1.0) -> bool:
	if not _streams.has(voice) or _ui == null or not _ui.is_inside_tree():
		return false
	_ui.stream = _streams[voice]
	_ui.pitch_scale = pitch
	_ui.volume_db = UI_DB + sound_db
	_ui.play()
	return true


## THE TELL, wired to the same edge the draught is (D0293): per BLOW, above `HOLLOW_RING`. Legacy layers
## it over the pick's own thud rather than replacing it — "the tell is the rock answering the same blow:
## the pick sounds the same, the wall does not" — and since 6f (ii) the thud is `VoiceCues`' per-blow
## strike, so this is the RING and only the ring. Returns whether it played, so a caller can tell
## "nothing to say" from "the pool refused".
func note_frame(frame: Frame) -> bool:
	var v: Dictionary = voice_for_frame(frame)
	if v.is_empty():
		return false
	return play(v["voice"], v["at"], v["pitch"], v["db"])


## WHAT THIS FRAME SHOULD SOUND LIKE, as data: `{}` for silence, else voice/at/pitch/db. Static and pure.
##
## Split from `note_frame` for the reason `legacy/tools/check_pump.gd` states as the lesson that
## generalises past audio -- "every generator, every stream and the whole `set_line` driver shipped and
## went green in check_voice, which called `set_line` by hand, while the controller never called it once".
## The decision and the actuation are separate things that fail separately, and only one of them can be
## asserted without an audio device in the tree. `tests/test_sfx_driver.gd` takes the five branches here
## and the pooled player over there.
static func voice_for_frame(frame: Frame) -> Dictionary:
	if frame == null or frame.obs == null or frame.obs.cell_px <= 0:
		return {}
	var obs: Interface.Observation = frame.obs
	var at: Vector2 = _cell_centre(obs.mining_charging_cell, obs.cell_px)
	if obs.mining_breach:
		return {"voice": &"breach", "at": at, "pitch": BREACH_PITCH, "db": BREACH_DB}
	if not obs.mining_swing or not obs.mining_is_charging:
		return {}
	if obs.mining_hollow < Interface.HOLLOW_RING:
		return {}
	var v: Dictionary = voice_for_hollow(obs.mining_hollow, Interface.HOLLOW_FULL)
	return {"voice": &"hollow", "at": at, "pitch": v["pitch"], "db": v["db"]}


## THE STRIKE MAP, from `legacy/scenes/sfx.gd:26-35 STRIKE` (D0313). Legacy's reason is about a session
## rather than a sound: *"an hour of digging soil, coal, ore and the deep band is not one noise several
## hundred times over."*
##
## **THE FALLBACK IS `crunch`, LEGACY'S PLAIN STONE VOICE** — "an absent material falls back to the plain
## `crunch`, which is itself the stone voice: a dry fracture". D0313 stood the fallback on `hollow`
## because no crunch existed yet and the ring was the nearest thing; with `VoiceBank.crunch` in the
## library (6f (ii), D0367) the port is legacy's own structure, and the ring is layered on top by
## `voice_for_frame`, above the threshold, as legacy layered it. `hardrock` and anything unmapped
## keep the plain fracture.
##
## The pitch of the blow is `VoiceCues.blow_pitch`: WHAT you hit chooses the timbre and its hardness the
## pitch; how hollow the rock behind it is still chooses the ring's pitch and volume. Different facts
## about one blow, and legacy keeps them separate too.
static func strike_voice(material: StringName) -> StringName:
	return STRIKE.get(material, &"crunch")


static func step_voice(material: StringName) -> StringName:
	if WOOD_GROUND.has(material):
		return &"step_wood"
	if VoiceCues.hardness(material) >= ROCK_HARDNESS and material != &"":
		return &"step_rock"
	return &"step"


static func _cell_centre(cell: Vector2i, cell_px: int) -> Vector2:
	return Vector2(float(cell.x) + 0.5, float(cell.y) + 0.5) * float(cell_px)
