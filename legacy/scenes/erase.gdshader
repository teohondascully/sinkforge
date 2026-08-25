shader_type canvas_item;
render_mode blend_disabled, unshaded;

// The eraser. The coarse-terrain bake is a retained render target: a dig re-renders only the chunks that
// changed and the rest keep their pixels. Alpha blending adds coverage but can never remove it, so a
// changed chunk could not take its old rock away. `blend_disabled` writes COLOR straight to the target,
// alpha included, so drawing a transparent rect with this clears it. Ordered below the chunk painters, it
// gives each dirty chunk a blank slate without clearing the rest of the roughly 16-megapixel target.
void fragment() {
	COLOR = vec4(0.0);
}
