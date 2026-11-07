## TrapCake.gd
## "Cake in Face" trap: covers the victim's screen in pink frosting, stops
## them for a moment while they wipe their face, and makes them giggle.
extends TrapBase

const WIPE_STUN: float = 2.0


func _apply_trap_effect(player: Player) -> void:
	if player.apply_debuff(Constants.DebuffType.SPLAT, effect_duration):
		player.apply_debuff(Constants.DebuffType.LAUGHING, Constants.DEBUFF_DURATION_LAUGHING)
		player.stun(WIPE_STUN)


func _play_trap_sfx() -> void:
	AudioManager.play_sfx(AudioManager.SoundEffect.CAKE_SPLAT)
