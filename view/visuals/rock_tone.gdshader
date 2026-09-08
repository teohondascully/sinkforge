shader_type canvas_item;

// THE MOLDED TONE IN A SHADER, from a per-chunk data texture (D0528, T040's evidence; OFF by default
// behind `BakeChunk.shader_tone()`). `data_tex` is `BakeData`'s image for the chunk -- one texel a cell:
// R material index, G grammar + speck bits, B distance to air, A soil-depth code + root bit -- and
// `palette` its material table. This file is `TerrainPainter.cell_fill` term by term:
//   `MaterialLook.cell_color`  -> cell_color()     EXACT: the depth darkening, `BeddingTone`'s sines and
//                                                  `apply_tone`; the speck is DECIDED on the CPU (G bits)
//   `RockTone.shade`           -> rock_shade()     EXACT in its arithmetic, its neighbour terms and
//                                                  `BedSequence` (32-bit masked hashes, ported as uint)
//   `SurfaceTone.shade`        -> surface_shade()  EXACT in its arithmetic and its neighbour terms
//   the cap and the root       -> fragment()       EXACT (the root column is the CPU's bit, A bit 7)
//   the tuft                   -> NOT HERE. `TerrainPainter._paint_tuft` draws a sub-cell blade in an AIR
//                                cell above the walked line; an air texel here writes nothing at all, and
//                                the function is private to a file this ticket may not move. The flag
//                                therefore LOSES the tufts, and the capture diff counts them.
//
// WHAT IS NOT EXACT, said plainly: the eleven `FastNoiseLite` fields. FastNoiseLite's OpenSimplex2,
// OpenSimplex2S and value noise are not in GLSL and were not transcribed. Each field here keeps its
// FREQUENCY, its OCTAVE COUNT (FBM at lacunarity 2, gain 0.5, with FastNoiseLite's fractal bounding) and
// its SEED SALT, on a standard 2D simplex (Gustavson/McEwan) or an integer-hashed value noise -- so the
// picture has the same feature sizes, the same grammar direction and the same term structure, with
// different sample values. THIS IS THE WHOLE OF WHY A CAPTURE DIFF EXISTS: every rock texel may move.

// THE DATA PLANE IS ITS OWN UNIFORM, NOT `TEXTURE`, and that is a compiler constraint rather than a
// preference: Godot's shader compiler refuses a BUILT-IN sampler passed as a function argument
// ("custom_samplers.has(tex_builtin)", shader_compiler.cpp:1294), and every neighbour probe below takes
// the plane as an argument. Bound by `BakeChunk.paint_tone`; the quad itself is drawn untextured.
uniform sampler2D data_tex : filter_nearest, repeat_disable;
uniform sampler2D palette : filter_nearest, repeat_disable;
uniform int cell_px = 4;
uniform int world_seed = 0;
// The cell of the data image's texel (0, 0): the paint rect grown by `BakeData.MARGIN`. The texel is
// derived from the world position rather than from UV, so the quad's own size and filtering cannot move
// which cell a pixel reads.
uniform ivec2 span_origin = ivec2(0, 0);
// `BakeData.unknown_index()`: a solid legend entry no record knows. `MaterialLook.matrix_color` returns
// its debug brown BEFORE it tones anything, so this one index skips the tone.
uniform int unknown_index = 0;
const vec3 DEBUG_BROWN = vec3(0.42, 0.34, 0.24);

// `MaterialLook` / `BeddingTone`
const int SURFACE_ROW = 80;
const float CELLS_PER_METRE = 4.0;
const float DEPTH_DARKEN_FULL_M = 128.0;
const float TONE_BOOST_FULL_M = 256.0;
const float TONE_BOOST_AT_FLOOR = 1.0;
const vec3 STRATA_WARM = vec3(0.86, 0.74, 0.52);
const vec3 STRATA_COOL = vec3(0.15, 0.16, 0.21);
const float STRATA_AMOUNT = 0.22;
const float GRAM_BEDDING[3] = {0.9, 1.4, 0.45};
const float SPECK_LIGHTEN = 0.22;
const float SPECK_DARKEN = 0.18;

// `RockTone`
const float TONAL_FREQ = 0.085;
const float GRAIN_FREQ = 0.09;
const float GRAIN_FREQ2 = 0.115;
const float GRAIN_XSTRETCH = 0.38;
const float GRAIN_AMP = 0.10;
const float PATCH_FREQ = 0.045;
const float PATCH_AMP = 0.22;
const float STONE_FREQ = 0.10;
const float STONE_THRESH = 0.42;
const float STONE_RAMP = 1.6;
const float STONE_DARKEN = 0.11;
const float CRACK_FREQ = 0.09;
const float CRACK_BAND = 0.075;
const float CRACK_DARKEN = 0.15;
const float HUE_FREQ = 0.028;
const float HUE_AMP = 0.12;
const vec3 HUE_TEAL = vec3(0.16, 0.30, 0.34);
const vec3 HUE_BROWN = vec3(0.30, 0.24, 0.17);
const vec3 HUE_VIOLET = vec3(0.24, 0.18, 0.30);
const float GRAM_GRAIN[3] = {1.60, 0.60, 0.22};
const float GRAM_XSTR[3] = {1.00, 0.35, 1.60};
const float GRAM_CLUMP[3] = {1.45, 0.60, 0.25};
const float GRAM_SEAM[3] = {0.15, 1.00, 0.70};
const float GRAM_PATCH[3] = {1.35, 0.80, 0.60};
const float GRAM_SEAM_X[3] = {1.00, 0.35, 3.40};
const float GRAM_SEAM_Y[3] = {1.00, 3.00, 0.40};
const float GRAM_SEAM_W[3] = {1.00, 1.35, 1.70};
const float LAM_DARKEN = 0.42;
const float LAM_ADD = 0.045;
const float LAM_FADE_FREQ = 0.03;
const float GRAM_LAMINA[3] = {0.0, 1.0, 0.0};
const float VALUE_FLOOR = 0.22;
const vec3 SHADOW_TEAL = vec3(0.13, 0.20, 0.27);
const float AO_PER_NEIGHBOUR = 0.125;
const float AO_TEAL_GATE = 0.5;
const float AO_TEAL_AMOUNT = 0.20;
const int RIM_DEPTH = 2;
const float RIM_LIGHT = 0.10;
const float RIM_WARM = 0.03;
const int FORM_REACH = 6;
const float FORM_LIFT = 0.22;
const float FORM_SINK = 0.13;

// `BedSequence`
const float SPACING_M = 1.0;
const float ABSENT = 0.30;
const float JITTER_M = 0.6;
const float WOBBLE_M = 0.10;
const float WOBBLE_FREQ = 0.7;
const float HALF_THIN_M = 0.125;
const float HALF_THICK_M = 0.25;
const float THICK_SHARE = 0.20;
const float STRENGTH_FLOOR = 0.45;
const float FINE_WEIGHT = 0.55;
const float FADE_FLOOR = 0.30;
const float THICK_LO = -0.35;
const float THICK_HI = -0.15;
const float FINE_LO = 0.35;
const float FINE_HI = 0.55;

// `SurfaceTone`
const int SOIL_ROWS = 40;
const int HUMUS_ROWS = 5;
const float HUMUS_DARKEN = 0.26;
const int SUBSOIL_ROWS = 20;
const float SUBSOIL_WARM = 0.13;
const vec3 SUBSOIL_POLE = vec3(0.52, 0.35, 0.18);
const float COBBLE_SCALE = 1.0;
const float COBBLE_THRESH = 0.26;
const float COBBLE_GAIN = 0.942;
const float CLAST_THRESH = -0.30;
const float CLAST_DARKEN = 0.20;
const float ROOT_FREQ = 0.14;
const float ROOT_GATE = 0.34;
const float ROOT_MAX = 26.0;
const float ROOT_DARKEN = 0.30;
const vec3 MOSS_COLOR = vec3(0.25, 0.36, 0.15);
const int MOSS_DEPTH = 3;
const float MOSS_FREQ = 0.15;
const float MOSS_LUSH_M = 2.0;
const float MOSS_DEAD_M = 14.0;
const int HANG_DEPTH = 3;
const float HANG_GATE = 0.30;
const float CAP_ROOT_DARKEN = 0.34;
const float CAP_ROOT_MIX = 0.5;
const int NONE = -1;

// `BakeData`'s encoding
const int G_GRAM_MASK = 3;
const int G_SPECK_BIT = 4;
const int G_FACET_BIT = 8;
const int A_ROOT_BIT = 128;
const int A_CODE_MASK = 127;
const int A_SURFACE = 1;

varying vec2 world_px;

void vertex() {
	// The chunk layers sit at the origin of a world-sized target, so local IS world px.
	world_px = VERTEX;
}

// ---- Colour helpers: GDScript's `Color.lightened` / `Color.darkened`. ----
vec3 lightened(vec3 c, float f) { return c + (1.0 - c) * f; }
vec3 darkened(vec3 c, float f) { return c * (1.0 - f); }

// ---- Noise: the approximate part. See the header. ----
vec3 mod289v3(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec2 mod289v2(vec2 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec3 permute(vec3 x) { return mod289v3(((x * 34.0) + 1.0) * x); }

float snoise(vec2 v) {
	const vec4 C = vec4(0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439);
	vec2 i = floor(v + dot(v, C.yy));
	vec2 x0 = v - i + dot(i, C.xx);
	vec2 i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
	vec4 x12 = x0.xyxy + C.xxzz;
	x12.xy -= i1;
	i = mod289v2(i);
	vec3 p = permute(permute(i.y + vec3(0.0, i1.y, 1.0)) + i.x + vec3(0.0, i1.x, 1.0));
	vec3 m = max(0.5 - vec3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), 0.0);
	m = m * m;
	m = m * m;
	vec3 x = 2.0 * fract(p * C.www) - 1.0;
	vec3 h = abs(x) - 0.5;
	vec3 ox = floor(x + 0.5);
	vec3 a0 = x - ox;
	m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);
	vec3 g;
	g.x = a0.x * x0.x + h.x * x0.y;
	g.yz = a0.yz * x12.xz + h.yz * x12.yw;
	return 130.0 * dot(m, g);
}

float ihash(ivec2 p, uint seed) {
	uint h = (uint(p.x) * 0x27d4eb2du) ^ (uint(p.y) * 0x165667b1u) ^ seed;
	h = (h ^ (h >> 15u)) * 0x2c1b3c6du;
	h ^= h >> 12u;
	return float(h & 0xFFFFFFu) / 16777216.0 * 2.0 - 1.0;
}

// Value noise with FastNoiseLite's Hermite interpolation and a seedable integer hash.
float vnoise(vec2 p, uint seed) {
	vec2 i = floor(p);
	vec2 f = p - i;
	vec2 u = f * f * (3.0 - 2.0 * f);
	ivec2 c = ivec2(i);
	float a = ihash(c, seed);
	float b = ihash(c + ivec2(1, 0), seed);
	float cc = ihash(c + ivec2(0, 1), seed);
	float d = ihash(c + ivec2(1, 1), seed);
	return mix(mix(a, b, u.x), mix(cc, d, u.x), u.y);
}

// The seed moves the simplex domain, inside its 289-unit period.
vec2 seed_offset(uint s) {
	uint h = s * 0x9E3779B1u;
	h ^= h >> 15u;
	h *= 0x85EBCA77u;
	h ^= h >> 13u;
	return vec2(float(h & 0xFFFFu), float(h >> 16u)) / 65536.0 * 289.0;
}

// FastNoiseLite's FBM: `fractal_bounding` = 1 / sum(gain^i), lacunarity 2, gain 0.5, seed + 1 an octave.
float fnl(vec2 p, float freq, uint salt, int octaves, bool value_type) {
	uint seed = uint(world_seed) ^ salt;
	float bounding = 0.0;
	float a = 1.0;
	for (int i = 0; i < octaves; i++) { bounding += a; a *= 0.5; }
	float amp = 1.0 / bounding;
	float sum = 0.0;
	vec2 q = p * freq;
	for (int i = 0; i < octaves; i++) {
		float n = value_type ? vnoise(q, seed) : snoise(q + seed_offset(seed));
		sum += n * amp;
		amp *= 0.5;
		q *= 2.0;
		seed += 1u;
	}
	return sum;
}

// The eleven fields, each with `RockTone._init` / `SurfaceTone._init`'s own salt, type and octave count.
float n_drift(float x, float y) { return fnl(vec2(x, y), TONAL_FREQ, 0u, 3, false); }
float n_grain(float x, float y) { return fnl(vec2(x, y), GRAIN_FREQ, 0x27d4eb2fu, 1, false); }
float n_grain2(float x, float y) { return fnl(vec2(x, y), GRAIN_FREQ2, 0x165667b1u, 1, true); }
float n_patch(float x, float y) { return fnl(vec2(x, y), PATCH_FREQ, 0x2545f491u, 3, false); }
float n_stone(float x, float y) { return fnl(vec2(x, y), STONE_FREQ, 0x1b873593u, 1, false); }
float n_crack(float x, float y) { return fnl(vec2(x, y), CRACK_FREQ, 0x85ebca77u, 1, false); }
float n_huex(float x, float y) { return fnl(vec2(x, y), HUE_FREQ, 0xc2b2ae35u, 1, false); }
float n_huey(float x, float y) { return fnl(vec2(x, y), HUE_FREQ, 0x27d4eb2fu, 1, false); }
float n_lam_fade(float x, float y) { return fnl(vec2(x, y), LAM_FADE_FREQ, 0x9e3779b9u, 2, false); }
float n_moss(float x, float y) { return fnl(vec2(x, y), MOSS_FREQ, 0x9e3779b1u, 1, false); }
float n_root(float x, float y) { return fnl(vec2(x, y), ROOT_FREQ, 0x7feb352du, 1, false); }

// ---- `BeddingTone`, exact. ----
float depth_m_exact(int row) { return float(row - SURFACE_ROW) / CELLS_PER_METRE; }

float tone_depth_boost(int row) {
	float frac = clamp(depth_m_exact(row) / TONE_BOOST_FULL_M, 0.0, 1.0);
	return 1.0 + frac * TONE_BOOST_AT_FLOOR;
}

float bedding_metres(float x, float y) {
	float xm = x / CELLS_PER_METRE;
	float ym = y / CELLS_PER_METRE;
	return ym + sin(xm * 0.055) * 2.4 + sin(xm * 0.021) * 3.6;
}

float strata(float col, float row) {
	float y = bedding_metres(col, row);
	float n = sin(y * 0.34) * 0.46 + sin(y * 0.88) * 0.36 + sin(y * 1.62) * 0.18;
	return n * STRATA_AMOUNT;
}

float cell_jitter(float col, float row) {
	float x = col / CELLS_PER_METRE;
	float y = row / CELLS_PER_METRE;
	float n = sin(x * 0.37 + y * 0.21) + sin(x * 0.13 - y * 0.41) + sin((x + y) * 0.27);
	return n / 3.0 * 0.06;
}

vec2 cell_tone(int col, int row, bool bedded, int g) {
	float boost = tone_depth_boost(row);
	float pull = GRAM_BEDDING[g];
	return vec2(cell_jitter(float(col), float(row)) * boost,
		(bedded ? strata(float(col), float(row)) * pull : 0.0) * boost);
}

vec3 apply_tone(vec3 base, vec2 tone) {
	vec3 c = tone.x > 0.0 ? lightened(base, tone.x) : darkened(base, -tone.x);
	if (tone.y > 0.0) {
		return mix(lightened(c, tone.y * 0.85), STRATA_WARM, tone.y * 0.30);
	}
	return mix(darkened(c, -tone.y * 1.05), STRATA_COOL, -tone.y * 0.20);
}

// `MaterialLook.cell_color`: the speck (decided on the CPU) or the matrix -- base, depth-darkened, toned.
vec3 cell_color(int mat, int col, int row, int g, bool speck, bool lit) {
	if (mat == unknown_index) {
		return DEBUG_BROWN;
	}
	vec4 base = texelFetch(palette, ivec2(mat, 0), 0);
	vec4 nug = texelFetch(palette, ivec2(mat, 1), 0);
	if (speck) {
		return lit ? lightened(nug.rgb, SPECK_LIGHTEN) : darkened(nug.rgb, SPECK_DARKEN);
	}
	float depth_m = floor(float(row - SURFACE_ROW) / CELLS_PER_METRE);
	float frac = clamp(depth_m / DEPTH_DARKEN_FULL_M, 0.0, 1.0);
	vec3 c = darkened(base.rgb, frac * base.a);
	bool country = nug.a < 0.5;
	return apply_tone(c, cell_tone(col, row, country, g));
}

// ---- `BedSequence`, exact: its hashes mask to 32 bits at every step, so uint arithmetic IS the CPU's. ----
float bed_unit(int id, int salt) {
	uint h = uint(id) * 374761393u + uint(salt) * 668265263u + uint(world_seed) * 1274126177u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	h = h ^ (h >> 16u);
	return float(h & 0xFFFFFFu) / 16777216.0;
}

float bed_boundary(float b, float x_m, int j, int lane, float facies) {
	int id = j * 2 + lane;
	if (bed_unit(id, 1) < ABSENT) {
		return 0.0;
	}
	float pos = (float(j) + 0.5 * float(lane)) * SPACING_M + (bed_unit(id, 2) - 0.5) * JITTER_M;
	pos += WOBBLE_M * sin(x_m * WOBBLE_FREQ + bed_unit(id, 5) * TAU);
	float half_w = bed_unit(id, 3) < THICK_SHARE ? HALF_THICK_M : HALF_THIN_M;
	if (abs(b - pos) >= half_w) {
		return 0.0;
	}
	return facies * (STRENGTH_FLOOR + (1.0 - STRENGTH_FLOOR) * bed_unit(id, 4));
}

float bed_weight(float b, float x_m, float n) {
	int k = int(floor(b / SPACING_M));
	float odd_weight = smoothstep(THICK_LO, THICK_HI, n);
	float fine_weight = smoothstep(FINE_LO, FINE_HI, n) * FINE_WEIGHT;
	float best = 0.0;
	for (int j = k - 1; j <= k + 1; j++) {
		float facies = ((j & 1) == 0) ? 1.0 : odd_weight;
		if (facies > 0.0) {
			best = max(best, bed_boundary(b, x_m, j, 0, facies));
		}
		if (fine_weight > 0.0) {
			best = max(best, bed_boundary(b, x_m, j, 1, fine_weight));
		}
	}
	if (best <= 0.0) {
		return 0.0;
	}
	return best * clamp(0.7 + 0.5 * n, FADE_FLOOR, 1.0);
}

float lamina(float x, float y) {
	float n = n_lam_fade(x, y);
	return bed_weight(bedding_metres(x, y), x / CELLS_PER_METRE, n);
}

// ---- The neighbour probes, on the data texture's R. Beyond the image is AIR, which is what
// `Observation.material_at` answers beyond its window; the margin keeps every probe of a RECT cell inside
// the image, so this boundary is only ever reached by a margin cell nothing reads. ----
bool solid_at(sampler2D tex, ivec2 t, ivec2 sz) {
	if (t.x < 0 || t.y < 0 || t.x >= sz.x || t.y >= sz.y) {
		return false;
	}
	return texelFetch(tex, t, 0).r > 0.001;
}

// `RockTone._air_weight`: orthogonals 1.0, diagonals 0.5.
float air_weight(sampler2D tex, ivec2 t, ivec2 sz) {
	float w = 0.0;
	w += solid_at(tex, t + ivec2(-1, 0), sz) ? 0.0 : 1.0;
	w += solid_at(tex, t + ivec2(1, 0), sz) ? 0.0 : 1.0;
	w += solid_at(tex, t + ivec2(0, -1), sz) ? 0.0 : 1.0;
	w += solid_at(tex, t + ivec2(0, 1), sz) ? 0.0 : 1.0;
	w += solid_at(tex, t + ivec2(-1, -1), sz) ? 0.0 : 0.5;
	w += solid_at(tex, t + ivec2(1, -1), sz) ? 0.0 : 0.5;
	w += solid_at(tex, t + ivec2(-1, 1), sz) ? 0.0 : 0.5;
	w += solid_at(tex, t + ivec2(1, 1), sz) ? 0.0 : 0.5;
	return w;
}

// `RockTone._sky_form`: only the NEAREST opening each way counts.
float sky_form(sampler2D tex, ivec2 t, ivec2 sz) {
	float f = 0.0;
	for (int d = 0; d < FORM_REACH; d++) {
		if (!solid_at(tex, t + ivec2(0, -d - 1), sz)) {
			f += FORM_LIFT * (1.0 - float(d) / float(FORM_REACH));
			break;
		}
	}
	for (int d = 0; d < FORM_REACH; d++) {
		if (!solid_at(tex, t + ivec2(0, d + 1), sz)) {
			f -= FORM_SINK * (1.0 - float(d) / float(FORM_REACH));
			break;
		}
	}
	return f;
}

// `SurfaceTone.air_distance`, which `RockTone._top_air_distance` is at dir -1, reach RIM_DEPTH.
int air_distance(sampler2D tex, ivec2 t, ivec2 sz, int dir, int reach) {
	for (int d = 0; d < reach; d++) {
		if (!solid_at(tex, t + ivec2(0, dir * (d + 1)), sz)) {
			return d;
		}
	}
	return NONE;
}

// ---- `RockTone.shade`, term by term. ----
float micro_texture(float x, float y, int g) {
	float gx = x * GRAIN_XSTRETCH * GRAM_XSTR[g];
	float gamp = GRAIN_AMP * GRAM_GRAIN[g];
	float grain = n_grain(gx, y) * gamp + n_grain2(gx, y) * (gamp * 0.35);
	float stone = n_stone(x, y);
	if (stone > STONE_THRESH) {
		grain -= STONE_DARKEN * GRAM_CLUMP[g] * smoothstep(0.0, 1.0, (stone - STONE_THRESH) * STONE_RAMP);
	}
	float crackv = abs(n_crack(x * GRAM_SEAM_X[g], y * GRAM_SEAM_Y[g]));
	float band = CRACK_BAND * GRAM_SEAM_W[g];
	if (crackv < band) {
		grain -= CRACK_DARKEN * GRAM_SEAM[g] * smoothstep(0.0, 1.0, 1.0 - crackv / band);
	}
	return grain;
}

vec3 rock_shade(vec3 base, int col, int row, int g, sampler2D tex, ivec2 t, ivec2 sz, int dist) {
	float x = float(col);
	float y = float(row);
	float drift = n_drift(x * 0.35 + 500.0, y * 0.35) * 0.07;
	drift += n_patch(x, y) * PATCH_AMP * GRAM_PATCH[g];
	float grain = micro_texture(x, y, g);
	vec3 c = base;
	float hx = n_huex(x, y);
	float hy = n_huey(x, y);
	vec3 pole = hx < -0.15 ? HUE_TEAL : (hx > 0.20 ? HUE_BROWN : HUE_VIOLET);
	c = mix(c, pole, HUE_AMP * clamp(0.5 + 0.5 * hy, 0.15, 1.0));
	float ao = 0.0;
	float form = 0.0;
	float rim = 0.0;
	float rim_warm = 0.0;
	// B says whether any neighbour term can be live at all: past FORM_REACH every probe finds rock.
	if (dist <= FORM_REACH) {
		ao = air_weight(tex, t, sz);
		form = sky_form(tex, t, sz);
		if (ao > AO_TEAL_GATE) {
			c = mix(c, SHADOW_TEAL, clamp(ao / 6.0, 0.0, 1.0) * AO_TEAL_AMOUNT);
		}
		int top = air_distance(tex, t, sz, -1, RIM_DEPTH);
		if (top >= 0 && top < RIM_DEPTH && solid_at(tex, t + ivec2(0, 1), sz)) {
			float lip = 1.0 - float(top) / float(RIM_DEPTH);
			rim = RIM_LIGHT * lip;
			rim_warm = RIM_WARM * lip;
		}
	}
	float lam = lamina(x, y) * GRAM_LAMINA[g];
	float vmul = max(VALUE_FLOOR, 1.0 - AO_PER_NEIGHBOUR * ao + grain * (1.0 - lam) + form)
		* (1.0 - LAM_DARKEN * lam);
	drift -= LAM_ADD * lam;
	return clamp(vec3(c.r * vmul + drift + rim + rim_warm, c.g * vmul + drift + rim,
		c.b * vmul + drift + rim), 0.0, 1.0);
}

// ---- `SurfaceTone.soil` and `SurfaceTone.shade`. ----
vec3 soil(vec3 c, int col, int row, int depth) {
	if (depth < 0 || depth >= SOIL_ROWS) {
		return c;
	}
	float strength = clamp(float(SOIL_ROWS - depth) / (float(SOIL_ROWS) * 0.34), 0.0, 1.0);
	vec3 o = c;
	if (depth < HUMUS_ROWS) {
		float d = float(depth) / float(HUMUS_ROWS);
		o = darkened(o, HUMUS_DARKEN * smoothstep(0.0, 0.4, d) * (1.0 - d));
	} else if (depth < HUMUS_ROWS + SUBSOIL_ROWS) {
		float t = float(depth - HUMUS_ROWS) / float(SUBSOIL_ROWS);
		o = mix(o, SUBSOIL_POLE, SUBSOIL_WARM * (1.0 - t) * strength);
	}
	float peb = n_stone(float(col) * COBBLE_SCALE, float(row) * COBBLE_SCALE);
	if (peb > COBBLE_THRESH) {
		float gain = 1.0 + COBBLE_GAIN * smoothstep(0.0, 1.0, (peb - COBBLE_THRESH) * STONE_RAMP) * strength;
		o = min(o * gain, vec3(1.0));
	} else if (peb < CLAST_THRESH) {
		o = darkened(o, CLAST_DARKEN * smoothstep(0.0, 1.0, (CLAST_THRESH - peb) * STONE_RAMP) * strength);
	}
	float rn = n_root(float(col) * 1.9, float(row) * 0.18);
	if (rn > ROOT_GATE) {
		float reach = ROOT_MAX * clamp((rn - ROOT_GATE) * 3.0, 0.0, 1.0);
		if (float(depth) < reach) {
			o = darkened(o, ROOT_DARKEN * (1.0 - float(depth) / reach));
		}
	}
	return o;
}

vec3 surface_shade(vec3 base, int col, int row, int scode, sampler2D tex, ivec2 t, ivec2 sz, int dist) {
	vec3 o = base;
	if (scode != 0) {
		o = soil(o, col, row, scode - 2);
	}
	float alive = clamp((MOSS_DEAD_M - depth_m_exact(row)) / (MOSS_DEAD_M - MOSS_LUSH_M), 0.0, 1.0);
	// `dist > MOSS_DEPTH` is the CPU's own outcome, not an approximation: both probes reach 3 rows, and
	// no air within L1 3 means no air within 3 rows either way.
	if (alive <= 0.0 || dist > MOSS_DEPTH) {
		return o;
	}
	int top = air_distance(tex, t, sz, -1, MOSS_DEPTH);
	if (top != NONE) {
		float patch = n_moss(float(col), float(row) * 0.6);
		if (patch > -0.28) {
			float band = (1.0 - float(top) / float(MOSS_DEPTH)) * clamp((patch + 0.28) * 1.5, 0.0, 1.0);
			return mix(o, MOSS_COLOR, 0.55 * band * alive);
		}
		return o;
	}
	int hang = air_distance(tex, t, sz, 1, HANG_DEPTH);
	if (hang != NONE) {
		float hp = n_moss(float(col) * 0.9, float(row) * 0.9 + 90.0);
		if (hp > HANG_GATE) {
			float hband = (1.0 - float(hang) / float(HANG_DEPTH)) * clamp((hp - HANG_GATE) * 3.0, 0.0, 1.0);
			return mix(o, darkened(MOSS_COLOR, 0.12), 0.55 * hband * alive);
		}
	}
	return o;
}

void fragment() {
	// THE CELL FROM THE WORLD POSITION, NOT FROM UV: the quad covers the paint rect while the image
	// covers that rect grown by the margin, so a UV-derived texel would be wrong by the margin.
	ivec2 cell = ivec2(floor(world_px / float(cell_px)));
	ivec2 sz = textureSize(data_tex, 0);
	ivec2 t = cell - span_origin;
	vec4 d = (t.x < 0 || t.y < 0 || t.x >= sz.x || t.y >= sz.y) ? vec4(0.0) : texelFetch(data_tex, t, 0);
	int mat = int(d.r * 255.0 + 0.5);
	if (mat == 0) {
		// Air: the CPU painter fills nothing here, so neither does this and the wall plane below shows.
		COLOR = vec4(0.0);
	} else {
		int col = cell.x;
		int row = cell.y;
		int gbyte = int(d.g * 255.0 + 0.5);
		int g = gbyte & G_GRAM_MASK;
		bool speck = (gbyte & G_SPECK_BIT) != 0;
		bool lit = (gbyte & G_FACET_BIT) != 0;
		int dist = int(d.b * 255.0 + 0.5);
		int abyte = int(d.a * 255.0 + 0.5);
		bool root = (abyte & A_ROOT_BIT) != 0;
		int scode = abyte & A_CODE_MASK;
		vec3 fill = cell_color(mat, col, row, g, speck, lit);
		fill = rock_shade(fill, col, row, g, data_tex, t, sz, dist);
		fill = surface_shade(fill, col, row, scode, data_tex, t, sz, dist);
		// `TerrainPainter.cell_fill`'s cap: the walked surface cell IS the cap, and a root column's next
		// row leans half toward the cap's dark.
		vec4 cap = texelFetch(palette, ivec2(mat, 2), 0);
		if (scode != 0 && cap.a > 0.0) {
			if (scode == A_SURFACE) {
				fill = cap.rgb;
			} else if (scode == A_SURFACE + 1 && root) {
				fill = mix(fill, darkened(cap.rgb, CAP_ROOT_DARKEN), CAP_ROOT_MIX);
			}
		}
		COLOR = vec4(fill, 1.0);
	}
}
