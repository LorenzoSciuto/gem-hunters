// arena_floor.gdshader
// Arena floor: world-space checker of rounded, bevelled tiles with recessed
// grout, a little per-tile colour jitter and soft large-scale variation, lit by
// the shared stylized light model.
shader_type spatial;

#include "res://shaders/stylized_light.gdshaderinc"

uniform vec4 color_a : source_color = vec4(0.38, 0.78, 0.45, 1.0);
uniform vec4 color_b : source_color = vec4(0.48, 0.85, 0.40, 1.0);
uniform vec4 grout_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float grout_mix : hint_range(0.0, 1.0) = 0.35;
uniform float tile_size : hint_range(0.5, 10.0) = 2.0;
/// Grout half-width and bevel width, as a fraction of a tile.
uniform float grout_width : hint_range(0.0, 0.1) = 0.025;
uniform float bevel_width : hint_range(0.01, 0.3) = 0.06;
uniform float bevel_strength : hint_range(0.0, 1.0) = 0.18;
/// World XZ direction the bevel highlight faces (roughly toward the sun).
uniform vec2 bevel_light_dir = vec2(-0.6, 0.8);
uniform float tile_jitter : hint_range(0.0, 0.2) = 0.05;
uniform float macro_variation : hint_range(0.0, 0.3) = 0.07;
uniform float roughness_val : hint_range(0.0, 1.0) = 0.45;

varying vec3 v_world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = v_world_pos.xz / tile_size;
	vec2 cell = floor(uv);
	vec2 local = fract(uv) - 0.5;
	float checker = mod(cell.x + cell.y, 2.0);

	// Distance to the tile edge (0 at the edge, 0.5 at the centre).
	vec2 edge = 0.5 - abs(local);
	float d = min(edge.x, edge.y);
	float grout = 1.0 - smoothstep(grout_width, grout_width + 0.01, d);
	float bevel = 1.0 - smoothstep(grout_width, grout_width + bevel_width, d);

	vec3 base = mix(color_a.rgb, color_b.rgb, checker);
	base *= 1.0 + (hash(cell) - 0.5) * 2.0 * tile_jitter;
	base *= 1.0 + (value_noise(v_world_pos.xz * 0.08) - 0.5) * 2.0 * macro_variation;
	base = mix(base, base * 0.55 + grout_color.rgb * 0.45, grout * grout_mix);
	ALBEDO = base * (1.0 - grout * 0.25);

	// Bevel baked into the colour: edges facing the light catch a highlight,
	// the opposite edges fall into shade, so tiles read as pillowed.
	vec2 toward_edge = abs(local.x) > abs(local.y) ? vec2(sign(local.x), 0.0) : vec2(0.0, sign(local.y));
	float facing = dot(toward_edge, normalize(bevel_light_dir));
	ALBEDO *= 1.0 + bevel * (1.0 - grout) * facing * bevel_strength;
	ROUGHNESS = roughness_val;
}
