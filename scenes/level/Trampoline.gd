## Trampoline.gd
## Giant bouncy mushroom / trampoline.
## Propels players skyward on contact, enabling vertical play and shortcut jumps.
extends Area3D

@export var bounce_force: float = 16.0

@onready var anim: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		(body as Player).velocity.y = bounce_force
		ParticleConfigs.spawn_burst(get_parent(), global_position, ParticleConfigs.spring_launch())
		if anim and anim.has_animation("bounce"):
			anim.play("bounce")
		AudioManager.play_sfx(AudioManager.SoundEffect.SPRING_BOING)
