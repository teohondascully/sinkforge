shader_type canvas_item;
render_mode blend_add;

// THE TOOTH THAT SURVIVES THE DARK — the same job as rock_grit.gdshader, done ABOVE the veil.
//
// rock_grit runs on the fine-terrain layer at z=-9. The darkness veil is a MULTIPLY layer at z=50. So
// every texture the terrain paints — including rock_grit's `grit_add`, the additive floor written
// specifically "so rock that the veil has taken most of the way down still has something in it" — is
// scaled by exactly the factor that made the rock dark. MEASURED: outside the lamp the sampled median is
// 8.7/255, and to land ±2 levels through that veil the floor would have to be ±20 levels in LIT rock.
// The mechanism cannot reach its own stated purpose from below the multiply. That is not a tuning
// failure; it is a layer-order one, and it is why raising GRAIN_AMP, adding an additive companion, and
// raising the noise FREQUENCY all measured as nothing (58% -> 55% -> 59%, against a 75% floor).
//
// So this draws the same fine texture again, above the veil, and adds tooth in ABSOLUTE levels. Being
// additive and post-veil, what it writes is what arrives.
//
// It masks on VOID_ALPHA, which is the other half of the same story: fine_terrain paints the back wall
// opaque, so rock_grit's `step(0.004, COLOR.a)` — under a comment reading "air gets none of this" — was
// true of the void as well. Measured before the fix, air carried MORE tooth than rock (grain 2.06 vs
// 1.83). Texturing both equally cannot separate them, at any amplitude.
//
// POSITIVE ONLY, because an additive pass cannot subtract. The consequence is honest and small: rock
// gains about `tooth_add/2` of mean brightness where it is nearly black, which also puts solid rock
// ABOVE open air in value — currently inverted, air 9.0 against rock 8.5, so the thing you walk through
// reads as more substantial than the thing you dig. This is not a global brighten: air, sky and every lit
// surface are untouched, and the amount is a couple of levels on the darkest rock in the frame.

uniform float tooth_add : hint_range(0.0, 0.06) = 0.030;   // absolute value added at peak, post-veil
uniform float mottle_add : hint_range(0.0, 0.03) = 0.006;  // coarser octave so the tooth is not uniform
uniform float mottle_scale : hint_range(1.0, 16.0) = 5.0;  // world px per mottle sample

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
	// Solid rock only. 254/255 = 0.996 is air with something behind it; 1.0 is rock; 0.0 is sky.
	float solid = step(0.998, src.a);
	float tooth = hash(floor(world_pos)) * tooth_add;
	float mottle = hash(floor(world_pos / mottle_scale) + 17.0) * mottle_add;
	COLOR = vec4(vec3((tooth + mottle) * solid), 1.0);
}
