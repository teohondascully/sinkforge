shader_type canvas_item;

// Screen-space post pass (docs/MODERN_FEEL.md): a vignette + animated film grain + a whisper of
// chromatic aberration at the edges — the "lens" that makes the framebuffer read as a shot through
// real glass rather than flat pixels — plus the PALETTE GRADE (FABLE_50 #18): a gentle filmic
// S-curve and a split-tone that pulls shadows toward the underworld's cool blue-black and
// highlights toward the lamp's warm gold, so every material/light/UI colour passes through one
// shared "one artist made this" grade. Runs on a full-screen ColorRect on a CanvasLayer BELOW the
// HUD, so the world gets the lens treatment and the UI stays crisp.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.22;  // how dark the corners go (dialed back)
uniform float vignette_inner : hint_range(0.0, 1.0) = 0.48;     // radius where darkening starts
uniform float vignette_outer : hint_range(0.0, 1.5) = 0.98;     // radius of full darkening
uniform float grain_amount : hint_range(0.0, 0.2) = 0.014;      // film-grain intensity (was 0.030 — too busy)
uniform float aberration : hint_range(0.0, 0.01) = 0.0007;      // edge colour-fringe amount
uniform float time_scale = 24.0;                                // grain re-seed speed
uniform float grade_amount : hint_range(0.0, 1.0) = 0.55;       // master mix of the palette grade
uniform float grade_curve : hint_range(0.0, 1.0) = 0.30;        // filmic S-curve strength (contrast cohesion)
uniform float grade_saturation : hint_range(0.5, 1.5) = 1.07;   // a touch of richness, never neon

// Cheap hash noise for the grain (no texture needed).
float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float d = length(c);

	// Chromatic aberration: split the channels outward, growing with distance from centre.
	vec2 shift = c * aberration;
	vec3 col;
	col.r = texture(screen_tex, uv + shift).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - shift).b;

	// --- the palette grade: filmic S-curve + cool-shadow / warm-highlight split-tone ---
	vec3 curved = mix(col, col * col * (3.0 - 2.0 * col), grade_curve);
	float luma = dot(curved, vec3(0.299, 0.587, 0.114));
	// Near-unity hue nudges (multiplicative), NOT crushing tints: shadows drift toward the veil's
	// blue-black, highlights toward lamp gold — the two poles the game's light already lives between.
	vec3 tone = mix(vec3(0.93, 0.97, 1.09), vec3(1.06, 1.00, 0.91), smoothstep(0.05, 0.85, luma));
	vec3 toned = curved * tone;
	toned = mix(vec3(dot(toned, vec3(0.299, 0.587, 0.114))), toned, grade_saturation);
	col = mix(col, toned, grade_amount);

	// Vignette: 1.0 in the centre, falling to (1 - strength) past the outer radius.
	float vig = 1.0 - smoothstep(vignette_inner, vignette_outer, d);
	col *= mix(1.0 - vignette_strength, 1.0, vig);

	// Animated film grain — a faint per-pixel flicker, re-seeded over time.
	float g = hash(uv * vec2(1280.0, 720.0) + fract(TIME * time_scale * 0.04) * 137.0);
	col += (g - 0.5) * grain_amount;

	COLOR = vec4(col, 1.0);
}
