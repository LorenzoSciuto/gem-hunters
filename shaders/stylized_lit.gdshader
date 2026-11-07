// stylized_lit.gdshader
// Default surface of characters, props and architecture: flat colour with the
// shared stylized light model and a soft contact shade near the floor that
// grounds every object (works per instance inside MultiMeshes).
shader_type spatial;

#include "res://shaders/stylized_light.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);
uniform float roughness_val : hint_range(0.0, 1.0) = 0.6;
/// How dark the colour gets where the surface meets the floor (world y = 0).
uniform float ground_shade : hint_range(0.0, 1.0) = 0.3;
uniform float ground_shade_height : hint_range(0.05, 4.0) = 1.2;
/// Slight top-lit gradient: surfaces get brighter the higher they are.
uniform float height_tint : hint_range(0.0, 0.5) = 0.06;

varying float v_world_y;

void vertex() {
	v_world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	float contact = mix(1.0 - ground_shade, 1.0, smoothstep(0.0, ground_shade_height, v_world_y));
	float lift = 1.0 + clamp(v_world_y * 0.25, 0.0, 1.0) * height_tint;
	ALBEDO = albedo.rgb * contact * lift;
	ROUGHNESS = roughness_val;
}
