class_name RevealAudio
extends Node

## THE AUDIO RIG of the play scene (A' step 6f, D0366): the one-shot voice pool, the ten beds and the
## level derivation, in one node so the scene keeps only the call -- the same split `reveal_view_setup`
## makes for the render stack (D0276). WHEN to build and step it is scene work; WHAT the game sounds
## like is not.

var sfx: Sfx = null
var beds: Beds = null
var _levels: BedLevels = BedLevels.new()
var _cues: VoiceCues = null


func setup(seed_value: int) -> void:
	sfx = Sfx.new()
	add_child(sfx)
	sfx.setup(seed_value)
	beds = Beds.new()
	add_child(beds)
	beds.setup(seed_value)
	_cues = VoiceCues.new(seed_value)


## One frame: the room probed, the ring and the breach, every bed pushed from the frame's levels --
## including the frames where a level is zero, which is what lets a bed go quiet instead of hanging on
## -- and the one-shot cues played into the room (6f (ii), D0367).
func note_frame(frame: Frame, delta: float) -> void:
	if frame == null or frame.obs == null:
		return
	var o: Interface.Observation = frame.obs
	var listener: Vector2 = VoiceCues.body_px(o)
	sfx.space.update(o, listener, delta)
	sfx.note_frame(frame)
	beds.drive(_levels.levels(o), delta)
	# Every one-shot the frame calls for, through the room: the rock between a source and the ear
	# takes off up to OCCLUSION_DB_MAX on top of the player's own distance falloff.
	for c: Dictionary in _cues.cues(o, delta, beds.level(&"cave")):
		if bool(c["ui"]):
			sfx.ui(c["voice"], float(c["pitch"]))
		else:
			var occluded: float = SfxSpace.occlusion(o, c["at"], listener) * SfxSpace.OCCLUSION_DB_MAX
			sfx.play(c["voice"], c["at"], float(c["pitch"]), float(c["db"]), occluded)
