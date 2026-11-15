## PlayerCombat.gd
## Hunter-vs-hunter contact: bumps (run into a rival: both drop gems), stomps
## (land on their head: the clash is won), robbing frozen/confused rivals by
## contact, and the ground pound. Every won hit goes through [method _hit_feedback]
## so it reads on all screens. Child node "Combat" of Player.
extends Node
class_name PlayerCombat

## A hunter was hit (bump, stomp, ground pound, trap): [param gems] changed hands or scattered.
signal impact(attacker_id: int, victim_id: int, gems: int)

## impact's attacker_id when nobody else dealt the hit.
const NO_ATTACKER: int = -1

## Bump: running into a rival (this much speed, aimed at it as a cosine) wins
## nothing: both bounce apart and drop BUMP_GEMS on the ground (never a life),
## then get a grace period. Landing on a head (stomp) is what wins a clash.
const TACKLE_MIN_SPEED: float = 4.0
const TACKLE_AIM: float = 0.5
const BUMP_GEMS: int = 3
const TACKLE_FORCE: float = 9.0
const TACKLE_LIFT: float = 4.0
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

const HIT_SPIN_TIME: float = 0.45
## Who won a clash must read at a glance: the winner cheers in sparkles, the
## loser flashes red and sheds gems.
const WIN_SPARKLE_AMOUNT: int = 36
const WIN_CHEER_TIME: float = 0.8
const LOSS_BURST_AMOUNT: int = 30
const HIT_BURST_LIFETIME: float = 0.8
const DUST_LIFETIME: float = 0.6
const BUMP_DUST_AMOUNT: int = 20

@onready var player: Player = get_parent()
@onready var _reach: Area3D = $"../InteractArea"

var _pounding: bool = false
var _pound_started: float = 0.0
var _steal_target: Player = null
var _steal_timer: float = 0.0


func _now() -> float:
	return GameManager.game_time()


## Per physics frame while the hunter has control.
func update(delta: float) -> void:
	_process_steal(delta)
	_process_bump()


func can_be_hit() -> bool:
	return not player.status.in_grace(PlayerStatus.Grace.TACKLE)


## The victim spins and winces.
func spin_from_hit() -> void:
	player.model.play_hurt()
	var tween: Tween = player.create_tween()
	tween.tween_property(player.model, "rotation:y", player.model.rotation.y + TAU, HIT_SPIN_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# ─── Bump ─────────────────────────────────────────────────────────────────

func _process_bump() -> void:
	if not can_be_hit():
		return
	var run: Vector3 = Vector3(player.velocity.x, 0.0, player.velocity.z)
	if run.length() < TACKLE_MIN_SPEED:
		return
	for body: Node3D in _reach.get_overlapping_bodies():
		var rival: Player = body as Player
		if rival == null or rival == player or not rival.combat.can_be_hit():
			continue
		var to_rival: Vector3 = rival.global_position - player.global_position
		to_rival.y = 0.0
		if run.normalized().dot(to_rival.normalized()) >= TACKLE_AIM:
			_bump(rival, to_rival.normalized())
			return


## Nobody wins a bump: both fly apart and drop gems for anyone to grab.
func _bump(rival: Player, toward_rival: Vector3) -> void:
	AudioManager.play_sfx(AudioManager.SoundEffect.SPRING_BOING)
	ParticleConfigs.spawn_burst(player.get_parent(), (player.global_position + rival.global_position) * 0.5 + Vector3.UP,
		ParticleConfigs.dust_puff(), BUMP_DUST_AMOUNT, DUST_LIFETIME)
	for pair: Array in [[rival, toward_rival], [player, -toward_rival]]:
		var hunter: Player = pair[0]
		hunter.status.grant_grace(PlayerStatus.Grace.TACKLE, TACKLE_GRACE)
		# Gems first: a bubble pops or a shield holds here, before any push.
		var protected: bool = hunter.status.is_protected()
		var lost: int = hunter.lose_gems(BUMP_GEMS)
		if not protected:
			hunter.apply_knockback((pair[1] as Vector3) * TACKLE_FORCE + Vector3.UP * TACKLE_LIFT)
			hunter.combat.take_remote_hit(NO_ATTACKER, lost)


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
	if not rival.combat.can_be_hit():
		return  # Still a bounce pad, just no second steal.
	rival.status.grant_grace(PlayerStatus.Grace.TACKLE, TACKLE_GRACE)
	rival.take_hit()
	rival.model.play_squash(1.0)
	rival.status.stun(STOMP_STUN)
	_steal_and_show(rival, STOMP_GEMS + (player.character_data.stomp_bonus_gems if player.character_data else 0))


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
	var amount: int = player.character_data.contact_steal_gems if player.character_data else 1
	_steal_target.take_hit()
	player.collect_gem(_steal_target.lose_gems(amount, false), false)


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
		var protected: bool = rival.status.is_protected()
		rival.take_hit()
		var lost: int = rival.lose_gems(POUND_GEMS)  # Before the push, which would pop a bubble.
		if not protected:
			rival.apply_knockback(push + Vector3.UP * POUND_FORCE * 0.5)
			_hit_feedback(rival, lost, false)


# ─── Feedback ─────────────────────────────────────────────────────────────

func _steal_and_show(rival: Player, amount: int) -> void:
	var stolen: int = rival.lose_gems(amount, false)
	player.collect_gem(stolen, false)
	_hit_feedback(rival, stolen, true)


## Makes a hit readable on every screen: the winner cheers with a green "+N" /
## "POW!", the loser spins with a red "-N" / "OUCH!", then the impact signal.
func _hit_feedback(rival: Player, gems: int, stolen: bool) -> void:
	var world: Node = player.get_parent()
	player.model.play_cheer(WIN_CHEER_TIME)
	ParticleConfigs.spawn_burst(world, player.global_position + Vector3.UP, ParticleConfigs.gem_collect_burst(),
		WIN_SPARKLE_AMOUNT, HIT_BURST_LIFETIME)
	# Higher than the loser's text so the two never overlap.
	PopupText.spawn(world, player.global_position + Vector3.UP * PopupText.HEIGHT * 1.5,
		"+%d" % gems if stolen and gems > 0 else tr("MSG_HIT"), PopupText.GAIN_COLOR)
	rival.combat.spin_from_hit()
	rival.combat.show_loss(gems)
	impact.emit(player.player_id, rival.player_id, gems)


## A hit with no attacker in reach (a trap): spin, loss number and screen shake,
## for [param attacker_id] too unless it is this hunter (its own trap) or -1.
func take_remote_hit(attacker_id: int, gems: int) -> void:
	spin_from_hit()
	show_loss(gems)
	impact.emit(attacker_id if attacker_id != player.player_id else NO_ATTACKER, player.player_id, gems)


## Red "-N" (or "OUCH!") over this hunter, with gems bursting out.
func show_loss(gems: int) -> void:
	ParticleConfigs.spawn_burst(player.get_parent(), player.global_position + Vector3.UP, ParticleConfigs.gem_lost_burst(),
		LOSS_BURST_AMOUNT, HIT_BURST_LIFETIME)
	PopupText.spawn(player.get_parent(), player.global_position + Vector3.UP * PopupText.HEIGHT,
		"-%d" % gems if gems > 0 else tr("MSG_HIT_TAKEN"), PopupText.LOSS_COLOR)
