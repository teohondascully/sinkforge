shader_type canvas_item;

// Screen-space post pass: a vignette + animated film grain + a whisper of
// chromatic aberration at the edges — the "lens" that makes the framebuffer read as a shot through
// real glass rather than flat pixels — plus the PALETTE GRADE (FABLE_50 #18): a gentle filmic
// S-curve and a split-tone that pulls shadows toward the underworld's cool blue-black and
// highlights toward the lamp's warm gold, so every material/light/UI colour passes through one
// shared "one artist made this" grade. Runs on a full-screen ColorRect on a CanvasLayer BELOW the
// HUD, so the world gets the lens treatment and the UI stays crisp.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float defocus : hint_range(0.0, 6.0) = 0.0;             // mip level the world is sampled at
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.32;  // darker corners focus the light-pools-in-black
uniform float vignette_inner : hint_range(0.0, 1.0) = 0.48;     // radius where darkening starts
uniform float vignette_outer : hint_range(0.0, 1.5) = 0.98;     // radius of full darkening
uniform float grain_amount : hint_range(0.0, 0.2) = 0.014;      // film-grain intensity (was 0.030 — too busy)
uniform float aberration : hint_range(0.0, 0.01) = 0.0007;      // edge colour-fringe amount
uniform float time_scale = 24.0;                                // grain re-seed speed
uniform float grade_amount : hint_range(0.0, 1.0) = 0.68;       // master mix of the palette grade (up for Noita contrast)
uniform float grade_curve : hint_range(0.0, 1.0) = 0.38;        // filmic S-curve strength (fix-2 diff 1): 0.52 →
                                                                // 0.38 — pass-1's hard S-curve crushed the gloom
                                                                // back toward black, undoing the raised ambient
                                                                // floor. Softer curve keeps the light-pools popping
                                                                // while the moonlit rock stays LEGIBLE across the
                                                                // frame (the grade no longer fights the ambient).
uniform float grade_saturation : hint_range(0.5, 1.5) = 1.14;   // richer light-pools (saturated cores blaze), never neon

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
	col.r = textureLod(screen_tex, uv + shift, defocus).r;
	col.g = textureLod(screen_tex, uv, defocus).g;
	col.b = textureLod(screen_tex, uv - shift, defocus).b;
	// DEFOCUS (#S34): while the Bazaar counter is open the WORLD goes out of focus behind it and loses a
	// little of its colour, the way a camera racks focus onto the thing you are looking at. This is what
	// stops a panel reading as pasted onto a screenshot — the old counter dimmed the world 38% and left it
	// perfectly sharp, so nothing said the panel was in FRONT of anything. The HUD draws on a layer above
	// this pass, so the counter itself stays crisp. Free: it is a mip level, not a kernel.
	if (defocus > 0.001) {
		float g = dot(col, vec3(0.299, 0.587, 0.114));
		col = mix(col, vec3(g), clamp(defocus * 0.13, 0.0, 0.34)) * (1.0 - clamp(defocus * 0.05, 0.0, 0.18));
	}

	// --- the palette grade: filmic S-curve + cool-shadow / warm-highlight split-tone ---
	vec3 curved = mix(col, col * col * (3.0 - 2.0 * col), grade_curve);
	float luma = dot(curved, vec3(0.299, 0.587, 0.114));
	// Near-unity hue nudges (multiplicative), NOT crushing tints: shadows drift toward the veil's
	// blue-black, highlights toward lamp gold — the two poles the game's light already lives between.
	// Shadow pole pulled cooler (fix-2 diff 3): shadows drift toward teal-blue (less red, a touch more
	// green+blue) so the whole gloom reads cold; highlights stay warm gold.
	vec3 tone = mix(vec3(0.90, 0.98, 1.12), vec3(1.06, 1.00, 0.91), smoothstep(0.05, 0.85, luma));
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
