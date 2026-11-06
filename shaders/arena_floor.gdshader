// arena_floor.gdshader
// Vibrant stylized party arena floor with checkered grid, toon shading, and specular rim.
// Produced for Gem Hunters: Tag & Trap by Wennovate.
shader_type spatial;
render_mode diffuse_toon, specular_toon;

uniform vec4 color_a : source_color = vec4(0.38, 0.78, 0.45, 1.0);  // Lush Mint Green
uniform vec4 color_b : source_color = vec4(0.48, 0.85, 0.40, 1.0);  // Bright Lime Green
uniform vec4 grid_line_color : source_color = vec4(1.0, 1.0, 1.0, 0.35); // Subtle white chalk line
uniform float tile_size : hint_range(0.5, 10.0) = 2.0;
uniform float line_thickness : hint_range(0.01, 0.2) = 0.04;
uniform float roughness_val : hint_range(0.0, 1.0) = 0.35;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.3;

varying vec3 v_world_pos;
varying vec3 v_normal;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// Calculate checkered pattern based on world coordinates
	vec2 grid_uv = v_world_pos.xz / tile_size;
	vec2 check = floor(grid_uv);
	float pattern = mod(check.x + check.y, 2.0);

	vec4 base = mix(color_a, color_b, pattern);

	// Grid lines
	vec2 grid_dist = abs(fract(grid_uv) - 0.5);
	float line_mask = step(0.5 - line_thickness * 0.5, max(grid_dist.x, grid_dist.y));

	vec3 final_color = mix(base.rgb, grid_line_color.rgb, line_mask * grid_line_color.a);

	ALBEDO = final_color;
	ROUGHNESS = roughness_val;
	SPECULAR = 0.3;
}
