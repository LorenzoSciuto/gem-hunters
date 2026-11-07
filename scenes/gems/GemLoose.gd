## GemLoose.gd
## A whole gem knocked out of a hunter: it bounces out (no rolling, it never
## tips over), blinks while it can't be picked up yet, then spins and bobs like
## the gems in the maze so it clearly reads as "grab me". Collectible by any
## player on contact; drifts toward a hunter nearby; fades out after LIFETIME.
extends RigidBody3D
class_name GemLoose

const LIFETIME: float = 15.0
const PULSE_THRESHOLD: float = 5.0
const PULSE_SPEED: float = 6.0
const PULSE_AMPLITUDE: float = 0.1
## Gems burst out of the player who lost them; without a delay they would be
## re-collected instantly by that same player.
const PICKUP_DELAY: float = 0.8
## Blink rate (visibility toggles per second) while not pickable yet.
const BLINK_RATE: float = 12.0
const SPIN_SPEED: float = 2.5
const BOB_SPEED: float = 4.0
const BOB_HEIGHT: float = 0.08
## Once pickable, a loose gem drifts toward the nearest hunter within this range.
const MAGNET_RADIUS: float = 3.0
const MAGNET_FORCE: float = 30.0
## The hunter who lost the gem can't pull it back or grab it for this long, so
## rivals get a real chance at it.
const DROPPER_DELAY: float = 3.0

const MAT_STANDARD: Material = preload("res://resources/materials/mat_gem_standard.tres")
const MAT_RARE: Material = preload("res://resources/materials/mat_gem_rare.tres")
const MAT_EPIC: Material = preload("res://resources/materials/mat_gem_epic.tres")


@export var value: int = 1
## Player who lost this gem (-1 = nobody, e.g. a trap's bonus gems).
var dropped_by: int = -1

@onready var visual: Node3D = $Visual
@onready var pickup_range: Area3D = $PickupRange

var _lifetime_remaining: float = LIFETIME
var _collected: bool = false
var _time: float = 0.0
var _pickable: bool = false


func _ready() -> void:
	_apply_material()
	pickup_range.body_entered.connect(_on_pickup_range_body_entered)
	pickup_range.monitoring = false
	get_tree().create_timer(PICKUP_DELAY).timeout.connect(func() -> void:
		pickup_range.monitoring = true
		_pickable = true
		visual.visible = true)


func launch(impulse: Vector3) -> void:
	apply_impulse(impulse)


func _process(delta: float) -> void:
	_time += delta
	if not _pickable:
		visual.visible = fmod(_time * BLINK_RATE, 2.0) < 1.0
	visual.rotation.y += SPIN_SPEED * delta
	visual.position.y = sin(_time * BOB_SPEED) * BOB_HEIGHT
	var pulse: float = 1.0
	if _lifetime_remaining <= PULSE_THRESHOLD:
		pulse += sin(_time * PULSE_SPEED) * PULSE_AMPLITUDE
	visual.scale = Vector3.ONE * pulse


func _physics_process(delta: float) -> void:
	if _collected:
		return
	_lifetime_remaining -= delta
	if _lifetime_remaining <= 0.0:
		_expire()
		return
	if _pickable:
		_pull_toward_nearest_player()


func _pull_toward_nearest_player() -> void:
	var best: Vector3 = Vector3.ZERO
	var best_dist: float = MAGNET_RADIUS
	for node: Node in get_tree().get_nodes_in_group(Constants.GROUP_PLAYERS):
		if not _can_take(node as Player):
			continue
		var offset: Vector3 = (node as Node3D).global_position + Vector3.UP * 0.5 - global_position
		if offset.length() < best_dist:
			best_dist = offset.length()
			best = offset
	if best != Vector3.ZERO:
		apply_central_force(best.normalized() * MAGNET_FORCE * (1.0 - best_dist / MAGNET_RADIUS + 0.3))


func _can_take(player: Player) -> bool:
	return player.player_id != dropped_by or LIFETIME - _lifetime_remaining >= DROPPER_DELAY


func _apply_material() -> void:
	var mat: Material = MAT_STANDARD
	if value >= 5:
		mat = MAT_EPIC
	elif value >= 3:
		mat = MAT_RARE
	for part: Node in visual.get_children():
		(part as MeshInstance3D).set_surface_override_material(0, mat)


## Scattered gems are a transfer between players, so the frenzy does not double them.
func _on_pickup_range_body_entered(body: Node3D) -> void:
	if _collected or not body is Player or not _can_take(body as Player):
		return
	_collected = true
	(body as Player).collect_gem(value, false)
	queue_free()


func _expire() -> void:
	if _collected:
		return
	_collected = true
	queue_free()
