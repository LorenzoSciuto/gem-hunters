## Player.gd
## Controls a single player character: movement, third-person look,
## a 3-slot item inventory, the character's superpower, gem pickups/losses and
## debuffs. Gem totals live in GameManager; this script
## only forwards changes. Communicates outward via signals.
extends CharacterBody3D
class_name Player

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

## The mouse wheel armed another slot (0-2 items, 3 = superpower).
signal selection_changed(player_id: int, slot: int)

## A hunter hit another (tackle, ground pound): [param gems] changed hands or scattered.
signal impact(attacker_id: int, victim_id: int, gems: int)

## Asks this player's HUD to show the arena map for [param duration] seconds.
signal map_reveal_requested(player_id: int, duration: float)

## The camera switched between first-person (true) and third-person view.
signal view_changed(player_id: int, first_person: bool)

## Requests that this player's HUD shows a debuff overlay.
signal screen_effect_requested(player_id: int, debuff_type: int, duration: float)

## A debuff ended (expired, or the player broke free of the ice).
signal debuff_cleared(player_id: int, debuff_type: int)


const MAX_JUMPS_SPRING: int = 2
## Traps are dropped this far behind the player so they don't trigger instantly.
const TRAP_DROP_DISTANCE: float = 1.4
## Body turns toward the movement direction at this rate (rad/s factor).
const MODEL_TURN_SPEED: float = 14.0
## Height at which loose gems burst out of a hit player.
const GEM_BURST_HEIGHT: float = 1.0
const WINNER_HOP_HEIGHT: float = 1.2
const WINNER_CHEER_TIME: float = 3.0
## Third-person camera sits slightly right of the head, over the shoulder.
const SHOULDER_OFFSET: float = 0.6
const MIN_KNOCKBACK_RESISTANCE: float = 0.1
## Speedsters shake off ice slides this much faster.
const SPEEDSTER_ICE_RECOVERY: float = 0.5
## Teleports land this high so the player never clips into the floor.
const TELEPORT_HEIGHT: float = 0.5

## Superpowers, one per character trait.
const TURBO_DURATION: float = 4.0
const TURBO_MULTIPLIER: float = 1.8
const SHIELD_DURATION: float = 6.0
const POUND_JUMP_VELOCITY: float = 13.0
## Gravity multiplier while slamming back down.
const POUND_FALL_GRAVITY: float = 2.5
const POUND_MIN_AIR_TIME: float = 0.25
const POUND_RADIUS: float = 6.5
const POUND_FORCE: float = 9.0
const POUND_GEMS: int = 2

## Running into a rival tackles them: they fly back and you take their gems
## (more from the crowned leader). The victim gets a moment to run away.
const TACKLE_GEMS: int = 1
const TACKLE_LEADER_GEMS: int = 2
const TACKLE_FORCE: float = 9.0
const TACKLE_LIFT: float = 4.0
const TACKLE_COOLDOWN: float = 1.5
## A tackle needs this much horizontal speed, aimed at the rival (cosine).
const TACKLE_MIN_SPEED: float = 4.0
const TACKLE_AIM: float = 0.5
## Mouse wheel: slots 0-2 are items, MOUSE_SUPER_SLOT is the superpower.
const MOUSE_SUPER_SLOT: int = 3
const TACKLE_GRACE: float = 2.0

## Frozen hunters mash jump to crack the ice: each press takes this much off
## the freeze, which still lasts at least FREEZE_MIN_TIME (a trap must hold
## its victim for a couple of seconds so rivals can come and rob them).
const FREEZE_MASH_STEP: float = 0.15
const FREEZE_MIN_TIME: float = 2.0
const STRUGGLE_SQUASH: float = 0.2
const STRUGGLE_PUFF_AMOUNT: int = 6
## After a trap goes off, other traps let the victim pass for this long (no chain-trapping).
const TRAP_GRACE: float = 2.0

## Jumping onto a rival's head: you bounce off, they get flattened and dazed,
## and one of their gems is yours.
const STOMP_MIN_FALL_SPEED: float = 2.0
## Collision normal must point up at least this much (cosine) to count as a stomp.
const STOMP_NORMAL_Y: float = 0.7
const STOMP_BOUNCE: float = 9.5
const STOMP_GEMS: int = 1
const STOMP_STUN: float = 1.0

## Any knockback takes control away briefly, so the hit actually carries the
## victim; during the stun they slide with this (lower) friction.
const KNOCKBACK_STUN: float = 0.45
const KNOCKBACK_FRICTION: float = 22.0

## Landing squash scales with fall speed up to this; harder landings kick up dust.
const LAND_SQUASH_SPEED: float = 14.0
const LAND_SQUASH_MAX: float = 0.45
const LAND_DUST_SPEED: float = 7.0
## Running feet puff dust this often (s) above TACKLE_MIN_SPEED.
const RUN_DUST_INTERVAL: float = 0.24
const RUN_DUST_AMOUNT: int = 4
const LAND_DUST_AMOUNT: int = 14
const DUST_LIFETIME: float = 0.6
## Short happy reaction on every gem pickup.
const GEM_CHEER_TIME: float = 0.35

## A launch ignores floor contact for this long (it starts on the pad).
const LAUNCH_MIN_AIR: float = 0.2

## Dizzy stars circling the head while stunned or confused.
const DIZZY_STAR_COUNT: int = 5

## Golden light pillar over the leader, visible over the walls from anywhere.
const LEADER_BEAM_HEIGHT: float = 40.0
const LEADER_BEAM_RADIUS: float = 0.35
const LEADER_BEAM_BASE: float = 2.6
const LEADER_BEAM_COLOR: Color = Color(1.0, 0.85, 0.3, 0.35)

## Hit feedback: the victim spins, a "+N" / "-N" floats up over both hunters.
const HIT_SPIN_TIME: float = 0.45
const POPUP_HEIGHT: float = 2.4
const POPUP_GAIN_COLOR: Color = Color(0.5, 1.0, 0.55)
const POPUP_LOSS_COLOR: Color = Color(1.0, 0.4, 0.35)

@export var player_id: int = 0

# Spawnable scenes are assigned in Player.tscn rather than preloaded: those
# scenes reference Player themselves, and a preload here would be a load cycle.
@export var gem_loose_scene: PackedScene
@export var spring_glove_scene: PackedScene
@export var magnet_scene: PackedScene
@export var tickle_ray_scene: PackedScene
@export var snowball_scene: PackedScene
@export var trap_cake_scene: PackedScene
@export var trap_water_balloon_scene: PackedScene
@export var trap_speaker_scene: PackedScene
@export var trap_banana_scene: PackedScene
@export var trap_black_box_scene: PackedScene

@onready var camera_origin: Node3D = $CameraOrigin
@onready var camera_target: Node3D = $CameraOrigin/SpringArm3D/CameraTarget
@onready var spring_arm: SpringArm3D = $CameraOrigin/SpringArm3D
@onready var model: CharacterModel = $Model
@onready var name_tag: Label3D = $NameTag
@onready var player_ring: MeshInstance3D = $PlayerRing
@onready var ice_effect: MeshInstance3D = $IceEffect
@onready var confusion_particles: GPUParticles3D = $ConfusionStars
@onready var bubble_mesh: MeshInstance3D = $BubbleShield
@onready var interact_area: Area3D = $InteractArea
@onready var muzzle: Marker3D = $Muzzle

var character_data: CharacterData = null
var controls_enabled: bool = false

var _speed: float = Constants.BASE_SPEED
var _jump_velocity: float = Constants.JUMP_VELOCITY
var _slots: Array[int] = []
## Engine time (s) at which the superpower is ready again.
var _super_ready_at: float = 0.0
var _selected_slot: int = 0
## The last item a box gave; boxes avoid handing it out twice in a row.
var last_box_item: int = Constants.PowerUpType.NONE
var _jump_count: int = 0
var _uses_mouse: bool = false
var _first_person: bool = false

## DebuffType → engine time (s) at which it expires. Re-applying extends it.
var _debuff_until: Dictionary = {}
var _bubble_until: float = 0.0
var _shoes_until: float = 0.0
var _turbo_until: float = 0.0
var _shield_until: float = 0.0
var _portal_until: float = 0.0
var _pounding: bool = false
var _tackle_ready_at: float = 0.0
var _tackle_immune_until: float = 0.0
var _leader_beam: MeshInstance3D = null
var _pound_started: float = 0.0

var _steal_target: Player = null
var _steal_timer: float = 0.0
var _laugh_time: float = 0.0
var _stunned_until: float = 0.0
## Riding an aimed launch (return pad): no control until it lands. Ended by
## touching the floor, not a timer, so a frame hitch can't drop it mid-air.
var _launched: bool = false
var _launch_started: float = 0.0
var _frozen_since: float = 0.0
var _was_frozen: bool = false
var _trap_immune_until: float = 0.0
var _was_on_floor: bool = true
var _dust_timer: float = 0.0


# ─── Setup ────────────────────────────────────────────────────────────────

func initialize(new_id: int, color: Color) -> void:
	player_id = new_id
	name_tag.text = "P%d" % (new_id + 1)
	name_tag.font = Constants.DISPLAY_FONT
	name_tag.modulate = color
	name_tag.layers = 1 << (Constants.NAME_TAG_LAYER_BASE + new_id)
	var body_layer: int = Constants.MODEL_LAYER_BASE + new_id
	model.set_render_layer(body_layer)
	confusion_particles.draw_pass_1 = ParticleConfigs.star_mesh()
	confusion_particles.amount = DIZZY_STAR_COUNT
	for fx: VisualInstance3D in [bubble_mesh, ice_effect, confusion_particles]:
		fx.layers = 1 << body_layer
	var ring_mat: StandardMaterial3D = (player_ring.mesh.surface_get_material(0) as StandardMaterial3D).duplicate()
	ring_mat.albedo_color = color
	player_ring.material_override = ring_mat
	# Never let the camera arm collide with its own body.
	spring_arm.add_excluded_object(get_rid())
	camera_origin.rotation.x = deg_to_rad(Constants.CAMERA_START_PITCH_DEG)
	_slots.resize(Constants.ITEM_SLOT_COUNT)
	_slots.fill(Constants.PowerUpType.NONE)


func apply_character_data(data: CharacterData) -> void:
	if data == null:
		return
	character_data = data
	_speed = Constants.BASE_SPEED * data.speed_multiplier
	_jump_velocity = Constants.JUMP_VELOCITY * data.jump_multiplier
	model.set_character(data)
	superpower_changed.emit(player_id, data.trait_type, 0.0)


func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	_uses_mouse = player_id == 0 and InputManager.player_joypad_map.get(0, -1) < 0
	if _uses_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if enabled else Input.MOUSE_MODE_VISIBLE
		selection_changed.emit(player_id, _selected_slot)


func set_leader(is_leader: bool) -> void:
	model.set_crown_visible(is_leader)
	if _leader_beam == null:
		_leader_beam = _make_leader_beam()
	_leader_beam.visible = is_leader


func _make_leader_beam() -> MeshInstance3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = LEADER_BEAM_COLOR
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = LEADER_BEAM_RADIUS
	cylinder.bottom_radius = LEADER_BEAM_RADIUS
	cylinder.height = LEADER_BEAM_HEIGHT
	cylinder.material = mat
	var beam: MeshInstance3D = MeshInstance3D.new()
	beam.mesh = cylinder
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.position.y = LEADER_BEAM_BASE + LEADER_BEAM_HEIGHT * 0.5
	add_child(beam)
	return beam


func get_camera_target() -> Node3D:
	return camera_target


## Switches between the over-the-shoulder camera and the character's eyes.
func toggle_view() -> void:
	_first_person = not _first_person
	spring_arm.spring_length = 0.0 if _first_person else Constants.CAMERA_TP_DISTANCE
	spring_arm.position.x = 0.0 if _first_person else SHOULDER_OFFSET
	camera_origin.position.y = Constants.CAMERA_FP_HEIGHT if _first_person else Constants.CAMERA_TP_HEIGHT
	_apply_look(Vector2.ZERO)  # Re-clamp pitch to the new view's limits.
	view_changed.emit(player_id, _first_person)


func get_gems() -> int:
	return GameManager.get_score(player_id)


# ─── Debuff state ─────────────────────────────────────────────────────────

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func has_debuff(type: Constants.DebuffType) -> bool:
	return _debuff_until.get(type, 0.0) > _now()


## Dazed by a hit: no control for a moment, dizzy stars overhead.
func is_stunned() -> bool:
	return _stunned_until > _now()


## Takes control away for [param duration] seconds (shield and bubble protect).
func stun(duration: float) -> void:
	if _is_shielded() or _has_bubble():
		return
	_stunned_until = maxf(_stunned_until, _now() + duration)
	model.play_hurt()


## Frozen or confused players can be robbed by bumping into them.
func is_vulnerable() -> bool:
	return has_debuff(Constants.DebuffType.FROZEN) or has_debuff(Constants.DebuffType.INVERTED)


func _has_bubble() -> bool:
	return _bubble_until > _now()


## Tanky's superpower: nothing gets through, and it doesn't pop.
func _is_shielded() -> bool:
	return _shield_until > _now()


func _has_double_jump() -> bool:
	var bouncer: bool = character_data != null and character_data.trait_type == CharacterData.TraitType.BOUNCER
	return bouncer or _shoes_until > _now()


# ─── Input ────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled or not _uses_mouse:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if has_debuff(Constants.DebuffType.FROZEN):
			return
		var look: Vector2 = (event as InputEventMouseMotion).relative * Constants.MOUSE_SENSITIVITY
		if has_debuff(Constants.DebuffType.INVERTED):
			look = -look
		_apply_look(look)
	elif event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			_handle_mouse_button(event.button_index)
		get_viewport().set_input_as_handled()


## Wheel arms a slot (items, then the superpower), left click fires it, right click jumps.
func _handle_mouse_button(button: MouseButton) -> void:
	match button:
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			var step: int = -1 if button == MOUSE_BUTTON_WHEEL_UP else 1
			_selected_slot = posmod(_selected_slot + step, MOUSE_SUPER_SLOT + 1)
			selection_changed.emit(player_id, _selected_slot)
		MOUSE_BUTTON_LEFT:
			if has_debuff(Constants.DebuffType.FROZEN):
				return
			if _selected_slot == MOUSE_SUPER_SLOT:
				use_superpower()
			else:
				use_item(_selected_slot)
		MOUSE_BUTTON_RIGHT:
			_jump()


func _action(action: String) -> String:
	return "p%d_%s" % [player_id, action]


func _stick(neg_x: String, pos_x: String, neg_y: String, pos_y: String) -> Vector2:
	var raw: Vector2 = Vector2(
		Input.get_axis(_action(neg_x), _action(pos_x)),
		Input.get_axis(_action(neg_y), _action(pos_y))
	)
	return Vector2.ZERO if raw.length() < Constants.JOYSTICK_DEAD_ZONE else raw.limit_length(1.0)


## Yaw turns the whole body, pitch tilts the camera pivot.
func _apply_look(look: Vector2) -> void:
	rotate_y(-look.x)
	var min_deg: float = Constants.CAMERA_FP_MIN_DEG if _first_person else Constants.CAMERA_VERTICAL_MIN_DEG
	var max_deg: float = Constants.CAMERA_FP_MAX_DEG if _first_person else Constants.CAMERA_VERTICAL_MAX_DEG
	camera_origin.rotation.x = clampf(camera_origin.rotation.x - look.y, deg_to_rad(min_deg), deg_to_rad(max_deg))


# ─── Frame update ─────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	var frozen: bool = has_debuff(Constants.DebuffType.FROZEN)
	if _was_frozen and not frozen:
		debuff_cleared.emit(player_id, Constants.DebuffType.FROZEN)
	_was_frozen = frozen
	ice_effect.visible = frozen
	confusion_particles.emitting = has_debuff(Constants.DebuffType.INVERTED) or is_stunned()
	bubble_mesh.visible = _has_bubble() or _is_shielded()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		var slam: bool = _pounding and velocity.y < 0.0
		velocity.y -= Constants.GRAVITY * (POUND_FALL_GRAVITY if slam else 1.0) * delta
	else:
		_jump_count = 0
		if _pounding and _now() - _pound_started > POUND_MIN_AIR_TIME:
			_ground_pound_impact()

	if Input.is_action_just_pressed(_action("toggle_view")):
		toggle_view()
	var launched: bool = _launched
	if controls_enabled and not has_debuff(Constants.DebuffType.FROZEN) and not is_stunned() and not launched:
		_handle_look(delta)
		_handle_movement(delta)
		_handle_actions()
		_process_steal(delta)
		_process_tackle()
	elif controls_enabled and has_debuff(Constants.DebuffType.FROZEN):
		if Input.is_action_just_pressed(_action("jump")):
			_jump()  # Frozen: a jump press cracks the ice instead.
		_decelerate(delta, Constants.FRICTION_GROUND)
	elif is_stunned() or launched:
		# Knocked back or launched: keep the momentum in the air, slide it out on the ground
		# (barely slowing on ice / after a banana).
		if is_on_floor():
			var on_ice: bool = has_debuff(Constants.DebuffType.ICE_SLIDE)
			_decelerate(delta, Constants.FRICTION_ICE if on_ice else KNOCKBACK_FRICTION)
	else:
		_decelerate(delta, Constants.FRICTION_GROUND)
	var pre_slide: Vector3 = velocity
	move_and_slide()
	if _launched and is_on_floor() and _now() - _launch_started > LAUNCH_MIN_AIR:
		_launched = false
	_process_stomp(pre_slide)
	_process_landing(pre_slide, delta)
	_animate_model(delta)


func _handle_look(delta: float) -> void:
	var look: Vector2 = _stick("look_left", "look_right", "look_up", "look_down")
	if has_debuff(Constants.DebuffType.INVERTED):
		look = -look
	look *= Constants.JOYSTICK_SENSITIVITY * delta
	if has_debuff(Constants.DebuffType.LAUGHING):
		_laugh_time += delta
		look.y += sin(_laugh_time * Constants.CAMERA_LAUGHING_FREQUENCY) \
			* deg_to_rad(Constants.CAMERA_LAUGHING_AMPLITUDE) * delta
		look.x += cos(_laugh_time * Constants.CAMERA_LAUGHING_FREQUENCY * 0.5) \
			* deg_to_rad(Constants.CAMERA_LAUGHING_AMPLITUDE) * delta
	_apply_look(look)


func _handle_movement(delta: float) -> void:
	var move: Vector2 = _stick("move_left", "move_right", "move_forward", "move_back")
	if has_debuff(Constants.DebuffType.INVERTED):
		move = -move
	var on_ice: bool = has_debuff(Constants.DebuffType.ICE_SLIDE)
	if move == Vector2.ZERO:
		_decelerate(delta, Constants.FRICTION_ICE if on_ice else Constants.FRICTION_GROUND)
		return
	var speed: float = _speed * (Constants.SPRING_SHOES_SPEED_MULTIPLIER if _shoes_until > _now() else 1.0)
	if _turbo_until > _now():
		speed *= TURBO_MULTIPLIER
	var direction: Vector3 = transform.basis * Vector3(move.x, 0.0, move.y)
	var target: Vector3 = direction * speed
	if on_ice:
		# On ice you can only nudge your sliding momentum.
		velocity.x = move_toward(velocity.x, target.x, Constants.FRICTION_ICE * 4.0 * delta)
		velocity.z = move_toward(velocity.z, target.z, Constants.FRICTION_ICE * 4.0 * delta)
	else:
		velocity.x = target.x
		velocity.z = target.z


func _decelerate(delta: float, friction: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	velocity.z = move_toward(velocity.z, 0.0, friction * delta)


func _handle_actions() -> void:
	if Input.is_action_just_pressed(_action("jump")):
		_jump()
	for slot: int in Constants.ITEM_SLOT_COUNT:
		if Input.is_action_just_pressed(_action(InputManager.ITEM_ACTIONS[slot])):
			use_item(slot)
	if Input.is_action_just_pressed(_action("super")):
		use_superpower()


func _jump() -> void:
	if not controls_enabled:
		return
	if has_debuff(Constants.DebuffType.FROZEN):
		_struggle()
		return
	if is_on_floor():
		velocity.y = _jump_velocity
		_jump_count = 1
	elif _has_double_jump() and _jump_count < MAX_JUMPS_SPRING:
		velocity.y = Constants.SPRING_DOUBLE_JUMP_VELOCITY
		_jump_count = MAX_JUMPS_SPRING
		AudioManager.play_sfx(AudioManager.SoundEffect.SPRING_BOING)


## The model animates itself from speed and floor contact; here it only turns
## toward where the body is moving.
func _animate_model(delta: float) -> void:
	var horiz: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	model.set_motion(horiz.length(), is_on_floor())
	if horiz.length() > 0.5 and not is_stunned():
		var local: Vector3 = global_transform.basis.inverse() * horiz
		var yaw: float = atan2(local.x, local.z)
		model.rotation.y = lerp_angle(model.rotation.y, yaw, delta * MODEL_TURN_SPEED)


## Landing squash and dust, plus running dust puffs.
func _process_landing(pre_slide: Vector3, delta: float) -> void:
	var grounded: bool = is_on_floor()
	if grounded and not _was_on_floor:
		var fall: float = -pre_slide.y
		model.play_squash(clampf(fall / LAND_SQUASH_SPEED, 0.0, 1.0) * LAND_SQUASH_MAX)
		if fall > LAND_DUST_SPEED:
			ParticleConfigs.spawn_burst(get_parent(), global_position, ParticleConfigs.dust_puff(),
				LAND_DUST_AMOUNT, DUST_LIFETIME)
	_was_on_floor = grounded
	var running: bool = grounded and Vector2(velocity.x, velocity.z).length() > TACKLE_MIN_SPEED
	_dust_timer = _dust_timer - delta if running else RUN_DUST_INTERVAL
	if _dust_timer <= 0.0:
		_dust_timer = RUN_DUST_INTERVAL
		ParticleConfigs.spawn_burst(get_parent(), global_position, ParticleConfigs.dust_puff(),
			RUN_DUST_AMOUNT, DUST_LIFETIME)


# ─── Items ────────────────────────────────────────────────────────────────

func has_free_slot() -> bool:
	return _slots.has(Constants.PowerUpType.NONE)


## Called by SurpriseBox: stores the item in the first free slot.
## Returns false when all slots are full.
func equip_powerup(type: Constants.PowerUpType) -> bool:
	var slot: int = _slots.find(Constants.PowerUpType.NONE)
	if slot < 0:
		return false
	_slots[slot] = type
	last_box_item = type
	inventory_changed.emit(player_id, _slots.duplicate())
	item_received.emit(player_id, slot, type)
	return true


func use_item(slot: int) -> void:
	var type: int = _slots[slot]
	if type == Constants.PowerUpType.NONE or has_debuff(Constants.DebuffType.LAUGHING):
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
	inventory_changed.emit(player_id, _slots.duplicate())


func _activate_utility(type: int) -> void:
	match type:
		Constants.PowerUpType.UTILITY_SPRING_SHOES:
			_shoes_until = _now() + Constants.POWERUP_DURATION_SPRING_SHOES
		Constants.PowerUpType.UTILITY_BUBBLE:
			_bubble_until = _now() + Constants.POWERUP_DURATION_BUBBLE
		Constants.PowerUpType.UTILITY_JACKPOT:
			collect_gem(randi_range(Constants.JACKPOT_MIN_GEMS, Constants.JACKPOT_MAX_GEMS))
		Constants.PowerUpType.UTILITY_WARP:
			var spots: Array[Node] = get_tree().get_nodes_in_group(Constants.GROUP_GEM_SPAWNS)
			if not spots.is_empty():
				teleport_to((spots.pick_random() as Node3D).global_position)
		Constants.PowerUpType.UTILITY_RADAR:
			reveal_map(Constants.POWERUP_DURATION_RADAR)
	AudioManager.play_sfx(AudioManager.SoundEffect.POWERUP_GRAB)
	powerup_activated.emit(player_id, type)


func _drop_trap(scene: PackedScene) -> void:
	var trap: TrapBase = scene.instantiate() as TrapBase
	trap.owner_player_id = player_id
	get_parent().add_child(trap)
	var behind: Vector3 = global_transform.basis.z * TRAP_DROP_DISTANCE
	trap.global_position = Vector3(global_position.x + behind.x, global_position.y, global_position.z + behind.z)


## Projectiles fly level along the body's facing; camera pitch would aim them into the floor.
func _fire_projectile(scene: PackedScene) -> void:
	var projectile: Node3D = scene.instantiate() as Node3D
	get_parent().add_child(projectile)
	projectile.global_position = muzzle.global_position
	projectile.global_rotation = Vector3(0.0, global_rotation.y, 0.0)
	projectile.set("shooter_id", player_id)


## Every rival drops a gem and giggles for a moment.
func _thunder() -> void:
	AudioManager.play_sfx(AudioManager.SoundEffect.TICKLE_ZAP)
	for rival: Player in _rivals():
		rival.lose_gems(1)
		rival.apply_debuff(Constants.DebuffType.LAUGHING, Constants.DEBUFF_DURATION_THUNDER_LAUGH)


func _rivals() -> Array[Player]:
	var out: Array[Player] = []
	for node: Node in get_tree().get_nodes_in_group(Constants.GROUP_PLAYERS):
		if node != self and node is Player:
			out.append(node as Player)
	return out


## Black Box: empties every slot and restarts the superpower's recharge.
## Tanky's shield protects; a bubble was already popped by the trap's gem loss.
func strip_items() -> void:
	if _is_shielded():
		return
	_slots.fill(Constants.PowerUpType.NONE)
	inventory_changed.emit(player_id, _slots.duplicate())
	if character_data:
		_super_ready_at = _now() + Constants.SUPERPOWER_COOLDOWN
		superpower_changed.emit(player_id, character_data.trait_type, Constants.SUPERPOWER_COOLDOWN)
	items_stripped.emit(player_id)


## Moves the player (portals, warp item, swap). Portals are ignored briefly afterwards.
func teleport_to(pos: Vector3) -> void:
	ParticleConfigs.spawn_burst(get_parent(), global_position + Vector3.UP, ParticleConfigs.bubble_pop_burst())
	global_position = Vector3(pos.x, maxf(pos.y, TELEPORT_HEIGHT), pos.z)
	velocity = Vector3.ZERO
	_portal_until = _now() + Constants.PORTAL_COOLDOWN
	ParticleConfigs.spawn_burst(get_parent(), global_position + Vector3.UP, ParticleConfigs.bubble_pop_burst())
	AudioManager.play_sfx(AudioManager.SoundEffect.SPRING_BOING)


## Throws the player along a ballistic arc that lands on [param target] after
## [param flight_time] seconds; steering is off until then.
func launch_to(target: Vector3, flight_time: float) -> void:
	var offset: Vector3 = target - global_position
	velocity = Vector3(offset.x / flight_time,
		(offset.y + 0.5 * Constants.GRAVITY * flight_time * flight_time) / flight_time,
		offset.z / flight_time)
	_launched = true
	_launch_started = _now()
	_pounding = false


## Shows this player the arena map (radar item, map beacons).
func reveal_map(duration: float) -> void:
	map_reveal_requested.emit(player_id, duration)


func can_use_portal() -> bool:
	return _portal_until <= _now()


# ─── Superpower ───────────────────────────────────────────────────────────

## Each character has one superpower, chosen by its trait; it then recharges.
func use_superpower() -> void:
	if character_data == null or _super_ready_at > _now() or has_debuff(Constants.DebuffType.LAUGHING):
		return
	match character_data.trait_type:
		CharacterData.TraitType.SPEEDSTER:
			_turbo_until = _now() + TURBO_DURATION
			ParticleConfigs.spawn_burst(get_parent(), global_position, ParticleConfigs.spring_launch())
		CharacterData.TraitType.BOUNCER:
			velocity.y = POUND_JUMP_VELOCITY
			_pounding = true
			_pound_started = _now()
			ParticleConfigs.spawn_burst(get_parent(), global_position, ParticleConfigs.spring_launch())
		CharacterData.TraitType.TANK:
			_shield_until = _now() + SHIELD_DURATION
		CharacterData.TraitType.PRANKSTER:
			if not _swap_with_rival():
				return
		_:
			return
	AudioManager.play_sfx(AudioManager.SoundEffect.POWERUP_GRAB)
	_super_ready_at = _now() + Constants.SUPERPOWER_COOLDOWN
	superpower_changed.emit(player_id, character_data.trait_type, Constants.SUPERPOWER_COOLDOWN)
	superpower_used.emit(player_id, character_data.trait_type)


## Bouncer lands: rivals nearby are blown away and drop gems, traps nearby break.
func _ground_pound_impact() -> void:
	_pounding = false
	ParticleConfigs.spawn_burst(get_parent(), global_position, ParticleConfigs.gem_lost_burst())
	ParticleConfigs.spawn_burst(get_parent(), global_position, ParticleConfigs.dust_puff(), LAND_DUST_AMOUNT * 2, DUST_LIFETIME)
	model.play_squash(LAND_SQUASH_MAX)
	for node: Node in get_tree().get_nodes_in_group(Constants.GROUP_TRAPS):
		var trap: TrapBase = node as TrapBase
		if trap and trap.global_position.distance_to(global_position) <= POUND_RADIUS:
			trap.defuse()
	AudioManager.play_sfx(AudioManager.SoundEffect.BUBBLE_POP)
	for rival: Player in _rivals():
		var offset: Vector3 = rival.global_position - global_position
		if offset.length() > POUND_RADIUS:
			continue
		var push: Vector3 = Vector3(offset.x, 0.0, offset.z).normalized() * POUND_FORCE
		rival.apply_knockback(push + Vector3.UP * POUND_FORCE * 0.5)
		_hit_feedback(rival, rival.lose_gems(POUND_GEMS), false)


## Tricky trades places with the leader (or a random rival if Tricky leads).
func _swap_with_rival() -> bool:
	var rivals: Array[Player] = _rivals()
	if rivals.is_empty():
		return false
	var target: Player = rivals.pick_random()
	for rival: Player in rivals:
		if rival.player_id == GameManager.get_leader():
			target = rival
	var mine: Vector3 = global_position
	teleport_to(target.global_position)
	target.teleport_to(mine)
	return true


# ─── Gems ─────────────────────────────────────────────────────────────────

## Pickup from the world. Returns the gems actually gained (frenzy doubles them).
func collect_gem(value: int, boost: bool = true) -> int:
	var gained: int = GameManager.add_gems(player_id, value, boost)
	if gained > 0:
		AudioManager.play_sfx(AudioManager.SoundEffect.GEM_COLLECT)
		ParticleConfigs.spawn_burst(get_parent(), global_position + Vector3.UP * GEM_BURST_HEIGHT,
			ParticleConfigs.gem_collect_burst())
		model.play_cheer(GEM_CHEER_TIME)
	return gained


## Removes gems (absorbed by the bubble). With [param scatter] they burst out as
## loose gems anyone can grab; without, they are handed to a thief by the caller.
## Returns the gems actually removed.
func lose_gems(amount: int, scatter: bool = true) -> int:
	if _is_shielded():
		return 0
	if _has_bubble():
		_pop_bubble()
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
		gem.launch(Vector3(
			cos(angle) * Constants.GEM_LOOSE_SPREAD_FORCE,
			Constants.GEM_LOOSE_UP_FORCE,
			sin(angle) * Constants.GEM_LOOSE_SPREAD_FORCE
		))


## Knockback divided by the character's resistance (1 = normal, Tanky barely budges).
func apply_knockback(impulse: Vector3) -> void:
	if _is_shielded():
		return
	if _has_bubble():
		_pop_bubble()
		return
	var resistance: float = character_data.knockback_resistance if character_data else 1.0
	velocity += impulse / maxf(resistance, MIN_KNOCKBACK_RESISTANCE)
	stun(KNOCKBACK_STUN)


func play_winner_animation() -> void:
	var hop: Tween = create_tween().set_loops(4)
	hop.tween_property(model, "position:y", WINNER_HOP_HEIGHT, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hop.tween_property(model, "position:y", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	ParticleConfigs.spawn_burst(get_parent(), global_position + Vector3.UP * 3.0,
		ParticleConfigs.confetti_shower(), 80, 2.5)
	model.play_cheer(WINNER_CHEER_TIME)


# ─── Debuffs ──────────────────────────────────────────────────────────────

## Applies a debuff for [param duration] seconds. The bubble absorbs it instead.
## Returns false when absorbed.
func apply_debuff(type: Constants.DebuffType, duration: float) -> bool:
	if _is_shielded():
		return false
	if _has_bubble():
		_pop_bubble()
		return false
	if type == Constants.DebuffType.ICE_SLIDE and character_data \
			and character_data.trait_type == CharacterData.TraitType.SPEEDSTER:
		duration *= SPEEDSTER_ICE_RECOVERY
	_debuff_until[type] = maxf(_debuff_until.get(type, 0.0), _now() + duration)
	if type == Constants.DebuffType.LAUGHING:
		_laugh_time = 0.0
	if type == Constants.DebuffType.FROZEN:
		if not _was_frozen:
			_frozen_since = _now()
		ParticleConfigs.spawn_burst(get_parent(), global_position + Vector3.UP, ParticleConfigs.freeze_puff())
	screen_effect_requested.emit(player_id, type, duration)
	return true


## One mash while frozen: shave the freeze down toward its minimum.
func _struggle() -> void:
	var earliest: float = _frozen_since + FREEZE_MIN_TIME
	var until: float = maxf(_debuff_until[Constants.DebuffType.FROZEN] - FREEZE_MASH_STEP, earliest)
	_debuff_until[Constants.DebuffType.FROZEN] = until
	model.play_squash(STRUGGLE_SQUASH)
	ParticleConfigs.spawn_burst(get_parent(), global_position + Vector3.UP, ParticleConfigs.freeze_puff(),
		STRUGGLE_PUFF_AMOUNT, 0.4)
	if until <= _now():
		AudioManager.play_sfx(AudioManager.SoundEffect.BUBBLE_POP)


## Bubble or shield up: the next hit is absorbed (traps check this before
## taking gems, since taking them pops the bubble).
func is_protected() -> bool:
	return _has_bubble() or _is_shielded()


## Traps skip a hunter who was just caught by another one.
func can_be_trapped() -> bool:
	return _trap_immune_until <= _now()


func mark_trapped() -> void:
	_trap_immune_until = _now() + TRAP_GRACE


func _pop_bubble() -> void:
	_bubble_until = 0.0
	velocity += global_transform.basis.z * Constants.BUBBLE_POP_PUSH_FORCE \
		+ Vector3.UP * Constants.BUBBLE_POP_PUSH_FORCE
	AudioManager.play_sfx(AudioManager.SoundEffect.BUBBLE_POP)
	ParticleConfigs.spawn_burst(get_parent(), global_position + Vector3.UP, ParticleConfigs.bubble_pop_burst())


# ─── Contact steal ────────────────────────────────────────────────────────

## Bumping into a frozen/confused opponent steals one gem every GEM_STEAL_INTERVAL.
func _process_steal(delta: float) -> void:
	if _steal_target == null or not is_instance_valid(_steal_target) or not _steal_target.is_vulnerable():
		_steal_target = _find_steal_target()
		_steal_timer = 0.0
		return
	_steal_timer += delta
	if _steal_timer < Constants.GEM_STEAL_INTERVAL:
		return
	_steal_timer -= Constants.GEM_STEAL_INTERVAL
	var amount: int = 1
	if character_data and character_data.trait_type == CharacterData.TraitType.PRANKSTER:
		amount = 2
	collect_gem(_steal_target.lose_gems(amount, false), false)


# ─── Stomp ────────────────────────────────────────────────────────────────

## Landing on a rival's head (falling onto them, contact normal pointing up).
func _process_stomp(pre_slide: Vector3) -> void:
	if not controls_enabled or pre_slide.y > -STOMP_MIN_FALL_SPEED:
		return
	for n: int in get_slide_collision_count():
		var hit: KinematicCollision3D = get_slide_collision(n)
		var rival: Player = hit.get_collider() as Player
		if rival and hit.get_normal().y >= STOMP_NORMAL_Y:
			_stomp(rival)
			return


func _stomp(rival: Player) -> void:
	velocity.y = STOMP_BOUNCE
	_jump_count = 1
	AudioManager.play_sfx(AudioManager.SoundEffect.SPRING_BOING)
	if not rival.can_be_tackled():
		return  # Still a bounce pad, just no second steal.
	rival._tackle_immune_until = _now() + TACKLE_GRACE
	rival.model.play_squash(1.0)
	rival.stun(STOMP_STUN)
	var stolen: int = rival.lose_gems(STOMP_GEMS, false)
	collect_gem(stolen, false)
	_hit_feedback(rival, stolen, true)


## Tanky's shield bounces projectiles back at whoever fired them.
func reflects_projectiles() -> bool:
	return _is_shielded()


# ─── Tackle ───────────────────────────────────────────────────────────────

func _process_tackle() -> void:
	var run: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	if run.length() < TACKLE_MIN_SPEED or _now() < _tackle_ready_at:
		return
	for body: Node3D in interact_area.get_overlapping_bodies():
		var rival: Player = body as Player
		if rival == null or rival == self or not rival.can_be_tackled():
			continue
		var to_rival: Vector3 = rival.global_position - global_position
		to_rival.y = 0.0
		if run.normalized().dot(to_rival.normalized()) >= TACKLE_AIM:
			tackle(rival)
			return


func can_be_tackled() -> bool:
	return _tackle_immune_until <= _now()


func tackle(rival: Player) -> void:
	_tackle_ready_at = _now() + TACKLE_COOLDOWN
	rival._tackle_immune_until = _now() + TACKLE_GRACE
	# Head-on bumps: whoever tackles first wins, no instant tackle back.
	_tackle_immune_until = maxf(_tackle_immune_until, _now() + TACKLE_GRACE * 0.5)
	var away: Vector3 = rival.global_position - global_position
	away.y = 0.0
	rival.apply_knockback(away.normalized() * TACKLE_FORCE + Vector3.UP * TACKLE_LIFT)
	var amount: int = TACKLE_LEADER_GEMS if rival.player_id == GameManager.get_leader() else TACKLE_GEMS
	var stolen: int = rival.lose_gems(amount, false)
	collect_gem(stolen, false)
	_hit_feedback(rival, stolen, true)
	AudioManager.play_sfx(AudioManager.SoundEffect.SPRING_BOING)


## Makes a hit readable on every screen: burst, spin, floating numbers, impact signal.
func _hit_feedback(rival: Player, gems: int, stolen: bool) -> void:
	var mid: Vector3 = (global_position + rival.global_position) * 0.5 + Vector3.UP
	ParticleConfigs.spawn_burst(get_parent(), mid, ParticleConfigs.confetti_shower(), 40, 0.8)
	rival.spin_from_hit()
	var victim_text: String = "-%d" % gems if gems > 0 else tr("MSG_HIT")
	ParticleConfigs.spawn_popup_text(get_parent(), rival.global_position + Vector3.UP * POPUP_HEIGHT,
		victim_text, POPUP_LOSS_COLOR)
	if stolen and gems > 0:
		# Higher than the victim's number so the two never overlap.
		ParticleConfigs.spawn_popup_text(get_parent(), global_position + Vector3.UP * POPUP_HEIGHT * 1.5,
			"+%d" % gems, POPUP_GAIN_COLOR)
	impact.emit(player_id, rival.player_id, gems)


func spin_from_hit() -> void:
	model.play_hurt()
	var tween: Tween = create_tween()
	tween.tween_property(model, "rotation:y", model.rotation.y + TAU, HIT_SPIN_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _find_steal_target() -> Player:
	for body: Node3D in interact_area.get_overlapping_bodies():
		if body != self and body is Player and (body as Player).is_vulnerable():
			return body as Player
	return null
