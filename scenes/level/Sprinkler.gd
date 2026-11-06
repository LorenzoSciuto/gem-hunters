## Sprinkler.gd
## Periodic rotating garden sprinkler.
## If hit by the active stream, player slips and drops 1 gem.
extends Node3D

@export var spray_duration: float = 3.0
@export var pause_duration: float = 4.0
@export var ice_slide_duration: float = 2.5
@export var rotation_speed: float = 2.0

@onready var hit_area: Area3D = $Nozzle/HitArea
@onready var particles: GPUParticles3D = $Nozzle/WaterParticles
@onready var nozzle: Node3D = $Nozzle

var _is_spraying: bool = false

func _ready() -> void:
	if hit_area:
		hit_area.body_entered.connect(_on_hit_area_body_entered)
	_run_cycle()

func _physics_process(delta: float) -> void:
	if _is_spraying and nozzle:
		nozzle.rotate_y(rotation_speed * delta)

func _run_cycle() -> void:
	while is_inside_tree():
		_is_spraying = true
		if particles:
			particles.emitting = true
		if hit_area:
			hit_area.monitoring = true
		await get_tree().create_timer(spray_duration).timeout

		_is_spraying = false
		if particles:
			particles.emitting = false
		if hit_area:
			hit_area.monitoring = false
		await get_tree().create_timer(pause_duration).timeout

func _on_hit_area_body_entered(body: Node3D) -> void:
	if not _is_spraying or not body is Player:
		return
	var player: Player = body as Player
	if player.apply_debuff(Constants.DebuffType.ICE_SLIDE, ice_slide_duration):
		player.lose_gems(1)
