## TrapSpeaker.gd
## "Prank Speaker" trap: triggers on proximity, scares the victim stiff for a
## moment and scrambles their controls.
extends TrapBase

@onready var detection_area: Area3D = $DetectionArea
@onready var anim: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	super._ready()
	detection_area.body_entered.connect(_on_body_entered)


func _apply_trap_effect(player: Player) -> void:
	if player.apply_debuff(Constants.DebuffType.FROZEN, Constants.DEBUFF_DURATION_SPEAKER_FREEZE):
		player.apply_debuff(Constants.DebuffType.INVERTED, Constants.DEBUFF_DURATION_INVERTED)
	if anim.has_animation("scare_jump"):
		anim.play("scare_jump")


func _play_trap_sfx() -> void:
	AudioManager.play_sfx(AudioManager.SoundEffect.SPEAKER_SCARE)
