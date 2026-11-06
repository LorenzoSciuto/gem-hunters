## ArenaBackdrop.gd
## Menu background: generates an arena in its own world and slowly orbits a
## camera around it. A left-to-right shade keeps menu text readable.
extends SubViewportContainer

const ORBIT_SPEED: float = 0.08
const ORBIT_RADIUS_FACTOR: float = 0.75
const ORBIT_HEIGHT_FACTOR: float = 0.6

@onready var viewport: SubViewport = $SubViewport
@onready var camera: Camera3D = $SubViewport/Camera3D

var _level: MazeLevel = null
var _radius: float = 40.0
var _angle: float = 0.0


func show_arena(config: LevelConfig) -> void:
	if _level:
		_level.queue_free()
	_level = MazeLevel.new()
	_level.config = config
	viewport.add_child(_level)
	_radius = maxf(config.columns, config.rows) * config.cell_size * ORBIT_RADIUS_FACTOR


func _process(delta: float) -> void:
	_angle += ORBIT_SPEED * delta
	camera.position = Vector3(cos(_angle) * _radius, _radius * ORBIT_HEIGHT_FACTOR, sin(_angle) * _radius)
	camera.look_at(Vector3.ZERO, Vector3.UP)
