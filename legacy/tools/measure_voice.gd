extends SceneTree

## THE SOUND, ON PAPER. A bench instrument for the Sfx layer: it instantiates the synthesiser, reads every
## buffer it produced, and prints the numbers you would otherwise have to have ears to know — length, peak,
## RMS, DC offset, clipped samples, spectral centroid, and how much of the energy actually sits in the LOW
## end (the thing "weight" means when you cannot listen). It also prints check_voice's own feature vectors
## and the full pairwise distance matrix, so a new sound can be judged against the library BEFORE the
## harness judges it.
##
## Not a pass/fail layer — it asserts nothing and is not in run_harness.sh. It is the microscope.
##
##   godot --headless --path . --script res://tools/measure_voice.gd

const LOW_HZ: float = 160.0        ## "weight" band: what you feel in the chest rather than hear
const BINS: int = 44               ## log-spaced probe frequencies for the spectrum estimate
const F_LO: float = 24.0
const F_HI: float = 9000.0


func _initialize() -> void:
	var sfx: Sfx = Sfx.new()
	root.add_child(sfx)
	var t0: int = Time.get_ticks_usec()
	sfx._ready()
	print("synthesis at boot: %.1f ms" % (float(Time.get_ticks_usec() - t0) / 1000.0))

	print("== one-shots ==")
	print("%-14s %7s %6s %6s %7s %5s %8s %6s | %5s %5s %5s %5s %5s %6s"
		% ["name", "sec", "peak", "rms", "dc", "clip", "centroid", "low%",
			"rms", "peak", "brgt", "atk", "frnt", "slide"])
	var names: Array = sfx._streams.keys()
	names.sort()
	var feats: Dictionary = {}
	for n: StringName in names:
		var buf: PackedFloat32Array = _samples(sfx._streams[n])
		var f: Array[float] = _features(buf)
		feats[n] = f
		var sp: Array[float] = _spectrum(buf)
		print("%-14s %7.3f %6.3f %6.3f %+7.4f %5d %8.0f %5.1f%% | %5.3f %5.3f %5.3f %5.3f %5.3f %+6.3f"
			% [String(n), float(buf.size()) / float(Sfx.RATE), f[1], f[0], _dc(buf), _clipped(buf),
				sp[0], sp[1] * 100.0, f[0], f[1], f[2], f[3], f[4], f[5]])

	print("\n== closest neighbours (check_voice floor is 0.16) ==")
	var worst: float = INF
	var worst_pair: String = ""
	for i: int in names.size():
		var best: float = INF
		var who: String = ""
		for j: int in names.size():
			if i == j:
				continue
			var d: float = _distance(feats[names[i]], feats[names[j]])
			if d < best:
				best = d
				who = String(names[j])
			if j > i and d < worst:
				worst = d
				worst_pair = "%s/%s" % [names[i], names[j]]
		print("  %-14s nearest %-14s %.3f%s"
			% [String(names[i]), who, best, "   <-- UNDER FLOOR" if best < 0.16 else ""])
	print("  closest pair in the library: %s at %.3f" % [worst_pair, worst])

	print("\n== looping beds ==")
	print("%-10s %7s %6s %6s %8s %6s %8s"
		% ["bed", "sec", "peak", "rms", "centroid", "low%", "seam(x)"])
	for pair: Array in _beds(sfx):
		var buf: PackedFloat32Array = _samples((pair[1] as AudioStreamPlayer).stream)
		if buf.size() < 2:
			print("  %-10s (empty)" % pair[0])
			continue
		var f: Array[float] = _features(buf)
		var sp: Array[float] = _spectrum(buf)
		var seam: float = absf(buf[buf.size() - 1] - buf[0]) / maxf(_mean_step(buf), 1e-6)
		print("%-10s %7.3f %6.3f %6.3f %8.0f %5.1f%% %8.2f"
			% [String(pair[0]), float(buf.size()) / float(Sfx.RATE), f[1], f[0], sp[0],
				sp[1] * 100.0, seam])

	sfx.free()
	await _in_the_world()
	quit(0)


## ...and the half of this that no buffer can show: does the mixer actually READ the world? Boots the
## real scene, then asks the live Sfx what a blow on each material resolves to and what the room around
## a few landmark positions measures as. A synthesiser that sounds right and resolves nothing is silent
## about the very thing the material voice was built for.
func _in_the_world() -> void:
	MainView.dev_start = false
	var main: MainView = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _i: int in 30:
		await physics_frame
	var sfx: Sfx = main._sfx
	var sim: FactorySim = main.sim

	print("\n== the strike, resolved from the world ==")
	var seen: Dictionary = {}
	for key: Variant in sim.solid:
		var cell: Vector2i = key
		var mat: StringName = sim.solid[cell]
		if seen.has(mat):
			continue
		seen[mat] = true
		var at := Vector2(cell) * float(Sfx.CELL) + Vector2(16.0, 16.0)
		print("  %-12s -> %-12s   (footstep from above: %s)"
			% [String(mat), String(sfx._resolve(&"crunch", at)),
				String(sfx._resolve(&"step", at - Vector2(0.0, 2.0)))])

	print("\n== the room, measured ==")
	print("%-26s %7s %7s %6s %6s %6s" % ["where", "closed", "room", "wet", "size", "damp"])
	for probe: Array in _places(sim):
		sfx._closed = 0.0
		sfx._room = 0.0
		for _i: int in 60:                                   # let the smoothing settle on this spot
			sfx._probe_space(probe[1])
		sfx._probe_in = 999.0
		sfx._update_space(probe[1], 0.0)
		print("%-26s %7.2f %7.2f %6.2f %6.2f %6.2f"
			% [probe[0], sfx._closed, sfx._room, sfx._reverb.wet, sfx._reverb.room_size,
				sfx._reverb.damping])
	main.queue_free()
	await physics_frame


## A handful of honest listening positions: high above the ground, on the surface, buried in the solid
## rock of the same column — and then two spaces CARVED into this throwaway world, because the whole
## claim of the reverb is that it can tell a one-cell crawl from a room, and only digging proves it.
func _places(sim: FactorySim) -> Array:
	var col: int = 64
	var top: int = sim.surface_row(col)
	var c: float = float(Sfx.CELL)
	var shaft: int = top + 46
	for r: int in range(top + 40, top + 56):                 # a 1-wide bore straight down
		sim.solid.erase(Vector2i(col, r))
	var room: int = top + 70
	for r: int in range(room - 6, room + 7):                 # ...and a 13x13 chamber further down
		for k: int in range(col - 6, col + 7):
			sim.solid.erase(Vector2i(k, r))
	return [
		["open sky (20 rows up)", Vector2(float(col) * c, float(top - 20) * c)],
		["on the surface", Vector2(float(col) * c, float(top - 1) * c)],
		["3 rows down, in rock", Vector2(float(col) * c, float(top + 3) * c)],
		["80 rows down, in rock", Vector2(float(col) * c, float(top + 80) * c)],
		["a 1-wide bore", Vector2(float(col) * c + 16.0, float(shaft) * c + 16.0)],
		["a 13x13 chamber", Vector2(float(col) * c + 16.0, float(room) * c + 16.0)],
	]


func _beds(sfx: Sfx) -> Array:
	var out: Array = []
	for n: String in ["_hum_player", "_hum_mid_player", "_hum_top_player", "_wind_player",
			"_cave_player", "_rush_player", "_pour_player", "_pump_player", "_winch_player",
			"_creak_player"]:
		var p: Variant = sfx.get(n)
		if p != null:
			out.append([n.trim_prefix("_").trim_suffix("_player"), p])
	return out


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


## Spectral centroid (Hz) and the fraction of energy under LOW_HZ, from a log-spaced DFT probe. Each bin
## is integrated with its own bandwidth so a log sweep still reports honest energy shares.
func _spectrum(buf: PackedFloat32Array) -> Array[float]:
	if buf.size() < 16:
		return [0.0, 0.0] as Array[float]
	var total: float = 0.0
	var weighted: float = 0.0
	var low: float = 0.0
	for b: int in BINS:
		var f: float = F_LO * pow(F_HI / F_LO, float(b) / float(BINS - 1))
		var bw: float = f * (pow(F_HI / F_LO, 1.0 / float(BINS - 1)) - 1.0)
		var w: float = TAU * f / float(Sfx.RATE)
		var cw: float = cos(w)
		var sw: float = sin(w)
		var cr: float = 1.0
		var ci: float = 0.0
		var re: float = 0.0
		var im: float = 0.0
		for i: int in buf.size():
			var v: float = buf[i]
			re += v * cr
			im -= v * ci
			var nr: float = cr * cw - ci * sw
			ci = cr * sw + ci * cw
			cr = nr
		var e: float = (re * re + im * im) / float(buf.size()) * bw
		total += e
		weighted += e * f
		if f < LOW_HZ:
			low += e
	if total <= 0.0:
		return [0.0, 0.0] as Array[float]
	return [weighted / total, low / total] as Array[float]


func _dc(buf: PackedFloat32Array) -> float:
	var s: float = 0.0
	for v: float in buf:
		s += v
	return s / maxf(float(buf.size()), 1.0)


func _clipped(buf: PackedFloat32Array) -> int:
	var c: int = 0
	for v: float in buf:
		if absf(v) >= 0.9995:
			c += 1
	return c


## check_voice's own feature vector, verbatim, so the two instruments always agree.
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
	var early: float = 0.0
	for i: int in buf.size() / 2:
		early += buf[i] * buf[i]
	var front: float = early / maxf(sum_sq, 1e-9)
	var q: int = maxi(1, buf.size() / 4)
	var head: float = _crossings(buf, 0, q)
	var tail: float = _crossings(buf, buf.size() - q, buf.size())
	var slide: float = (head - tail) / maxf(head + tail, 1e-6)
	return [rms, peak, bright, attack, front, slide] as Array[float]


func _crossings(buf: PackedFloat32Array, from: int, to: int) -> float:
	var c: int = 0
	for i: int in range(maxi(from, 1), to):
		if signf(buf[i]) != signf(buf[i - 1]):
			c += 1
	return float(c) / maxf(float(to - from), 1.0)


func _mean_step(buf: PackedFloat32Array) -> float:
	var total: float = 0.0
	for i: int in range(1, buf.size()):
		total += absf(buf[i] - buf[i - 1])
	return total / maxf(float(buf.size() - 1), 1.0)


const _WEIGHT: Array[float] = [1.4, 0.8, 2.2, 0.9, 1.1, 1.6]


func _distance(a: Array[float], b: Array[float]) -> float:
	var total: float = 0.0
	for i: int in a.size():
		var d: float = (a[i] - b[i]) * _WEIGHT[i]
		total += d * d
	return sqrt(total)
