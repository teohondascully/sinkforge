class_name RevealAudio
extends Node

## THE AUDIO RIG of the play scene (A' step 6f, D0366): the one-shot voice pool, the ten beds and the
## level derivation, in one node so the scene keeps only the call -- the same split `reveal_view_setup`
## makes for the render stack (D0276). WHEN to build and step it is scene work; WHAT the game sounds
## like is not.

var sfx: Sfx = null
var beds: Beds = null
var _levels: BedLevels = BedLevels.new()


func setup(seed_value: int) -> void:
	sfx = Sfx.new()
	add_child(sfx)
	sfx.setup(seed_value)
	beds = Beds.new()
	add_child(beds)
	beds.setup(seed_value)


## One frame: the voices the frame calls for, and every bed pushed from the frame's levels -- including
## the frames where a level is zero, which is what lets a bed go quiet instead of hanging on.
func note_frame(frame: Frame, delta: float) -> void:
	if frame == null or frame.obs == null:
		return
	sfx.note_frame(frame)
	beds.drive(_levels.levels(frame.obs), delta)
