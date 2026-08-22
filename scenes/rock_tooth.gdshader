shader_type canvas_item;
render_mode blend_add;

// The tooth: the one rock pass that draws ABOVE the darkness veil, adding in absolute value levels.
// See the standing constraint at the head of scenes/fine_terrain.gd -- everything painted into the bake
// is multiplied by a veil that takes underground rock to a mean of ~10/255, so a mark written there is
// divided by the dark. This pass is what survives it.
//
// AND IT USED TO CARRY NO DIRECTION, which cost the material grammar its second cue. The grammar states
// two things about a material: how loud its surface is, and which way it runs. The loudness reached the
// frame; the direction did not. `check_material_grammar` measured stone's rendered anisotropy at +0.019
// against earth's +0.022, on a scale where +-1 is fully directional -- a difference of 0.003, and
// indistinguishable from that layer's earth-vs-earth null at +0.019/+0.017. Two materials whose seam
// sampling differs by 3.40 against 1.00 on x were rendering as the same isotropic field.
//
// The cause was here. `hash(floor(world_pos))` is per-world-pixel white noise: the highest-frequency,
// most isotropic signal available, added on top of everything else at the largest amplitude any rock
// mark gets. It raised the horizontal and vertical gradients by the same amount everywhere and flattened
// the grammar underneath it. The layer's own TOOTH OFF arm had been printing the evidence all along --
// with this pass disabled the earth/stone anisotropy gap is 0.038 against 0.019, six times wider than
// with it on.
//
// So the tooth now asks what it is drawing over. `gram_tex` is the coarse GRAM_* map on the same world
// rect as the bake, so it samples with the identical UV, and the hash cell is stretched to match: soil
// stays square because loose ground has no grain, bedded rock runs flat, and massive rock runs steep.
// hint_default_black means an unbound sampler reads as GRAM_CLASTIC, so a missing map is the old
// isotropic behaviour rather than a wrong one.
uniform sampler2D gram_tex : hint_default_black, filter_nearest, repeat_disable;

uniform float tooth_add : hint_range(0.0, 0.12) = 0.060;   // absolute value added at peak, post-veil
uniform float mottle_add : hint_range(0.0, 0.03) = 0.006;  // coarser octave so the tooth is not uniform
uniform float mottle_scale : hint_range(1.0, 16.0) = 5.0;  // world px per mottle sample

// Hash cell in world px per grammar, as (width, height). A cell wider than it is tall makes the field
// change slowly along x and quickly along y, which is a flat lamina; the transpose is a steep one. The
// measuring window steps 3px, so an elongation of 3 is what it takes for the long axis to still be
// correlated at the sample spacing while the short axis is not.
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
	world_pos = VERTEX;
}

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	float solid = step(0.998, src.a);
	// 0 clastic, 1 bedded, 2 massive -- one byte per coarse cell, so the read is exact rather than a
	// threshold on a blended value; the sampler is nearest for that reason.
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
