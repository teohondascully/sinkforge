shader_type canvas_item;
render_mode blend_add;

// THE TOOTH: the one rock pass that draws ABOVE the darkness veil, adding in absolute value levels. Lifted
// whole from `legacy/scenes/rock_tooth.gdshader` (69 lines) for A' step 6p (D0379). Legacy's header:
// "everything painted into the bake is multiplied by a veil that takes underground rock to a mean of
// ~10/255, so a mark written there is divided by the dark. This pass is what survives it."
//
// AND IT MUST BE DIRECTION-AWARE, which legacy learned by measurement (`check_material_grammar`): an
// isotropic per-pixel hash "raised the horizontal and vertical gradients by the same amount everywhere and
// flattened the grammar underneath it" -- stone's rendered anisotropy +0.019 against earth's +0.022, and
// with the pass off the gap was 0.038, six times wider. So the tooth asks what it is drawing over:
// `gram_tex` is the grammar map on the same world rect as the bake (`GramMap`, one byte per cell), and
// the hash cell is stretched to match: soil stays square, bedded rock runs flat, massive rock runs steep.
// hint_default_black means an unbound sampler reads as clastic: a missing map is the old isotropic
// behaviour rather than a wrong one.
//
// UNITS: legacy's cells are in ITS world pixels (32 to the metre); ours are 16, so `world_pos` is doubled
// before hashing to keep legacy's 1/32-metre tooth cell (the same conversion `rock_grit.gdshader` makes).
const float TOOTH_SAMPLES_PER_WORLD_PX = 2.0;

uniform sampler2D gram_tex : hint_default_black, filter_nearest, repeat_disable;

uniform float tooth_add : hint_range(0.0, 0.12) = 0.060;   // absolute value added at peak, post-veil
uniform float mottle_add : hint_range(0.0, 0.03) = 0.006;  // coarser octave so the tooth is not uniform
uniform float mottle_scale : hint_range(1.0, 16.0) = 5.0;  // legacy world px per mottle sample

// Hash cell in legacy world px per grammar, as (width, height). A cell wider than it is tall makes the
// field change slowly along x and quickly along y, which is a flat lamina; the transpose is a steep one.
uniform vec2 cell_clastic = vec2(1.0, 1.0);   // soil: granular, no direction
uniform vec2 cell_bedded = vec2(3.0, 1.0);    // bedding: features run flat
uniform vec2 cell_massive = vec2(1.0, 3.0);   // massive: seams dip steeply

varying vec2 world_pos;

float hash(vec2 p) {
	p = fract(p * vec2(127.11, 311.71));
	p += dot(p, p + 34.79);
	return fract(p.x * p.y);
}

void vertex() {
	world_pos = VERTEX * TOOTH_SAMPLES_PER_WORLD_PX;
}

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	float solid = step(0.998, src.a);
	// 0 clastic, 1 bedded, 2 massive -- one byte per cell, so the read is exact rather than a threshold on
	// a blended value; the sampler is nearest for that reason.
	float g = texture(gram_tex, UV).r * 255.0;
	vec2 cell = cell_clastic;
	if (g > 1.5) {
		cell = cell_massive;
	} else if (g > 0.5) {
		cell = cell_bedded;
	}
	float tooth = hash(floor(world_pos / cell)) * tooth_add;
	float mottle = hash(floor(world_pos / mottle_scale) + 17.0) * mottle_add;
	COLOR = vec4(vec3((tooth + mottle) * solid), 1.0);
}
