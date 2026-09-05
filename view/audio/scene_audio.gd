class_name SceneAudio
extends Node

## THE AUDIO RIG of the play scene (A' step 6f, D0366): the one-shot voice pool, the ten beds and the
## level derivation, in one node so the scene keeps only the call -- the same split `reveal_view_setup`
## makes for the render stack (D0276). WHEN to build and step it is scene work; WHAT the game sounds
## like is not.

var sfx: Sfx = null
var beds: Beds = null
var _levels: BedLevels = BedLevels.new()
var _cues: VoiceCues = null
var _seed: int = 0
var _task: int = -1                  ## the worker-thread synthesis, -1 when none is pending
var _synth: Dictionary = {}          ## its result: {"sfx": Sfx.synthesize(...), "beds": Beds.synthesize(...)}


## Synchronous: every voice and bed built before this returns. The suites' path.
func setup(seed_value: int) -> void:
	_nodes(seed_value)
	sfx.setup(seed_value)
	beds.setup(seed_value)


## The seat's path (D0397): the half-second of sample synthesis runs on a worker thread while the first
## frames draw; the players attach on the first `note_frame` after it finishes. Until then a one-shot is
## refused and a bed is silent, and nothing can be heard that early anyway (the arrival plate is still
## priming). The content is identical: `synthesize` is pure over the seed on both paths.
func setup_async(seed_value: int) -> void:
	_nodes(seed_value)
	_task = WorkerThreadPool.add_task(_synthesize, false, "sinkforge audio synthesis")


func _nodes(seed_value: int) -> void:
	_seed = seed_value
	sfx = Sfx.new()
	add_child(sfx)
	beds = Beds.new()
	add_child(beds)
	_cues = VoiceCues.new(seed_value)


func _synthesize() -> void:
	_synth = {"sfx": Sfx.synthesize(_seed), "beds": Beds.synthesize(_seed)}


## Attach the synthesis if it has finished; true once the rig is complete.
func settle() -> bool:
	if _task < 0:
		return true
	if not WorkerThreadPool.is_task_completed(_task):
		return false
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	sfx.attach(_synth["sfx"], _seed)
	beds.attach(_synth["beds"])
	_synth = {}
	return true


func _exit_tree() -> void:
	if _task >= 0:   # a task may not outlive the node that owns its result
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


## One frame: the room probed, the ring and the breach, every bed pushed from the frame's levels --
## including the frames where a level is zero, which is what lets a bed go quiet instead of hanging on
## -- and the one-shot cues played into the room (6f (ii), D0367).
func note_frame(frame: Frame, delta: float) -> void:
	if frame == null or frame.obs == null or not settle():
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
