## PlayerItems.gd
## A hunter's gift-box items and character superpower: the
## Constants.ITEM_SLOT_COUNT slots, using an item (projectile, trap, thunder,
## utility), the mouse-wheel armed slot, and the superpower with its recharge.
## Child node "Items" of Player.
extends Node
class_name PlayerItems

## The item slots changed: [param slots] holds one PowerUpType per slot (NONE = empty).
signal inventory_changed(player_id: int, slots: Array)
## A gift box put an item into [param slot].
signal item_received(player_id: int, slot: int, powerup_type: int)
## A utility item took effect.
signal powerup_activated(player_id: int, powerup_type: int)
## The superpower was set up, used or reset; it is ready again in [param ready_in] seconds.
signal superpower_changed(player_id: int, trait_type: int, ready_in: float)
## The superpower was fired.
signal superpower_used(player_id: int, trait_type: int)
## A Black Box emptied the slots and reset the superpower.
signal items_stripped(player_id: int)
## The mouse wheel armed another slot (0-2 items, SUPER_SLOT = superpower).
signal selection_changed(player_id: int, slot: int)

## Mouse wheel: slots 0-2 are items, SUPER_SLOT is the superpower.
const SUPER_SLOT: int = 3
## Traps are dropped this far behind the player so they don't trigger instantly.
const TRAP_DROP_DISTANCE: float = 1.4
const TURBO_DURATION: float = 4.0
const SHIELD_DURATION: float = 6.0
## Thunder: every rival loses this many gems, giggles and is dazed.
const THUNDER_GEMS: int = 3
const THUNDER_STUN: float = 1.0

# Assigned in Player.tscn rather than preloaded: these scenes reference Player,
# and a preload here would be a load cycle ("Parse Error: Busy").
@export var spring_glove_scene: PackedScene
@export var magnet_scene: PackedScene
@export var tickle_ray_scene: PackedScene
@export var snowball_scene: PackedScene
@export var trap_cake_scene: PackedScene
@export var trap_water_balloon_scene: PackedScene
@export var trap_speaker_scene: PackedScene
@export var trap_banana_scene: PackedScene
@export var trap_black_box_scene: PackedScene

@onready var player: Player = get_parent()

## The last item a box gave; boxes avoid handing it out twice in a row.
var last_box_item: int = Constants.PowerUpType.NONE
var selected_slot: int = 0
var _slots: Array[int] = []
## Game time at which the superpower is ready again.
var _super_ready_at: float = 0.0


func _ready() -> void:
	_slots.resize(Constants.ITEM_SLOT_COUNT)
	_slots.fill(Constants.PowerUpType.NONE)


func _now() -> float:
	return GameManager.game_time()


# ─── Slots ────────────────────────────────────────────────────────────────

func has_free_slot() -> bool:
	return _slots.has(Constants.PowerUpType.NONE)


## Called by SurpriseBox: stores the item in the first free slot.
## Returns false when all slots are full.
func equip(type: Constants.PowerUpType) -> bool:
	var slot: int = _slots.find(Constants.PowerUpType.NONE)
	if slot < 0:
		return false
	_slots[slot] = type
	last_box_item = type
	inventory_changed.emit(player.player_id, _slots.duplicate())
	item_received.emit(player.player_id, slot, type)
	return true


## Mouse wheel: arm the next/previous slot (items, then the superpower).
func cycle_selection(step: int) -> void:
	selected_slot = posmod(selected_slot + step, SUPER_SLOT + 1)
	selection_changed.emit(player.player_id, selected_slot)


## Left click: fire the armed slot.
func use_selected() -> void:
	if selected_slot == SUPER_SLOT:
		use_superpower()
	else:
		use_item(selected_slot)


func use_item(slot: int) -> void:
	var type: int = _slots[slot]
	if type == Constants.PowerUpType.NONE or player.status.has(Constants.DebuffType.LAUGHING):
		return  # Empty, or too busy giggling.
	match type:
		Constants.PowerUpType.ATTACK_SPRING_GLOVE: _fire_projectile(spring_glove_scene)
		Constants.PowerUpType.ATTACK_MAGNET: _fire_projectile(magnet_scene)
		Constants.PowerUpType.ATTACK_TICKLE_RAY: _fire_projectile(tickle_ray_scene)
		Constants.PowerUpType.ATTACK_SNOWBALL: _fire_projectile(snowball_scene)
		Constants.PowerUpType.ATTACK_THUNDER: _thunder()
		Constants.PowerUpType.TRAP_CAKE: _drop_trap(trap_cake_scene)
		Constants.PowerUpType.TRAP_WATER_BALLOON: _drop_trap(trap_water_balloon_scene)
		Constants.PowerUpType.TRAP_SPEAKER: _drop_trap(trap_speaker_scene)
		Constants.PowerUpType.TRAP_BANANA: _drop_trap(trap_banana_scene)
		Constants.PowerUpType.TRAP_BLACK_BOX: _drop_trap(trap_black_box_scene)
		_: _activate_utility(type)
	_slots[slot] = Constants.PowerUpType.NONE
	inventory_changed.emit(player.player_id, _slots.duplicate())


## Black Box: empties every slot and restarts the superpower's recharge.
## Tanky's shield protects; a bubble was already popped by the trap's gem loss.
func strip() -> void:
	if player.status.has_buff(PlayerStatus.Buff.SHIELD):
		return
	_slots.fill(Constants.PowerUpType.NONE)
	inventory_changed.emit(player.player_id, _slots.duplicate())
	_restart_recharge()
	items_stripped.emit(player.player_id)


func _activate_utility(type: int) -> void:
	match type:
		Constants.PowerUpType.UTILITY_SPRING_SHOES:
			player.status.grant(PlayerStatus.Buff.SHOES, Constants.POWERUP_DURATION_SPRING_SHOES)
		Constants.PowerUpType.UTILITY_BUBBLE:
			player.status.grant(PlayerStatus.Buff.BUBBLE, Constants.POWERUP_DURATION_BUBBLE)
		Constants.PowerUpType.UTILITY_JACKPOT:
			player.collect_gem(randi_range(Constants.JACKPOT_MIN_GEMS, Constants.JACKPOT_MAX_GEMS))
		Constants.PowerUpType.UTILITY_WARP:
			var spots: Array[Node] = get_tree().get_nodes_in_group(Constants.GROUP_GEM_SPAWNS)
			if not spots.is_empty():
				player.teleport_to((spots.pick_random() as Node3D).global_position)
		Constants.PowerUpType.UTILITY_RADAR:
			player.reveal_map(Constants.POWERUP_DURATION_RADAR)
	AudioManager.play_sfx(AudioManager.SoundEffect.POWERUP_GRAB)
	powerup_activated.emit(player.player_id, type)


func _drop_trap(scene: PackedScene) -> void:
	var trap: TrapBase = scene.instantiate() as TrapBase
	trap.owner_player_id = player.player_id
	player.get_parent().add_child(trap)
	var behind: Vector3 = player.global_transform.basis.z * TRAP_DROP_DISTANCE
	trap.global_position = Vector3(player.global_position.x + behind.x, player.global_position.y,
		player.global_position.z + behind.z)


## Projectiles fly level along the body's facing; camera pitch would aim them into the floor.
func _fire_projectile(scene: PackedScene) -> void:
	var projectile: Projectile = scene.instantiate() as Projectile
	player.get_parent().add_child(projectile)
	projectile.global_position = player.muzzle.global_position
	projectile.global_rotation = Vector3(0.0, player.global_rotation.y, 0.0)
	projectile.shooter_id = player.player_id


## Every rival is zapped: gems lost, giggles and a short daze.
func _thunder() -> void:
	AudioManager.play_sfx(AudioManager.SoundEffect.TICKLE_ZAP)
	for rival: Player in player.rivals():
		rival.take_hit()  # Before the gem loss, which pops a bubble.
		rival.lose_gems(THUNDER_GEMS)
		rival.status.apply_debuff(Constants.DebuffType.LAUGHING, Constants.DEBUFF_DURATION_THUNDER_LAUGH)
		rival.status.stun(THUNDER_STUN)


# ─── Superpower ───────────────────────────────────────────────────────────

## Announces the character's superpower, ready right away.
func reset_superpower() -> void:
	_super_ready_at = 0.0
	superpower_changed.emit(player.player_id, player.character_data.trait_type, 0.0)


func super_ready_in() -> float:
	return maxf(_super_ready_at - _now(), 0.0)


## Each character has one superpower, chosen by its trait; it then recharges.
func use_superpower() -> void:
	var data: CharacterData = player.character_data
	if data == null or super_ready_in() > 0.0 or player.status.has(Constants.DebuffType.LAUGHING):
		return
	match data.trait_type:
		CharacterData.TraitType.SPEEDSTER:
			player.status.grant(PlayerStatus.Buff.TURBO, TURBO_DURATION)
			ParticleConfigs.spawn_burst(player.get_parent(), player.global_position, ParticleConfigs.spring_launch())
		CharacterData.TraitType.BOUNCER:
			player.combat.start_ground_pound()
		CharacterData.TraitType.TANK:
			player.status.grant(PlayerStatus.Buff.SHIELD, SHIELD_DURATION)
		CharacterData.TraitType.PRANKSTER:
			if not _swap_with_rival():
				return
		_:
			return
	AudioManager.play_sfx(AudioManager.SoundEffect.POWERUP_GRAB)
	_restart_recharge()
	superpower_used.emit(player.player_id, data.trait_type)


func _restart_recharge() -> void:
	if player.character_data == null:
		return
	_super_ready_at = _now() + Constants.SUPERPOWER_COOLDOWN
	superpower_changed.emit(player.player_id, player.character_data.trait_type, Constants.SUPERPOWER_COOLDOWN)


## Tricky trades places with the leader (or a random rival if Tricky leads).
func _swap_with_rival() -> bool:
	var rivals: Array[Player] = player.rivals()
	if rivals.is_empty():
		return false
	var target: Player = rivals.pick_random()
	for rival: Player in rivals:
		if rival.player_id == GameManager.get_leader():
			target = rival
	var mine: Vector3 = player.global_position
	player.teleport_to(target.global_position)
	target.teleport_to(mine)
	return true
