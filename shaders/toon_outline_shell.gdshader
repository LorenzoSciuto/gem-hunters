// toon_outline_shell.gdshader
// Outline-only pass rendered as an enlarged, inverted-normal shell.
// Place this shader on a duplicate MeshInstance3D (same mesh) with
// cull_front so only the back faces of the expanded shell are visible,
// creating a clean outline around the original mesh.
//
// Technique: expand vertices along their normals in VIEW space.
// Using view space (not object/world space) avoids the common artefact
// where outlines become uneven at grazing angles or for non-uniform scale.

shader_type spatial;
render_mode cull_front, unshaded, depth_prepass_alpha, ambient_light_disabled;

// ---------------------------------------------------------------------------
// Uniforms
// ---------------------------------------------------------------------------

/// World-space thickness of the outline. Tweak per-mesh for best results.
uniform float outline_width : hint_range(0.0, 0.1) = 0.02;

/// Colour of the outline stroke.
uniform vec4 outline_color : source_color = vec4(0.08, 0.05, 0.05, 1.0);

// ---------------------------------------------------------------------------
// Vertex shader — expand along view-space normals
// ---------------------------------------------------------------------------
void vertex() {
	// 1. Transform the normal into view space.
	//    NORMAL is in model space; MODELVIEW_MATRIX goes model→view.
	//    We only need the 3×3 rotation/scale part (upper-left).
	vec3 view_normal = normalize(mat3(MODELVIEW_MATRIX) * NORMAL);

	// 2. Discard the depth component of the view-space normal so the
	//    expansion happens purely sideways on screen (keeps outline width
	//    visually consistent regardless of viewing angle depth).
	view_normal.z = 0.0;
	view_normal = normalize(view_normal);

	// 3. Push the vertex outward in view space by outline_width.
	//    VERTEX is in model space here; we work via MODELVIEW_MATRIX.
	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	view_pos.xy += view_normal.xy * outline_width;

	// 4. Write final clip-space position.
	POSITION = PROJECTION_MATRIX * view_pos;
}

// ---------------------------------------------------------------------------
// Fragment shader — solid outline colour
// ---------------------------------------------------------------------------
void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA  = outline_color.a;
}
