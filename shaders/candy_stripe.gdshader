// candy_stripe.gdshader
// Vibrant diagonal candy stripes with toon diffuse and bouncy specular rim.
// Produced for Gem Hunters: Tag & Trap by Wennovate.
shader_type spatial;
render_mode diffuse_toon, specular_toon;

uniform vec4 stripe_color_1 : source_color = vec4(1.0, 0.35, 0.45, 1.0); // Vivid Coral Pink
uniform vec4 stripe_color_2 : source_color = vec4(1.0, 1.0, 1.0, 1.0);     // Pure Cream White
uniform float stripe_frequency : hint_range(0.2, 5.0) = 1.2;
uniform float stripe_angle : hint_range(0.0, 3.14159) = 0.7854; // 45 degrees
uniform float rim_amount : hint_range(0.0, 1.0) = 0.4;
uniform float roughness_val : hint_range(0.0, 1.0) = 0.25;

varying vec3 v_world_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Rotate coordinates for diagonal stripes
	float s = sin(stripe_angle);
	float c = cos(stripe_angle);
	vec2 rotated = vec2(v_world_pos.x * c - v_world_pos.y * s, v_world_pos.x * s + v_world_pos.y * c);

	float pattern = step(0.5, fract(rotated.x * stripe_frequency));
	vec3 base = mix(stripe_color_1.rgb, stripe_color_2.rgb, pattern);

	ALBEDO = base;
	ROUGHNESS = roughness_val;
	SPECULAR = 0.4;
}
