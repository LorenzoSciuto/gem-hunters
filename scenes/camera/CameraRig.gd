## CameraRig.gd
## Camera3D living inside a player's SubViewport. Smoothly follows the player's
## third-person camera target (the end of its SpringArm3D).
extends Camera3D
class_name CameraRig

@export var target: Node3D = null
@export var position_lerp_speed: float = 20.0
@export var rotation_lerp_speed: float = 20.0

## Shake strength (metres of jitter) decays at this rate per second.
const SHAKE_DECAY: float = 1.5

var _shake: float = 0.0


## Jolts the camera; [param strength] is the starting jitter in metres.
func shake(strength: float) -> void:
	_shake = maxf(_shake, strength)


func set_target(new_target: Node3D) -> void:
	target = new_target
	if target:
		global_transform = target.global_transform
	set_process(target != null)


func _ready() -> void:
	set_process(target != null)


func _process(delta: float) -> void:
	global_position = global_position.lerp(target.global_position, clampf(position_lerp_speed * delta, 0.0, 1.0))
	var current: Quaternion = Quaternion(global_basis.orthonormalized())
	var wanted: Quaternion = Quaternion(target.global_basis.orthonormalized())
	global_basis = Basis(current.slerp(wanted, clampf(rotation_lerp_speed * delta, 0.0, 1.0)))
	if _shake > 0.0:
		global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake
		_shake = move_toward(_shake, 0.0, SHAKE_DECAY * delta)
