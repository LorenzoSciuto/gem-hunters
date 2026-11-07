## ToonMaterials.gd
## Factory for the project's stylized material (soft ramp, glossy highlight,
## lit-side rim, contact shade near the floor), optionally with an outline pass
## (characters and interactive objects). The outline is a dark shade of the
## object's own colour rather than black ink, which reads cleaner and more modern.
## Materials are cached per (color, outline) so identical props share one material.
class_name ToonMaterials

const SHADER_LIT: Shader = preload("res://shaders/stylized_lit.gdshader")
const SHADER_OUTLINE: Shader = preload("res://shaders/toon_outline_shell.gdshader")

const DEFAULT_OUTLINE_WIDTH: float = 0.03
## Outline colour = object colour darkened by this much, slightly desaturated.
const OUTLINE_DARKEN: float = 0.72
const OUTLINE_BASE: Color = Color(0.1, 0.06, 0.16, 1.0)
const OUTLINE_BASE_MIX: float = 0.45

static var _cache: Dictionary = {}


## Returns the stylized material for [param color]. [param outline_width] 0 disables the outline pass.
static func get_material(color: Color, outline_width: float = DEFAULT_OUTLINE_WIDTH) -> ShaderMaterial:
	var key: String = "%s|%.3f" % [color.to_html(), outline_width]
	if _cache.has(key):
		return _cache[key]
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = SHADER_LIT
	mat.set_shader_parameter("albedo", color)
	if outline_width > 0.0:
		var outline: ShaderMaterial = ShaderMaterial.new()
		outline.shader = SHADER_OUTLINE
		outline.set_shader_parameter("outline_width", outline_width)
		outline.set_shader_parameter("outline_color", color.darkened(OUTLINE_DARKEN).lerp(OUTLINE_BASE, OUTLINE_BASE_MIX))
		mat.next_pass = outline
	_cache[key] = mat
	return mat
