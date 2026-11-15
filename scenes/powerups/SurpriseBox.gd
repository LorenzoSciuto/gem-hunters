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
## "PRANK!" or the item name floats over the box so everyone sees what happened.
const TEXT_HEIGHT: float = 2.2
const PRANK_TEXT_COLOR: Color = Color(1.0, 0.45, 0.7)
## Opening burst and the colour of the item name.
const OPEN_CONFETTI: int = 50
const OPEN_LIFETIME: float = 0.9
const ITEM_TEXT_COLOR: Color = Color(1.0, 0.9, 0.4)


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
	PopupText.spawn(get_parent(), global_position + Vector3.UP * TEXT_HEIGHT,
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
	ParticleConfigs.spawn_burst(get_parent(), global_position + Vector3.UP, ParticleConfigs.confetti_shower(), OPEN_CONFETTI, OPEN_LIFETIME)
	PopupText.spawn(get_parent(), global_position + Vector3.UP * TEXT_HEIGHT,
		tr(ItemCatalog.NAME_KEYS[data.type]), ITEM_TEXT_COLOR)
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
	# Only boxes waiting to be opened count for spacing and SpawnClearance.
	remove_from_group(Constants.GROUP_SURPRISE_BOXES)
	if visual_root:
		visual_root.visible = false
	set_deferred("monitoring", false)

	if anim.is_playing():
		anim.stop()

	await get_tree().create_timer(respawn_time, false).timeout
	while not _relocate_to_new_spot():
		await get_tree().create_timer(SpawnClearance.RETRY_INTERVAL, false).timeout
	_activate()


## Moves to a random power-up spot clear of every pickup, prop and trap
## (SpawnClearance) and MIN_BOX_SPACING from the other active boxes.
## Returns false, without moving, while no spot is free.
func _relocate_to_new_spot() -> bool:
	var candidates: Array[Vector3] = []
	for marker: Node in get_tree().get_nodes_in_group(Constants.GROUP_POWERUP_SPAWNS):
		var pos: Vector3 = (marker as Node3D).global_position
		if SpawnClearance.is_clear(get_tree(), pos, self) and not _near_active_box(pos):
			candidates.append(pos)
	if candidates.is_empty():
		return false
	var chosen: Vector3 = candidates.pick_random()
	# Markers float at gem height; boxes sit on the floor.
	global_position = Vector3(chosen.x, _initial_position.y, chosen.z)
	return true


func _near_active_box(pos: Vector3) -> bool:
	for node: Node in get_tree().get_nodes_in_group(Constants.GROUP_SURPRISE_BOXES):
		var box: SurpriseBox = node as SurpriseBox
		if box != self and box.global_position.distance_to(pos) < MIN_BOX_SPACING:
			return true
	return false


## Restore the box to its active, visible state.
func _activate() -> void:
	add_to_group(Constants.GROUP_SURPRISE_BOXES)
	if visual_root:
		visual_root.visible = true
	monitoring = true
	_is_active = true

	if pickup_particles:
		pickup_particles.restart()


	if anim.has_animation("idle_bounce"):
		anim.play("idle_bounce")
