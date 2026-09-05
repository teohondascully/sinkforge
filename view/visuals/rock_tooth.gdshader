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
// UNITS: legacy's cells are in ITS world pixels (32 to the metre); ours are 16. D0379 doubled `world_pos`
// to keep legacy's 1/32-metre tooth cell. THAT CELL WAS THE STATIC (D0398): at the player's zoom of 2 a
// 1/32 m cell is ONE SCREEN PIXEL, and +0.06 absolute over rock the veil has taken to a mean near 0.05
// doubles the rock's value pixel by pixel -- the "television static" of VISUAL_QUEUE V02, sitting on top
// of a bake whose laminae and plates could not be seen through it. Legacy's fine cell was 8 px over a 1 px
// tooth; ours is 4 px, and the same tooth at the same absolute size is twice as loud against it. The
// tooth cell is 1/8 m now (a sample every 2 world px, 4 screen px at zoom 2: grit, a quarter of a terrain
// cell) at half the weight, and the mottle is a broader, slightly stronger lift so a face still varies.
const float TOOTH_SAMPLES_PER_WORLD_PX = 0.5;

uniform sampler2D gram_tex : hint_default_black, filter_nearest, repeat_disable;

uniform float tooth_add : hint_range(0.0, 0.12) = 0.030;   // absolute value added at peak, post-veil (was 0.060)
uniform float mottle_add : hint_range(0.0, 0.03) = 0.012;  // coarser octave so the tooth is not uniform (was 0.006)
uniform float mottle_scale : hint_range(1.0, 16.0) = 4.0;  // tooth samples per mottle sample: 8 world px, two cells

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
