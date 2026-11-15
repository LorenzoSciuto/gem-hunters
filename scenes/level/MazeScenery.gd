## MazeScenery.gd
## Themed set dressing of a MazeLevel: a giant landmark outside each zone's
## corner, posts where walls meet, trees, the scenery ring on the horizon and
## small solid decorations tucked into cell corners. Everything is queued on the
## level's MeshBatcher.
extends RefCounted
class_name MazeScenery

## Scenery ring around the maze: start distance from the wall and depth.
const SCENERY_MARGIN: float = 10.0
const SCENERY_DEPTH: float = 45.0
const SCENERY_COUNT: int = 70
## Only this share of LevelConfig.decoration_count is placed: fewer, solid props
## tucked into cell corners instead of many walk-through ones.
const DECORATION_FRACTION: float = 0.5
## Collision of a decoration prop, and its gap from the walls of its corner.
const DECORATION_RADIUS: float = 0.35
const DECORATION_HEIGHT: float = 1.0
const DECORATION_WALL_GAP: float = 0.25
## Ink outline width on decoration props (they are small, so the hull holds up).
const DECORATION_OUTLINE: float = 0.03
## Landmarks stand this far outside the maze corner.
const LANDMARK_OFFSET: float = 6.0
## Landmarks must tower over the themed scenery around the maze.
const LANDMARK_SCALE: float = 1.8

var _level: Node3D
var _grid: MazeGrid
var _config: LevelConfig
var _rng: RandomNumberGenerator
var _batch: MeshBatcher
var _cs: float


func _init(level: Node3D, grid: MazeGrid, config: LevelConfig, rng: RandomNumberGenerator, batch: MeshBatcher) -> void:
	_level = level
	_grid = grid
	_config = config
	_rng = rng
	_batch = batch
	_cs = grid.cell_size


## A random colour from the theme's accent palette.
func accent() -> Color:
	return _config.accent_colors[_rng.randi() % _config.accent_colors.size()]


## A giant, differently shaped landmark outside each quadrant's corner, tall
## enough to be seen over the walls from anywhere in that zone.
func build_landmarks() -> void:
	var half: Vector2 = Vector2(_grid.cols, _grid.rows) * _cs * 0.5 + Vector2.ONE * LANDMARK_OFFSET
	var k: float = LANDMARK_SCALE
	for zone: int in MazeLevel.ZONE_CENTER:
		var c: Color = MazeLevel.ZONE_COLORS[zone]
		var p: Vector3 = Vector3(half.x * (1.0 if zone & 1 else -1.0), 0.0, half.y * (1.0 if zone & 2 else -1.0))
		match zone:
			0:  # Crystal spire
				_batch.add("box", c.darkened(0.3), p, Vector3(4.0, 1.5, 4.0) * k, PI * 0.25)
				_batch.add("pyramid", c, p + Vector3(0, 1.5, 0) * k, Vector3(3.2, 17.0, 3.2) * k)
				_batch.add("pyramid", c.lightened(0.3), p + Vector3(2.2, 0, 1.2) * k, Vector3(1.6, 7.0, 1.6) * k, 0.4)
			1:  # Orb tower
				_batch.add("cylinder", c.darkened(0.25), p, Vector3(1.6, 13.0, 1.6) * k)
				_batch.add("sphere", c, p + Vector3(0, 15.0, 0) * k, Vector3.ONE * 6.0 * k)
				_batch.add("cylinder", c.lightened(0.3), p + Vector3(0, 14.6, 0) * k, Vector3(7.5, 0.6, 7.5) * k)
			2:  # Pyramid
				_batch.add("pyramid", c, p, Vector3(11.0, 11.0, 11.0) * k, PI * 0.25)
				_batch.add("sphere", Color.WHITE, p + Vector3(0, 11.5, 0) * k, Vector3.ONE * 1.6 * k)
			3:  # Castle
				_batch.add("box", c.darkened(0.2), p, Vector3(5.0, 10.0, 5.0) * k)
				_batch.add("box", c, p + Vector3(0, 10.0, 0) * k, Vector3(6.4, 1.2, 6.4) * k)
				_batch.add("cone", c.lightened(0.25), p + Vector3(0, 11.2, 0) * k, Vector3(5.5, 6.0, 5.5) * k)


## Themed post at a wall end, corner or junction.
func add_post(p: Vector3) -> void:
	var h: float = _config.wall_height
	var t: float = _config.wall_thickness
	match _config.style:
		LevelConfig.Style.CANDY:
			_batch.add("cylinder", Color.WHITE, p, Vector3(0.25, h + 1.2, 0.25))
			_batch.add("sphere", accent(), p + Vector3(0, h + 1.3, 0), Vector3(1.2, 1.2, 0.5))
		LevelConfig.Style.FOREST:
			add_tree(p, _rng.randf_range(1.1, 1.5))
		LevelConfig.Style.GARDEN:
			_batch.add("sphere", _config.wall_color_a.lightened(0.1), p + Vector3(0, h, 0), Vector3.ONE * t * 1.5)
		LevelConfig.Style.ROMAN:
			_batch.add("box", _config.wall_color_b, p, Vector3(t * 1.5, 0.3, t * 1.5))
			_batch.add("cylinder", _config.wall_color_b, p + Vector3(0, 0.3, 0), Vector3(t * 1.25, h + 0.3, t * 1.25))
			_batch.add("box", _config.wall_color_b, p + Vector3(0, h + 0.6, 0), Vector3(t * 1.5, 0.3, t * 1.5))
		LevelConfig.Style.EGYPT:
			_batch.add("box", _config.wall_color_a.darkened(0.1), p, Vector3(t * 1.5, h + 0.8, t * 1.5))
			_batch.add("pyramid", _config.accent_colors[0], p + Vector3(0, h + 0.8, 0), Vector3(t * 1.5, 0.9, t * 1.5))
		LevelConfig.Style.WINTER:
			_batch.add("cylinder", _config.wall_color_a.lightened(0.2), p, Vector3(t * 1.3, h + 0.5, t * 1.3))
			_batch.add("sphere", Color.WHITE, p + Vector3(0, h + 0.5, 0), Vector3.ONE * t * 1.4)


func add_tree(p: Vector3, s: float) -> void:
	var trunk: Color = Color(0.45, 0.3, 0.18)
	match _config.style:
		LevelConfig.Style.WINTER:
			_batch.add("cylinder", trunk, p, Vector3(0.35, 1.0, 0.35) * s)
			_batch.add("cone", _config.accent_colors[0], p + Vector3(0, 0.8 * s, 0), Vector3(2.4, 2.4, 2.4) * s)
			_batch.add("cone", Color.WHITE, p + Vector3(0, 2.3 * s, 0), Vector3(1.4, 1.4, 1.4) * s)
		LevelConfig.Style.EGYPT:
			# Palm: tall thin trunk, flattened canopy.
			_batch.add("cylinder", trunk, p, Vector3(0.35, 4.5, 0.35) * s)
			_batch.add("sphere", _config.accent_colors[1], p + Vector3(0, 4.6 * s, 0), Vector3(3.0, 0.8, 3.0) * s)
		LevelConfig.Style.ROMAN:
			# Cypress: tall dark cone.
			_batch.add("cylinder", trunk, p, Vector3(0.3, 0.8, 0.3) * s)
			_batch.add("cone", Color(0.2, 0.42, 0.25), p + Vector3(0, 0.6 * s, 0), Vector3(1.3, 5.0, 1.3) * s)
		_:
			_batch.add("cylinder", trunk, p, Vector3(0.45, 1.6, 0.45) * s)
			var leaves: Color = _config.wall_color_a if _config.style == LevelConfig.Style.FOREST else Color(0.35, 0.7, 0.35)
			_batch.add("cone", leaves, p + Vector3(0, 1.2 * s, 0), Vector3(2.6, 2.4, 2.6) * s)
			_batch.add("cone", leaves.lightened(0.12), p + Vector3(0, 2.5 * s, 0), Vector3(1.9, 2.0, 1.9) * s)


## Large props in a ring outside the maze to sell the theme on the horizon.
func build_scenery() -> void:
	var half: float = maxf(_grid.cols, _grid.rows) * _cs * 0.5
	for n: int in SCENERY_COUNT:
		var angle: float = _rng.randf() * TAU
		var dist: float = half + SCENERY_MARGIN + _rng.randf() * SCENERY_DEPTH
		var p: Vector3 = Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		var s: float = _rng.randf_range(1.5, 3.0)
		match _config.style:
			LevelConfig.Style.CANDY:
				if n % 2 == 0:
					_batch.add("cylinder", Color.WHITE, p, Vector3(0.5, 7.0, 0.5) * s)
					_batch.add("sphere", accent(), p + Vector3(0, 7.5 * s, 0), Vector3(4.0, 4.0, 1.6) * s, angle)
				else:
					_batch.add("sphere", accent(), p, Vector3(4.0, 3.0, 4.0) * s)
			LevelConfig.Style.EGYPT:
				if n % 5 == 0:
					_batch.add("pyramid", _config.wall_color_a, p * 1.6, Vector3(30, 22, 30) * (s * 0.6), PI * 0.25)
				elif n % 2 == 0:
					add_tree(p, s * 0.7)
				else:
					_batch.add("box", _config.wall_color_a, p, Vector3(1.2, 9.0, 1.2) * s * 0.6)
					_batch.add("pyramid", _config.accent_colors[0], p + Vector3(0, 9.0 * s * 0.6, 0), Vector3(1.2, 1.4, 1.2) * s * 0.6)
			LevelConfig.Style.ROMAN:
				if n % 3 == 0:
					# Ruined column: base, shaft of random height, sometimes a capital.
					var col: Color = _config.wall_color_b
					var shaft: float = _rng.randf_range(2.0, 8.0) * s * 0.6
					_batch.add("box", col, p, Vector3(1.8, 0.5, 1.8) * s * 0.6)
					_batch.add("cylinder", col, p, Vector3(1.2, shaft, 1.2) * s * 0.6)
					if shaft > 3.5:
						_batch.add("box", col, p + Vector3(0, shaft, 0), Vector3(1.8, 0.5, 1.8) * s * 0.6)
				else:
					add_tree(p, s * 0.8)
			LevelConfig.Style.GARDEN:
				if n % 3 == 0:
					_batch.add("sphere", accent(), p, Vector3(3.0, 2.0, 3.0) * s * 0.6)
				else:
					add_tree(p, s)
			_:
				add_tree(p, s)


## Small solid props tucked into cell corners, clear of the corridors.
func build_decorations() -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = Constants.LAYER_WORLD
	_level.add_child(body)
	var inset: float = _cs * 0.5 - _config.wall_thickness * 0.5 - DECORATION_RADIUS - DECORATION_WALL_GAP
	for n: int in int(_config.decoration_count * DECORATION_FRACTION):
		var c: Vector2i = Vector2i(_rng.randi() % _grid.cols, _rng.randi() % _grid.rows)
		if _grid.ring_of(c) <= MazeGrid.CENTER_PLAZA_RADIUS:
			continue  # Keep the plaza open.
		var corner: Vector3 = Vector3(1.0 if _rng.randf() < 0.5 else -1.0, 0.0, 1.0 if _rng.randf() < 0.5 else -1.0)
		var p: Vector3 = _grid.cell_pos(c) + corner * inset
		var shape: CollisionShape3D = CollisionShape3D.new()
		var cylinder: CylinderShape3D = CylinderShape3D.new()
		cylinder.radius = DECORATION_RADIUS
		cylinder.height = DECORATION_HEIGHT
		shape.shape = cylinder
		shape.position = p + Vector3.UP * DECORATION_HEIGHT * 0.5
		body.add_child(shape)
		var o: float = DECORATION_OUTLINE
		match _config.style:
			LevelConfig.Style.CANDY:
				_batch.add("sphere", accent(), p + Vector3(0, 0.3, 0), Vector3(0.7, 0.6, 0.7), 0.0, o)
			LevelConfig.Style.FOREST:
				_batch.add("cylinder", Color(0.95, 0.92, 0.85), p, Vector3(0.25, 0.5, 0.25), 0.0, o)
				_batch.add("sphere", Color(0.9, 0.2, 0.2), p + Vector3(0, 0.55, 0), Vector3(0.8, 0.45, 0.8), 0.0, o)
			LevelConfig.Style.GARDEN:
				for k: int in 3:
					var q: Vector3 = p + Vector3(_rng.randf_range(-0.3, 0.3), 0, _rng.randf_range(-0.3, 0.3))
					_batch.add("cylinder", Color(0.3, 0.6, 0.3), q, Vector3(0.06, 0.5, 0.06), 0.0, o)
					_batch.add("sphere", accent(), q + Vector3(0, 0.55, 0), Vector3.ONE * 0.3, 0.0, o)
			LevelConfig.Style.ROMAN:
				_batch.add("sphere", _config.accent_colors[0], p + Vector3(0, 0.45, 0), Vector3(0.6, 0.8, 0.6), 0.0, o)
				_batch.add("cylinder", _config.accent_colors[0], p + Vector3(0, 0.8, 0), Vector3(0.25, 0.35, 0.25), 0.0, o)
			LevelConfig.Style.EGYPT:
				_batch.add("cylinder", _config.accent_colors[1], p, Vector3(0.5, 0.7, 0.5), 0.0, o)
				_batch.add("sphere", _config.accent_colors[1], p + Vector3(0, 0.7, 0), Vector3(0.55, 0.3, 0.55), 0.0, o)
			LevelConfig.Style.WINTER:
				_batch.add("sphere", Color.WHITE, p + Vector3(0, 0.4, 0), Vector3.ONE * 0.8, 0.0, o)
				_batch.add("sphere", Color.WHITE, p + Vector3(0, 1.0, 0), Vector3.ONE * 0.55, 0.0, o)
				_batch.add("cone", Color(1.0, 0.55, 0.1), p + Vector3(0, 1.0, 0.25), Vector3(0.1, 0.3, 0.1), 0.0, o)

	# Golden circle on the floor marks the center where the golden gem appears.
	_batch.add("cylinder", _config.accent_colors[0], Vector3(0, 0.0, 0), Vector3(3.0, 0.06, 3.0))
