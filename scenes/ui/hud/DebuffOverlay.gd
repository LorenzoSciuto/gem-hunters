## DebuffOverlay.gd
## Full-screen debuff feedback on one hunter's view: cake splat and frost use
## shaders that wipe away, laughing and confusion tint the screen.
extends ColorRect
class_name DebuffOverlay

const SHADER_SPLAT: Shader = preload("res://shaders/splat_overlay.gdshader")
const SHADER_ICE: Shader = preload("res://shaders/ice_overlay.gdshader")
const SPLAT_TINT: Color = Color(1.0, 0.45, 0.75, 1.0)
const FROST_COLOR: Color = Color(0.65, 0.9, 1.0, 0.85)
const COLOR_LAUGHING: Color = Color(1.0, 0.9, 0.2, 0.25)
const COLOR_CONFUSED: Color = Color(0.5, 0.2, 0.8, 0.35)
const FADE: float = 0.25
## Shader overlays wipe away over the last second.
const WIPE_TIME: float = 1.0

var _tween: Tween = null


func _ready() -> void:
	modulate.a = 0.0


func show_effect(debuff_type: int, duration: float) -> void:
	_restart_tween()
	match debuff_type:
		Constants.DebuffType.SPLAT:
			_show_shader(SHADER_SPLAT, "tint_color", SPLAT_TINT, "progress", duration)
		Constants.DebuffType.FROZEN, Constants.DebuffType.ICE_SLIDE:
			_show_shader(SHADER_ICE, "frost_color", FROST_COLOR, "intensity", duration)
		_:
			_show_tint(COLOR_LAUGHING if debuff_type == Constants.DebuffType.LAUGHING else COLOR_CONFUSED, duration)


## Broke free of the ice early: wipe the frost now.
func clear_frost() -> void:
	var mat: ShaderMaterial = material as ShaderMaterial
	if mat == null or mat.shader != SHADER_ICE:
		return
	_restart_tween()
	_tween.tween_method(func(v: float) -> void: mat.set_shader_parameter("intensity", v), 1.0, 0.0, FADE)
	_tween.tween_callback(_clear)


func _show_shader(shader: Shader, color_param: String, color: Color, amount_param: String, duration: float) -> void:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter(color_param, color)
	mat.set_shader_parameter(amount_param, 1.0)
	material = mat
	modulate.a = 1.0
	_tween.tween_interval(maxf(0.0, duration - WIPE_TIME))
	_tween.tween_method(func(v: float) -> void: mat.set_shader_parameter(amount_param, v), 1.0, 0.0, WIPE_TIME)
	_tween.tween_callback(_clear)


func _show_tint(tint: Color, duration: float) -> void:
	material = null
	color = Color(tint, 1.0)
	_tween.tween_property(self, "modulate:a", tint.a, FADE)
	_tween.tween_interval(maxf(0.0, duration - FADE * 2.0))
	_tween.tween_property(self, "modulate:a", 0.0, FADE)


func _clear() -> void:
	material = null
	modulate.a = 0.0


func _restart_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
