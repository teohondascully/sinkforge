shader_type canvas_item;
render_mode blend_mul;

// THE VEIL ON THE GPU (D0390). `view/visuals/veil_painter.gd` is the specification: every term below is
// that file's expression -- `shade_at` (mass and key over the blurred openness), `skylight_ceiling`,
// `lamp_lift` (the three cuts), `VeilSources.compose` (every other light lifting each channel toward its
// tint) -- evaluated once per PIXEL here instead of once per metre-texel on the CPU. The CPU path built
// a lightmap over ~100K cells on every camera move (60-76 ms) and 4 ms of texels every frame; this pass
// costs the CPU two texture uploads when the window moves and a handful of uniforms a frame.
//
// Two textures, both cut from the observation with no per-cell loop: `cells_tex` is the window's material
// plane byte for byte (0 = air, anything else solid), `field_tex` the blurred openness at ONE TEXEL PER
// METRE -- legacy's own resolution, since legacy's cell WAS a metre -- sampled linearly so mass reads as a
// gradient. World px are what VERTEX carries for a root-level canvas item, so no camera math is needed.

uniform sampler2D cells_tex : filter_nearest, repeat_disable;
uniform sampler2D field_tex : filter_linear, repeat_disable;
uniform sampler2D walls_tex : filter_nearest, repeat_disable;   // the wall plane's ordinals; 0 = no wall
uniform sampler2D sky_tex : filter_nearest, repeat_disable;     // per window column: the first solid row under the sky
uniform bool has_walls = false;
uniform vec2 cells_origin_px;   // world px of the cells plane's top-left
uniform vec2 cells_size_px;
uniform vec2 field_origin_px;   // world px of the field's top-left (metre-aligned)
uniform vec2 field_size_px;
uniform vec2 field_texels;      // texels in the field
uniform float cell_px = 4.0;
uniform float cells_per_metre = 4.0;
uniform float surface_row = 80.0;

// `shade_at`
uniform float mass_shade = 0.55;
uniform float key_strength = 0.30;
uniform float key_gain = 3.0;
uniform float openness_saturate = 2.2;
// `skylight_ceiling` and legacy's `_skylight_alpha(row, surf)` (VeilLight.sky_light)
uniform float ambient_dark = 0.66;
uniform float sky_reach_m = 12.0;
uniform float surface_line_m = 2.0;
uniform float sky_fade_m = 16.0;
// legacy's colour of the dark (VeilLight): the deep's own tint, the void floor, the lamp's tint
uniform vec3 ambient_light = vec3(0.34, 0.35, 0.42);
uniform float void_floor = 0.35;
uniform vec3 lamp_tint = vec3(1.0, 0.95, 0.86);
// `cut_lift`
uniform float lamp_grain = 0.13;
uniform float lamp_window_gain = 2.2;
// `lamp_lift`: three cuts in CELLS -- xy centre, z radius, w strength (already scaled by depth)
uniform vec4 lamp_cuts[3];
// every other source (`VeilSources.cuts`): xy centre, z radius, w strength, all in cells; and its tint
const int MAX_CUTS = 64;
uniform vec4 cuts[MAX_CUTS];
uniform vec4 cut_tints[MAX_CUTS];
uniform int cut_count = 0;

varying vec2 world_px;

void vertex() {
	world_px = VERTEX;
}

// `VeilPainter.cut_lift`, with the grain keyed on the integer cell as the CPU keys it and the distance
// taken at the pixel's own position so a pool is round rather than stepped.
float cut_lift(vec4 cut, vec2 at_cells, vec2 cell) {
	float dist = length(at_cells - cut.xy);
	if (dist >= cut.z || cut.z <= 0.0) {
		return 0.0;
	}
	float f = 1.0 - dist / cut.z;
	float window = (1.0 - f) * clamp(f * lamp_window_gain, 0.0, 1.0);
	float g = (sin(cell.x * 1.7 + cell.y * 2.3) * 0.62 + sin(cell.x * 4.1 - cell.y * 3.7) * 0.38) * lamp_grain * window;
	return clamp(cut.w * f * f + g * cut.w, 0.0, 1.0);
}

void fragment() {
	vec2 at_cells = world_px / cell_px;
	vec2 cell = floor(at_cells);
	vec2 cuv = (world_px - cells_origin_px) / cells_size_px;
	bool inside = cuv.x >= 0.0 && cuv.x < 1.0 && cuv.y >= 0.0 && cuv.y < 1.0;
	bool solid = inside && texture(cells_tex, cuv).r > 0.001;
	// `VeilLight.sky_light`: darkness by depth, then the scatter under this column's own surface
	float depth_m = (at_cells.y - surface_row) / cells_per_metre;
	float d = ambient_dark * clamp((depth_m - surface_line_m) / sky_reach_m, 0.0, 1.0);
	float surf = inside ? texture(sky_tex, vec2(cuv.x, 0.5)).r : 1.0e9;
	float under = clamp((at_cells.y - surf) / (sky_fade_m * cells_per_metre), 0.0, 1.0);
	if (at_cells.y > surf) {
		d = mix(d, ambient_dark, under);
	}
	float sky = 1.0 - d;
	// legacy's VOID_FLOOR: air with no wall behind it, under the scatter band, is the darkest thing down here
	bool void_here = inside && !solid && (!has_walls || texture(walls_tex, cuv).r < 0.001);
	// `shade_at`
	float shade = 1.0;
	if (solid) {
		vec2 fuv = (world_px - field_origin_px) / field_size_px;
		vec2 step_m = vec2(0.0, 1.0 / field_texels.y);
		float o = texture(field_tex, fuv).r;
		float above = texture(field_tex, fuv - step_m).r;
		float below = texture(field_tex, fuv + step_m).r;
		float key = clamp((above - below) * key_gain, -1.0, 1.0);
		float mass = mix(1.0 - mass_shade, 1.0, clamp(o * openness_saturate, 0.0, 1.0));
		shade = mass * (1.0 + key_strength * key);
	}
	float s = shade * sky;
	if (void_here) {
		s *= mix(1.0, void_floor, under);
	}
	// `VeilLight.level_rgb`: the dark is a colour -- white at full light, `ambient_light` at the ambient
	float lit_s = clamp(s, 0.0, 1.0);
	vec3 cool = ambient_light * (lit_s / (1.0 - ambient_dark));
	vec3 rgb = mix(vec3(lit_s), cool, clamp((1.0 - lit_s) / ambient_dark, 0.0, 1.0));
	// `lamp_lift`: each cut lifts what the previous left; the lamp lifts toward ITS colour (legacy `_light_tint`)
	float lit = 0.0;
	for (int i = 0; i < 3; i++) {
		lit += (1.0 - lit) * cut_lift(lamp_cuts[i], at_cells, cell);
	}
	rgb += max(lamp_tint - rgb, vec3(0.0)) * clamp(lit, 0.0, 1.0);
	// `VeilSources.compose`: a cut only ever adds, per channel, toward its tint
	for (int i = 0; i < MAX_CUTS; i++) {
		if (i >= cut_count) {
			break;
		}
		float lift = cut_lift(cuts[i], at_cells, cell);
		if (lift <= 0.0) {
			continue;
		}
		vec3 target = cut_tints[i].rgb;
		rgb += max(target - rgb, vec3(0.0)) * lift;
	}
	COLOR = vec4(clamp(rgb, 0.0, 1.0), 1.0);
}
