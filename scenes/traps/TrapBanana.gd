## TrapBanana.gd
## "Banana Peel" trap: the victim slips and slides out of control.
extends TrapBase

## Sideways shove so the slip is visible.
const SLIP_PUSH: float = 6.0


func _apply_trap_effect(player: Player) -> void:
	if player.apply_debuff(Constants.DebuffType.ICE_SLIDE, Constants.DEBUFF_DURATION_ICE_SLIDE):
		player.apply_knockback(player.global_transform.basis.x * SLIP_PUSH)


func _play_trap_sfx() -> void:
	AudioManager.play_sfx(AudioManager.SoundEffect.SPRING_BOING)
