## TrapWaterBalloon.gd
## "Water Balloon" trap: soaks the victim and leaves an ice patch that makes
## everyone who crosses it slide.
extends TrapBase

const ICE_PATCH_SCENE: PackedScene = preload("res://scenes/effects/FX_IcePatch.tscn")


func _apply_trap_effect(player: Player) -> void:
	if player.apply_debuff(Constants.DebuffType.FROZEN, Constants.DEBUFF_DURATION_BALLOON_FREEZE):
		player.apply_debuff(Constants.DebuffType.ICE_SLIDE, Constants.DEBUFF_DURATION_ICE_SLIDE)
	var patch: Node3D = ICE_PATCH_SCENE.instantiate() as Node3D
	get_parent().add_child(patch)
	patch.global_position = global_position


func _play_trap_sfx() -> void:
	AudioManager.play_sfx(AudioManager.SoundEffect.FART_HORN)
