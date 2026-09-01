class_name Sfx
extends Node2D

## THE VOICE POOL. Ported in shape from `legacy/scenes/sfx.gd`'s player pool and its `play()` call site
## at `legacy/scenes/main.gd:1601-1603`. `docs/LEGACY_GAP.md` T1 #6, Lane G.
##
## **LEGACY'S FILE IS 1,125 LINES AND THIS IS NOT A PORT OF IT.** Its `sfx.gd` carries a dozen ambience
## beds — factory hum in three layers, winch, creak, rush, wind, cave-air, pour, pump — every one of them
## for a system this build does not have. Porting the file would be porting eleven dead players and the
## crossfade logic that drives them from state nothing produces. What comes over is the pool, the one
## `play()` this build has a caller for, and the two voices `view/audio/sfx_bank.gd` generates.
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
const BREACH_DB: float = -7.0
const BREACH_PITCH: float = 1.0

var _pool: Array[AudioStreamPlayer2D] = []
var _next: int = 0
var _streams: Dictionary = {}


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


## Builds the pool and generates both voices. The seed is explicit so two runs sound identical, which is
## what `tests/test_sfx_bank.gd`'s spectral assertions rest on.
func setup(seed_value: int = 20260901) -> void:
	var rng: SplitRng = SplitRng.new(seed_value).split("sfx")
	_streams[&"hollow"] = SfxBank.to_stream(SfxBank.hollow(rng))
	_streams[&"breach"] = SfxBank.to_stream(SfxBank.breach(rng))
	for _i: int in VOICES:
		var player := AudioStreamPlayer2D.new()
		add_child(player)
		_pool.append(player)


## Plays one voice at a world position. Round-robin over the pool: the oldest voice is the one taken,
## which is legacy's policy and the right one — refusing to play once the pool is full would drop exactly
## the blows landing fastest, which is when the player is paying most attention.
func play(voice: StringName, at: Vector2, pitch: float, volume_db: float) -> bool:
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
	player.stream = _streams[voice]
	player.position = at
	player.pitch_scale = pitch
	player.volume_db = volume_db
	player.play()
	return true


## THE TELL, wired to the same edge the draught is (D0293): per BLOW, above `HOLLOW_RING`. Legacy layers
## it over the pick's own thud rather than replacing it — "the tell is the rock answering the same blow:
## the pick sounds the same, the wall does not" — and this build has no pick thud yet, so for now the
## ring is the whole of it. Returns whether it played, so a caller can tell "nothing to say" from "the
## pool refused".
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


static func _cell_centre(cell: Vector2i, cell_px: int) -> Vector2:
	return Vector2(float(cell.x) + 0.5, float(cell.y) + 0.5) * float(cell_px)
