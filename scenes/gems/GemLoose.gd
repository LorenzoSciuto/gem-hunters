## GemLoose.gd
## A physics-driven gem dropped by a player when they lose gems.
## Collectible by any player on body contact. Auto-destroys after LIFETIME seconds.
extends RigidBody3D
class_name GemLoose

const LIFETIME: float = 15.0
const PULSE_THRESHOLD: float = 5.0
const PULSE_SPEED: float = 6.0
const PULSE_AMPLITUDE: float = 0.1
## Gems burst out of the player who lost them; without a delay they would be
## re-collected instantly by that same player.
const PICKUP_DELAY: float = 0.8
## Once pickable, a loose gem drifts toward the nearest hunter within this range.
const MAGNET_RADIUS: float = 3.0
const MAGNET_FORCE: float = 30.0

const MAT_STANDARD: Material = preload("res://resources/materials/mat_gem_standard.tres")
const MAT_RARE: Material = preload("res://resources/materials/mat_gem_rare.tres")
const MAT_EPIC: Material = preload("res://resources/materials/mat_gem_epic.tres")


@export var value: int = 1

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var pickup_range: Area3D = $PickupRange

var _lifetime_remaining: float = LIFETIME
var _collected: bool = false
var _base_scale: Vector3 = Vector3.ONE
var _pulse_time: float = 0.0
var _pickable: bool = false

func _ready() -> void:
	_base_scale = scale
	_apply_material()
	pickup_range.body_entered.connect(_on_pickup_range_body_entered)
	pickup_range.monitoring = false
	get_tree().create_timer(PICKUP_DELAY).timeout.connect(func() -> void:
		pickup_range.monitoring = true
		_pickable = true)

func launch(impulse: Vector3) -> void:
	apply_impulse(impulse)

func _physics_process(delta: float) -> void:
	if _collected:
		return

	_lifetime_remaining -= delta
	if _lifetime_remaining <= 0.0:
		_expire()
		return

	if _pickable:
		_pull_toward_nearest_player()

	if _lifetime_remaining <= PULSE_THRESHOLD:
		_pulse_time += delta * PULSE_SPEED
		var pulse_offset: float = sin(_pulse_time) * PULSE_AMPLITUDE
		scale = _base_scale * (1.0 + pulse_offset)

func _pull_toward_nearest_player() -> void:
	var best: Vector3 = Vector3.ZERO
	var best_dist: float = MAGNET_RADIUS
	for node: Node in get_tree().get_nodes_in_group(Constants.GROUP_PLAYERS):
		var offset: Vector3 = (node as Node3D).global_position + Vector3.UP * 0.5 - global_position
		if offset.length() < best_dist:
			best_dist = offset.length()
			best = offset
	if best != Vector3.ZERO:
		apply_central_force(best.normalized() * MAGNET_FORCE * (1.0 - best_dist / MAGNET_RADIUS + 0.3))


func _apply_material() -> void:
	if not mesh_instance:
		return
	var mat: Material = MAT_STANDARD
	if value >= 5:
		mat = MAT_EPIC
	elif value >= 3:
		mat = MAT_RARE
	mesh_instance.set_surface_override_material(0, mat)

## Scattered gems are a transfer between players, so the frenzy does not double them.
func _on_pickup_range_body_entered(body: Node3D) -> void:
	if _collected or not body is Player:
		return
	_collected = true
	(body as Player).collect_gem(value, false)
	queue_free()


func _expire() -> void:
	if _collected:
		return
	_collected = true
	queue_free()
