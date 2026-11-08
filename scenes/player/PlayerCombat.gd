## PlayerCombat.gd
## Hunter-vs-hunter contact: tackles (run into a rival), stomps (land on their
## head), robbing frozen/confused rivals by bumping into them, and Bouncer's
## ground pound. Every hit goes through [method _hit_feedback] so it reads on
## all screens. Child node "Combat" of Player.
extends Node
class_name PlayerCombat

## A hunter hit another (tackle, stomp, ground pound): [param gems] changed hands or scattered.
signal impact(attacker_id: int, victim_id: int, gems: int)

## Tackle: needs this much horizontal speed, aimed at the rival (cosine). The
## victim flies back and loses gems (more if crowned), then gets a grace period.
const TACKLE_MIN_SPEED: float = 4.0
const TACKLE_AIM: float = 0.5
const TACKLE_GEMS: int = 2
const TACKLE_LEADER_GEMS: int = 3
const TACKLE_FORCE: float = 9.0
const TACKLE_LIFT: float = 4.0
const TACKLE_COOLDOWN: float = 1.5
const TACKLE_GRACE: float = 2.0

## Stomp: falling onto a rival (contact normal pointing up at least this much).
const STOMP_MIN_FALL_SPEED: float = 2.0
const STOMP_NORMAL_Y: float = 0.7
const STOMP_BOUNCE: float = 9.5
const STOMP_GEMS: int = 2
const STOMP_STUN: float = 1.5

## Ground pound (Bouncer): leap, slam down with extra gravity, blast rivals and traps.
const POUND_JUMP_VELOCITY: float = 13.0
const POUND_FALL_GRAVITY: float = 2.5
const POUND_MIN_AIR_TIME: float = 0.25
const POUND_RADIUS: float = 6.5
const POUND_FORCE: float = 9.0
const POUND_GEMS: int = 3
const POUND_DUST_AMOUNT: int = 28
const POUND_SQUASH: float = 0.45

## Robbing a frozen/confused rival by contact: gems per steal (Pranksters take more).
const STEAL_GEMS: int = 1
const PRANKSTER_STEAL_GEMS: int = 2

const HIT_SPIN_TIME: float = 0.45
const HIT_CONFETTI_AMOUNT: int = 40
const HIT_CONFETTI_LIFETIME: float = 0.8
const DUST_LIFETIME: float = 0.6

@onready var player: Player = get_parent()
@onready var _reach: Area3D = $"../InteractArea"

var _tackle_ready_at: float = 0.0
var _pounding: bool = false
var _pound_started: float = 0.0
var _steal_target: Player = null
var _steal_timer: float = 0.0


func _now() -> float:
	return GameManager.game_time()


## Per physics frame while the hunter has control.
func update(delta: float) -> void:
	_process_steal(delta)
	_process_tackle()


func can_be_tackled() -> bool:
	return not player.status.in_grace(PlayerStatus.Grace.TACKLE)


## The victim spins and winces.
func spin_from_hit() -> void:
	player.model.play_hurt()
	var tween: Tween = player.create_tween()
	tween.tween_property(player.model, "rotation:y", player.model.rotation.y + TAU, HIT_SPIN_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# ─── Tackle ───────────────────────────────────────────────────────────────

func _process_tackle() -> void:
	var run: Vector3 = Vector3(player.velocity.x, 0.0, player.velocity.z)
	if run.length() < TACKLE_MIN_SPEED or _now() < _tackle_ready_at:
		return
	for body: Node3D in _reach.get_overlapping_bodies():
		var rival: Player = body as Player
		if rival == null or rival == player or not rival.combat.can_be_tackled():
			continue
		var to_rival: Vector3 = rival.global_position - player.global_position
		to_rival.y = 0.0
		if run.normalized().dot(to_rival.normalized()) >= TACKLE_AIM:
			_tackle(rival)
			return


func _tackle(rival: Player) -> void:
	_tackle_ready_at = _now() + TACKLE_COOLDOWN
	rival.status.grant_grace(PlayerStatus.Grace.TACKLE, TACKLE_GRACE)
	# Head-on bumps: whoever tackles first wins, no instant tackle back.
	player.status.grant_grace(PlayerStatus.Grace.TACKLE, TACKLE_GRACE * 0.5)
	var away: Vector3 = rival.global_position - player.global_position
	away.y = 0.0
	rival.take_hit()
	rival.apply_knockback(away.normalized() * TACKLE_FORCE + Vector3.UP * TACKLE_LIFT)
	var amount: int = TACKLE_LEADER_GEMS if rival.player_id == GameManager.get_leader() else TACKLE_GEMS
	_steal_and_show(rival, amount)
	AudioManager.play_sfx(AudioManager.SoundEffect.SPRING_BOING)


# ─── Stomp ────────────────────────────────────────────────────────────────

## After move_and_slide: did we land on a rival's head?
func check_stomp(pre_slide: Vector3) -> void:
	if not player.controls_enabled or pre_slide.y > -STOMP_MIN_FALL_SPEED:
		return
	for n: int in player.get_slide_collision_count():
		var hit: KinematicCollision3D = player.get_slide_collision(n)
		var rival: Player = hit.get_collider() as Player
		if rival and hit.get_normal().y >= STOMP_NORMAL_Y:
			_stomp(rival)
			return


func _stomp(rival: Player) -> void:
	player.bounce(STOMP_BOUNCE)
	AudioManager.play_sfx(AudioManager.SoundEffect.SPRING_BOING)
	if not rival.combat.can_be_tackled():
		return  # Still a bounce pad, just no second steal.
	rival.status.grant_grace(PlayerStatus.Grace.TACKLE, TACKLE_GRACE)
	rival.take_hit()
	rival.model.play_squash(1.0)
	rival.status.stun(STOMP_STUN)
	_steal_and_show(rival, STOMP_GEMS)


# ─── Contact steal ────────────────────────────────────────────────────────

## Bumping into a frozen/confused rival steals gems every GEM_STEAL_INTERVAL.
func _process_steal(delta: float) -> void:
	if _steal_target == null or not is_instance_valid(_steal_target) or not _steal_target.status.is_vulnerable():
		_steal_target = _find_steal_target()
		_steal_timer = 0.0
		return
	_steal_timer += delta
	if _steal_timer < Constants.GEM_STEAL_INTERVAL:
		return
	_steal_timer -= Constants.GEM_STEAL_INTERVAL
	var prankster: bool = player.character_data and player.character_data.trait_type == CharacterData.TraitType.PRANKSTER
	_steal_target.take_hit()
	player.collect_gem(_steal_target.lose_gems(PRANKSTER_STEAL_GEMS if prankster else STEAL_GEMS, false), false)


func _find_steal_target() -> Player:
	for body: Node3D in _reach.get_overlapping_bodies():
		if body != player and body is Player and (body as Player).status.is_vulnerable():
			return body as Player
	return null


# ─── Ground pound ─────────────────────────────────────────────────────────

func start_ground_pound() -> void:
	player.velocity.y = POUND_JUMP_VELOCITY
	_pounding = true
	_pound_started = _now()
	ParticleConfigs.spawn_burst(player.get_parent(), player.global_position, ParticleConfigs.spring_launch())


## Extra gravity while slamming back down.
func gravity_scale() -> float:
	return POUND_FALL_GRAVITY if _pounding and player.velocity.y < 0.0 else 1.0


func cancel_ground_pound() -> void:
	_pounding = false


## On touching the floor: a pound in progress lands.
func on_floor() -> void:
	if _pounding and _now() - _pound_started > POUND_MIN_AIR_TIME:
		_ground_pound_impact()


## Rivals nearby are blown away and drop gems; traps nearby break.
func _ground_pound_impact() -> void:
	_pounding = false
	var at: Vector3 = player.global_position
	ParticleConfigs.spawn_burst(player.get_parent(), at, ParticleConfigs.gem_lost_burst())
	ParticleConfigs.spawn_burst(player.get_parent(), at, ParticleConfigs.dust_puff(), POUND_DUST_AMOUNT, DUST_LIFETIME)
	player.model.play_squash(POUND_SQUASH)
	AudioManager.play_sfx(AudioManager.SoundEffect.BUBBLE_POP)
	for node: Node in get_tree().get_nodes_in_group(Constants.GROUP_TRAPS):
		var trap: TrapBase = node as TrapBase
		if trap and trap.global_position.distance_to(at) <= POUND_RADIUS:
			trap.defuse()
	for rival: Player in player.rivals():
		var offset: Vector3 = rival.global_position - at
		if offset.length() > POUND_RADIUS:
			continue
		var push: Vector3 = Vector3(offset.x, 0.0, offset.z).normalized() * POUND_FORCE
		rival.take_hit()
		rival.apply_knockback(push + Vector3.UP * POUND_FORCE * 0.5)
		_hit_feedback(rival, rival.lose_gems(POUND_GEMS), false)


# ─── Feedback ─────────────────────────────────────────────────────────────

func _steal_and_show(rival: Player, amount: int) -> void:
	var stolen: int = rival.lose_gems(amount, false)
	player.collect_gem(stolen, false)
	_hit_feedback(rival, stolen, true)


## Makes a hit readable on every screen: burst, spin, floating numbers, impact signal.
func _hit_feedback(rival: Player, gems: int, stolen: bool) -> void:
	var world: Node = player.get_parent()
	var mid: Vector3 = (player.global_position + rival.global_position) * 0.5 + Vector3.UP
	ParticleConfigs.spawn_burst(world, mid, ParticleConfigs.confetti_shower(), HIT_CONFETTI_AMOUNT, HIT_CONFETTI_LIFETIME)
	rival.combat.spin_from_hit()
	var victim_text: String = "-%d" % gems if gems > 0 else tr("MSG_HIT")
	ParticleConfigs.spawn_popup_text(world, rival.global_position + Vector3.UP * ParticleConfigs.POPUP_HEIGHT,
		victim_text, ParticleConfigs.POPUP_LOSS_COLOR)
	if stolen and gems > 0:
		# Higher than the victim's number so the two never overlap.
		ParticleConfigs.spawn_popup_text(world, player.global_position + Vector3.UP * ParticleConfigs.POPUP_HEIGHT * 1.5,
			"+%d" % gems, ParticleConfigs.POPUP_GAIN_COLOR)
	impact.emit(player.player_id, rival.player_id, gems)
