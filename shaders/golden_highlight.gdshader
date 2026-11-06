// golden_highlight.gdshader
// Spatial shader for the special "King of the Hill" golden gem.
// Rendered with depth_test_disabled so it shows through walls —
// players always know where this gem is.
// Features an animated gold shimmer and a pulsing emissive glow.
//
// Apply to the golden gem's MeshInstance3D surface.

shader_type spatial;
render_mode depth_test_disabled, unshaded;

// ---------------------------------------------------------------------------
// Uniforms
// ---------------------------------------------------------------------------

/// Primary gold colour.
uniform vec4 gold_color : source_color = vec4(1.0, 0.84, 0.0, 1.0);

/// Speed of the emissive pulse in cycles per second.
uniform float pulse_speed : hint_range(0.1, 10.0) = 2.0;

/// Minimum brightness multiplier at the bottom of the pulse cycle.
uniform float pulse_min : hint_range(0.0, 1.0) = 0.5;

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------
/// Intensity of the scrolling shimmer band (0 = off, 1 = very bright stripe).
const float SHIMMER_BAND_STRENGTH = 0.5;

/// Width (in UV units) of the scrolling highlight band.
const float SHIMMER_BAND_WIDTH    = 0.15;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Returns a value in [0, 1] representing a bright stripe scrolling over UV.
float shimmer_band(vec2 uv, float speed) {
	float pos = fract(uv.x * 1.5 + uv.y * 0.5 - TIME * speed * 0.3);
	return smoothstep(0.0, SHIMMER_BAND_WIDTH, pos)
	     * smoothstep(SHIMMER_BAND_WIDTH * 2.0, SHIMMER_BAND_WIDTH, pos);
}

// ---------------------------------------------------------------------------
// Fragment shader
// ---------------------------------------------------------------------------
void fragment() {
	// --- 1. Pulsing emissive brightness ------------------------------------
	// Oscillate between pulse_min and 1.0 using a smooth sine wave.
	float pulse = mix(pulse_min, 1.0,
	                  sin(TIME * pulse_speed * TAU * 0.5) * 0.5 + 0.5);

	// --- 2. Scrolling shimmer highlight ------------------------------------
	float band  = shimmer_band(UV, pulse_speed) * SHIMMER_BAND_STRENGTH;

	// --- 3. Compose colour -------------------------------------------------
	vec3 color  = gold_color.rgb * pulse + vec3(band);

	// --- 4. Add a slight warm-to-white hot-spot glint ----------------------
	float glint = pow(max(0.0, 1.0 - length(UV - 0.5) * 3.5), 4.0);
	color += vec3(1.0, 0.95, 0.6) * glint * 0.8;

	// --- 5. Output ---------------------------------------------------------
	ALBEDO   = color;
	EMISSION = color * pulse * 1.2; // Strong emissive so it glows through walls
	ALPHA    = gold_color.a;
}
