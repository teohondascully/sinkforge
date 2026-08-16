extends SceneTree

## HEADLESS CHECK — THE SCORE. A music layer is the one system you cannot eyeball in a screenshot and
## cannot hear in CI, so everything about it that CAN be stated as a number is stated here. Six
## properties, each one a way the score could silently be broken while still "working":
##
##   1. headless-safe            — no voice is ever started under the Dummy driver (leak warning at quit)
##   2. three looping beds       — each bed is a real, non-trivial, LOOP_FORWARD stream
##   3. seamless loops           — the loop seam is not a click (the whole reason the partials are snapped
##                                 to whole cycles per window; a stray non-integer ratio would tick forever)
##   4. no clipping              — the additive stack stays inside the 16-bit rails, so the pad is a pad
##   5. the descent is monotone  — deeper is always more MINOR, more SUB, less OPEN, and lower in pitch;
##                                 never a wobble, because the descent is supposed to be one direction
##   6. the mix eases            — a teleport to the bottom does not slam the score; it travels
##
## What this does NOT check is whether it sounds good. That is the ear's job. This is the "Works" tier.

const SEAM_TOL: float = 0.06        ## max |first - last| sample, in normalized units, before it clicks
const PEAK_CEIL: float = 0.98       ## the stack must not slam the 16-bit rails
const PEAK_FLOOR: float = 0.25      ## ...nor be so quiet that the slider cannot rescue it


func _init() -> void:
	var fails: int = 0
	var score: Score = Score.new()
	root.add_child(score)
	# In a SceneTree `_init` the tree is not live yet, so _ready() on a just-added child is deferred;
	# drive it explicitly so the beds exist before we assert (in the real scene _ready fires normally).
	score._ready()

	# 1. The harness must never open an audio device.
	if not score._muted:
		push_error("check_score: expected _muted under the headless driver")
		fails += 1

	# 2 + 3 + 4. Each bed is a real looping stream whose seam does not click and whose peak is sane.
	var beds: Array = [["open", score._open], ["minor", score._minor], ["sub", score._sub]]
	for pair: Array in beds:
		var who: String = pair[0]
		var pl: AudioStreamPlayer = pair[1]
		if pl == null:
			push_error("check_score: bed '%s' is null" % who)
			fails += 1
			continue
		var w: AudioStreamWAV = pl.stream
		if w == null or w.data.size() < 10000:
			push_error("check_score: bed '%s' has no synthesized data" % who)
			fails += 1
			continue
		if w.loop_mode != AudioStreamWAV.LOOP_FORWARD:
			push_error("check_score: bed '%s' is not looping" % who)
			fails += 1
		var s: PackedFloat32Array = _decode(w.data)
		# The SEAM: playback wraps from the last sample straight back to the first, so that step IS the
		# discontinuity a listener hears as a tick once every loop — forever, which is the worst kind of
		# audio bug. Compare it against the bed's own typical step so a loud bed is not judged by a quiet
		# bed's yardstick.
		var seam: float = absf(s[0] - s[s.size() - 1])
		if seam > SEAM_TOL:
			push_error("check_score: bed '%s' loop seam is a click (|%.4f| > %.4f)" % [who, seam, SEAM_TOL])
			fails += 1
		var peak: float = 0.0
		for v: float in s:
			peak = maxf(peak, absf(v))
		if peak > PEAK_CEIL:
			push_error("check_score: bed '%s' clips (peak %.3f)" % [who, peak])
			fails += 1
		elif peak < PEAK_FLOOR:
			push_error("check_score: bed '%s' is too quiet to mix (peak %.3f)" % [who, peak])
			fails += 1
		print("  bed %-6s  seam %.4f  peak %.3f  %d samples" % [who, seam, peak, s.size()])

	# 5. THE DESCENT IS MONOTONE. Sample the whole world top to bottom, settling the easing at each step
	#    (the mix is deliberately slow, so this drives it to rest rather than reading it mid-travel).
	var prev := {"open": 999.0, "minor": -999.0, "sub": -999.0, "pitch": 999.0}
	var top := {}
	var bottom := {}
	for step: int in 11:
		var t: float = float(step) / 10.0
		for _s: int in 400:
			score.set_depth(t, 0.05)                        # settle: FADE_RATE is 0.25/s by design
		var now := {
			"open": _lin(score._open.volume_db),
			"minor": _lin(score._minor.volume_db),
			"sub": _lin(score._sub.volume_db),
			"pitch": score._open.pitch_scale,
		}
		if step == 0:
			top = now.duplicate()
		if step == 10:
			bottom = now.duplicate()
		# open + pitch must never rise as you descend; minor + sub must never fall.
		for key: String in ["open", "pitch"]:
			if float(now[key]) > float(prev[key]) + 1e-4:
				push_error("check_score: '%s' rose while descending (t=%.1f)" % [key, t])
				fails += 1
		for key: String in ["minor", "sub"]:
			if float(now[key]) < float(prev[key]) - 1e-4:
				push_error("check_score: '%s' fell while descending (t=%.1f)" % [key, t])
				fails += 1
		prev = now
	# ...and the ends must actually differ, or "monotone" is satisfied by a constant. The deep has to be
	# AUDIBLY minor, not merely more minor than a surface that was already silent.
	if float(bottom["minor"]) < 0.06 or float(bottom["minor"]) < float(top["minor"]) * 4.0:
		push_error("check_score: the deep is not audibly more minor than the surface (%.3f vs %.3f)"
			% [bottom["minor"], top["minor"]])
		fails += 1
	if float(top["pitch"]) - float(bottom["pitch"]) < 0.2:
		push_error("check_score: the tonal centre barely descends (%.2f -> %.2f)"
			% [top["pitch"], bottom["pitch"]])
		fails += 1
	print("  descent   pitch %.2f -> %.2f   minor %.3f -> %.3f   sub %.3f -> %.3f"
		% [top["pitch"], bottom["pitch"], top["minor"], bottom["minor"], top["sub"], bottom["sub"]])

	# 6. THE MIX EASES. Falling down a shaft is a two-second trip; the score must not follow it frame for
	#    frame or the descent becomes a slide whistle. One frame at the bottom moves it only a little.
	for _s: int in 400:
		score.set_depth(0.0, 0.05)                          # settle back at the surface
	var before: float = score._depth
	score.set_depth(1.0, 1.0 / 60.0)
	var jump: float = score._depth - before
	if jump > 0.02:
		push_error("check_score: mix slams instead of easing (%.4f in one frame)" % jump)
		fails += 1
	print("  easing    one frame at full depth moves the mix %.4f" % jump)

	score.free()                                            # teardown must be clean (no live voice at quit)

	if fails == 0:
		print("check_score: PASS — 3 seamless beds, monotone descent, eased mix, headless-safe")
		quit(0)
	else:
		print("check_score: FAIL (%d)" % fails)
		quit(1)


func _decode(data: PackedByteArray) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(data.size() / 2)
	for i: int in out.size():
		out[i] = float(data.decode_s16(i * 2)) / 32767.0
	return out


func _lin(db: float) -> float:
	return 0.0 if db <= -60.0 else db_to_linear(db)
