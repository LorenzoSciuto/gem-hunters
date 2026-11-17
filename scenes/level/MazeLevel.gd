## MazeLevel.gd
## Builds a themed maze arena from a LevelConfig at runtime.
##
## Pipeline: layout (wall grid) → connectivity repair → moving gates picked
##           → environment → floor → walls & posts → scenery (MazeScenery)
##           → spawn markers and gameplay props (MazeProps).
##
## The maze is a grid of square cells centered on the origin. Walls live on cell
## edges: grid.east[i] is the wall on the +X side of cell i, grid.south[i] the wall on
## its +Z side. The perimeter is always closed.
##
## Every arena is split into four quadrant zones plus the center plaza. Each
## zone has its own floor tint and a giant landmark just outside its corner, so
## a glance at a rival's screen tells where they are (the HUD names the zone
## too). Repeated meshes are batched into one MultiMeshInstance3D per
## (mesh, color) pair (MeshBatcher) to keep draw calls low across the four
## split-screen cameras.
extends Node3D
class_name MazeLevel

const SHADER_FLOOR: Shader = preload("res://shaders/arena_floor.gdshader")
const SHADER_STRIPE: Shader = preload("res://shaders/candy_stripe.gdshader")

## Side of the decorative ground outside the maze.
const OUTER_GROUND_SIZE: float = 500.0
## Spacing between trees along FOREST walls.
const TREE_SPACING: float = 2.0
## Cap on top of the walls, per style (the collision box includes it, so feet
## rest on the cap instead of sinking into it); candy frosting overhangs.
const WALL_CAP_HEIGHTS: Dictionary = {
	LevelConfig.Style.CANDY: 0.22, LevelConfig.Style.ROMAN: 0.25,
	LevelConfig.Style.EGYPT: 0.35, LevelConfig.Style.WINTER: 0.35,
}
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
## Lifts the center floor over the quadrant floors without z-fighting.
const CENTER_FLOOR_LIFT: float = 0.02

@export var config: LevelConfig

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## The maze as data: bots find their way on it.
var grid: MazeGrid = null
var _cs: float = 0.0

var _batch: MeshBatcher = MeshBatcher.new()
var _scenery: MazeScenery = null


func _ready() -> void:
	if config == null:
		push_error("MazeLevel: no LevelConfig assigned.")
		return
	_rng.randomize()
	grid = MazeGrid.new(config, _rng)
	grid.generate(config)
	_cs = grid.cell_size

	_scenery = MazeScenery.new(self, grid, config, _rng, _batch)

	ArenaEnvironment.build(self, config)
	_build_floor()
	_scenery.build_landmarks()
	_build_walls()
	_build_gates()
	_build_posts()
	_scenery.build_scenery()
	_scenery.build_decorations()
	_batch.flush(self)
	MazeProps.new(self, grid, config, _rng).place()


func _build_gates() -> void:
	var t: float = config.wall_thickness
	for edge: Array in grid.gate_edges:
		var gate: MovingGate = MovingGate.new()
		var along_x: bool = edge[0].x == edge[1].x  # cells stacked in Z: the wall runs along X
		gate.gate_size = Vector3(_cs - t, config.wall_height, t * 0.8) if along_x \
			else Vector3(t * 0.8, config.wall_height, _cs - t)
		gate.color = config.accent_colors[0]
		gate.position = (grid.cell_pos(edge[0]) + grid.cell_pos(edge[1])) * 0.5
		add_child(gate)


# ─── Environment & floor ──────────────────────────────────────────────────

func _build_floor() -> void:
	var width: float = grid.cols * _cs
	var depth: float = grid.rows * _cs

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


# ─── Walls ────────────────────────────────────────────────────────────────

## Merge consecutive wall edges on each grid line into long segments.
func _build_walls() -> void:
	var half_w: float = grid.cols * _cs * 0.5
	var half_d: float = grid.rows * _cs * 0.5
	# Lines of constant X (walls running along Z).
	for line: int in range(grid.cols + 1):
		var run_start: int = -1
		for j: int in range(grid.rows + 1):
			var solid: bool = j < grid.rows and (line == 0 or line == grid.cols or grid.east[grid.idx(line - 1, j)] == 1)
			if solid and run_start < 0:
				run_start = j
			elif not solid and run_start >= 0:
				var x: float = line * _cs - half_w
				var z0: float = run_start * _cs - half_d
				var z1: float = j * _cs - half_d
				_add_wall(Vector3(x, 0.0, (z0 + z1) * 0.5), z1 - z0, false)
				run_start = -1
	# Lines of constant Z (walls running along X).
	for line: int in range(grid.rows + 1):
		var run_start: int = -1
		for i: int in range(grid.cols + 1):
			var solid: bool = i < grid.cols and (line == 0 or line == grid.rows or grid.south[grid.idx(i, line - 1)] == 1)
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
	var cap: float = WALL_CAP_HEIGHTS.get(config.style, 0.0)
	var full: float = length + t
	var size: Vector3 = Vector3(full, h, t) if along_x else Vector3(t, h, full)

	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = Constants.LAYER_WORLD
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size + Vector3(0.0, cap, 0.0)
	shape.shape = box
	shape.position = center + Vector3(0.0, (h + cap) * 0.5, 0.0)
	body.add_child(shape)
	add_child(body)

	var a: Color = config.wall_color_a
	var b: Color = config.wall_color_b
	var yaw: float = 0.0 if along_x else PI * 0.5
	var unit: Vector3 = Vector3(full, h, t)  # size in the wall's local frame
	match config.style:
		LevelConfig.Style.CANDY:
			_add_candy_wall(center, size)
			_batch.add("box", b, center + Vector3(0, h, 0), Vector3(full + WALL_CAP_OVERHANG, cap, t + WALL_CAP_OVERHANG), yaw)
		LevelConfig.Style.FOREST:
			_batch.add("box", a.darkened(0.25), center, Vector3(full, 1.1, t * 1.2), yaw)
			var count: int = maxi(1, int(full / TREE_SPACING))
			for n: int in count:
				var f: float = (n + 0.5) / count - 0.5
				var p: Vector3 = center + (Vector3(f * full, 0, 0) if along_x else Vector3(0, 0, f * full))
				_scenery.add_tree(p, _rng.randf_range(0.85, 1.25))
		LevelConfig.Style.GARDEN:
			_batch.add("box", a, center, unit, yaw)
			var flowers: int = int(full / 1.5)
			for n: int in flowers:
				if _rng.randf() < 0.5:
					var f: float = _rng.randf() - 0.5
					# Sunk half into the hedge top so flowers never float.
					var p: Vector3 = center + (Vector3(f * full, h, 0) if along_x else Vector3(0, h, f * full))
					_batch.add("sphere", _scenery.accent(), p, Vector3(0.5, 0.35, 0.5))
		LevelConfig.Style.ROMAN:
			_batch.add("box", a, center, unit, yaw)
			_batch.add("box", b, center + Vector3(0, h, 0), Vector3(full, cap, t * 1.15), yaw)
		LevelConfig.Style.EGYPT:
			_batch.add("box", a, center, unit, yaw)
			_batch.add("box", b, center + Vector3(0, h * 0.62, 0), Vector3(full, 0.45, t * 1.08), yaw)
			_batch.add("box", a.darkened(0.12), center + Vector3(0, h, 0), Vector3(full, cap, t * 1.2), yaw)
		LevelConfig.Style.WINTER:
			_batch.add("box", a, center, unit, yaw)
			_batch.add("box", b, center + Vector3(0, h, 0), Vector3(full + 0.1, cap, t * 1.25), yaw)


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
	for j: int in grid.rows:
		for i: int in grid.cols:
			if i == 0:
				_mark_edge(dirs, Vector2i(i, j), Vector2i(i, j + 1))
			if i == grid.cols - 1 or grid.east[grid.idx(i, j)] == 1:
				_mark_edge(dirs, Vector2i(i + 1, j), Vector2i(i + 1, j + 1))
			if j == 0:
				_mark_edge(dirs, Vector2i(i, j), Vector2i(i + 1, j))
			if j == grid.rows - 1 or grid.south[grid.idx(i, j)] == 1:
				_mark_edge(dirs, Vector2i(i, j + 1), Vector2i(i + 1, j + 1))
	var half_w: float = grid.cols * _cs * 0.5
	var half_d: float = grid.rows * _cs * 0.5
	for v: Vector2i in dirs:
		var straight: bool = dirs[v] == 3 or dirs[v] == 12
		if straight and config.style != LevelConfig.Style.FOREST:
			continue
		_scenery.add_post(Vector3(v.x * _cs - half_w, 0.0, v.y * _cs - half_d))


func _mark_edge(dirs: Dictionary, a: Vector2i, b: Vector2i) -> void:
	var horizontal: bool = a.y == b.y
	dirs[a] = dirs.get(a, 0) | (1 if horizontal else 4)
	dirs[b] = dirs.get(b, 0) | (2 if horizontal else 8)
