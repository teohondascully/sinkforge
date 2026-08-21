shader_type canvas_item;
render_mode blend_add;

// The tooth that survives the dark: the same job as rock_grit.gdshader, done above the veil.
//
// rock_grit runs on the fine-terrain layer at z=-9. The darkness veil is a multiply layer at z=50, so
// every texture the terrain paints, including rock_grit's `grit_add` (the additive floor written
// specifically "so rock that the veil has taken most of the way down still has something in it"), is
// scaled by exactly the factor that made the rock dark. Outside the lamp the sampled median is
// 8.7/255, so to land 2 levels through that veil the floor would have to be 20 levels in lit rock.
// The mechanism cannot reach its own stated purpose from below the multiply. That is not a tuning
// failure, it is a layer-order one, and it is why raising GRAIN_AMP, adding an additive companion, and
// raising the noise frequency all came to nothing (58% -> 55% -> 59%, against a 75% floor).
//
// So this draws the same fine texture again, above the veil, and adds tooth in absolute levels. Being
// additive and post-veil, what it writes is what arrives.
//
// It masks on VOID_ALPHA, which is the other half of the same story: fine_terrain paints the back wall
// opaque, so rock_grit's `step(0.004, COLOR.a)`, under a comment reading "air gets none of this", was
// true of the void as well. Before that was fixed, air carried more tooth than rock (grain 2.06 vs
// 1.83). Texturing both equally cannot separate them, at any amplitude.
//
// Positive only, because an additive pass cannot subtract. The consequence is honest and small: rock
// gains about `tooth_add/2` of mean brightness where it is nearly black, which also puts solid rock
// above open air in value. Without it the two invert, air 9.0 against rock 8.5, so the thing you walk
// through reads as more substantial than the thing you dig. This is not a global brighten: air, sky and
// every lit surface are untouched, and the amount is a couple of levels on the darkest rock in the frame.

// The back wall deliberately gets no share of this tooth, and giving it one was measured and rejected.
//
// The mask below is `step(0.998, src.a)`, solids only, and the note above explains why: before it, air
// carried more tooth than rock. That was right about the void and questionable about the back wall, which
// is not void but the earth you did not dig, one plane behind the face. And the wall is measurably flat:
// inside the lamp at 22 rows, local texture (mean |luma delta| to the neighbouring pixel) is 4.13 on rock
// against 2.02 on the wall, at medians of 31.5 and 18.8. The hole is not dark, it is smooth, and similar
// value with no structure is exactly what a cut-out looks like. So the complaint about it is real, and
// the word "black" points the wrong way. Dropping this pass costs the rock 1.43 levels/px and the wall
// nothing, so this one mask is two thirds of the gap.
//
// A `wall_frac = 0.5` band was built and measured. It works, and it is not worth it:
//
//     wall texture   2.02 -> 2.30   (+14%, and the wall's median rises 2 levels with it)
//     contact-edge detectability   95% -> 94%,  edge step median 15.5 -> 14.9
//     lit edge step  23.27 -> 21.57      polarity unchanged at 97%
//
// The gain is subliminal: across the frame 55% of pixels move by >=2 levels but only 0.04% by >=10,
// and the cost lands on the rock/void gate, a property already proved and guarded by "existing
// rock/void gate must not regress". Trading a guarded property for one below the perceptual threshold is
// the wrong trade even when both are small.
//
// Why it cannot be fixed by tuning, which is the part worth keeping: this pass is `blend_add` and
// positive only, so any texture it gives the wall also raises the wall's mean, and raising the wall's mean
// is precisely what narrows the face step. The wall does not need brightness, it needs structure: a
// zero-mean texture that darkens as much as it lightens. An additive pass cannot make one at any
// amplitude. A post-veil mix layer can, and one now exists at z 53 (`_marks`); that is where a back-wall
// grain belongs, not here.
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
