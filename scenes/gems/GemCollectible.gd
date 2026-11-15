## GemCollectible.gd
## A stationary collectible gem in the world.
## Features a brilliant-cut 3D diamond crystal mesh, sparkling light, and orbiting particles.
## Floats and rotates via AnimationPlayer. Collected on body contact (Area3D).
extends Area3D
class_name GemCollectible

const MAT_STANDARD: Material = preload("res://resources/materials/mat_gem_standard.tres")
const MAT_RARE: Material = preload("res://resources/materials/mat_gem_rare.tres")
const MAT_EPIC: Material = preload("res://resources/materials/mat_gem_epic.tres")
const MAT_GOLDEN: Material = preload("res://resources/materials/mat_gem_golden.tres")
const MAT_LIFE: Material = preload("res://resources/materials/mat_gem_life.tres")
const LIFE_SCALE_FACTOR: float = 1.3
const LIFE_LIGHT: Color = Color(1.0, 0.35, 0.5)
const POPUP_LIFE_COLOR: Color = Color(1.0, 0.5, 0.65)

const GOLDEN_SCALE_FACTOR: float = 1.6

@export var gem_type: Constants.GemType = Constants.GemType.STANDARD
@export var value: int = 1
@export var is_golden: bool = false

signal collected(by_player_id: int, gem_value: int)

@onready var model_root: Node3D = $MeshInstance3D
@onready var crown_mesh: MeshInstance3D = $MeshInstance3D/Crown
@onready var pavilion_mesh: MeshInstance3D = $MeshInstance3D/Pavilion
@onready var gem_light: OmniLight3D = $MeshInstance3D/GemLight
@onready var anim_player: AnimationPlayer = $AnimationPlayer

var _already_collected: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_visuals()

	if anim_player and anim_player.has_animation("float_rotate"):
		anim_player.play("float_rotate")


func _apply_visuals() -> void:
	if not crown_mesh or not pavilion_mesh:
		return

	var mat: Material = MAT_STANDARD
	var light_col: Color = Color(0.3, 0.9, 1.0)

	if is_golden or gem_type == Constants.GemType.GOLDEN:
		mat = MAT_GOLDEN
		light_col = Color(1.0, 0.85, 0.1)
		scale = Vector3.ONE * GOLDEN_SCALE_FACTOR
	else:
		match gem_type:
			Constants.GemType.STANDARD:
				mat = MAT_STANDARD
				light_col = Color(0.3, 0.9, 1.0)
			Constants.GemType.RARE:
				mat = MAT_RARE
				light_col = Color(0.75, 0.35, 1.0)
			Constants.GemType.EPIC:
				mat = MAT_EPIC
				light_col = Color(1.0, 0.55, 0.1)
			Constants.GemType.LIFE:
				mat = MAT_LIFE
				light_col = LIFE_LIGHT
				scale = Vector3.ONE * LIFE_SCALE_FACTOR
			_:
				mat = MAT_STANDARD
				light_col = Color(0.3, 0.9, 1.0)

	crown_mesh.set_surface_override_material(0, mat)
	pavilion_mesh.set_surface_override_material(0, mat)

	if gem_light:
		gem_light.light_color = light_col


func _on_body_entered(body: Node3D) -> void:
	if _already_collected or not body is Player:
		return
	if gem_type == Constants.GemType.LIFE and GameManager.has_max_lives((body as Player).player_id):
		return  # Full: it stays for a rival.
	_already_collected = true
	var player: Player = body as Player
	if gem_type == Constants.GemType.LIFE:
		# Survival: a life instead of points.
		GameManager.add_life(player.player_id)
		_popup(player, "MSG_LIFE_GAINED_POP")
		AudioManager.play_sfx(AudioManager.SoundEffect.POWERUP_GRAB)
	else:
		player.collect_gem(value)
		if is_golden and GameManager.is_survival():
			# Survival: the golden gem also tops lives back up.
			GameManager.refill_lives(player.player_id, Constants.GOLDEN_REFILL_LIVES)
			_popup(player, "MSG_LIVES_REFILLED_POP")
	collected.emit(player.player_id, value)
	queue_free()


func _popup(player: Player, key: String) -> void:
	PopupText.spawn(get_parent(), player.global_position + Vector3.UP * PopupText.HEIGHT,
		tr(key), POPUP_LIFE_COLOR)
