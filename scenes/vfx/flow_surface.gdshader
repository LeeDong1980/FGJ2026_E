shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 source_position = vec3(0.0);
uniform vec3 target_position = vec3(-4.0, 0.0, 0.0);
uniform int effect_kind = 0;
uniform vec4 tint : source_color = vec4(0.52, 0.86, 1.0, 0.55);
varying float particle_phase;

void vertex() {
	particle_phase = INSTANCE_CUSTOM.z;
	vec3 center = (VIEW_MATRIX * MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec2 direction = (VIEW_MATRIX * vec4(target_position - source_position, 0.0)).xy;
	if (length(direction) < 0.001) {
		direction = vec2(0.0, 1.0);
	}
	direction = normalize(direction);
	vec2 side = vec2(direction.y, -direction.x);
	vec2 size = vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz));
	vec2 point = side * VERTEX.x * size.x + direction * VERTEX.y * size.y;
	VERTEX = center + vec3(point, 0.0);
	MODELVIEW_MATRIX = mat4(1.0);
}

void fragment() {
	vec2 point = UV * 2.0 - 1.0;
	float shape = 1.0 - smoothstep(0.25, 1.0, dot(point, point));
	vec3 color = tint.rgb;
	float brightness = 0.25;
	if (effect_kind == 1) {
		float taper = mix(0.40, 1.0, UV.y);
		float wave = sin(UV.y * 14.0 + TIME * 18.0 + particle_phase * 17.0) * 0.10;
		point.x = (point.x + wave) / taper;
		shape = 1.0 - smoothstep(0.15, 1.0, dot(point, point));
		color = mix(vec3(1.0, 0.15, 0.015), vec3(1.0, 0.72, 0.16), shape);
		brightness = 2.2;
	} else if (effect_kind == 2) {
		brightness = 2.4;
	} else if (effect_kind == 3) {
		brightness = 0.0;
	}
	ALBEDO = color;
	EMISSION = color * brightness;
	ALPHA = shape * COLOR.a * tint.a;
}
