## Sprinkler.gd
## Rotating garden sprinkler: grey base, yellow head, two arcing water jets.
## It sprays for spray_duration, rests for pause_duration (shaking just before
## it starts again); anyone the water hits slips and drops a gem.
extends Node3D

const BASE_COLOR: Color = Color(0.55, 0.58, 0.66)
const HEAD_COLOR: Color = Color(1.0, 0.82, 0.25)
const ARM_COLOR: Color = Color(0.25, 0.6, 1.0)
const JET_AMOUNT: int = 70
const JET_LIFETIME: float = 0.9
## Warning wiggle before each spray.
const WARN_TIME: float = 0.7
const WARN_SHAKE: float = 0.12
const WARN_SHAKE_STEP: float = 0.05

@export var spray_duration: float = 3.0
@export var pause_duration: float = 4.0
@export var ice_slide_duration: float = 2.5
@export var rotation_speed: float = 2.0

@onready var hit_area: Area3D = $Nozzle/HitArea
@onready var particles: GPUParticles3D = $Nozzle/WaterParticles
@onready var nozzle: Node3D = $Nozzle
@onready var base_mesh: MeshInstance3D = $BaseMesh
@onready var head_mesh: MeshInstance3D = $Nozzle/HeadMesh
@onready var arm_mesh: MeshInstance3D = $Nozzle/ArmMesh
@onready var back_particles: GPUParticles3D = $Nozzle/BackParticles

var _is_spraying: bool = false

func _ready() -> void:
	base_mesh.material_override = ToonMaterials.get_material(BASE_COLOR)
	head_mesh.material_override = ToonMaterials.get_material(HEAD_COLOR)
	arm_mesh.material_override = ToonMaterials.get_material(ARM_COLOR)
	for jet: GPUParticles3D in [particles, back_particles]:
		jet.process_material = ParticleConfigs.water_jet()
		jet.draw_pass_1 = ParticleConfigs.soft_quad()
		jet.amount = JET_AMOUNT
		jet.lifetime = JET_LIFETIME
		jet.local_coords = false  # Droplets keep flying after the head turns: a spiral of water.
	if hit_area:
		hit_area.body_entered.connect(_on_hit_area_body_entered)
	_run_cycle()

func _physics_process(delta: float) -> void:
	if _is_spraying and nozzle:
		nozzle.rotate_y(rotation_speed * delta)

func _run_cycle() -> void:
	while is_inside_tree():
		_is_spraying = true
		particles.emitting = true
		back_particles.emitting = true
		if hit_area:
			hit_area.monitoring = true
		await get_tree().create_timer(spray_duration).timeout

		_is_spraying = false
		particles.emitting = false
		back_particles.emitting = false
		if hit_area:
			hit_area.monitoring = false
		await get_tree().create_timer(maxf(pause_duration - WARN_TIME, 0.0)).timeout
		var shake: Tween = create_tween().set_loops(int(WARN_TIME / (WARN_SHAKE_STEP * 2.0)))
		shake.tween_property(nozzle, "rotation:z", WARN_SHAKE, WARN_SHAKE_STEP)
		shake.tween_property(nozzle, "rotation:z", -WARN_SHAKE, WARN_SHAKE_STEP)
		await get_tree().create_timer(WARN_TIME).timeout
		shake.kill()
		nozzle.rotation.z = 0.0

func _on_hit_area_body_entered(body: Node3D) -> void:
	if not _is_spraying or not body is Player:
		return
	var player: Player = body as Player
	if player.apply_debuff(Constants.DebuffType.ICE_SLIDE, ice_slide_duration):
		player.lose_gems(1)
