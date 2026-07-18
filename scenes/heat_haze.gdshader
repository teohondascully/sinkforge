// THE DISTORTION INFRA (FABLE_50 #20): the ONE screen-space distortion pass every future warp effect
// shares — L4 heat shimmer and L3 water refraction are the same trick with different masks. A canvas
// quad drawn with this material repaints its area with the SCREEN displaced by a rising ripple; the
// per-VERTEX alpha of the drawn geometry is the local strength mask (so a haze plume fades with
// height, a water surface masks below its line — the consumers shape the effect, the shader never
// changes). Where the mask is 0 the displaced UV equals the original, so quad edges are seamless.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float strength_px = 2.4;   // peak displacement, in screen pixels
uniform float speed = 2.6;         // ripple climb rate

void fragment() {
	float mask = COLOR.a;
	float y = SCREEN_UV.y;
	float x = SCREEN_UV.x;
	// Two vertical frequencies climbing at different rates + a slow horizontal wobble: reads as
	// convecting air, not a sine curtain.
	vec2 wave = vec2(
		sin(y * 110.0 + TIME * speed * 3.1) * 0.6 + sin(y * 53.0 + TIME * speed * 4.7) * 0.4,
		sin(x * 90.0 + y * 40.0 + TIME * speed * 2.3) * 0.35
	);
	vec2 duv = SCREEN_UV + wave * mask * strength_px * SCREEN_PIXEL_SIZE;
	COLOR = vec4(texture(screen_tex, duv).rgb, 1.0);
}
