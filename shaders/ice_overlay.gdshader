// ice_overlay.gdshader
// Full-screen canvas item overlay that draws a frost / ice vignette around
// the screen edges when a player is affected by the "ice slide" power-up.
//
// Usage: attach to a ColorRect covering the full viewport.
// Animate `intensity` from 0.0 → 1.0 to reveal the frost, then back
// down when the effect expires.

shader_type canvas_item;

// ---------------------------------------------------------------------------
// Uniforms
// ---------------------------------------------------------------------------

/// Overall effect strength: 0 = invisible, 1 = maximum frost vignette.
uniform float intensity : hint_range(0.0, 1.0) = 0.0;

/// Colour of the frost overlay (icy blue-white).
uniform vec4 frost_color : source_color = vec4(0.75, 0.92, 1.0, 1.0);

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------
/// Inner radius (UV units from centre) where the frost begins to appear.
const float VIGNETTE_INNER  = 0.30;

/// Outer radius — frost reaches full opacity here.
const float VIGNETTE_OUTER  = 0.70;

/// Controls how crystalline / jagged the frost edges look (noise frequency).
const float CRYSTAL_FREQ    = 18.0;

/// Strength of the animated shimmer / sparkle on the frost surface.
const float SHIMMER_STRENGTH = 0.15;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Simple pseudo-random hash based on a 2D position.
float rand2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

/// 2D value noise – smooth interpolation over a grid of random values.
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f); // smoothstep curve

	float a = rand2(i + vec2(0.0, 0.0));
	float b = rand2(i + vec2(1.0, 0.0));
	float c = rand2(i + vec2(0.0, 1.0));
	float d = rand2(i + vec2(1.0, 1.0));

	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// ---------------------------------------------------------------------------
// Fragment shader
// ---------------------------------------------------------------------------
void fragment() {
	// --- 1. Compute distance from screen centre ----------------------------
	// UV is [0,1] x [0,1]; centre is (0.5, 0.5).
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered);

	// --- 2. Vignette mask ---------------------------------------------------
	// Smooth ring from VIGNETTE_INNER to VIGNETTE_OUTER, then multiply by
	// user intensity.
	float vignette = smoothstep(VIGNETTE_INNER, VIGNETTE_OUTER, dist);
	vignette *= intensity;

	// --- 3. Crystal / frost texture noise ----------------------------------
	// Layer two octaves of value noise to create an icy crystal pattern.
	vec2 noise_uv = UV * CRYSTAL_FREQ;
	float crystal = value_noise(noise_uv)
	              + 0.5 * value_noise(noise_uv * 2.1 + vec2(5.3, 1.7));
	crystal = crystal / 1.5; // normalise back to [0,1]

	// Carve sharp crystal edges (take absolute of shifted noise).
	float edge = abs(crystal - 0.5) * 2.0;
	edge = pow(edge, 2.0); // sharpen

	// --- 4. Animated shimmer -----------------------------------------------
	float shimmer = sin(TIME * 3.0 + UV.x * 25.0 + UV.y * 17.0) * 0.5 + 0.5;
	shimmer *= SHIMMER_STRENGTH * intensity;

	// --- 5. Compose final alpha --------------------------------------------
	// Combine vignette mask with crystal texture so frost only appears at edges.
	float alpha = vignette * mix(0.5, 1.0, edge) + shimmer * vignette;
	alpha = clamp(alpha, 0.0, 1.0);

	// --- 6. Output ----------------------------------------------------------
	COLOR = vec4(frost_color.rgb + shimmer, frost_color.a * alpha);
}
