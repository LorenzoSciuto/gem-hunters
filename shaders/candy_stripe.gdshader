// candy_stripe.gdshader
// Candy-cane walls: world-space diagonal stripes with soft anti-aliased edges,
// a contact shade at the base and the shared stylized light model.
shader_type spatial;

#include "res://shaders/stylized_light.gdshaderinc"

uniform vec4 stripe_color_1 : source_color = vec4(1.0, 0.35, 0.45, 1.0);
uniform vec4 stripe_color_2 : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float stripe_frequency : hint_range(0.2, 5.0) = 1.2;
uniform float stripe_angle : hint_range(0.0, 3.14159) = 0.7854;
uniform float roughness_val : hint_range(0.0, 1.0) = 0.3;
uniform float ground_shade : hint_range(0.0, 1.0) = 0.3;
uniform float ground_shade_height : hint_range(0.05, 4.0) = 1.2;

varying vec3 v_world_pos;
varying vec3 v_world_normal;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	float s = sin(stripe_angle);
	float c = cos(stripe_angle);
	// Stripes follow whichever horizontal axis the wall runs along.
	float along = abs(v_world_normal.x) > abs(v_world_normal.z) ? v_world_pos.z : v_world_pos.x;
	float coord = (along * c - v_world_pos.y * s) * stripe_frequency;
	float f = fract(coord);
	float aa = fwidth(coord) * 1.5;
	float pattern = smoothstep(0.5 - aa, 0.5 + aa, f) - smoothstep(1.0 - aa, 1.0, f);
	vec3 base = mix(stripe_color_1.rgb, stripe_color_2.rgb, pattern);
	float contact = mix(1.0 - ground_shade, 1.0, smoothstep(0.0, ground_shade_height, v_world_pos.y));
	ALBEDO = base * contact;
	ROUGHNESS = roughness_val;
}
