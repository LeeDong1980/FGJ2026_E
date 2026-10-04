shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform float strength : hint_range(0.0, 1.0) = 0.0;
// Gradient from the mouth (base) to the tip. Defaults are the fire colors; the ice breath overrides them.
uniform vec3 base_color : source_color = vec3(1.0, 0.20, 0.015);
uniform vec3 tip_color : source_color = vec3(1.0, 0.60, 0.08);

void vertex() {
	float ripple = sin(UV.y * 31.0 - TIME * 19.0 + UV.x * 12.56637) * 0.08;
	VERTEX.xz *= 1.0 + ripple;
}

void fragment() {
	float flutter = sin(UV.y * 38.0 + UV.x * 18.84956 - TIME * 23.0);
	float along = smoothstep(0.0, 0.12, UV.y) * (1.0 - smoothstep(0.8, 1.0, UV.y));
	vec3 warm = mix(base_color, tip_color, UV.y);
	ALBEDO = warm;
	EMISSION = warm * 1.8;
	ALPHA = strength * along * mix(0.10, 0.20, flutter * 0.5 + 0.5);
}
