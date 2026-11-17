## Player.gd
## One hunter's body: movement and input, jumps and landings, gems in and out,
## knockback, teleports and launches, leader marker and elimination.
## Behaviour lives in child components:
##   Look   (PlayerLook)   — stick/mouse look, camera view, P1's mouse buttons
##   Status (PlayerStatus) — debuffs, stun, buffs, grace periods
##   Items  (PlayerItems)  — gift-box items and the character's superpower
##   Combat (PlayerCombat) — tackles, stomps, contact steals, ground pound
## Gem totals live in GameManager; this script only forwards changes.
extends CharacterBody3D
class_name Player

## Asks this player's HUD to show the arena map for [param duration] seconds.
signal map_reveal_requested(player_id: int, duration: float)
## Something happened that this player's HUD should explain ([param message_key]
## is a localization key; [param good] picks the toast colour).
signal notice_requested(player_id: int, message_key: String, good: bool)

## Body turns toward the movement direction at this rate (rad/s factor).
const MODEL_TURN_SPEED: float = 14.0
const MODEL_TURN_MIN_SPEED: float = 0.5
## On ice you can only nudge your sliding momentum (fraction of ice friction).
const ICE_STEER: float = 4.0
## Height at which gems burst out of / into a hunter.
const GEM_BURST_HEIGHT: float = 1.0
const GEM_CHEER_TIME: float = 0.35
const MIN_KNOCKBACK_RESISTANCE: float = 0.1
## Any knockback takes control away briefly so the hit actually carries the
## victim; while stunned they slide with this (lower) friction.
const KNOCKBACK_STUN: float = 0.8
const KNOCKBACK_FRICTION: float = 22.0
## Teleports land this high so the player never clips into the floor.
const TELEPORT_HEIGHT: float = 0.5
## An aimed launch ignores floor contact for this long (it starts on the pad).
const LAUNCH_MIN_AIR: float = 0.2

## Landing squash scales with fall speed up to this; harder landings kick up dust.
const LAND_SQUASH_SPEED: float = 14.0
const LAND_SQUASH_MAX: float = 0.45
const LAND_DUST_SPEED: float = 7.0
const LAND_DUST_AMOUNT: int = 14
## Running feet puff dust this often (s) at tackle speed.
const RUN_DUST_INTERVAL: float = 0.24
const RUN_DUST_AMOUNT: int = 4
const DUST_LIFETIME: float = 0.6

## Golden pillar over the leader, visible over the walls from anywhere.
const LEADER_BEAM_HEIGHT: float = 40.0
const LEADER_BEAM_RADIUS: float = 0.35
const LEADER_BEAM_BASE: float = 2.6
const LEADER_BEAM_COLOR: Color = Color(1.0, 0.85, 0.3, 0.35)

const WINNER_HOPS: int = 4
const WINNER_HOP_HEIGHT: float = 1.2
const WINNER_HOP_TIME: float = 0.25
const WINNER_CHEER_TIME: float = 3.0
const LOSER_SAD_TIME: float = 3.5
const CONFETTI_HEIGHT: float = 3.0
const WINNER_CONFETTI_AMOUNT: int = 80
const WINNER_CONFETTI_LIFETIME: float = 2.5
const OUT_CONFETTI_AMOUNT: int = 60
const OUT_POP_AMOUNT: int = 40
const OUT_BURST_LIFETIME: float = 1.2
const LIFE_POPUP_HEIGHT_SCALE: float = 1.8

@export var player_id: int = 0
## Assigned in Player.tscn (GemLoose references Player: a preload would be a load cycle).
@export var gem_loose_scene: PackedScene

@onready var status: PlayerStatus = $Status
@onready var items: PlayerItems = $Items
@onready var combat: PlayerCombat = $Combat
@onready var look: PlayerLook = $Look
@onready var model: CharacterModel = $Model
@onready var muzzle: Marker3D = $Muzzle
@onready var camera_target: Node3D = $CameraOrigin/SpringArm3D/CameraTarget
@onready var name_tag: Label3D = $NameTag
@onready var player_ring: MeshInstance3D = $PlayerRing

var character_data: CharacterData = null
var controls_enabled: bool = false

var _speed: float = Constants.BASE_SPEED
var _jump_velocity: float = Constants.JUMP_VELOCITY
var _jump_count: int = 0
## Riding an aimed launch (return pad): no control until it lands. Ended by
## touching the floor, not a timer, so a frame hitch can't drop it mid-air.
var _launched: bool = false
var _launch_started: float = 0.0
var _was_on_floor: bool = true
var _dust_timer: float = 0.0
var _leader_beam: LightBeam = null


# ─── Setup ────────────────────────────────────────────────────────────────

func initialize(new_id: int, color: Color) -> void:
	player_id = new_id
	name_tag.text = tr("UI_PLAYER_SHORT").format([new_id + 1])
	name_tag.font = Constants.DISPLAY_FONT
	name_tag.modulate = color
	name_tag.layers = 1 << (Constants.NAME_TAG_LAYER_BASE + new_id)
	var body_layer: int = Constants.MODEL_LAYER_BASE + new_id
	model.set_render_layer(body_layer)
	status.set_render_layer(body_layer)
	var ring_mat: StandardMaterial3D = (player_ring.mesh.surface_get_material(0) as StandardMaterial3D).duplicate()
	ring_mat.albedo_color = color
	player_ring.material_override = ring_mat
	look.setup()


func apply_character_data(data: CharacterData) -> void:
	if data == null:
		return
	character_data = data
	_speed = Constants.BASE_SPEED * data.speed_multiplier
	_jump_velocity = Constants.JUMP_VELOCITY * data.jump_multiplier
	model.set_character(data)
	items.reset_superpower()


func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	look.set_controls_enabled(enabled)


func set_leader(is_leader: bool) -> void:
	model.set_crown_visible(is_leader)
	if _leader_beam == null:
		_leader_beam = LightBeam.create(LEADER_BEAM_HEIGHT, LEADER_BEAM_RADIUS, LEADER_BEAM_COLOR, LEADER_BEAM_BASE)
		add_child(_leader_beam)
	_leader_beam.visible = is_leader


func get_camera_target() -> Node3D:
	return camera_target


## Every other hunter still in the match.
func rivals() -> Array[Player]:
	var out: Array[Player] = []
	for node: Node in get_tree().get_nodes_in_group(Constants.GROUP_PLAYERS):
		if node != self and node is Player:
			out.append(node as Player)
	return out


# ─── Input ────────────────────────────────────────────────────────────────

func _action(action: String) -> String:
	return InputManager.action_name(player_id, action)


## A stick's value from four actions, dead zone applied.
func stick(neg_x: String, pos_x: String, neg_y: String, pos_y: String) -> Vector2:
	var raw: Vector2 = Vector2(
		Input.get_axis(_action(neg_x), _action(pos_x)),
		Input.get_axis(_action(neg_y), _action(pos_y))
	)
	return Vector2.ZERO if raw.length() < Constants.JOYSTICK_DEAD_ZONE else raw.limit_length(1.0)


# ─── Frame update ─────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if is_on_floor():
		_jump_count = 0
		combat.on_floor()
	else:
		velocity.y -= Constants.GRAVITY * combat.gravity_scale() * delta

	if Input.is_action_just_pressed(_action("toggle_view")):
		look.toggle_view()
	var frozen: bool = status.has(Constants.DebuffType.FROZEN)
	if controls_enabled and not frozen and not status.is_stunned() and not _launched:
		look.update(delta)
		_handle_movement(delta)
		_handle_actions()
		combat.update(delta)
	elif controls_enabled and frozen:
		if Input.is_action_just_pressed(_action("jump")):
			jump()  # Frozen: a jump press cracks the ice instead.
		_decelerate(delta, Constants.FRICTION_GROUND)
	elif status.is_stunned() or _launched:
		# Knocked back or launched: keep the momentum in the air, slide it out
		# on the ground (barely slowing on ice / after a banana).
		if is_on_floor():
			var on_ice: bool = status.has(Constants.DebuffType.ICE_SLIDE)
			_decelerate(delta, Constants.FRICTION_ICE if on_ice else KNOCKBACK_FRICTION)
	else:
		_decelerate(delta, Constants.FRICTION_GROUND)
	var pre_slide: Vector3 = velocity
	move_and_slide()
	if _launched and is_on_floor() and GameManager.game_time() - _launch_started > LAUNCH_MIN_AIR:
		_launched = false
	combat.check_stomp(pre_slide)
	_process_landing(pre_slide, delta)
	_animate_model(delta)


func _handle_movement(delta: float) -> void:
	var move: Vector2 = stick("move_left", "move_right", "move_forward", "move_back")
	if status.has(Constants.DebuffType.INVERTED):
		move = -move
	var on_ice: bool = status.has(Constants.DebuffType.ICE_SLIDE)
	if move == Vector2.ZERO:
		_decelerate(delta, Constants.FRICTION_ICE if on_ice else Constants.FRICTION_GROUND)
		return
	var target: Vector3 = transform.basis * Vector3(move.x, 0.0, move.y) * _speed * status.speed_multiplier()
	if on_ice:
		velocity.x = move_toward(velocity.x, target.x, Constants.FRICTION_ICE * ICE_STEER * delta)
		velocity.z = move_toward(velocity.z, target.z, Constants.FRICTION_ICE * ICE_STEER * delta)
	else:
		velocity.x = target.x
		velocity.z = target.z


func _decelerate(delta: float, friction: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	velocity.z = move_toward(velocity.z, 0.0, friction * delta)


func _handle_actions() -> void:
	if Input.is_action_just_pressed(_action("jump")):
		jump()
	for slot: int in Constants.ITEM_SLOT_COUNT:
		if Input.is_action_just_pressed(_action(InputManager.ITEM_ACTIONS[slot])):
			items.use_item(slot)
	if Input.is_action_just_pressed(_action("super")):
		items.use_superpower()


## Jump, mid-air jump, or (frozen) crack the ice.
func jump() -> void:
	if not controls_enabled:
		return
	if status.has(Constants.DebuffType.FROZEN):
		status.struggle()
		return
	if is_on_floor():
		velocity.y = _jump_velocity
		_jump_count = 1
	elif _jump_count <= _air_jumps():
		velocity.y = Constants.SPRING_DOUBLE_JUMP_VELOCITY
		_jump_count += 1
		AudioManager.play_sfx(AudioManager.SoundEffect.SPRING_BOING)


## Mid-air jumps: the character's own, or one from spring shoes.
func _air_jumps() -> int:
	var own: int = character_data.air_jumps if character_data else 0
	return maxi(own, 1 if status.has_buff(PlayerStatus.Buff.SHOES) else 0)


## Bounce up off something (a rival's head); mid-air jumps are still available.
func bounce(speed: float) -> void:
	velocity.y = speed
	_jump_count = 1


## The model animates itself from speed and floor contact; here it only turns
## toward where the body is moving.
func _animate_model(delta: float) -> void:
	var horiz: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	model.set_motion(horiz.length(), is_on_floor())
	if horiz.length() > MODEL_TURN_MIN_SPEED and not status.is_stunned():
		var local: Vector3 = global_transform.basis.inverse() * horiz
		model.rotation.y = lerp_angle(model.rotation.y, atan2(local.x, local.z), delta * MODEL_TURN_SPEED)


## Landing squash and dust, plus running dust puffs.
func _process_landing(pre_slide: Vector3, delta: float) -> void:
	var grounded: bool = is_on_floor()
	if grounded and not _was_on_floor:
		var fall: float = -pre_slide.y
		model.play_squash(clampf(fall / LAND_SQUASH_SPEED, 0.0, 1.0) * LAND_SQUASH_MAX)
		if fall > LAND_DUST_SPEED:
			_dust(LAND_DUST_AMOUNT)
	_was_on_floor = grounded
	var running: bool = grounded and Vector2(velocity.x, velocity.z).length() > PlayerCombat.TACKLE_MIN_SPEED
	_dust_timer = _dust_timer - delta if running else RUN_DUST_INTERVAL
	if _dust_timer <= 0.0:
		_dust_timer = RUN_DUST_INTERVAL
		_dust(RUN_DUST_AMOUNT)


func _dust(amount: int) -> void:
	ParticleConfigs.spawn_burst(get_parent(), global_position, ParticleConfigs.dust_puff(), amount, DUST_LIFETIME)


# ─── Gems ─────────────────────────────────────────────────────────────────

## Pickup from the world. Returns the gems actually gained (frenzy doubles them).
## [param color]: the gem's colour in collector mode (see GameManager.add_gems).
func collect_gem(value: int, boost: bool = true, color: int = -1) -> int:
	var lives_before: int = GameManager.get_lives(player_id)
	var gained: int = GameManager.add_gems(player_id, value, boost, color)
	if GameManager.get_lives(player_id) > lives_before:
		_life_popup("MSG_LIFE_GAINED_POP", PopupText.GAIN_COLOR)
	if gained > 0:
		AudioManager.play_sfx(AudioManager.SoundEffect.GEM_COLLECT)
		ParticleConfigs.spawn_burst(get_parent(), global_position + Vector3.UP * GEM_BURST_HEIGHT,
			ParticleConfigs.gem_collect_burst())
		model.play_cheer(GEM_CHEER_TIME)
	return gained


## Removes gems (a bubble or shield absorbs it). With [param scatter] they burst
## out as loose gems anyone can grab; without, the caller hands them to a thief.
## Returns the gems actually removed.
func lose_gems(amount: int, scatter: bool = true) -> int:
	if status.absorb_hit():
		return 0
	var final_amount: int = amount
	if character_data and character_data.gem_loss_multiplier < 1.0:
		final_amount = maxi(1, int(amount * character_data.gem_loss_multiplier))
	var removed: int = GameManager.remove_gems(player_id, final_amount)
	if removed == 0:
		return 0
	AudioManager.play_sfx(AudioManager.SoundEffect.GEM_LOST)
	ParticleConfigs.spawn_burst(get_parent(), global_position + Vector3.UP * GEM_BURST_HEIGHT,
		ParticleConfigs.gem_lost_burst())
	if scatter:
		_spawn_loose_gems(removed)
	return removed


func _spawn_loose_gems(count: int) -> void:
	for i: int in count:
		var gem: GemLoose = gem_loose_scene.instantiate() as GemLoose
		gem.dropped_by = player_id
		get_parent().add_child(gem)
		gem.global_position = global_position + Vector3.UP * GEM_BURST_HEIGHT
		var angle: float = randf() * TAU
		gem.launch(Vector3(cos(angle) * Constants.GEM_LOOSE_SPREAD_FORCE, Constants.GEM_LOOSE_UP_FORCE,
			sin(angle) * Constants.GEM_LOOSE_SPREAD_FORCE))


# ─── Being hit ────────────────────────────────────────────────────────────

## Knockback divided by the character's resistance (1 = normal, Tanky barely budges).
func apply_knockback(impulse: Vector3) -> void:
	if status.absorb_hit():
		return
	var resistance: float = character_data.knockback_resistance if character_data else 1.0
	velocity += impulse / maxf(resistance, MIN_KNOCKBACK_RESISTANCE)
	status.stun(KNOCKBACK_STUN)


## Any attack (box item, tackle, stomp, ground pound, robbing) hit this hunter:
## in survival mode it costs a life, unless a bubble or shield absorbs the hit or
## a life was just lost (LIFE_LOSS_GRACE). Call it before the hit's own effect,
## since knockback or taking gems pops the bubble.
func take_hit() -> void:
	if not GameManager.is_survival() or status.is_protected() or status.in_grace(PlayerStatus.Grace.LIFE):
		return
	status.grant_grace(PlayerStatus.Grace.LIFE, Constants.LIFE_LOSS_GRACE)
	GameManager.lose_life(player_id)
	_life_popup("MSG_LIFE_LOST_POP", PopupText.LOSS_COLOR)


## Life popups float above the gem numbers so both stay readable.
func _life_popup(key: String, color: Color) -> void:
	PopupText.spawn(get_parent(), global_position + Vector3.UP * PopupText.HEIGHT * LIFE_POPUP_HEIGHT_SCALE,
		tr(key), color)


# ─── Movement from outside ────────────────────────────────────────────────

## Moves the player (portals, warp item, swap). Portals are ignored briefly afterwards.
func teleport_to(pos: Vector3) -> void:
	ParticleConfigs.spawn_burst(get_parent(), global_position + Vector3.UP, ParticleConfigs.bubble_pop_burst())
	global_position = Vector3(pos.x, maxf(pos.y, TELEPORT_HEIGHT), pos.z)
	velocity = Vector3.ZERO
	status.grant_grace(PlayerStatus.Grace.PORTAL, Constants.PORTAL_COOLDOWN)
	ParticleConfigs.spawn_burst(get_parent(), global_position + Vector3.UP, ParticleConfigs.bubble_pop_burst())
	AudioManager.play_sfx(AudioManager.SoundEffect.SPRING_BOING)


func can_use_portal() -> bool:
	return not status.in_grace(PlayerStatus.Grace.PORTAL)


## Throws the player along a ballistic arc that lands on [param target] after
## [param flight_time] seconds; steering is off until it lands.
func launch_to(target: Vector3, flight_time: float) -> void:
	var offset: Vector3 = target - global_position
	velocity = Vector3(offset.x / flight_time,
		(offset.y + 0.5 * Constants.GRAVITY * flight_time * flight_time) / flight_time,
		offset.z / flight_time)
	_launched = true
	_launch_started = GameManager.game_time()
	combat.cancel_ground_pound()


# ─── Messages, end of match ───────────────────────────────────────────────

## Shows a short explanation on this player's HUD (pranks, special events).
func notify(message_key: String, good: bool = false) -> void:
	notice_requested.emit(player_id, message_key, good)


## Shows this player the arena map (radar item, map beacons).
func reveal_map(duration: float) -> void:
	map_reveal_requested.emit(player_id, duration)


## Match over: turn to face [param viewer] (this hunter's own camera), then
## cheer if [param won], otherwise slump. Knocked-out hunters come back to sulk.
func play_finale(won: bool, viewer: Vector3) -> void:
	visible = true
	var local: Vector3 = global_transform.basis.inverse() * (viewer - global_position)
	model.rotation.y = atan2(local.x, local.z)
	if won:
		_play_winner_animation()
	else:
		model.play_sad(LOSER_SAD_TIME)


func _play_winner_animation() -> void:
	var hop: Tween = create_tween().set_loops(WINNER_HOPS).set_trans(Tween.TRANS_QUAD)
	hop.tween_property(model, "position:y", WINNER_HOP_HEIGHT, WINNER_HOP_TIME).set_ease(Tween.EASE_OUT)
	hop.tween_property(model, "position:y", 0.0, WINNER_HOP_TIME).set_ease(Tween.EASE_IN)
	ParticleConfigs.spawn_burst(get_parent(), global_position + Vector3.UP * CONFETTI_HEIGHT,
		ParticleConfigs.confetti_shower(), WINNER_CONFETTI_AMOUNT, WINNER_CONFETTI_LIFETIME)
	model.play_cheer(WINNER_CHEER_TIME)


## Survival: out of lives. The hunter vanishes from the arena (no collisions,
## not targeted, not counted as a rival) and their camera spectates others.
func eliminate() -> void:
	controls_enabled = false
	remove_from_group(Constants.GROUP_PLAYERS)
	var at: Vector3 = global_position + Vector3.UP
	ParticleConfigs.spawn_burst(get_parent(), at, ParticleConfigs.confetti_shower(), OUT_CONFETTI_AMOUNT, OUT_BURST_LIFETIME)
	ParticleConfigs.spawn_burst(get_parent(), at, ParticleConfigs.bubble_pop_burst(), OUT_POP_AMOUNT)
	AudioManager.play_sfx(AudioManager.SoundEffect.BUBBLE_POP)
	visible = false
	collision_layer = 0
	set_physics_process(false)
	status.set_process(false)
