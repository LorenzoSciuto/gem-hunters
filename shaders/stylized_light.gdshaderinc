// stylized_light.gdshaderinc
// Shared light model of the project: soft two-tone ramp (no hard cel banding),
// a tight glossy highlight and a lit-side rim. Shadowed sides fall back to the
// arena's tinted ambient, which keeps them colourful instead of grey.
// Include it after `shader_type spatial;` in any surface shader.

uniform float shade_softness : hint_range(0.01, 1.0) = 0.35;
uniform float spec_strength : hint_range(0.0, 2.0) = 0.35;
uniform float spec_size : hint_range(0.0, 0.5) = 0.06;
uniform float rim_strength : hint_range(0.0, 2.0) = 0.45;
uniform float rim_power : hint_range(1.0, 8.0) = 3.5;

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float ramp = smoothstep(-0.05, shade_softness, ndl);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * ramp / PI;

	vec3 half_vec = normalize(LIGHT + VIEW);
	float spec = smoothstep(1.0 - spec_size - 0.02, 1.0 - spec_size, dot(NORMAL, half_vec));
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power) * smoothstep(-0.2, 0.4, ndl);
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * (spec * spec_strength + rim * rim_strength) / PI;
}
