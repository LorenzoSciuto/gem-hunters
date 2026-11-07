// stylized_sky.gdshader
// Painterly sky: smooth three-stop gradient, a soft sun with halo, and a band
// of fluffy procedural clouds near the horizon. Static (no TIME) so the
// radiance map is baked once per arena.
shader_type sky;

uniform vec4 top_color : source_color = vec4(0.35, 0.55, 0.95, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.85, 0.9, 1.0, 1.0);
uniform vec4 ground_color : source_color = vec4(0.4, 0.4, 0.45, 1.0);
uniform vec4 cloud_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.5;
uniform float sun_size : hint_range(0.0, 0.2) = 0.035;
uniform float sun_halo : hint_range(0.0, 2.0) = 0.6;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += noise(p) * a;
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void sky() {
	float y = EYEDIR.y;
	vec3 col = mix(horizon_color.rgb, top_color.rgb, smoothstep(0.0, 0.55, y));
	col = mix(col, ground_color.rgb, smoothstep(0.0, -0.12, y));

	// Clouds: project the view ray onto a dome so they flatten toward the horizon.
	if (y > 0.0) {
		vec2 dome = EYEDIR.xz / (y + 0.18);
		float c = fbm(dome * 1.6);
		float mask = smoothstep(1.0 - cloud_coverage, 1.15 - cloud_coverage * 0.6, c);
		mask *= smoothstep(0.0, 0.08, y) * (1.0 - smoothstep(0.45, 0.8, y));
		float shade = mix(0.82, 1.0, smoothstep(0.35, 0.8, fbm(dome * 1.6 + vec2(0.15, 0.25))));
		col = mix(col, cloud_color.rgb * shade, mask * 0.9);
	}

	float sun_dot = dot(EYEDIR, LIGHT0_DIRECTION);
	float sun_disc = smoothstep(cos(sun_size), cos(sun_size * 0.8), sun_dot);
	float halo = pow(max(sun_dot, 0.0), 24.0) * sun_halo;
	col += LIGHT0_COLOR * (sun_disc * 2.0 + halo) * float(LIGHT0_ENABLED);
	COLOR = col;
}
