// gem_shine.gdshader
// Spatial shader for collectible gems.
// Produces an animated iridescent crystal effect with glassy specular toon highlights
// and facet edge fresnels so gems look like radiant sparkling 3D diamonds.

shader_type spatial;
render_mode diffuse_toon, specular_toon, blend_mix;

// ---------------------------------------------------------------------------
// Uniforms
// ---------------------------------------------------------------------------

uniform vec4 base_color : source_color = vec4(0.2, 0.9, 1.0, 1.0);
uniform float shine_speed : hint_range(0.1, 5.0) = 1.2;
uniform float shine_intensity : hint_range(0.0, 1.0) = 0.45;
uniform float roughness_val : hint_range(0.0, 1.0) = 0.08;
uniform float metallic_val : hint_range(0.0, 1.0) = 0.2;
uniform float emission_boost : hint_range(0.0, 2.0) = 0.65;

// ---------------------------------------------------------------------------
// Helpers — HSV ↔ RGB conversion
// ---------------------------------------------------------------------------

vec3 hsv_to_rgb(float h, float s, float v) {
	vec3 rgb = clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
	return v * mix(vec3(1.0), rgb, s);
}

// ---------------------------------------------------------------------------
// Fragment shader
// ---------------------------------------------------------------------------
void fragment() {
	// Animated hue gradient across the gem facets
	float hue_offset = UV.y * 0.35 + NORMAL.y * 0.25;
	float hue = fract(TIME * shine_speed * 0.12 + hue_offset);

	float lum = dot(base_color.rgb, vec3(0.299, 0.587, 0.114));
	vec3 rainbow = hsv_to_rgb(hue, 0.85, max(lum, 0.75));

	vec3 final_color = mix(base_color.rgb, rainbow, shine_intensity);

	// Crisp glass/crystal fresnel on facet edges
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);

	ALBEDO = final_color;
	ROUGHNESS = roughness_val;
	METALLIC = metallic_val;
	SPECULAR = 0.85;

	// Glowing crystal core + edge glint
	EMISSION = (final_color * 0.3 + vec3(fresnel * 0.55)) * emission_boost;
}
