shader_type canvas_item;

// Sub-cell tooth for the rock. The molded terrain texture holds one texel per 8-pixel world cell and is
// drawn NEAREST, so rock carries no detail below one cell; at default zoom a cell covers about a dozen
// screen pixels. This pass textures the inside of a cell and leaves cell boundaries alone.
//
// The grain is in WORLD space, not screen space. The screen post-pass already carries a film grain and
// cannot do this job: a grain that sits still while the rock slides underneath it reads as dirt on the
// lens, while tooth that travels with the surface reads as roughness. Two octaves, a per-pixel hash for
// the tooth and a coarser one for the mottle, so it does not resolve as uniform static.

// Mostly multiplicative, so a dark face gets proportionally less tooth and the shadows do not fizz.
// The additive floor is still below the darkness veil, which scales it with everything else, so it
// cannot hold a level in dark rock. rock_tooth.gdshader carries the post-veil floor that can.
uniform float grit_mul : hint_range(0.0, 0.3) = 0.075;    // per-world-pixel tooth, as a fraction of value
uniform float grit_add : hint_range(0.0, 0.05) = 0.010;   // its additive floor
uniform float mottle_mul : hint_range(0.0, 0.3) = 0.055;  // the coarser second octave
uniform float mottle_scale : hint_range(1.0, 16.0) = 5.0; // world px per mottle sample

varying vec2 world_pos;

// Cheap hash noise: no texture, stable in world space, so the same rock is the same rock every frame.
float hash(vec2 p) {
	p = fract(p * vec2(127.11, 311.71));
	p += dot(p, p + 34.79);
	return fract(p.x * p.y);
}

void vertex() {
	world_pos = VERTEX;                 // the fine layer sits at the world origin, so local is world
}

// COLOR arrives already holding texture x modulate. Sampling TEXTURE again and multiplying it back in
// squares the value, darkening the world to about 0.4x. Only ever modulate what is already here.
void fragment() {
	// Solid rock only. fine_terrain paints the back wall opaque and clears only the sky, so an alpha
	// test against 0 is true of the void as well and would texture air as heavily as rock. Air is
	// stamped with VOID_ALPHA (254), one level below solid, so this mask can separate the two.
	float solid = step(0.998, COLOR.a);   // no branch, no early return
	float tooth = (hash(floor(world_pos)) - 0.5) * solid;
	float mottle = (hash(floor(world_pos / mottle_scale) + 17.0) - 0.5) * solid;
	float k = 1.0 + tooth * 2.0 * grit_mul + mottle * 2.0 * mottle_mul;
	COLOR.rgb = COLOR.rgb * k + tooth * 2.0 * grit_add;
}
