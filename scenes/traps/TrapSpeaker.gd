## TrapSpeaker.gd
## "Prank Speaker" trap: whoever steps on it is scared stiff for a moment and
## their controls are scrambled.
extends TrapBase

@onready var anim: AnimationPlayer = $AnimationPlayer


func _apply_trap_effect(player: Player) -> void:
	if player.status.apply_debuff(Constants.DebuffType.FROZEN, effect_duration):
		player.status.apply_debuff(Constants.DebuffType.INVERTED, Constants.DEBUFF_DURATION_INVERTED)
	if anim.has_animation("scare_jump"):
		anim.play("scare_jump")


func _play_trap_sfx() -> void:
	AudioManager.play_sfx(AudioManager.SoundEffect.SPEAKER_SCARE)
