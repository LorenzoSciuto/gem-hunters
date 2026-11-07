## TrapBanana.gd
## "Banana Peel" trap: the victim slips, falls and slides helplessly for a
## couple of seconds, then keeps skidding on slippery feet.
extends TrapBase

## Sideways shove so the slip is visible.
const SLIP_PUSH: float = 6.0
## Time on the floor with no control (dizzy stars) after the slip.
const SLIP_STUN: float = 2.0


func _apply_trap_effect(player: Player) -> void:
	if player.apply_debuff(Constants.DebuffType.ICE_SLIDE, effect_duration):
		player.apply_knockback(player.global_transform.basis.x * SLIP_PUSH)
		player.stun(SLIP_STUN)


func _play_trap_sfx() -> void:
	AudioManager.play_sfx(AudioManager.SoundEffect.SPRING_BOING)
