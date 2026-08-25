// The one screen-space distortion pass every warp effect shares: heat shimmer and water refraction are
// the same trick with different masks. A quad drawn with this material repaints its area with the screen
// displaced by a rising ripple, and the per-vertex alpha of that geometry is the local strength mask, so
// the consumer shapes the effect. Where the mask is 0 the displaced UV equals the original, so the quad
// edges are seamless.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float strength_px = 2.4;   // peak displacement, in screen pixels
uniform float speed = 2.6;         // ripple climb rate

void fragment() {
	float mask = COLOR.a;
	float y = SCREEN_UV.y;
	float x = SCREEN_UV.x;
	// Two vertical frequencies climbing at different rates plus a slow horizontal wobble, so it reads
	// as convecting air rather than a sine curtain.
	vec2 wave = vec2(
		sin(y * 110.0 + TIME * speed * 3.1) * 0.6 + sin(y * 53.0 + TIME * speed * 4.7) * 0.4,
		sin(x * 90.0 + y * 40.0 + TIME * speed * 2.3) * 0.35
	);
	vec2 duv = SCREEN_UV + wave * mask * strength_px * SCREEN_PIXEL_SIZE;
	COLOR = vec4(texture(screen_tex, duv).rgb, 1.0);
}
