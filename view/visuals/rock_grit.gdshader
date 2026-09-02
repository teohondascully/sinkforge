shader_type canvas_item;

// SUB-CELL TOOTH FOR THE ROCK. Ported from `legacy/scenes/rock_grit.gdshader` (D0331). Legacy names this
// build's exact symptom in its own header:
//
//   "The molded terrain texture holds one texel per 8-pixel world cell and is drawn NEAREST, so rock
//    carries no detail below one cell; at default zoom a cell covers about a dozen screen pixels. This
//    pass textures the inside of a cell and leaves cell boundaries alone."
//
// That is precisely what a capture of this build showed: the ore bodies read crisp, because their speck
// colours vary per cell, while country rock read as smooth brown mush -- every term in `RockTone` has a
// feature size of 9 to 22 CELLS, so nothing at all varies inside one cell.
//
// THE GRAIN IS IN WORLD SPACE, NOT SCREEN SPACE, and legacy is explicit that the two are different jobs:
// "The screen post-pass already carries a film grain and cannot do this job: a grain that sits still
// while the rock slides underneath it reads as dirt on the lens, while tooth that travels with the
// surface reads as roughness." `post_fx.gdshader` (D0328) is that screen-space grain; this is its
// world-space complement, and shipping only one of them is why the rock looked flat while the frame
// looked filmic.
//
// MOSTLY MULTIPLICATIVE, so a dark face gets proportionally less tooth and shadows do not fizz.

// THE PIXEL-SCALE CONVERSION, and the one thing that could not be copied unchanged. Legacy's world is
// 32 px per metre; this build's is 16. A tooth sampled per OUR world pixel would therefore be twice the
// physical size legacy authored, reading as coarse speckle rather than as roughness. Sampling at 2x our
// world pixel restores legacy's own 1/32-metre tooth cell. WG-4 regime question, D0305.
const float TOOTH_SAMPLES_PER_WORLD_PX = 2.0;

uniform float grit_mul : hint_range(0.0, 0.3) = 0.075;    // per-tooth-cell roughness, as a fraction of value
uniform float grit_add : hint_range(0.0, 0.05) = 0.010;   // its additive floor
uniform float mottle_mul : hint_range(0.0, 0.3) = 0.055;  // the coarser second octave
// Legacy's 5.0 is in ITS world pixels (5/32 metre). In ours that is (5/32) * 16 = 2.5.
uniform float mottle_scale : hint_range(0.5, 16.0) = 2.5;

varying vec2 world_pos;

// Cheap hash noise: no texture, stable in world space, so the same rock is the same rock every frame --
// which is also what keeps this deterministic for a capture, unlike a screen- or time-seeded grain.
float hash(vec2 p) {
	p = fract(p * vec2(127.11, 311.71));
	p += dot(p, p + 34.79);
	return fract(p.x * p.y);
}

void vertex() {
	world_pos = VERTEX;   // the quad sits at the world origin, so local is world
}

// COLOR arrives already holding texture x modulate. Sampling TEXTURE again and multiplying it back in
// squares the value, darkening the world to about 0.4x. Only ever modulate what is already here.
void fragment() {
	// OPAQUE CONTENT ONLY, and this is where the port deviates from legacy -- named rather than hidden.
	// Legacy stamps its back wall and eroded rock with VOID_ALPHA (254), one level below solid, so
	// `step(0.998, COLOR.a)` separates rock from wall and tooths only the rock. This build's painters
	// BLEND rather than stamp bytes: `WallPainter` draws its plane and then its cast-shadow overlay as
	// separate `draw_rect` calls, so a wall cell's final alpha is a blend result and lands anywhere
	// between 0.996 and 1.0 depending on how much AO fell on it -- straddling that very threshold.
	//
	// So the mask here is "did the bake draw anything opaque", which tooths the wall plane as well as the
	// rock. Legacy gives the wall its own quieter grain instead (WALL_GRAIN 0.055 against rock's tooth).
	// Recorded as a follow-up rather than faked: separating them needs the painters to stamp alpha the
	// way legacy does, which is a change to a painter shared with the non-baked path.
	float solid = step(0.5, COLOR.a);
	vec2 tooth_cell = floor(world_pos * TOOTH_SAMPLES_PER_WORLD_PX);
	float tooth = (hash(tooth_cell) - 0.5) * solid;
	float mottle = (hash(floor(world_pos / mottle_scale) + 17.0) - 0.5) * solid;
	float k = 1.0 + tooth * 2.0 * grit_mul + mottle * 2.0 * mottle_mul;
	COLOR.rgb = COLOR.rgb * k + tooth * 2.0 * grit_add;
}
