shader_type canvas_item;
// Ops skill HUD — dark-slot CD clock:
// Icon stays full-color; unrecovered wedge gets a cool dark veil so the wipe reads
// clearly without washing into a light plate or fighting a gold rim.
// progress 0 = fully veiled (just used), 1 = ready.

uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform float veil_alpha : hint_range(0.0, 1.0) = 0.72;
uniform vec3 veil_color : source_color = vec3(0.04, 0.05, 0.07);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 p = UV - vec2(0.5);
	float ang = atan(p.x, -p.y);
	float t = ang / TAU + 0.5;
	float ready = clamp(progress, 0.0, 1.0);
	float edge = 0.018;
	float lit = 1.0 - smoothstep(ready - edge, ready + edge, t);

	vec3 rgb = tex.rgb;
	float veil = (1.0 - lit) * veil_alpha;
	rgb = mix(rgb, veil_color, veil);
	// Keep a touch of icon chroma under the veil so silhouettes stay readable.
	rgb = mix(rgb, tex.rgb * 0.55, (1.0 - lit) * 0.22);
	COLOR = vec4(rgb * COLOR.rgb, tex.a * COLOR.a);
}
