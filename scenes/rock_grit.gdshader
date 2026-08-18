shader_type canvas_item;

// SUB-CELL TOOTH FOR THE ROCK.
//
// The molded terrain texture holds one texel per 8-pixel world cell and is drawn NEAREST, so the rock has
// exactly zero detail below that cell. At the default zoom one cell covers about a dozen screen pixels,
// which means the ground the player looks at all game is literally a field of flat squares — and it sits
// directly beside a miner sprite drawn at one-pixel detail, so the eye reads the whole world as the blurred
// thing behind the sharp thing. Magnify a lamp-lit shot 3x and it looks like compression artifacts.
//
// This is NOT the crisp-tiles-versus-molded-terrain question. That fork is about whether cell BOUNDARIES
// are hard or dissolved, and this shader deliberately does not touch boundaries. It is about what lives
// INSIDE a cell, and the answer in both aesthetics is "something": Terraria's tiles carry hand-drawn
// detail at texture resolution, Noita's rock is per-pixel by construction. Ours carried nothing.
//
// The grain is locked to WORLD space, not to the screen. That distinction is the whole point — the screen
// post-pass already has a film grain and it cannot do this job, because a grain that sits still while the
// rock slides underneath it reads as dirt on the lens. Tooth that travels with the surface reads as the
// surface being rough.
//
// Two octaves, because one is television static: a per-pixel hash for tooth, and a coarser one for the
// mottle that keeps the tooth from looking uniform. Both are mostly MULTIPLICATIVE so a dark face gets
// proportionally less of them and the shadows do not fizz, with a small additive floor so rock that the
// veil has taken most of the way down still has something in it rather than nothing.

uniform float grit_mul : hint_range(0.0, 0.3) = 0.075;    // per-world-pixel tooth, as a fraction of value
uniform float grit_add : hint_range(0.0, 0.05) = 0.010;   // ...and its floor, so dark rock keeps some
uniform float mottle_mul : hint_range(0.0, 0.3) = 0.055;  // the coarser second octave
uniform float mottle_scale : hint_range(1.0, 16.0) = 5.0; // world px per mottle sample

varying vec2 world_pos;

// Cheap hash noise — no texture, stable in world space, so the same rock is the same rock every frame.
float hash(vec2 p) {
	p = fract(p * vec2(127.11, 311.71));
	p += dot(p, p + 34.79);
	return fract(p.x * p.y);
}

void vertex() {
	world_pos = VERTEX;                 // the fine layer sits at the world origin, so local IS world
}

// COLOR arrives ALREADY holding texture x modulate — sampling TEXTURE again and multiplying it back in
// squares the value, which is not a subtle bug: it darkened the whole world to 0.4x and took a while to
// pin down precisely because an inert version of this shader did it too. Only ever MODULATE what is here.
void fragment() {
	// SOLID ROCK ONLY, and this used to be step(0.004, COLOR.a) — which is true of the VOID as well,
	// because fine_terrain paints the back wall opaque and clears only the sky. So this pass spent its
	// life putting rock's tooth on the air, and the two came out equally textured: measured air grain
	// 2.06 against rock 1.83, the void slightly rougher than the material. fine_terrain now stamps air
	// with VOID_ALPHA (254), one level below solid, so the mask has something true to read.
	float solid = step(0.998, COLOR.a);   // air gets none of this; no branch, no early return
	float tooth = (hash(floor(world_pos)) - 0.5) * solid;
	float mottle = (hash(floor(world_pos / mottle_scale) + 17.0) - 0.5) * solid;
	float k = 1.0 + tooth * 2.0 * grit_mul + mottle * 2.0 * mottle_mul;
	COLOR.rgb = COLOR.rgb * k + tooth * 2.0 * grit_add;
}
