shader_type canvas_item;
render_mode blend_disabled, unshaded;

// THE ERASER (#S14). The coarse-terrain bake is a RETAINED render target: a dig re-renders only the two or
// three chunks that changed, and everything else keeps the pixels it already had. That only works if a
// changed chunk can first take its old pixels away, and ordinary alpha blending cannot — blending can add
// coverage, never remove it, so a cell dug open at the surface would keep its rock forever.
//
// `blend_disabled` writes COLOR straight to the target, alpha included, instead of blending with what is
// there. Drawing a transparent rect with it therefore CLEARS that rect. Ordered below the chunk painters,
// it gives each dirty chunk a blank slate without clearing the other 16 megapixels the frame did not touch.
void fragment() {
	COLOR = vec4(0.0);
}
