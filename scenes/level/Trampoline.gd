## Trampoline.gd
## Giant bouncy mushroom / trampoline.
## Propels players skyward on contact, enabling vertical play and shortcut jumps.
## With [member aimed] it instead throws the player along an arc that lands on
## [member launch_target] (the golden return pad outside the maze uses this).
extends Area3D

@export var bounce_force: float = 16.0
@export var aimed: bool = false
@export var launch_target: Vector3 = Vector3.ZERO
@export var flight_time: float = 2.6

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var cap: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)


## Recolors the mushroom cap (e.g. gold for the return pad).
func set_cap_color(color: Color) -> void:
	cap.material_override = ToonMaterials.get_material(color)


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		var player: Player = body as Player
		if aimed:
			player.launch_to(launch_target, flight_time)
		else:
			player.velocity.y = bounce_force
		ParticleConfigs.spawn_burst(get_parent(), global_position, ParticleConfigs.spring_launch())
		if anim and anim.has_animation("bounce"):
			anim.play("bounce")
		AudioManager.play_sfx(AudioManager.SoundEffect.SPRING_BOING)
