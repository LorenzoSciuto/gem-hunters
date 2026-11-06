// splat_overlay.gdshader
// Full-screen canvas item overlay used for the "cake in face" power-up hit
// effect. A blob of colour (default pink) smears across the screen and fades
// out over time, driven by the `progress` uniform animated by the game.
//
// Usage: attach to a ColorRect or TextureRect that covers the full viewport.
// Animate `progress` from 1.0 → 0.0 to show then fade the splat.

shader_type canvas_item;

// ---------------------------------------------------------------------------
// Uniforms
// ---------------------------------------------------------------------------

/// Normalised progress: 1.0 = fully visible splat, 0.0 = fully transparent.
/// Drive this down over ~1.5 s from GDScript using a Tween.
uniform float progress : hint_range(0.0, 1.0) = 0.0;

/// Tint colour of the splat blob (default: party pink).
uniform vec4 tint_color : source_color = vec4(1.0, 0.45, 0.65, 1.0);

/// Optional splat texture (e.g., a hand-painted blob mask).
/// If left blank the shader uses a procedural fallback.
uniform sampler2D splat_texture : hint_default_white, repeat_disable;

/// Noise texture used to animate/deform the blob boundary.
uniform sampler2D noise_texture : hint_default_white, repeat_enable;

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------
const float NOISE_SCALE      = 3.0;  // How coarsely the noise tiles
const float DEFORM_STRENGTH  = 0.12; // How much the noise shifts the sample UV
const float EDGE_SOFTNESS    = 0.25; // Width of the feathered fade ring
const float TIME_SCALE       = 0.6;  // Speed of the animated noise crawl

// ---------------------------------------------------------------------------
// Fragment shader
// ---------------------------------------------------------------------------
void fragment() {
	// --- 1. Animated noise deformation of UV --------------------------------
	// Sample a low-frequency noise to wobble the lookup UV.  Offset by TIME
	// so the blob edge looks alive even when progress is static.
	vec2 noise_uv = UV * NOISE_SCALE + vec2(TIME * TIME_SCALE * 0.3,
	                                         TIME * TIME_SCALE * 0.17);
	float noise_val = texture(noise_texture, noise_uv).r;

	// Deform the base UV by the noise offset, scaled by progress so the
	// deformation shrinks as the splat fades away.
	vec2 deformed_uv = UV + (noise_val - 0.5) * DEFORM_STRENGTH * progress;

	// --- 2. Sample splat mask -----------------------------------------------
	// splat_texture is a white blob mask centred at (0.5, 0.5).
	float splat_mask = texture(splat_texture, deformed_uv).r;

	// --- 3. Compute effective coverage --------------------------------------
	// Map progress so the splat "eats into" the screen at high progress
	// and retreats as progress drops toward 0.
	// threshold: at progress=1 → 0.0 (everything inside mask shows),
	//            at progress=0 → 1.5 (nothing shows).
	float threshold = 1.0 - progress * 1.5;
	float coverage  = smoothstep(threshold, threshold + EDGE_SOFTNESS, splat_mask);

	// --- 4. Output ----------------------------------------------------------
	// Multiply tint alpha by coverage so edges are soft.
	COLOR = vec4(tint_color.rgb, tint_color.a * coverage * progress);
}
