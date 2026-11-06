## MapBeacon.gd
## A map board on a stand with a spinning map pin above it: stepping up to it
## shows the arena map with every player for a few seconds, then it needs time
## to recharge (board and pin turn grey meanwhile).
extends Area3D
class_name MapBeacon

const TRIGGER_RADIUS: float = 1.2
const TRIGGER_HEIGHT: float = 2.0
const LEG_SIZE: Vector3 = Vector3(0.12, 1.3, 0.12)
const LEG_SPACING: float = 0.7
const BOARD_SIZE: Vector3 = Vector3(1.8, 1.2, 0.1)
const BOARD_HEIGHT: float = 1.6
## Board leans back so it reads like a map on a lectern.
const BOARD_TILT: float = -0.35
## The board face shows the four arena zones as a 2x2 map.
const TILE_GAP: float = 0.08
const PIN_HEIGHT: float = 2.9
const PIN_RADIUS: float = 0.22
const BOB_AMPLITUDE: float = 0.12
const SPIN_SPEED: float = 2.0
const WOOD_COLOR: Color = Color(0.55, 0.36, 0.2)
const PAPER_COLOR: Color = Color(0.98, 0.93, 0.78)
const PIN_COLOR: Color = Color(0.95, 0.2, 0.25)
const SPENT_COLOR: Color = Color(0.5, 0.5, 0.55)

var _pin: Node3D = null
var _colored: Array[MeshInstance3D] = []  # zone tiles + pin, greyed while recharging
var _ready_at: float = 0.0


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

	for side: float in [-1.0, 1.0]:
		_box(self, LEG_SIZE, Vector3(side * LEG_SPACING * 0.5, LEG_SIZE.y * 0.5, 0.0), WOOD_COLOR)
	var board: Node3D = Node3D.new()
	board.position.y = BOARD_HEIGHT
	board.rotation.x = BOARD_TILT
	add_child(board)
	_box(board, BOARD_SIZE + Vector3(0.12, 0.12, 0.0), Vector3.ZERO, WOOD_COLOR)
	_box(board, Vector3(BOARD_SIZE.x, BOARD_SIZE.y, 0.02), Vector3(0, 0, BOARD_SIZE.z * 0.5), PAPER_COLOR)
	var tile: Vector3 = Vector3((BOARD_SIZE.x - TILE_GAP * 3.0) * 0.5, (BOARD_SIZE.y - TILE_GAP * 3.0) * 0.5, 0.02)
	for zone: int in MazeLevel.ZONE_CENTER:
		var x: float = (tile.x + TILE_GAP) * (0.5 if zone & 1 else -0.5)
		var y: float = (tile.y + TILE_GAP) * (-0.5 if zone & 2 else 0.5)
		_colored.append(_box(board, tile, Vector3(x, y, BOARD_SIZE.z * 0.5 + 0.02), MazeLevel.ZONE_COLORS[zone]))

	# Classic map pin: a ball on a downward cone.
	_pin = Node3D.new()
	add_child(_pin)
	var ball: SphereMesh = SphereMesh.new()
	ball.radius = PIN_RADIUS
	ball.height = PIN_RADIUS * 2.0
	var tip: CylinderMesh = CylinderMesh.new()
	tip.top_radius = PIN_RADIUS * 0.6
	tip.bottom_radius = 0.0
	tip.height = PIN_RADIUS * 2.5
	var ball_mesh: MeshInstance3D = MeshInstance3D.new()
	ball_mesh.mesh = ball
	ball_mesh.position.y = PIN_RADIUS * 2.0
	var tip_mesh: MeshInstance3D = MeshInstance3D.new()
	tip_mesh.mesh = tip
	tip_mesh.position.y = PIN_RADIUS * 0.6
	_pin.add_child(ball_mesh)
	_pin.add_child(tip_mesh)
	_colored.append(ball_mesh)
	_colored.append(tip_mesh)
	_set_ready(true)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_pin.rotate_y(SPIN_SPEED * delta)
	_pin.position.y = PIN_HEIGHT + sin(Time.get_ticks_msec() * 0.003) * BOB_AMPLITUDE
	if _ready_at > 0.0 and _now() >= _ready_at:
		_ready_at = 0.0
		_set_ready(true)


func _on_body_entered(body: Node3D) -> void:
	var player: Player = body as Player
	if player == null or _now() < _ready_at:
		return
	_ready_at = _now() + Constants.MAP_BEACON_RECHARGE
	_set_ready(false)
	player.reveal_map(Constants.MAP_BEACON_REVEAL)
	ParticleConfigs.spawn_burst(get_parent(), _pin.global_position, ParticleConfigs.gem_collect_burst())
	AudioManager.play_sfx(AudioManager.SoundEffect.POWERUP_GRAB)


## Zone tiles and pin show their colors when usable, grey while recharging.
func _set_ready(usable: bool) -> void:
	for n: int in _colored.size():
		var color: Color = SPENT_COLOR
		if usable:
			color = MazeLevel.ZONE_COLORS[n] if n < MazeLevel.ZONE_CENTER else PIN_COLOR
		_colored[n].material_override = ToonMaterials.get_material(color)


func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = ToonMaterials.get_material(color)
	parent.add_child(mi)
	return mi


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
