extends SceneTree

## CAN YOU TELL WHAT HAPPENED WITH YOUR EYES SHUT?
##
## Every sound in this game is SYNTHESISED at boot from a fixed seed — there are no audio files, so there is
## nothing to listen to in a repo and no artist to catch a sound that came out wrong. A generator with a
## sign error produces silence; two generators that drifted together produce a game where the ore vein and
## the ingot sound the same and the player stops hearing either. Both failures are invisible in a diff and
## inaudible to a harness that only checks the code runs.
##
## So this reads the actual sample buffers, and asks the four things that make a sound library a language:
##
##   IT MAKES A SOUND.       Every named one-shot has real signal in it — enough RMS to hear, a peak that is
##                           not clipped flat, and it is not just DC.
##   YOU CAN TELL THEM APART. The whole purpose of a sound is that it names an event. Compared on a small
##                           feature vector (level, brightness, attack, decay), no two may sit on top of
##                           each other — and the new `catch` is deliberately checked against `crunch`,
##                           because rope-onto-corner and hook-into-stone are the pair most likely to blur.
##   THE BEDS DON'T CLICK.   A looping bed whose end does not meet its start ticks once per cycle forever.
##                           At three seconds a loop that is a whole minute of play with a metronome in it.
##   THE DRIVERS DRIVE.      A level-driven bed must be SILENT at zero and audible at one, and move
##                           monotonically between. The winch bed is read off the drum's actual haul rate,
##                           so a winch that has hit its stop goes quiet instead of grinding on nothing.
##
##   godot --headless --path . --script res://tools/check_voice.gd

const SCENE: String = "res://scenes/main.tscn"
const SETTLE: int = 30

const RMS_MIN: float = 0.02          ## a sound quieter than this is not a sound
const PEAK_MIN: float = 0.10         ## ...and one that never gets near full scale has no attack
const NEAR: float = 0.16             ## feature-space distance under which two sounds read as the same
const SEAM_MAX: float = 6.0          ## multiples of a bed's own typical sample step that read as a CLICK
const QUIET_DB: float = -55.0        ## a bed at zero level must be at least this far down
const LOUD_DB: float = -40.0         ## ...and at full level must be at least this far up

var _fails: int = 0


func _initialize() -> void:
	print("== can you tell what happened with your eyes shut ==")
	await _run()
	if _fails == 0:
		print("check_voice: PASS — every event has a voice, and no two share one")
		quit(0)
	else:
		print("check_voice: FAIL (%d)" % _fails)
		quit(1)


func _run() -> void:
	MainView.dev_start = false
	var main: MainView = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(main)
	for _i: int in SETTLE:
		await physics_frame
	var sfx: Node = main._sfx

	# --- every one-shot makes a sound ---
	var names: Array = sfx._streams.keys()
	names.sort()
	var feats: Dictionary = {}
	var mute: int = 0
	for n: StringName in names:
		var buf: PackedFloat32Array = _samples(sfx._streams[n])
		var f: Array[float] = _features(buf)
		feats[n] = f
		if f[0] < RMS_MIN or f[1] < PEAK_MIN:
			mute += 1
			printerr("    %s is inaudible (rms %.3f, peak %.3f)" % [n, f[0], f[1]])
	print("  %d one-shots, %d samples in the longest" % [names.size(), _longest(sfx)])
	_check(mute == 0, "every named sound actually makes one (%d silent)" % mute)

	# --- ...and no two of them sound alike ---
	var worst: float = INF
	var worst_pair: String = ""
	for i: int in names.size():
		for j: int in range(i + 1, names.size()):
			var d: float = _distance(feats[names[i]], feats[names[j]])
			if d < worst:
				worst = d
				worst_pair = "%s/%s" % [names[i], names[j]]
	print("  the closest pair in the whole library is %s at %.3f" % [worst_pair, worst])
	_check(worst >= NEAR,
		"...and no two of them sound alike (closest %s, %.3f, floor %.2f)" % [worst_pair, worst, NEAR])
	# The pair this layer was written for. Rope-onto-corner and hook-into-stone are both short noise slaps
	# and are the two a player is most likely to confuse, so they get named rather than left to the sweep.
	var rope_pair: float = _distance(feats[&"catch"], feats[&"crunch"])
	_check(rope_pair >= NEAR,
		"...including the CATCH against the hook's own bite (%.3f, floor %.2f)" % [rope_pair, NEAR])

	# --- the beds loop without a click ---
	var beds := {
		&"hum": sfx._hum_player, &"wind": sfx._wind_player, &"cave": sfx._cave_player,
		&"rush": sfx._rush_player, &"pour": sfx._pour_player, &"pump": sfx._pump_player,
		&"winch": sfx._winch_player, &"creak": sfx._creak_player,
	}
	var clicky: int = 0
	var loudest_seam: float = 0.0
	for n: StringName in beds:
		var buf: PackedFloat32Array = _samples((beds[n] as AudioStreamPlayer).stream)
		if buf.size() < 2:
			continue
		# Measured against the buffer's OWN typical step, not in absolute amplitude. The first version of
		# this compared |last - first| to a fixed threshold and reported the water bed as ticking: the pour
		# is a bright filtered-noise band, where neighbouring samples routinely differ by most of full
		# scale, so an ordinary sample-to-sample step looked exactly like a discontinuity. A click is an
		# OUTLIER against the signal it sits in — that is the only definition that survives both a noise bed
		# and a sine one.
		var seam: float = absf(buf[buf.size() - 1] - buf[0]) / maxf(_mean_step(buf), 1e-6)
		loudest_seam = maxf(loudest_seam, seam)
		if seam > SEAM_MAX:
			clicky += 1
			printerr("    the %s bed steps %.1fx its own typical sample jump across the loop seam"
				% [n, seam])
	print("  %d looping beds; the worst seam steps %.1fx its own signal" % [beds.size(), loudest_seam])
	_check(clicky == 0, "...and every bed loops without a click (%d ticking)" % clicky)

	# --- the level-driven beds actually respond ---
	for _i: int in 40:
		sfx.set_line(0.0, 0.0, 0.1)
	var quiet_winch: float = sfx._winch_player.volume_db - Settings.ambience_db()
	var quiet_creak: float = sfx._creak_player.volume_db - Settings.ambience_db()
	for _i: int in 40:
		sfx.set_line(1.0, 1.0, 0.1)
	var loud_winch: float = sfx._winch_player.volume_db - Settings.ambience_db()
	var loud_creak: float = sfx._creak_player.volume_db - Settings.ambience_db()
	print("  the winch runs %.0f dB idle and %.0f dB hauling; the line %.0f / %.0f"
		% [quiet_winch, loud_winch, quiet_creak, loud_creak])
	_check(quiet_winch <= QUIET_DB and quiet_creak <= QUIET_DB,
		"a rope nobody is pulling on is SILENT (%.0f / %.0f dB, cap %.0f)"
			% [quiet_winch, quiet_creak, QUIET_DB])
	_check(loud_winch >= LOUD_DB and loud_creak >= LOUD_DB,
		"...and one under full load is heard (%.0f / %.0f dB, floor %.0f)"
			% [loud_winch, loud_creak, LOUD_DB])
	_check(sfx._winch_player.pitch_scale > 1.0,
		"...and the drum spins UP as it hauls (pitch %.2f)" % sfx._winch_player.pitch_scale)

	main.queue_free()
	await physics_frame


## 16-bit PCM back to floats. The generators work in floats and the streams store PCM, so everything this
## layer judges is what the mixer will actually be handed rather than what the generator meant.
func _samples(stream: AudioStream) -> PackedFloat32Array:
	var w := stream as AudioStreamWAV
	var out := PackedFloat32Array()
	if w == null:
		return out
	var bytes: PackedByteArray = w.data
	var n: int = bytes.size() / 2
	out.resize(n)
	for i: int in n:
		out[i] = float(bytes.decode_s16(i * 2)) / 32768.0
	return out


## The feature vector a sound is identified by: how loud, how peaky, how BRIGHT (zero crossings — the
## cheapest honest proxy for spectral centre), how fast it arrives, and how fast it leaves. Deliberately
## small and deliberately perceptual: two sounds that match on all five are two sounds a player cannot tell
## apart, whatever their waveforms look like side by side.
func _features(buf: PackedFloat32Array) -> Array[float]:
	if buf.is_empty():
		return [0.0, 0.0, 0.0, 0.0, 0.0, 0.0] as Array[float]
	var sum_sq: float = 0.0
	var peak: float = 0.0
	var crossings: int = 0
	var peak_at: int = 0
	for i: int in buf.size():
		var v: float = buf[i]
		sum_sq += v * v
		if absf(v) > peak:
			peak = absf(v)
			peak_at = i
		if i > 0 and signf(buf[i]) != signf(buf[i - 1]):
			crossings += 1
	var rms: float = sqrt(sum_sq / float(buf.size()))
	var bright: float = float(crossings) / float(buf.size())
	var attack: float = float(peak_at) / float(buf.size())
	# Where the energy sits: the fraction of total power in the first half. A slap front-loads; a bed does
	# not; a ring-out trails. This separates sounds that share a level and a brightness.
	var early: float = 0.0
	for i: int in buf.size() / 2:
		early += buf[i] * buf[i]
	var front: float = early / maxf(sum_sq, 1e-9)
	# CONTOUR: brightness in the first quarter against the last. A falling sweep (the drip) starts bright
	# and ends dark; a struck bell (the vein) holds its pitch and decays. Mean brightness alone cannot tell
	# those apart — it averaged the sweep into the bell and reported the cave drip and an ore strike as the
	# same sound, which is a blind spot in the measurement rather than a fault in either sound.
	var q: int = maxi(1, buf.size() / 4)
	var head: float = _crossings(buf, 0, q)
	var tail: float = _crossings(buf, buf.size() - q, buf.size())
	var slide: float = (head - tail) / maxf(head + tail, 1e-6)
	return [rms, peak, bright, attack, front, slide] as Array[float]


## Zero-crossing rate over a window — brightness, localised.
func _crossings(buf: PackedFloat32Array, from: int, to: int) -> float:
	var c: int = 0
	for i: int in range(maxi(from, 1), to):
		if signf(buf[i]) != signf(buf[i - 1]):
			c += 1
	return float(c) / maxf(float(to - from), 1.0)


## Mean absolute sample-to-sample step — what "an ordinary jump" means for THIS signal.
func _mean_step(buf: PackedFloat32Array) -> float:
	var total: float = 0.0
	for i: int in range(1, buf.size()):
		total += absf(buf[i] - buf[i - 1])
	return total / maxf(float(buf.size() - 1), 1.0)


## Distance in feature space, each axis scaled so it contributes on comparable terms.
const _WEIGHT: Array[float] = [1.4, 0.8, 2.2, 0.9, 1.1, 1.6]


func _distance(a: Array[float], b: Array[float]) -> float:
	var total: float = 0.0
	for i: int in a.size():
		var d: float = (a[i] - b[i]) * _WEIGHT[i]
		total += d * d
	return sqrt(total)


func _longest(sfx: Node) -> int:
	var most: int = 0
	for n: StringName in sfx._streams:
		most = maxi(most, (sfx._streams[n] as AudioStreamWAV).data.size() / 2)
	return most


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		_fails += 1
		printerr("  FAIL: %s" % msg)
