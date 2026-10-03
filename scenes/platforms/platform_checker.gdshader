shader_type spatial;

uniform vec4 light_color : source_color = vec4(0.48, 0.53, 0.57, 1.0);
uniform vec4 dark_color : source_color = vec4(0.18, 0.21, 0.24, 1.0);
uniform float tile_size : hint_range(0.05, 1.0) = 0.2;

varying vec3 world_position;
varying float top_face;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	top_face = abs(NORMAL.y);
}

void fragment() {
	vec2 tile = floor(world_position.xz / tile_size);
	float checker = mod(tile.x + tile.y, 2.0);
	vec3 surface_color = mix(dark_color.rgb, light_color.rgb, checker);
	ALBEDO = mix(dark_color.rgb, surface_color, step(0.5, top_face));
	ROUGHNESS = 0.95;
}
