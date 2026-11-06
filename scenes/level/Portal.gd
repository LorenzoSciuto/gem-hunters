## Portal.gd
## One end of a teleport pair: walking in sends the player out of its partner.
## Built in code by MazeLevel, which links the two ends and picks their color.
extends Area3D
class_name Portal

const RING_RADIUS: float = 1.1
const RING_THICKNESS: float = 0.18
const RING_HEIGHT: float = 1.3
const TRIGGER_RADIUS: float = 0.9
const TRIGGER_HEIGHT: float = 2.0
const SWIRL_SPEED: float = 2.5
const SWIRL_ALPHA: float = 0.55

var partner: Portal = null
var color: Color = Color(0.6, 0.4, 1.0)

var _swirl: MeshInstance3D = null


func _ready() -> void:
	collision_layer = 0
	collision_mask = Constants.LAYER_PLAYERS
	var shape: CollisionShape3D = CollisionShape3D.new()
	var cylinder: CylinderShape3D = CylinderShape3D.new()
	cylinder.radius = TRIGGER_RADIUS
	cylinder.height = TRIGGER_HEIGHT
	shape.shape = cylinder
	shape.position.y = TRIGGER_HEIGHT * 0.5
	add_child(shape)

	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = RING_RADIUS - RING_THICKNESS
	torus.outer_radius = RING_RADIUS
	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.mesh = torus
	ring.material_override = ToonMaterials.get_material(color)
	ring.rotation.x = PI * 0.5
	ring.position.y = RING_HEIGHT
	add_child(ring)

	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = RING_RADIUS - RING_THICKNESS
	disc.bottom_radius = disc.top_radius
	disc.height = 0.02
	var glow: StandardMaterial3D = StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.albedo_color = Color(color.lightened(0.4), SWIRL_ALPHA)
	glow.cull_mode = BaseMaterial3D.CULL_DISABLED
	disc.material = glow
	_swirl = MeshInstance3D.new()
	_swirl.mesh = disc
	_swirl.rotation.x = PI * 0.5
	_swirl.position.y = RING_HEIGHT
	add_child(_swirl)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_swirl.scale = Vector3.ONE * (0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.001 * SWIRL_SPEED))
	_swirl.rotate_object_local(Vector3.UP, SWIRL_SPEED * delta)


func _on_body_entered(body: Node3D) -> void:
	var player: Player = body as Player
	if player and partner and player.can_use_portal():
		player.teleport_to(partner.global_position)
