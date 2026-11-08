## Quicksand.gd
## Desert hazard: a pool of sand that slows down whoever wades through it
## (bubbles and shields don't help). Built in code; placed by MazeProps.
extends Area3D
class_name Quicksand

const RADIUS: float = 2.0
const HEIGHT: float = 0.3
## Sinking lasts this long after leaving, so stepping out isn't instant.
const HOLD: float = 0.25
const SAND_COLOR: Color = Color(0.86, 0.68, 0.38)
const SWIRL_COLOR: Color = Color(0.72, 0.52, 0.26)
const SWIRL_RADIUS: float = 0.6
const SWIRL_SPEED: float = 0.8
const PUFF_INTERVAL: float = 0.35
const PUFF_AMOUNT: int = 8
const PUFF_LIFETIME: float = 0.6

var _swirl: MeshInstance3D
var _puff_timer: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = Constants.LAYER_PLAYERS
	var shape: CollisionShape3D = CollisionShape3D.new()
	var cylinder: CylinderShape3D = CylinderShape3D.new()
	cylinder.radius = RADIUS
	cylinder.height = HEIGHT
	shape.shape = cylinder
	shape.position.y = HEIGHT * 0.5
	add_child(shape)
	add_child(_disc(RADIUS, SAND_COLOR, 0.02))
	_swirl = _disc(SWIRL_RADIUS, SWIRL_COLOR, 0.03)
	add_child(_swirl)


func _disc(radius: float, color: Color, lift: float) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.04
	var disc: MeshInstance3D = MeshInstance3D.new()
	disc.mesh = mesh
	disc.material_override = ToonMaterials.get_material(color, 0.0)
	disc.position.y = lift
	return disc


func _physics_process(delta: float) -> void:
	_swirl.rotate_y(SWIRL_SPEED * delta)
	_puff_timer -= delta
	for body: Node3D in get_overlapping_bodies():
		var player: Player = body as Player
		if player == null:
			continue
		player.status.sink(HOLD)
		if _puff_timer <= 0.0:
			ParticleConfigs.spawn_burst(get_parent(), player.global_position, ParticleConfigs.dust_puff(SAND_COLOR),
				PUFF_AMOUNT, PUFF_LIFETIME)
	if _puff_timer <= 0.0:
		_puff_timer = PUFF_INTERVAL
