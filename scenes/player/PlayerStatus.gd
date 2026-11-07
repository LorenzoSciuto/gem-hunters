## PlayerStatus.gd
## Timed states of one hunter, all measured on the pause-aware game clock:
## debuffs (frozen, confused, laughing, ice slide, splat), stun, buffs (bubble,
## shield, spring shoes, turbo) and short grace periods (tackle, traps, portals).
## Also shows them on the body (ice block, dizzy stars, bubble) and tells the
## HUD. Child node "Status" of Player.
extends Node
class_name PlayerStatus

## Requests that the HUD shows a debuff overlay.
signal screen_effect_requested(player_id: int, debuff_type: int, duration: float)
## A debuff ended (expired, or the player broke free of the ice).
signal debuff_cleared(player_id: int, debuff_type: int)

enum Buff { BUBBLE, SHIELD, SHOES, TURBO }
enum Grace { TACKLE, TRAP, PORTAL }

const TURBO_MULTIPLIER: float = 1.8
## Speedsters shake off ice slides this much faster.
const SPEEDSTER_ICE_RECOVERY: float = 0.5
## Frozen hunters mash jump to crack the ice: each press takes this much off,
## but the freeze lasts at least FREEZE_MIN_TIME (rivals need time to rob them).
const FREEZE_MASH_STEP: float = 0.15
const FREEZE_MIN_TIME: float = 2.0
const STRUGGLE_SQUASH: float = 0.2
const STRUGGLE_PUFF_AMOUNT: int = 6
const STRUGGLE_PUFF_LIFETIME: float = 0.4
const DIZZY_STAR_COUNT: int = 5

@onready var player: Player = get_parent()
@onready var _ice: MeshInstance3D = $"../IceEffect"
@onready var _stars: GPUParticles3D = $"../ConfusionStars"
@onready var _bubble: MeshInstance3D = $"../BubbleShield"

var _debuff_until: Dictionary = {}
var _buff_until: Dictionary = {}
var _grace_until: Dictionary = {}
var _stunned_until: float = 0.0
var _frozen_since: float = 0.0
var _was_frozen: bool = false


func _ready() -> void:
	_stars.draw_pass_1 = ParticleConfigs.star_mesh()
	_stars.amount = DIZZY_STAR_COUNT


## Status effects are only seen by others in first person: same layer as the body.
func set_render_layer(layer: int) -> void:
	for fx: VisualInstance3D in [_bubble, _ice, _stars]:
		fx.layers = 1 << layer


func _process(_delta: float) -> void:
	var frozen: bool = has(Constants.DebuffType.FROZEN)
	if _was_frozen and not frozen:
		debuff_cleared.emit(player.player_id, Constants.DebuffType.FROZEN)
	_was_frozen = frozen
	_ice.visible = frozen
	_stars.emitting = has(Constants.DebuffType.INVERTED) or is_stunned()
	_bubble.visible = is_protected()


func _now() -> float:
	return GameManager.game_time()


# ─── Debuffs ──────────────────────────────────────────────────────────────

func has(type: Constants.DebuffType) -> bool:
	return _debuff_until.get(type, 0.0) > _now()


## Applies a debuff for [param duration] seconds unless a bubble or shield
## absorbs it. Returns false when absorbed.
func apply_debuff(type: Constants.DebuffType, duration: float) -> bool:
	if absorb_hit():
		return false
	if type == Constants.DebuffType.ICE_SLIDE and _trait() == CharacterData.TraitType.SPEEDSTER:
		duration *= SPEEDSTER_ICE_RECOVERY
	_debuff_until[type] = maxf(_debuff_until.get(type, 0.0), _now() + duration)
	if type == Constants.DebuffType.FROZEN:
		if not _was_frozen:
			_frozen_since = _now()
		ParticleConfigs.spawn_burst(player.get_parent(), player.global_position + Vector3.UP, ParticleConfigs.freeze_puff())
	screen_effect_requested.emit(player.player_id, type, duration)
	return true


## One jump press while frozen: shave the freeze down toward its minimum.
func struggle() -> void:
	var until: float = maxf(_debuff_until[Constants.DebuffType.FROZEN] - FREEZE_MASH_STEP, _frozen_since + FREEZE_MIN_TIME)
	_debuff_until[Constants.DebuffType.FROZEN] = until
	player.model.play_squash(STRUGGLE_SQUASH)
	ParticleConfigs.spawn_burst(player.get_parent(), player.global_position + Vector3.UP, ParticleConfigs.freeze_puff(),
		STRUGGLE_PUFF_AMOUNT, STRUGGLE_PUFF_LIFETIME)
	if until <= _now():
		AudioManager.play_sfx(AudioManager.SoundEffect.BUBBLE_POP)


## Frozen or confused hunters can be robbed by bumping into them.
func is_vulnerable() -> bool:
	return has(Constants.DebuffType.FROZEN) or has(Constants.DebuffType.INVERTED)


# ─── Stun ─────────────────────────────────────────────────────────────────

## Dazed by a hit: no control for a moment, dizzy stars overhead.
func is_stunned() -> bool:
	return _stunned_until > _now()


## Takes control away for [param duration] seconds (bubble and shield protect).
func stun(duration: float) -> void:
	if is_protected():
		return
	_stunned_until = maxf(_stunned_until, _now() + duration)
	player.model.play_hurt()


# ─── Buffs & protection ───────────────────────────────────────────────────

func grant(buff: Buff, duration: float) -> void:
	_buff_until[buff] = _now() + duration


func has_buff(buff: Buff) -> bool:
	return _buff_until.get(buff, 0.0) > _now()


## Bubble or shield up: the next hit is absorbed. Check before taking gems,
## since taking them pops the bubble.
func is_protected() -> bool:
	return has_buff(Buff.BUBBLE) or has_buff(Buff.SHIELD)


## A hit lands: the shield (Tanky) blocks it for free, the bubble pops instead.
## Returns true when the hit was absorbed.
func absorb_hit() -> bool:
	if has_buff(Buff.SHIELD):
		return true
	if not has_buff(Buff.BUBBLE):
		return false
	_buff_until.erase(Buff.BUBBLE)
	player.velocity += player.global_transform.basis.z * Constants.BUBBLE_POP_PUSH_FORCE \
		+ Vector3.UP * Constants.BUBBLE_POP_PUSH_FORCE
	AudioManager.play_sfx(AudioManager.SoundEffect.BUBBLE_POP)
	ParticleConfigs.spawn_burst(player.get_parent(), player.global_position + Vector3.UP, ParticleConfigs.bubble_pop_burst())
	return true


## Spring shoes and turbo stack on the character's own speed.
func speed_multiplier() -> float:
	var multiplier: float = Constants.SPRING_SHOES_SPEED_MULTIPLIER if has_buff(Buff.SHOES) else 1.0
	return multiplier * (TURBO_MULTIPLIER if has_buff(Buff.TURBO) else 1.0)


# ─── Grace periods ────────────────────────────────────────────────────────

## Short immunity: no second tackle, no chain-trapping, no portal ping-pong.
func grant_grace(kind: Grace, duration: float) -> void:
	_grace_until[kind] = maxf(_grace_until.get(kind, 0.0), _now() + duration)


func in_grace(kind: Grace) -> bool:
	return _grace_until.get(kind, 0.0) > _now()


func _trait() -> int:
	return player.character_data.trait_type if player.character_data else CharacterData.TraitType.NONE
