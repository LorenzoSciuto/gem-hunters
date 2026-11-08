## MazeLevel.gd
## Builds a themed maze arena from a LevelConfig at runtime.
##
## Pipeline: layout (wall grid) → connectivity repair → moving gates picked
##           → environment → floor → walls & posts → scenery → spawn markers
##           → gameplay props (trampolines, boxes, portals, map beacons...).
##
## The maze is a grid of square cells centered on the origin. Walls live on cell
## edges: _grid.east[i] is the wall on the +X side of cell i, _grid.south[i] the wall on
## its +Z side. The perimeter is always closed.
##
## Every arena is split into four quadrant zones plus the center plaza. Each
## zone has its own floor tint and a giant landmark just outside its corner, so
## a glance at a rival's screen tells where they are (the HUD names the zone too). Repeated meshes are batched into
## one MultiMeshInstance3D per (mesh, color) pair to keep draw calls low across
## the four split-screen cameras.
extends Node3D
class_name MazeLevel

const SHADER_FLOOR: Shader = preload("res://shaders/arena_floor.gdshader")
const SHADER_STRIPE: Shader = preload("res://shaders/candy_stripe.gdshader")

## Side of the decorative ground outside the maze.
const OUTER_GROUND_SIZE: float = 500.0
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
## Spacing between trees along FOREST walls.
const TREE_SPACING: float = 2.0
## Frosting cap on candy walls: thickness and how far it overhangs the wall.
const WALL_CAP_HEIGHT: float = 0.22
const WALL_CAP_OVERHANG: float = 0.14
## Zones: quadrants 0 (-X -Z), 1 (+X -Z), 2 (-X +Z), 3 (+X +Z), then the center plaza.
## Hues avoid the player colors (red, blue, green, yellow) so they never get mixed up.
const ZONE_CENTER: int = 4
const ZONE_COLORS: Array[Color] = [
	Color(0.62, 0.35, 0.95), Color(0.1, 0.75, 0.72), Color(1.0, 0.55, 0.12), Color(1.0, 0.35, 0.7),
	Color(1.0, 0.82, 0.3),
]
const ZONE_KEYS: Array[String] = ["ZONE_CRYSTAL", "ZONE_ORB", "ZONE_PYRAMID", "ZONE_CASTLE", "ZONE_CENTER"]
## How far each quadrant's floor is tinted toward its zone color.
const ZONE_FLOOR_TINT: float = 0.5
## Landmarks stand this far outside the maze corner.
const LANDMARK_OFFSET: float = 6.0
## Landmarks must tower over the themed scenery around the maze.
const LANDMARK_SCALE: float = 1.8
## Lifts the center floor over the quadrant floors without z-fighting.
const CENTER_FLOOR_LIFT: float = 0.02

@export var config: LevelConfig

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _grid: MazeGrid = null
var _cs: float = 0.0

var _batch: MeshBatcher = MeshBatcher.new()


func _ready() -> void:
	if config == null:
		push_error("MazeLevel: no LevelConfig assigned.")
		return
	_rng.randomize()
	_grid = MazeGrid.new(config, _rng)
	_grid.generate(config)
	_cs = _grid.cell_size

	ArenaEnvironment.build(self, config)
	_build_floor()
	_build_landmarks()
	_build_walls()
	_build_gates()
	_build_posts()
	_build_scenery()
	_build_decorations()
	_batch.flush(self)
	MazeProps.new(self, _grid, config, _rng).place()


func _build_gates() -> void:
	var t: float = config.wall_thickness
	for edge: Array in _grid.gate_edges:
		var gate: MovingGate = MovingGate.new()
		var along_x: bool = edge[0].x == edge[1].x  # cells stacked in Z: the wall runs along X
		gate.gate_size = Vector3(_cs - t, config.wall_height, t * 0.8) if along_x \
			else Vector3(t * 0.8, config.wall_height, _cs - t)
		gate.color = config.accent_colors[0]
		gate.position = (_grid.cell_pos(edge[0]) + _grid.cell_pos(edge[1])) * 0.5
		add_child(gate)


func _accent() -> Color:
	return config.accent_colors[_rng.randi() % config.accent_colors.size()]


# ─── Environment & floor ──────────────────────────────────────────────────

func _build_floor() -> void:
	var width: float = _grid.cols * _cs
	var depth: float = _grid.rows * _cs

	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = Constants.LAYER_WORLD
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(OUTER_GROUND_SIZE, 1.0, OUTER_GROUND_SIZE)
	shape.shape = box
	shape.position.y = -0.5
	body.add_child(shape)
	add_child(body)

	# One floor plane per quadrant, tinted with its zone color; the shader tiles
	# in world space, so the seams line up.
	for zone: int in ZONE_CENTER:
		var side: Vector2 = Vector2(1.0 if zone & 1 else -1.0, 1.0 if zone & 2 else -1.0)
		_add_floor(Vector2(width, depth) * 0.5, Vector3(side.x * width * 0.25, 0.01, side.y * depth * 0.25),
			config.floor_color_a.lerp(ZONE_COLORS[zone], ZONE_FLOOR_TINT),
			config.floor_color_b.lerp(ZONE_COLORS[zone], ZONE_FLOOR_TINT))
	var plaza: float = _plaza_half_size(config) * 2.0
	_add_floor(Vector2(plaza, plaza), Vector3(0.0, 0.01 + CENTER_FLOOR_LIFT, 0.0), config.floor_color_a, config.floor_color_b)

	var outer: PlaneMesh = PlaneMesh.new()
	outer.size = Vector2(OUTER_GROUND_SIZE, OUTER_GROUND_SIZE)
	var outer_mesh: MeshInstance3D = MeshInstance3D.new()
	outer_mesh.mesh = outer
	outer_mesh.material_override = ToonMaterials.get_material(config.outer_ground_color, 0.0)
	add_child(outer_mesh)


func _add_floor(size: Vector2, pos: Vector3, color_a: Color, color_b: Color) -> void:
	var floor_mat: ShaderMaterial = ShaderMaterial.new()
	floor_mat.shader = SHADER_FLOOR
	floor_mat.set_shader_parameter("color_a", color_a)
	floor_mat.set_shader_parameter("color_b", color_b)
	floor_mat.set_shader_parameter("tile_size", _cs * 0.5)
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = size
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	floor_mesh.mesh = plane
	floor_mesh.material_override = floor_mat
	floor_mesh.position = pos
	add_child(floor_mesh)


# ─── Zones ────────────────────────────────────────────────────────────────

static func _plaza_half_size(level: LevelConfig) -> float:
	return level.cell_size * (MazeGrid.CENTER_PLAZA_RADIUS + 0.5)


## Zone index (0-3 quadrants, ZONE_CENTER) of a world position in [param level].
static func zone_of(pos: Vector3, level: LevelConfig) -> int:
	var plaza: float = _plaza_half_size(level)
	if absf(pos.x) < plaza and absf(pos.z) < plaza:
		return ZONE_CENTER
	return (1 if pos.x >= 0.0 else 0) | (2 if pos.z >= 0.0 else 0)


## True when [param pos] is outside the maze's outer walls.
static func is_outside(pos: Vector3, level: LevelConfig) -> bool:
	var half: Vector2 = Vector2(level.columns | 1, level.rows | 1) * level.cell_size * 0.5
	return absf(pos.x) > half.x or absf(pos.z) > half.y


## A giant, differently shaped landmark outside each quadrant's corner, tall
## enough to be seen over the walls from anywhere in that zone.
func _build_landmarks() -> void:
	var half: Vector2 = Vector2(_grid.cols, _grid.rows) * _cs * 0.5 + Vector2.ONE * LANDMARK_OFFSET
	var k: float = LANDMARK_SCALE
	for zone: int in ZONE_CENTER:
		var c: Color = ZONE_COLORS[zone]
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


# ─── Walls ────────────────────────────────────────────────────────────────

## Merge consecutive wall edges on each grid line into long segments.
func _build_walls() -> void:
	var half_w: float = _grid.cols * _cs * 0.5
	var half_d: float = _grid.rows * _cs * 0.5
	# Lines of constant X (walls running along Z).
	for line: int in range(_grid.cols + 1):
		var run_start: int = -1
		for j: int in range(_grid.rows + 1):
			var solid: bool = j < _grid.rows and (line == 0 or line == _grid.cols or _grid.east[_grid.idx(line - 1, j)] == 1)
			if solid and run_start < 0:
				run_start = j
			elif not solid and run_start >= 0:
				var x: float = line * _cs - half_w
				var z0: float = run_start * _cs - half_d
				var z1: float = j * _cs - half_d
				_add_wall(Vector3(x, 0.0, (z0 + z1) * 0.5), z1 - z0, false)
				run_start = -1
	# Lines of constant Z (walls running along X).
	for line: int in range(_grid.rows + 1):
		var run_start: int = -1
		for i: int in range(_grid.cols + 1):
			var solid: bool = i < _grid.cols and (line == 0 or line == _grid.rows or _grid.south[_grid.idx(i, line - 1)] == 1)
			if solid and run_start < 0:
				run_start = i
			elif not solid and run_start >= 0:
				var z: float = line * _cs - half_d
				var x0: float = run_start * _cs - half_w
				var x1: float = i * _cs - half_w
				_add_wall(Vector3((x0 + x1) * 0.5, 0.0, z), x1 - x0, true)
				run_start = -1


func _add_wall(center: Vector3, length: float, along_x: bool) -> void:
	var t: float = config.wall_thickness
	var h: float = config.wall_height
	var full: float = length + t
	var size: Vector3 = Vector3(full, h, t) if along_x else Vector3(t, h, full)

	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = Constants.LAYER_WORLD
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = center + Vector3(0.0, h * 0.5, 0.0)
	body.add_child(shape)
	add_child(body)

	var a: Color = config.wall_color_a
	var b: Color = config.wall_color_b
	var yaw: float = 0.0 if along_x else PI * 0.5
	var unit: Vector3 = Vector3(full, h, t)  # size in the wall's local frame
	match config.style:
		LevelConfig.Style.CANDY:
			_add_candy_wall(center, size)
			_batch.add("box", b, center + Vector3(0, h, 0), Vector3(full + WALL_CAP_OVERHANG, WALL_CAP_HEIGHT, t + WALL_CAP_OVERHANG), yaw)
		LevelConfig.Style.FOREST:
			_batch.add("box", a.darkened(0.25), center, Vector3(full, 1.1, t * 1.2), yaw)
			var count: int = maxi(1, int(full / TREE_SPACING))
			for n: int in count:
				var f: float = (n + 0.5) / count - 0.5
				var p: Vector3 = center + (Vector3(f * full, 0, 0) if along_x else Vector3(0, 0, f * full))
				_add_tree(p, _rng.randf_range(0.85, 1.25))
		LevelConfig.Style.GARDEN:
			_batch.add("box", a, center, unit, yaw)
			var flowers: int = int(full / 1.5)
			for n: int in flowers:
				if _rng.randf() < 0.5:
					var f: float = _rng.randf() - 0.5
					# Sunk half into the hedge top so flowers never float.
					var p: Vector3 = center + (Vector3(f * full, h, 0) if along_x else Vector3(0, h, f * full))
					_batch.add("sphere", _accent(), p, Vector3(0.5, 0.35, 0.5))
		LevelConfig.Style.ROMAN:
			_batch.add("box", a, center, unit, yaw)
			_batch.add("box", b, center + Vector3(0, h, 0), Vector3(full, 0.25, t * 1.15), yaw)
		LevelConfig.Style.EGYPT:
			_batch.add("box", a, center, unit, yaw)
			_batch.add("box", b, center + Vector3(0, h * 0.62, 0), Vector3(full, 0.45, t * 1.08), yaw)
			_batch.add("box", a.darkened(0.12), center + Vector3(0, h, 0), Vector3(full, 0.35, t * 1.2), yaw)
		LevelConfig.Style.WINTER:
			_batch.add("box", a, center, unit, yaw)
			_batch.add("box", b, center + Vector3(0, h, 0), Vector3(full + 0.1, 0.35, t * 1.25), yaw)


## Candy walls use the world-space stripe shader instead of flat toon colors.
func _add_candy_wall(center: Vector3, size: Vector3) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = SHADER_STRIPE
	mat.set_shader_parameter("stripe_color_1", config.wall_color_a)
	mat.set_shader_parameter("stripe_color_2", config.wall_color_b)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = center + Vector3(0, size.y * 0.5, 0)
	add_child(mi)


## Themed posts where walls end, turn or meet. Straight runs stay clean, except
## in the forest where every vertex gets a tree to thicken the canopy.
func _build_posts() -> void:
	var dirs: Dictionary = {}  # grid vertex → bitmask of wall directions (1 +X, 2 -X, 4 +Z, 8 -Z)
	for j: int in _grid.rows:
		for i: int in _grid.cols:
			if i == 0:
				_mark_edge(dirs, Vector2i(i, j), Vector2i(i, j + 1))
			if i == _grid.cols - 1 or _grid.east[_grid.idx(i, j)] == 1:
				_mark_edge(dirs, Vector2i(i + 1, j), Vector2i(i + 1, j + 1))
			if j == 0:
				_mark_edge(dirs, Vector2i(i, j), Vector2i(i + 1, j))
			if j == _grid.rows - 1 or _grid.south[_grid.idx(i, j)] == 1:
				_mark_edge(dirs, Vector2i(i, j + 1), Vector2i(i + 1, j + 1))
	var half_w: float = _grid.cols * _cs * 0.5
	var half_d: float = _grid.rows * _cs * 0.5
	for v: Vector2i in dirs:
		var straight: bool = dirs[v] == 3 or dirs[v] == 12
		if straight and config.style != LevelConfig.Style.FOREST:
			continue
		_add_post(Vector3(v.x * _cs - half_w, 0.0, v.y * _cs - half_d))


func _mark_edge(dirs: Dictionary, a: Vector2i, b: Vector2i) -> void:
	var horizontal: bool = a.y == b.y
	dirs[a] = dirs.get(a, 0) | (1 if horizontal else 4)
	dirs[b] = dirs.get(b, 0) | (2 if horizontal else 8)


func _add_post(p: Vector3) -> void:
	var h: float = config.wall_height
	var t: float = config.wall_thickness
	match config.style:
		LevelConfig.Style.CANDY:
			_batch.add("cylinder", Color.WHITE, p, Vector3(0.25, h + 1.2, 0.25))
			_batch.add("sphere", _accent(), p + Vector3(0, h + 1.3, 0), Vector3(1.2, 1.2, 0.5))
		LevelConfig.Style.FOREST:
			_add_tree(p, _rng.randf_range(1.1, 1.5))
		LevelConfig.Style.GARDEN:
			_batch.add("sphere", config.wall_color_a.lightened(0.1), p + Vector3(0, h, 0), Vector3.ONE * t * 1.5)
		LevelConfig.Style.ROMAN:
			_batch.add("box", config.wall_color_b, p, Vector3(t * 1.5, 0.3, t * 1.5))
			_batch.add("cylinder", config.wall_color_b, p + Vector3(0, 0.3, 0), Vector3(t * 1.25, h + 0.3, t * 1.25))
			_batch.add("box", config.wall_color_b, p + Vector3(0, h + 0.6, 0), Vector3(t * 1.5, 0.3, t * 1.5))
		LevelConfig.Style.EGYPT:
			_batch.add("box", config.wall_color_a.darkened(0.1), p, Vector3(t * 1.5, h + 0.8, t * 1.5))
			_batch.add("pyramid", config.accent_colors[0], p + Vector3(0, h + 0.8, 0), Vector3(t * 1.5, 0.9, t * 1.5))
		LevelConfig.Style.WINTER:
			_batch.add("cylinder", config.wall_color_a.lightened(0.2), p, Vector3(t * 1.3, h + 0.5, t * 1.3))
			_batch.add("sphere", Color.WHITE, p + Vector3(0, h + 0.5, 0), Vector3.ONE * t * 1.4)


func _add_tree(p: Vector3, s: float) -> void:
	var trunk: Color = Color(0.45, 0.3, 0.18)
	match config.style:
		LevelConfig.Style.WINTER:
			_batch.add("cylinder", trunk, p, Vector3(0.35, 1.0, 0.35) * s)
			_batch.add("cone", config.accent_colors[0], p + Vector3(0, 0.8 * s, 0), Vector3(2.4, 2.4, 2.4) * s)
			_batch.add("cone", Color.WHITE, p + Vector3(0, 2.3 * s, 0), Vector3(1.4, 1.4, 1.4) * s)
		LevelConfig.Style.EGYPT:
			# Palm: tall thin trunk, flattened canopy.
			_batch.add("cylinder", trunk, p, Vector3(0.35, 4.5, 0.35) * s)
			_batch.add("sphere", config.accent_colors[1], p + Vector3(0, 4.6 * s, 0), Vector3(3.0, 0.8, 3.0) * s)
		LevelConfig.Style.ROMAN:
			# Cypress: tall dark cone.
			_batch.add("cylinder", trunk, p, Vector3(0.3, 0.8, 0.3) * s)
			_batch.add("cone", Color(0.2, 0.42, 0.25), p + Vector3(0, 0.6 * s, 0), Vector3(1.3, 5.0, 1.3) * s)
		_:
			_batch.add("cylinder", trunk, p, Vector3(0.45, 1.6, 0.45) * s)
			var leaves: Color = config.wall_color_a if config.style == LevelConfig.Style.FOREST else Color(0.35, 0.7, 0.35)
			_batch.add("cone", leaves, p + Vector3(0, 1.2 * s, 0), Vector3(2.6, 2.4, 2.6) * s)
			_batch.add("cone", leaves.lightened(0.12), p + Vector3(0, 2.5 * s, 0), Vector3(1.9, 2.0, 1.9) * s)


# ─── Scenery & decorations ───────────────────────────────────────────────

## Large props in a ring outside the maze to sell the theme on the horizon.
func _build_scenery() -> void:
	var half: float = maxf(_grid.cols, _grid.rows) * _cs * 0.5
	for n: int in SCENERY_COUNT:
		var angle: float = _rng.randf() * TAU
		var dist: float = half + SCENERY_MARGIN + _rng.randf() * SCENERY_DEPTH
		var p: Vector3 = Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		var s: float = _rng.randf_range(1.5, 3.0)
		match config.style:
			LevelConfig.Style.CANDY:
				if n % 2 == 0:
					_batch.add("cylinder", Color.WHITE, p, Vector3(0.5, 7.0, 0.5) * s)
					_batch.add("sphere", _accent(), p + Vector3(0, 7.5 * s, 0), Vector3(4.0, 4.0, 1.6) * s, angle)
				else:
					_batch.add("sphere", _accent(), p, Vector3(4.0, 3.0, 4.0) * s)
			LevelConfig.Style.EGYPT:
				if n % 5 == 0:
					_batch.add("pyramid", config.wall_color_a, p * 1.6, Vector3(30, 22, 30) * (s * 0.6), PI * 0.25)
				elif n % 2 == 0:
					_add_tree(p, s * 0.7)
				else:
					_batch.add("box", config.wall_color_a, p, Vector3(1.2, 9.0, 1.2) * s * 0.6)
					_batch.add("pyramid", config.accent_colors[0], p + Vector3(0, 9.0 * s * 0.6, 0), Vector3(1.2, 1.4, 1.2) * s * 0.6)
			LevelConfig.Style.ROMAN:
				if n % 3 == 0:
					# Ruined column: base, shaft of random height, sometimes a capital.
					var col: Color = config.wall_color_b
					var shaft: float = _rng.randf_range(2.0, 8.0) * s * 0.6
					_batch.add("box", col, p, Vector3(1.8, 0.5, 1.8) * s * 0.6)
					_batch.add("cylinder", col, p, Vector3(1.2, shaft, 1.2) * s * 0.6)
					if shaft > 3.5:
						_batch.add("box", col, p + Vector3(0, shaft, 0), Vector3(1.8, 0.5, 1.8) * s * 0.6)
				else:
					_add_tree(p, s * 0.8)
			LevelConfig.Style.GARDEN:
				if n % 3 == 0:
					_batch.add("sphere", _accent(), p, Vector3(3.0, 2.0, 3.0) * s * 0.6)
				else:
					_add_tree(p, s)
			_:
				_add_tree(p, s)


## Small solid props tucked into cell corners, clear of the corridors.
func _build_decorations() -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = Constants.LAYER_WORLD
	add_child(body)
	var inset: float = _cs * 0.5 - config.wall_thickness * 0.5 - DECORATION_RADIUS - DECORATION_WALL_GAP
	for n: int in int(config.decoration_count * DECORATION_FRACTION):
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
		match config.style:
			LevelConfig.Style.CANDY:
				_batch.add("sphere", _accent(), p + Vector3(0, 0.3, 0), Vector3(0.7, 0.6, 0.7), 0.0, o)
			LevelConfig.Style.FOREST:
				_batch.add("cylinder", Color(0.95, 0.92, 0.85), p, Vector3(0.25, 0.5, 0.25), 0.0, o)
				_batch.add("sphere", Color(0.9, 0.2, 0.2), p + Vector3(0, 0.55, 0), Vector3(0.8, 0.45, 0.8), 0.0, o)
			LevelConfig.Style.GARDEN:
				for k: int in 3:
					var q: Vector3 = p + Vector3(_rng.randf_range(-0.3, 0.3), 0, _rng.randf_range(-0.3, 0.3))
					_batch.add("cylinder", Color(0.3, 0.6, 0.3), q, Vector3(0.06, 0.5, 0.06), 0.0, o)
					_batch.add("sphere", _accent(), q + Vector3(0, 0.55, 0), Vector3.ONE * 0.3, 0.0, o)
			LevelConfig.Style.ROMAN:
				_batch.add("sphere", config.accent_colors[0], p + Vector3(0, 0.45, 0), Vector3(0.6, 0.8, 0.6), 0.0, o)
				_batch.add("cylinder", config.accent_colors[0], p + Vector3(0, 0.8, 0), Vector3(0.25, 0.35, 0.25), 0.0, o)
			LevelConfig.Style.EGYPT:
				_batch.add("cylinder", config.accent_colors[1], p, Vector3(0.5, 0.7, 0.5), 0.0, o)
				_batch.add("sphere", config.accent_colors[1], p + Vector3(0, 0.7, 0), Vector3(0.55, 0.3, 0.55), 0.0, o)
			LevelConfig.Style.WINTER:
				_batch.add("sphere", Color.WHITE, p + Vector3(0, 0.4, 0), Vector3.ONE * 0.8, 0.0, o)
				_batch.add("sphere", Color.WHITE, p + Vector3(0, 1.0, 0), Vector3.ONE * 0.55, 0.0, o)
				_batch.add("cone", Color(1.0, 0.55, 0.1), p + Vector3(0, 1.0, 0.25), Vector3(0.1, 0.3, 0.1), 0.0, o)

	# Golden circle on the floor marks the center where the golden gem appears.
	_batch.add("cylinder", config.accent_colors[0], Vector3(0, 0.0, 0), Vector3(3.0, 0.06, 3.0))


