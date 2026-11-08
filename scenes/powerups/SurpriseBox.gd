## SurpriseBox.gd
## A power-up dispenser box that players walk into to receive a random power-up.
## Respawns after respawn_time seconds (default: Constants.POWERUP_BOX_RESPAWN).
## Players with full item slots can't open it. Some boxes are pranks that burst
## in the opener's face, some hold two items, and a box never repeats the item
## the player got last.
##
## Power-up pool:
##   Export powerup_pool with PowerUpData .tres resources. Each resource has a
##   pool_weight: int field. _pick_weighted() selects one proportionally.
##
## Visual states:
##   Active:   mesh visible, idle_bounce animation playing.
##   Inactive: mesh hidden, monitoring disabled until respawn completes.
extends Area3D
class_name SurpriseBox

## Weight multiplier for attack power-ups handed to the player in last place.
const TRAILING_ATTACK_WEIGHT_MULTIPLIER: int = 3
## Weight multiplier for the radar (shows where everyone is) for anyone not leading.
const CHASER_RADAR_WEIGHT_MULTIPLIER: int = 3
## Minimum distance between two active boxes after a relocation.
const MIN_BOX_SPACING: float = 12.0
## Prank box: the opener is tossed up and their controls flip for a moment.
const PRANK_LAUNCH_VELOCITY: float = 9.0
const PRANK_CONFUSION: float = 2.0
## "PRANK!" floats over the box so everyone sees why it burst.
const PRANK_TEXT_HEIGHT: float = 2.2
const PRANK_TEXT_COLOR: Color = Color(1.0, 0.45, 0.7)


# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------
## Assign PowerUpData resource files in the inspector to populate the pool.
@export var powerup_pool: Array[PowerUpData] = []
@export var respawn_time: float = Constants.POWERUP_BOX_RESPAWN

# ---------------------------------------------------------------------------
# Node references
# ---------------------------------------------------------------------------
@onready var visual_root: Node3D = $Model
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var pickup_particles: GPUParticles3D = $PickupParticles

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------
var _is_active: bool = true
var _initial_position: Vector3 = Vector3.ZERO

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	add_to_group(Constants.GROUP_SURPRISE_BOXES)
	_initial_position = global_position
	body_entered.connect(_on_body_entered)

	if anim.has_animation("idle_bounce"):
		anim.play("idle_bounce")


# ---------------------------------------------------------------------------
# Body contact
# ---------------------------------------------------------------------------

## Guard: box must be active and player must have an equip_powerup method.
func _on_body_entered(body: Node3D) -> void:
	if not _is_active:
		return
	if not body is Player or not (body as Player).items.has_free_slot():
		return

	var player: Player = body as Player
	if randf() < Constants.BOX_PRANK_CHANCE:
		_prank(player)
	else:
		_give_powerup(player)
		if randf() < Constants.BOX_DOUBLE_CHANCE and player.items.has_free_slot():
			_give_powerup(player)
	_start_respawn()


## A prank box: it bursts in the opener's face, tosses them up and flips their
## controls for a moment. Announced in the world and on the opener's HUD.
func _prank(player: Player) -> void:
	player.velocity.y = PRANK_LAUNCH_VELOCITY
	player.status.apply_debuff(Constants.DebuffType.INVERTED, PRANK_CONFUSION)
	player.notify("MSG_PRANK_BOX")
	ParticleConfigs.spawn_popup_text(get_parent(), global_position + Vector3.UP * PRANK_TEXT_HEIGHT,
		tr("MSG_PRANK_POP"), PRANK_TEXT_COLOR)
	ParticleConfigs.spawn_burst(get_parent(), global_position + Vector3.UP, ParticleConfigs.confetti_shower())
	AudioManager.play_sfx(AudioManager.SoundEffect.FART_HORN)


## Pick a power-up from the weighted pool and hand it to the player.
func _give_powerup(player: Player) -> void:
	if powerup_pool.is_empty():
		push_warning("SurpriseBox: powerup_pool is empty — nothing to give.")
		return

	var chasing: bool = GameManager.get_leader() != player.player_id
	var data: PowerUpData = _pick_weighted(_is_trailing(player.player_id), chasing, player.items.last_box_item)
	if not data:
		return

	player.items.equip(data.type)

	if pickup_particles:
		pickup_particles.restart()
	AudioManager.play_sfx(AudioManager.SoundEffect.POWERUP_GRAB)


## Last place (and not tied with the leader) gets attacks more often, to keep matches close.
func _is_trailing(player_id: int) -> bool:
	var standings: Array = GameManager.get_standings()
	var last: Dictionary = standings.back()
	return last["player_id"] == player_id and last["score"] < standings[0]["score"]


# ---------------------------------------------------------------------------
# Weighted random selection
# ---------------------------------------------------------------------------

## Select a PowerUpData entry probabilistically based on pool_weight values.
## Returns null only if the pool is empty (already guarded in _give_powerup).
func _pick_weighted(favor_attacks: bool, favor_radar: bool, exclude: int) -> PowerUpData:
	var weights: Array[int] = []
	var total_weight: int = 0
	for data: PowerUpData in powerup_pool:
		var w: int = 0 if data.type == exclude else data.pool_weight
		if favor_attacks and data.type in Constants.ATTACK_TYPES:
			w *= TRAILING_ATTACK_WEIGHT_MULTIPLIER
		if favor_radar and data.type == Constants.PowerUpType.UTILITY_RADAR:
			w *= CHASER_RADAR_WEIGHT_MULTIPLIER
		weights.append(w)
		total_weight += w

	if total_weight <= 0:
		push_warning("SurpriseBox: total pool weight is 0 — returning first entry.")
		return powerup_pool[0] if not powerup_pool.is_empty() else null

	var roll: int = randi() % total_weight
	var cumulative: int = 0
	for n: int in powerup_pool.size():
		cumulative += weights[n]
		if roll < cumulative:
			return powerup_pool[n]

	# Fallback (should never reach here).
	return powerup_pool[powerup_pool.size() - 1]


# ---------------------------------------------------------------------------
# Respawn cycle
# ---------------------------------------------------------------------------

## Deactivate the box, wait respawn_time, relocate to a new position, then reactivate.
func _start_respawn() -> void:
	_is_active = false
	if visual_root:
		visual_root.visible = false
	set_deferred("monitoring", false)

	if anim.is_playing():
		anim.stop()

	await get_tree().create_timer(respawn_time, false).timeout
	_relocate_to_new_spot()
	_activate()


## Selects a fresh, random spawn spot from the level's powerup_spawns markers.
func _relocate_to_new_spot() -> void:
	var spawns: Array[Node] = get_tree().get_nodes_in_group(Constants.GROUP_POWERUP_SPAWNS)
	if spawns.is_empty():
		return

	# Gather other active surprise boxes to avoid spawning right on top of another
	var other_boxes: Array[Node] = get_tree().get_nodes_in_group(Constants.GROUP_SURPRISE_BOXES)
	var candidates: Array[Node] = []

	for s in spawns:
		if not (s is Node3D):
			continue
		var m_pos: Vector3 = (s as Node3D).global_position
		# Check distance from currently active boxes
		var too_close: bool = false
		for b in other_boxes:
			if b != self and (b as SurpriseBox).is_active():
				if (b as Node3D).global_position.distance_to(m_pos) < MIN_BOX_SPACING:
					too_close = true
					break
		if not too_close:
			candidates.append(s)

	var pool: Array[Node] = candidates if not candidates.is_empty() else spawns
	var chosen: Vector3 = (pool[randi() % pool.size()] as Node3D).global_position
	# Markers float at gem height; boxes sit on the floor.
	global_position = Vector3(chosen.x, _initial_position.y, chosen.z)


func is_active() -> bool:
	return _is_active


## Restore the box to its active, visible state.
func _activate() -> void:
	if visual_root:
		visual_root.visible = true
	monitoring = true
	_is_active = true

	if pickup_particles:
		pickup_particles.restart()


	if anim.has_animation("idle_bounce"):
		anim.play("idle_bounce")
