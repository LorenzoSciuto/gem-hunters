## TrapCake.gd
## "Cake in Face" trap: covers the victim's screen in pink frosting and makes them giggle.
extends TrapBase


func _apply_trap_effect(player: Player) -> void:
	if player.apply_debuff(Constants.DebuffType.SPLAT, Constants.DEBUFF_DURATION_SPLAT):
		player.apply_debuff(Constants.DebuffType.LAUGHING, Constants.DEBUFF_DURATION_LAUGHING)


func _play_trap_sfx() -> void:
	AudioManager.play_sfx(AudioManager.SoundEffect.CAKE_SPLAT)
