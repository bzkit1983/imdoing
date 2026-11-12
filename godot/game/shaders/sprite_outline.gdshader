shader_type canvas_item;
// Optional runtime silhouette thicken (docs/alpha/voxel-cartoon-shading.md knife 3).
// Bake ink is the default look — this material is off unless Vox enables it.
// Body texels keep CanvasItem modulate (skin tint); outline stays near-ink.

uniform vec4 outline_color : source_color = vec4(0.102, 0.102, 0.102, 1.0); // #1a1a1a
uniform float outline_width : hint_range(0.0, 3.0, 0.5) = 1.0;
uniform float alpha_threshold : hint_range(0.0, 1.0) = 0.1;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE * max(outline_width, 0.0);
	float neighbor = 0.0;
	neighbor = max(neighbor, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
	neighbor = max(neighbor, texture(TEXTURE, UV + vec2(-px.x, 0.0)).a);
	neighbor = max(neighbor, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
	neighbor = max(neighbor, texture(TEXTURE, UV + vec2(0.0, -px.y)).a);
	bool is_outline = tex.a < alpha_threshold && neighbor >= alpha_threshold;
	// COLOR already includes CanvasItem.modulate (skin tint).
	if (is_outline) {
		vec3 safe = max(COLOR.rgb, vec3(0.001));
		COLOR = vec4(outline_color.rgb / safe, outline_color.a * COLOR.a);
	} else {
		COLOR *= tex;
	}
}
