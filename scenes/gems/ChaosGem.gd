## ChaosGem.gd
## The Chaos Gem: appears once per match (GemSpawner decides when), under a
## rainbow beam visible over the walls. Whoever grabs it halves every rival's
## gems (GameManager.halve_rivals); shields and bubbles don't help.
## Visuals are built in code, like MapBeacon.
extends Area3D
class_name ChaosGem

const GEM_RADIUS: float = 0.55
const CROWN_HEIGHT: float = 0.3
const PAVILION_HEIGHT: float = 0.75
const FLOAT_HEIGHT: float = 1.3
const BOB_AMPLITUDE: float = 0.15
const BOB_SPEED: float = 2.0
const SPIN_SPEED: float = 1.6
const PICKUP_RADIUS: float = 1.1
const BEAM_HEIGHT: float = 45.0
const BEAM_RADIUS: float = 0.6
const BEAM_ALPHA: float = 0.35
## The beam and gem cycle through the rainbow at this many hues per second.
const HUE_SPEED: float = 0.25
const GLOW_ENERGY: float = 2.5
const LIGHT_RANGE: float = 7.0

var _model: Node3D = null
var _gem_mat: StandardMaterial3D = null
var _beam: LightBeam = null
var _light: OmniLight3D = null
var _time: float = 0.0
var _taken: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = Constants.LAYER_PLAYERS
	var shape: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = PICKUP_RADIUS
	shape.shape = sphere
	shape.position.y = FLOAT_HEIGHT
	add_child(shape)
	_build_visuals()
	body_entered.connect(_on_body_entered)


func _build_visuals() -> void:
	_gem_mat = StandardMaterial3D.new()
	_gem_mat.albedo_color = Color.WHITE
	_gem_mat.metallic = 0.3
	_gem_mat.roughness = 0.1
	_gem_mat.emission_enabled = true
	_gem_mat.emission_energy_multiplier = GLOW_ENERGY
	_model = Node3D.new()
	_model.position.y = FLOAT_HEIGHT
	add_child(_model)
	_model.add_child(_cone(GEM_RADIUS * 0.5, GEM_RADIUS, CROWN_HEIGHT, CROWN_HEIGHT * 0.5))
	_model.add_child(_cone(GEM_RADIUS, 0.01, PAVILION_HEIGHT, -PAVILION_HEIGHT * 0.5))

	_beam = LightBeam.create(BEAM_HEIGHT, BEAM_RADIUS, Color(Color.WHITE, BEAM_ALPHA))
	add_child(_beam)

	_light = OmniLight3D.new()
	_light.omni_range = LIGHT_RANGE
	_light.position.y = FLOAT_HEIGHT
	add_child(_light)


func _cone(top: float, bottom: float, height: float, y: float) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 8
	mesh.material = _gem_mat
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.position.y = y
	return mi


func _process(delta: float) -> void:
	_time += delta
	_model.rotate_y(SPIN_SPEED * delta)
	_model.position.y = FLOAT_HEIGHT + sin(_time * BOB_SPEED) * BOB_AMPLITUDE
	var color: Color = Color.from_hsv(fmod(_time * HUE_SPEED, 1.0), 0.75, 1.0)
	_gem_mat.emission = color
	_gem_mat.albedo_color = color
	_beam.color = Color(color, BEAM_ALPHA)
	_light.light_color = color


func _on_body_entered(body: Node3D) -> void:
	var finder: Player = body as Player
	if finder == null or _taken:
		return
	_taken = true
	var lost: Dictionary = GameManager.halve_rivals(finder.player_id)
	for node: Node in get_tree().get_nodes_in_group(Constants.GROUP_PLAYERS):
		var rival: Player = node as Player
		if rival == finder or not lost.has(rival.player_id):
			continue
		rival.combat.spin_from_hit()
		ParticleConfigs.spawn_burst(get_parent(), rival.global_position + Vector3.UP, ParticleConfigs.gem_lost_burst(), 40)
		if lost[rival.player_id] > 0:
			PopupText.spawn(get_parent(), rival.global_position + Vector3.UP * PopupText.HEIGHT,
				"-%d" % lost[rival.player_id], PopupText.LOSS_COLOR)
	finder.model.play_cheer(1.5)
	ParticleConfigs.spawn_burst(get_parent(), global_position + Vector3.UP * FLOAT_HEIGHT,
		ParticleConfigs.confetti_shower(), 80, 1.5)
	AudioManager.play_sfx(AudioManager.SoundEffect.MATCH_END)
	queue_free()
