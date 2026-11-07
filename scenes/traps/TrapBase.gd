## TrapBase.gd
## Base class for all player-placed traps.
## On trigger the victim loses [member gems_stolen] gems: half go straight to the
## trap's owner, the rest burst out as loose gems for anyone to grab.
## Subclasses override [method _apply_trap_effect] and [method _play_trap_sfx].
extends Area3D
class_name TrapBase

## Loaded on use, not preloaded: GemLoose references Player, which references
## TrapBase, so a preload here is a load cycle ("Parse Error: Busy").
const GEM_LOOSE_PATH: String = "res://scenes/gems/GemLoose.tscn"

## Grace period before the owner can be caught by their own trap.
const ARM_DELAY: float = 1.0
## Loose gems a trap bursts into when the victim has nothing to lose.
const EMPTY_VICTIM_BONUS: int = 2
## Time left for particles and sounds before the trap is freed.
const DESTROY_DELAY: float = 1.2
const GEM_BURST_HEIGHT: float = 0.4
## After a trap goes off, other traps let the victim pass for this long (no chain-trapping).
const TRAP_GRACE: float = 2.0

## Player ID of the player who placed this trap.
@export var owner_player_id: int = -1
## Gems taken from the victim on trigger.
@export var gems_stolen: int = 3
## Duration of the trap's main debuff in seconds (set per trap scene).
@export var effect_duration: float = 3.5
## Traps catch their own owner too (after ARM_DELAY): watch where you drop them.
@export var can_self_trigger: bool = true

@onready var anim_player: AnimationPlayer = get_node_or_null("AnimationPlayer")

var _triggered: bool = false
var _is_armed: bool = false


func _ready() -> void:
	add_to_group(Constants.GROUP_TRAPS)
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(ARM_DELAY, false).timeout.connect(func() -> void: _is_armed = true)
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
	if player.status.in_grace(PlayerStatus.Grace.TRAP):
		return  # Just caught by another trap; this one stays armed.
	player.status.grant_grace(PlayerStatus.Grace.TRAP, TRAP_GRACE)
	_trigger(player)


func _trigger(player: Player) -> void:
	_triggered = true
	set_deferred("monitoring", false)
	# Read before taking gems: that pops the bubble, which must also absorb the effect.
	var protected: bool = player.status.is_protected()
	player.take_item_hit()

	var removed: int = player.lose_gems(gems_stolen, false)
	if removed > 0:
		var to_owner: int = ceili(removed / 2.0) if player.player_id != owner_player_id else 0
		_reward_owner(to_owner)
		scatter_loose_gems(removed - to_owner, player.player_id)
	else:
		scatter_loose_gems(EMPTY_VICTIM_BONUS)

	_play_trap_sfx()
	if not protected:
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


## [param dropped_by]: the victim, who can't grab them back straight away.
func scatter_loose_gems(count: int, dropped_by: int = -1) -> void:
	for i: int in count:
		var gem: GemLoose = (load(GEM_LOOSE_PATH) as PackedScene).instantiate() as GemLoose
		gem.dropped_by = dropped_by
		get_parent().add_child(gem)
		gem.global_position = global_position + Vector3.UP * GEM_BURST_HEIGHT
		var angle: float = randf() * TAU
		gem.launch(Vector3(
			cos(angle) * Constants.GEM_LOOSE_SPREAD_FORCE,
			Constants.GEM_LOOSE_UP_FORCE,
			sin(angle) * Constants.GEM_LOOSE_SPREAD_FORCE
		))


## Breaks the trap harmlessly (hit by a projectile, ground pound nearby).
func defuse() -> void:
	if _triggered:
		return
	_triggered = true
	set_deferred("monitoring", false)
	ParticleConfigs.spawn_burst(get_parent(), global_position + Vector3.UP * GEM_BURST_HEIGHT,
		ParticleConfigs.bubble_pop_burst())
	AudioManager.play_sfx(AudioManager.SoundEffect.BUBBLE_POP)
	_self_destruct()


## Virtual — apply the trap's debuff.
func _apply_trap_effect(_player: Player) -> void:
	pass


## Virtual — play the trap's sound.
func _play_trap_sfx() -> void:
	pass


## Hide meshes, fire particles, then free once effects have played out.
func _self_destruct() -> void:
	remove_from_group(Constants.GROUP_TRAPS)
	for child: Node in get_children():
		if child is GPUParticles3D:
			(child as GPUParticles3D).restart()
		elif child is VisualInstance3D:
			(child as VisualInstance3D).visible = false
	await get_tree().create_timer(DESTROY_DELAY, false).timeout
	queue_free()
