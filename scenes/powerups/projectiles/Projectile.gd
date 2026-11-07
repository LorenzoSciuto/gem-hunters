## Projectile.gd
## Base for fired power-ups: flies along its -Z axis, ignores the shooter, and
## ends on the first wall or opponent it touches. Light aim assist: a rival
## within range and roughly ahead pulls the shot into a gentle curve; a shot
## fired well away from everyone flies straight.
##
## Interactions: a shot that touches a trap breaks it, two rival shots cancel
## each other out, and Tanky's shield sends a shot back at its shooter.
extends Area3D
class_name Projectile

@export var speed: float = 20.0
@export var lifetime: float = 2.0

## Aim assist: rivals farther than this, or outside the cone ahead, are ignored.
const HOMING_RANGE: float = 14.0
const HOMING_CONE_DEG: float = 40.0
## Maximum turn toward the target (radians per second): a curve, not a lock-on.
const HOMING_TURN_RATE: float = 2.5
## Shots fly at chest height, over floor traps: any trap this close
## horizontally is hit and breaks.
const TRAP_HIT_RADIUS: float = 0.8

var shooter_id: int = -1
var _age: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	_steer(delta)
	global_position -= global_transform.basis.z * speed * delta
	if _hit_trap():
		return
	_age += delta
	if _age >= lifetime:
		queue_free()


## Turns (yaw only) toward the rival closest to the flight line, if any.
func _steer(delta: float) -> void:
	var forward: Vector3 = -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var best_angle: float = deg_to_rad(HOMING_CONE_DEG)
	var turn: float = 0.0
	for node: Node in get_tree().get_nodes_in_group(Constants.GROUP_PLAYERS):
		var player: Player = node as Player
		if player == null or player.player_id == shooter_id:
			continue
		var to_target: Vector3 = player.global_position - global_position
		to_target.y = 0.0
		if to_target.length() > HOMING_RANGE:
			continue
		var angle: float = forward.signed_angle_to(to_target.normalized(), Vector3.UP)
		if absf(angle) < best_angle:
			best_angle = absf(angle)
			turn = angle
	rotate_y(clampf(turn, -HOMING_TURN_RATE * delta, HOMING_TURN_RATE * delta))


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		var player: Player = body as Player
		if player.player_id == shooter_id:
			return
		if player.reflects_projectiles():
			_reflect(player)
			return
		_on_hit_player(player)
	_finish()


func _on_area_entered(area: Area3D) -> void:
	var other: Projectile = area as Projectile
	if other and other.shooter_id != shooter_id:
		_finish()  # The other shot gets its own callback and pops too.


func _hit_trap() -> bool:
	for node: Node in get_tree().get_nodes_in_group(Constants.GROUP_TRAPS):
		var trap: TrapBase = node as TrapBase
		var offset: Vector3 = trap.global_position - global_position
		if Vector2(offset.x, offset.z).length() <= TRAP_HIT_RADIUS:
			trap.defuse()
			_finish()
			return true
	return false


## Turns the shot around; it now belongs to [param by] and can hit its old shooter.
func _reflect(by: Player) -> void:
	shooter_id = by.player_id
	_age = 0.0
	rotate_y(PI)
	ParticleConfigs.spawn_burst(get_parent(), global_position, ParticleConfigs.bubble_pop_burst())
	AudioManager.play_sfx(AudioManager.SoundEffect.BUBBLE_POP)


## Virtual — effect applied to the opponent that was hit.
func _on_hit_player(_player: Player) -> void:
	pass


## Leaves any particle child behind as a final puff, then frees the projectile.
func _finish() -> void:
	for child: Node in get_children():
		if child is GPUParticles3D:
			(child as GPUParticles3D).reparent(get_parent())
			(child as GPUParticles3D).restart()
			get_tree().create_timer((child as GPUParticles3D).lifetime).timeout.connect(child.queue_free)
	queue_free()


func _find_shooter() -> Player:
	for node: Node in get_tree().get_nodes_in_group(Constants.GROUP_PLAYERS):
		if node is Player and (node as Player).player_id == shooter_id:
			return node as Player
	return null
