## TrapBase.gd
## Base class for all player-placed traps.
## On trigger the victim loses [member gems_stolen] gems: half go straight to the
## trap's owner, the rest burst out as loose gems for anyone to grab.
## Subclasses override [method _apply_trap_effect] and [method _play_trap_sfx].
extends Area3D
class_name TrapBase

const GEM_LOOSE_SCENE: PackedScene = preload("res://scenes/gems/GemLoose.tscn")

## Grace period before the owner can be caught by their own trap.
const ARM_DELAY: float = 1.0
## Loose gems a trap bursts into when the victim has nothing to lose.
const EMPTY_VICTIM_BONUS: int = 2
## Time left for particles and sounds before the trap is freed.
const DESTROY_DELAY: float = 1.2
const GEM_BURST_HEIGHT: float = 0.4

## Player ID of the player who placed this trap.
@export var owner_player_id: int = -1
## Gems taken from the victim on trigger.
@export var gems_stolen: int = 3
## Duration of the applied debuff in seconds.
@export var effect_duration: float = 3.5
## Traps catch their own owner too (after ARM_DELAY): watch where you drop them.
@export var can_self_trigger: bool = true

@onready var anim_player: AnimationPlayer = get_node_or_null("AnimationPlayer")

var _triggered: bool = false
var _is_armed: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(ARM_DELAY).timeout.connect(func() -> void: _is_armed = true)
	if anim_player and anim_player.has_animation("idle_wobble"):
		anim_player.play("idle_wobble")


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		_try_trigger(body as Player)


func _try_trigger(player: Player) -> void:
	if _triggered:
		return
	if player.player_id == owner_player_id and (not _is_armed or not can_self_trigger):
		return
	_trigger(player)


func _trigger(player: Player) -> void:
	_triggered = true
	set_deferred("monitoring", false)

	var removed: int = player.lose_gems(gems_stolen, false)
	if removed > 0:
		var to_owner: int = ceili(removed / 2.0) if player.player_id != owner_player_id else 0
		_reward_owner(to_owner)
		scatter_loose_gems(removed - to_owner)
	else:
		scatter_loose_gems(EMPTY_VICTIM_BONUS)

	_play_trap_sfx()
	_apply_trap_effect(player)
	_self_destruct()


func _reward_owner(amount: int) -> void:
	if amount <= 0:
		return
	for node: Node in get_tree().get_nodes_in_group(Constants.GROUP_PLAYERS):
		var p: Player = node as Player
		if p and p.player_id == owner_player_id:
			p.collect_gem(amount, false)
			return


func scatter_loose_gems(count: int) -> void:
	for i: int in count:
		var gem: GemLoose = GEM_LOOSE_SCENE.instantiate() as GemLoose
		get_parent().add_child(gem)
		gem.global_position = global_position + Vector3.UP * GEM_BURST_HEIGHT
		var angle: float = randf() * TAU
		gem.launch(Vector3(
			cos(angle) * Constants.GEM_LOOSE_SPREAD_FORCE,
			Constants.GEM_LOOSE_UP_FORCE,
			sin(angle) * Constants.GEM_LOOSE_SPREAD_FORCE
		))


## Virtual — apply the trap's debuff.
func _apply_trap_effect(_player: Player) -> void:
	pass


## Virtual — play the trap's sound.
func _play_trap_sfx() -> void:
	pass


## Hide meshes, fire particles, then free once effects have played out.
func _self_destruct() -> void:
	for child: Node in get_children():
		if child is GPUParticles3D:
			(child as GPUParticles3D).restart()
		elif child is VisualInstance3D:
			(child as VisualInstance3D).visible = false
	await get_tree().create_timer(DESTROY_DELAY).timeout
	queue_free()
