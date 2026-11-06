## ToonMaterials.gd
## Factory for the project's cel-shaded StandardMaterial3D, optionally with an
## ink outline pass (characters and interactive objects). Materials are cached
## per (color, outline) so identical props share one material.
class_name ToonMaterials

const SHADER_OUTLINE: Shader = preload("res://shaders/toon_outline_shell.gdshader")

const ROUGHNESS: float = 0.65
const RIM: float = 0.25
const RIM_TINT: float = 0.4
const OUTLINE_COLOR: Color = Color(0.12, 0.08, 0.14, 1.0)
const DEFAULT_OUTLINE_WIDTH: float = 0.03

static var _cache: Dictionary = {}


## Returns a toon material for [param color]. [param outline_width] 0 disables the ink pass.
static func get_material(color: Color, outline_width: float = DEFAULT_OUTLINE_WIDTH) -> StandardMaterial3D:
	var key: String = "%s|%.3f" % [color.to_html(), outline_width]
	if _cache.has(key):
		return _cache[key]
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
	mat.roughness = ROUGHNESS
	mat.rim_enabled = true
	mat.rim = RIM
	mat.rim_tint = RIM_TINT
	if outline_width > 0.0:
		var outline: ShaderMaterial = ShaderMaterial.new()
		outline.shader = SHADER_OUTLINE
		outline.set_shader_parameter("outline_width", outline_width)
		outline.set_shader_parameter("outline_color", OUTLINE_COLOR)
		mat.next_pass = outline
	_cache[key] = mat
	return mat
