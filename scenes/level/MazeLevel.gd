## MazeLevel.gd
## Builds a themed maze arena from a LevelConfig at runtime.
##
## Pipeline: layout (wall grid) → connectivity repair → moving gates picked
##           → environment → floor → walls & posts → scenery → spawn markers
##           → gameplay props (trampolines, boxes, portals, map beacons...).
##
## The maze is a grid of square cells centered on the origin. Walls live on cell
## edges: _east[i] is the wall on the +X side of cell i, _south[i] the wall on
## its +Z side. The perimeter is always closed.
##
## Every arena is split into four quadrant zones plus the center plaza. Each
## zone has its own floor tint and a giant landmark just outside its corner, so
## a glance at a rival's screen tells where they are (the HUD names the zone too). Repeated meshes are batched into
## one MultiMeshInstance3D per (mesh, color) pair to keep draw calls low across
## the four split-screen cameras.
extends Node3D
class_name MazeLevel

const SURPRISE_BOX_SCENE: PackedScene = preload("res://scenes/powerups/SurpriseBox.tscn")
const TRAMPOLINE_SCENE: PackedScene = preload("res://scenes/level/Trampoline.tscn")
const SPRINKLER_SCENE: PackedScene = preload("res://scenes/level/Sprinkler.tscn")
const ICE_PATCH_SCENE: PackedScene = preload("res://scenes/effects/FX_IcePatch.tscn")
const SHADER_FLOOR: Shader = preload("res://shaders/arena_floor.gdshader")
const SHADER_STRIPE: Shader = preload("res://shaders/candy_stripe.gdshader")
const SHADER_SKY: Shader = preload("res://shaders/stylized_sky.gdshader")

## Height of spawn markers above the floor.
const MARKER_HEIGHT: float = 1.0
## Side of the decorative ground outside the maze.
const OUTER_GROUND_SIZE: float = 500.0
## Scenery ring around the maze: start distance from the wall and depth.
const SCENERY_MARGIN: float = 10.0
const SCENERY_DEPTH: float = 45.0
const SCENERY_COUNT: int = 70
## Cells within this Chebyshev radius of the center form an open plaza.
const CENTER_PLAZA_RADIUS: int = 1
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
## Number of candidate power-up locations.
const POWERUP_SPAWN_COUNT: int = 14
const SUN_SHADOW_DISTANCE: float = 80.0
## Post-processing shared by every arena: crisp contrast and a bit more colour.
const SSAO_RADIUS: float = 1.0
const SSAO_INTENSITY: float = 2.0
const SSAO_LIGHT_AFFECT: float = 0.2
const GRADE_CONTRAST: float = 1.06
const GRADE_SATURATION: float = 1.12
const TONEMAP_WHITE: float = 6.0
const TONEMAP_EXPOSURE: float = 1.0
const GLOW_INTENSITY: float = 0.6
const GLOW_BLOOM: float = 0.05
const GLOW_THRESHOLD: float = 0.95
## Share of the ambient light taken from the sky (the rest is the arena tint).
const AMBIENT_SKY_SHARE: float = 0.45
const CLOUD_WHITENESS: float = 0.75
## Minimum distance haze, even in arenas without fog.
const HAZE_DENSITY: float = 0.0012
const FOG_SKY_AFFECT: float = 0.15
const FOG_AERIAL: float = 0.25
const SUN_SHADOW_BLUR: float = 2.0
const SUN_ANGULAR_SIZE: float = 1.5
const RING_GAP_BASE: int = 2
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
## Portal pair colors, cycled.
const PORTAL_COLORS: Array[Color] = [Color(0.6, 0.35, 1.0), Color(0.2, 0.85, 1.0), Color(1.0, 0.45, 0.8)]

@export var config: LevelConfig

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _cols: int = 0
var _rows: int = 0
var _cs: float = 0.0
var _east: PackedByteArray = PackedByteArray()
var _south: PackedByteArray = PackedByteArray()
var _used_cells: Dictionary = {}
## Wall edges ([cell_a, cell_b]) turned into moving gates.
var _gate_edges: Array = []

## (mesh, color) → Array[Transform3D] waiting to be turned into MultiMeshes.
var _batches: Dictionary = {}
var _meshes: Dictionary = {}


func _ready() -> void:
	if config == null:
		push_error("MazeLevel: no LevelConfig assigned.")
		return
	_rng.randomize()
	_cols = config.columns | 1
	_rows = config.rows | 1
	_cs = config.cell_size
	_east.resize(_cols * _rows)
	_south.resize(_cols * _rows)

	match config.layout:
		LevelConfig.Layout.CLASSIC:
			_generate_classic()
		LevelConfig.Layout.ROOMS:
			_generate_classic()
			_carve_rooms()
		LevelConfig.Layout.RINGS:
			_generate_rings()
	_carve_center_plaza()
	_ensure_connected()
	_pick_gates()

	_build_environment()
	_build_floor()
	_build_landmarks()
	_build_walls()
	_build_gates()
	_build_posts()
	_build_scenery()
	_build_decorations()
	_flush_batches()
	_place_markers()
	_place_props()


# ─── Grid helpers ─────────────────────────────────────────────────────────

func _idx(i: int, j: int) -> int:
	return i + j * _cols


func _center_cell() -> Vector2i:
	return Vector2i(_cols / 2, _rows / 2)


func _ring(c: Vector2i) -> int:
	var center: Vector2i = _center_cell()
	return maxi(absi(c.x - center.x), absi(c.y - center.y))


func _cell_pos(c: Vector2i) -> Vector3:
	var center: Vector2i = _center_cell()
	return Vector3((c.x - center.x) * _cs, 0.0, (c.y - center.y) * _cs)


func _in_grid(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < _cols and c.y < _rows


## True if a wall separates two orthogonally adjacent cells.
func _wall_between(a: Vector2i, b: Vector2i) -> bool:
	if a.x != b.x:
		return _east[_idx(mini(a.x, b.x), a.y)] == 1
	return _south[_idx(a.x, mini(a.y, b.y))] == 1


func _set_wall(a: Vector2i, b: Vector2i, value: bool) -> void:
	var v: int = 1 if value else 0
	if a.x != b.x:
		_east[_idx(mini(a.x, b.x), a.y)] = v
	else:
		_south[_idx(a.x, mini(a.y, b.y))] = v


func _neighbors(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		if _in_grid(c + d):
			out.append(c + d)
	return out


## Every interior edge as [cell_a, cell_b] (each edge listed once).
func _interior_edges() -> Array:
	var edges: Array = []
	for j: int in _rows:
		for i: int in _cols:
			if i + 1 < _cols:
				edges.append([Vector2i(i, j), Vector2i(i + 1, j)])
			if j + 1 < _rows:
				edges.append([Vector2i(i, j), Vector2i(i, j + 1)])
	return edges


func _wall_count(c: Vector2i) -> int:
	var walls: int = 4 - _neighbors(c).size()  # perimeter sides
	for n: Vector2i in _neighbors(c):
		if _wall_between(c, n):
			walls += 1
	return walls


# ─── Layout generation ────────────────────────────────────────────────────

## Recursive-backtracker perfect maze, then random walls removed to add loops.
func _generate_classic() -> void:
	_east.fill(1)
	_south.fill(1)
	var visited: Dictionary = {}
	var stack: Array[Vector2i] = [_center_cell()]
	visited[_center_cell()] = true
	while not stack.is_empty():
		var current: Vector2i = stack.back()
		var options: Array[Vector2i] = []
		for n: Vector2i in _neighbors(current):
			if not visited.has(n):
				options.append(n)
		if options.is_empty():
			stack.pop_back()
			continue
		var next: Vector2i = options[_rng.randi() % options.size()]
		_set_wall(current, next, false)
		visited[next] = true
		stack.append(next)

	for edge: Array in _interior_edges():
		if _wall_between(edge[0], edge[1]) and _rng.randf() < config.loop_chance:
			_set_wall(edge[0], edge[1], false)


## Clears all walls inside a few random rectangles to create plazas.
func _carve_rooms() -> void:
	for _r: int in config.room_count:
		var w: int = _rng.randi_range(2, 3)
		var h: int = _rng.randi_range(2, 3)
		var x0: int = _rng.randi_range(1, _cols - w - 1)
		var y0: int = _rng.randi_range(1, _rows - h - 1)
		_clear_rect(x0, y0, w, h)


func _carve_center_plaza() -> void:
	var c: Vector2i = _center_cell()
	var size: int = CENTER_PLAZA_RADIUS * 2 + 1
	_clear_rect(c.x - CENTER_PLAZA_RADIUS, c.y - CENTER_PLAZA_RADIUS, size, size)


func _clear_rect(x0: int, y0: int, w: int, h: int) -> void:
	for j: int in range(y0, y0 + h):
		for i: int in range(x0, x0 + w):
			var c: Vector2i = Vector2i(i, j)
			if i + 1 < x0 + w:
				_set_wall(c, c + Vector2i.RIGHT, false)
			if j + 1 < y0 + h:
				_set_wall(c, c + Vector2i.DOWN, false)


## Concentric square rings around the center, each with a few gaps, plus a
## couple of radial walls per corridor so it is not just a racetrack.
func _generate_rings() -> void:
	_east.fill(0)
	_south.fill(0)
	var boundaries: Dictionary = {}  # ring k → edges between ring k and k+1
	var corridors: Dictionary = {}   # ring k → edges inside ring k
	for edge: Array in _interior_edges():
		var ra: int = _ring(edge[0])
		var rb: int = _ring(edge[1])
		if ra != rb:
			var k: int = mini(ra, rb)
			if k >= 1:
				_set_wall(edge[0], edge[1], true)
				if not boundaries.has(k):
					boundaries[k] = []
				boundaries[k].append(edge)
		elif ra >= 2:
			if not corridors.has(ra):
				corridors[ra] = []
			corridors[ra].append(edge)

	for k: int in boundaries:
		var edges: Array = boundaries[k]
		edges.shuffle()
		var gaps: int = RING_GAP_BASE + k / 2
		for g: int in mini(gaps, edges.size()):
			_set_wall(edges[g][0], edges[g][1], false)

	for k: int in corridors:
		var edges: Array = corridors[k]
		edges.shuffle()
		for g: int in mini(1 + k / 3, edges.size()):
			_set_wall(edges[g][0], edges[g][1], true)


## Flood fill from the center; knock down walls until every cell is reachable.
func _ensure_connected() -> void:
	var reached: Dictionary = {}
	var frontier: Array[Vector2i] = [_center_cell()]
	reached[_center_cell()] = true
	while true:
		while not frontier.is_empty():
			var c: Vector2i = frontier.pop_back()
			for n: Vector2i in _neighbors(c):
				if not reached.has(n) and not _wall_between(c, n):
					reached[n] = true
					frontier.append(n)
		if reached.size() == _cols * _rows:
			return
		var candidates: Array = []
		for c: Vector2i in reached:
			for n: Vector2i in _neighbors(c):
				if not reached.has(n):
					candidates.append([c, n])
		var pick: Array = candidates[_rng.randi() % candidates.size()]
		_set_wall(pick[0], pick[1], false)
		reached[pick[1]] = true
		frontier.append(pick[1])


## Any interior wall can become a gate: the maze is already connected without
## them, so a closed gate only ever blocks a shortcut.
func _pick_gates() -> void:
	var walls: Array = []
	for edge: Array in _interior_edges():
		if _wall_between(edge[0], edge[1]):
			walls.append(edge)
	walls.shuffle()
	_gate_edges = walls.slice(0, mini(config.gate_count, walls.size()))
	for edge: Array in _gate_edges:
		_set_wall(edge[0], edge[1], false)


func _build_gates() -> void:
	var t: float = config.wall_thickness
	for edge: Array in _gate_edges:
		var gate: MovingGate = MovingGate.new()
		var along_x: bool = edge[0].x == edge[1].x  # cells stacked in Z: the wall runs along X
		gate.gate_size = Vector3(_cs - t, config.wall_height, t * 0.8) if along_x \
			else Vector3(t * 0.8, config.wall_height, _cs - t)
		gate.color = config.accent_colors[0]
		gate.position = (_cell_pos(edge[0]) + _cell_pos(edge[1])) * 0.5
		add_child(gate)


# ─── Mesh batching ────────────────────────────────────────────────────────

func _mesh(name: String) -> Mesh:
	if _meshes.has(name):
		return _meshes[name]
	var m: Mesh
	match name:
		"box":
			m = BoxMesh.new()
		"sphere":
			var s: SphereMesh = SphereMesh.new()
			s.radius = 0.5
			s.height = 1.0
			s.radial_segments = 16
			s.rings = 8
			m = s
		"cylinder":
			var c: CylinderMesh = CylinderMesh.new()
			c.top_radius = 0.5
			c.bottom_radius = 0.5
			c.height = 1.0
			c.radial_segments = 12
			m = c
		"cone":
			var c: CylinderMesh = CylinderMesh.new()
			c.top_radius = 0.0
			c.bottom_radius = 0.5
			c.height = 1.0
			c.radial_segments = 10
			m = c
		"pyramid":
			var c: CylinderMesh = CylinderMesh.new()
			c.top_radius = 0.0
			c.bottom_radius = 0.7071
			c.height = 1.0
			c.radial_segments = 4
			m = c
	_meshes[name] = m
	return m


## Queue one instance of a unit mesh: [param pos] is the bottom center for
## boxes/cylinders/cones, the center for spheres.
func _add(mesh_name: String, color: Color, pos: Vector3, size: Vector3, yaw: float = 0.0, outline: float = 0.0) -> void:
	# Scale in the mesh's local frame, then rotate (Basis.scaled() would scale world axes).
	var basis: Basis = Basis(Vector3.UP, yaw) * Basis.from_scale(size)
	var offset: Vector3 = Vector3.ZERO if mesh_name == "sphere" else Vector3(0.0, size.y * 0.5, 0.0)
	var key: String = "%s|%s|%.3f" % [mesh_name, color.to_html(), outline]
	if not _batches.has(key):
		_batches[key] = { "mesh": mesh_name, "color": color, "outline": outline, "xforms": [] }
	_batches[key]["xforms"].append(Transform3D(basis, pos + offset))


func _flush_batches() -> void:
	for key: String in _batches:
		var batch: Dictionary = _batches[key]
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _mesh(batch["mesh"])
		var xforms: Array = batch["xforms"]
		mm.instance_count = xforms.size()
		for n: int in xforms.size():
			mm.set_instance_transform(n, xforms[n])
		var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		mmi.multimesh = mm
		# Architecture has no ink outline (the hull trick breaks up on long thin
		# boxes); only small props ask for one.
		mmi.material_override = ToonMaterials.get_material(batch["color"], batch["outline"])
		add_child(mmi)
	_batches.clear()


func _accent() -> Color:
	return config.accent_colors[_rng.randi() % config.accent_colors.size()]


# ─── Environment & floor ──────────────────────────────────────────────────

func _build_environment() -> void:
	var sky_mat: ShaderMaterial = ShaderMaterial.new()
	sky_mat.shader = SHADER_SKY
	sky_mat.set_shader_parameter("top_color", config.sky_top_color)
	sky_mat.set_shader_parameter("horizon_color", config.sky_horizon_color)
	sky_mat.set_shader_parameter("ground_color", config.outer_ground_color)
	sky_mat.set_shader_parameter("cloud_color", config.sky_horizon_color.lerp(Color.WHITE, CLOUD_WHITENESS))
	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat

	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# Ambient = the arena's tint blended with the sky, so shaded sides stay colourful.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = config.ambient_color
	env.ambient_light_sky_contribution = AMBIENT_SKY_SHARE
	env.ambient_light_energy = config.ambient_energy
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = TONEMAP_WHITE
	env.tonemap_exposure = TONEMAP_EXPOSURE
	env.ssao_enabled = true
	env.ssao_radius = SSAO_RADIUS
	env.ssao_intensity = SSAO_INTENSITY
	env.ssao_light_affect = SSAO_LIGHT_AFFECT
	env.glow_enabled = true
	env.glow_intensity = GLOW_INTENSITY
	env.glow_bloom = GLOW_BLOOM
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = GLOW_THRESHOLD
	env.adjustment_enabled = true
	env.adjustment_contrast = GRADE_CONTRAST
	env.adjustment_saturation = GRADE_SATURATION
	# Distance haze in the horizon colour gives depth to the maze and scenery.
	env.fog_enabled = true
	env.fog_light_color = config.fog_color if config.fog_density > 0.0 else config.sky_horizon_color
	env.fog_density = maxf(config.fog_density, HAZE_DENSITY)
	env.fog_sky_affect = FOG_SKY_AFFECT
	env.fog_aerial_perspective = FOG_AERIAL
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.light_color = config.sun_color
	sun.light_energy = config.sun_energy
	sun.shadow_enabled = true
	sun.shadow_blur = SUN_SHADOW_BLUR
	sun.light_angular_distance = SUN_ANGULAR_SIZE
	sun.directional_shadow_max_distance = SUN_SHADOW_DISTANCE
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.rotation_degrees = Vector3(-50.0, 35.0, 0.0)
	add_child(sun)


func _build_floor() -> void:
	var width: float = _cols * _cs
	var depth: float = _rows * _cs

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
	return level.cell_size * (CENTER_PLAZA_RADIUS + 0.5)


## Zone index (0-3 quadrants, ZONE_CENTER) of a world position in [param level].
static func zone_of(pos: Vector3, level: LevelConfig) -> int:
	var plaza: float = _plaza_half_size(level)
	if absf(pos.x) < plaza and absf(pos.z) < plaza:
		return ZONE_CENTER
	return (1 if pos.x >= 0.0 else 0) | (2 if pos.z >= 0.0 else 0)


## A giant, differently shaped landmark outside each quadrant's corner, tall
## enough to be seen over the walls from anywhere in that zone.
func _build_landmarks() -> void:
	var half: Vector2 = Vector2(_cols, _rows) * _cs * 0.5 + Vector2.ONE * LANDMARK_OFFSET
	var k: float = LANDMARK_SCALE
	for zone: int in ZONE_CENTER:
		var c: Color = ZONE_COLORS[zone]
		var p: Vector3 = Vector3(half.x * (1.0 if zone & 1 else -1.0), 0.0, half.y * (1.0 if zone & 2 else -1.0))
		match zone:
			0:  # Crystal spire
				_add("box", c.darkened(0.3), p, Vector3(4.0, 1.5, 4.0) * k, PI * 0.25)
				_add("pyramid", c, p + Vector3(0, 1.5, 0) * k, Vector3(3.2, 17.0, 3.2) * k)
				_add("pyramid", c.lightened(0.3), p + Vector3(2.2, 0, 1.2) * k, Vector3(1.6, 7.0, 1.6) * k, 0.4)
			1:  # Orb tower
				_add("cylinder", c.darkened(0.25), p, Vector3(1.6, 13.0, 1.6) * k)
				_add("sphere", c, p + Vector3(0, 15.0, 0) * k, Vector3.ONE * 6.0 * k)
				_add("cylinder", c.lightened(0.3), p + Vector3(0, 14.6, 0) * k, Vector3(7.5, 0.6, 7.5) * k)
			2:  # Pyramid
				_add("pyramid", c, p, Vector3(11.0, 11.0, 11.0) * k, PI * 0.25)
				_add("sphere", Color.WHITE, p + Vector3(0, 11.5, 0) * k, Vector3.ONE * 1.6 * k)
			3:  # Castle
				_add("box", c.darkened(0.2), p, Vector3(5.0, 10.0, 5.0) * k)
				_add("box", c, p + Vector3(0, 10.0, 0) * k, Vector3(6.4, 1.2, 6.4) * k)
				_add("cone", c.lightened(0.25), p + Vector3(0, 11.2, 0) * k, Vector3(5.5, 6.0, 5.5) * k)


# ─── Walls ────────────────────────────────────────────────────────────────

## Merge consecutive wall edges on each grid line into long segments.
func _build_walls() -> void:
	var half_w: float = _cols * _cs * 0.5
	var half_d: float = _rows * _cs * 0.5
	# Lines of constant X (walls running along Z).
	for line: int in range(_cols + 1):
		var run_start: int = -1
		for j: int in range(_rows + 1):
			var solid: bool = j < _rows and (line == 0 or line == _cols or _east[_idx(line - 1, j)] == 1)
			if solid and run_start < 0:
				run_start = j
			elif not solid and run_start >= 0:
				var x: float = line * _cs - half_w
				var z0: float = run_start * _cs - half_d
				var z1: float = j * _cs - half_d
				_add_wall(Vector3(x, 0.0, (z0 + z1) * 0.5), z1 - z0, false)
				run_start = -1
	# Lines of constant Z (walls running along X).
	for line: int in range(_rows + 1):
		var run_start: int = -1
		for i: int in range(_cols + 1):
			var solid: bool = i < _cols and (line == 0 or line == _rows or _south[_idx(i, line - 1)] == 1)
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
			_add("box", b, center + Vector3(0, h, 0), Vector3(full + WALL_CAP_OVERHANG, WALL_CAP_HEIGHT, t + WALL_CAP_OVERHANG), yaw)
		LevelConfig.Style.FOREST:
			_add("box", a.darkened(0.25), center, Vector3(full, 1.1, t * 1.2), yaw)
			var count: int = maxi(1, int(full / TREE_SPACING))
			for n: int in count:
				var f: float = (n + 0.5) / count - 0.5
				var p: Vector3 = center + (Vector3(f * full, 0, 0) if along_x else Vector3(0, 0, f * full))
				_add_tree(p, _rng.randf_range(0.85, 1.25))
		LevelConfig.Style.GARDEN:
			_add("box", a, center, unit, yaw)
			var flowers: int = int(full / 1.5)
			for n: int in flowers:
				if _rng.randf() < 0.5:
					var f: float = _rng.randf() - 0.5
					# Sunk half into the hedge top so flowers never float.
					var p: Vector3 = center + (Vector3(f * full, h, 0) if along_x else Vector3(0, h, f * full))
					_add("sphere", _accent(), p, Vector3(0.5, 0.35, 0.5))
		LevelConfig.Style.ROMAN:
			_add("box", a, center, unit, yaw)
			_add("box", b, center + Vector3(0, h, 0), Vector3(full, 0.25, t * 1.15), yaw)
		LevelConfig.Style.EGYPT:
			_add("box", a, center, unit, yaw)
			_add("box", b, center + Vector3(0, h * 0.62, 0), Vector3(full, 0.45, t * 1.08), yaw)
			_add("box", a.darkened(0.12), center + Vector3(0, h, 0), Vector3(full, 0.35, t * 1.2), yaw)
		LevelConfig.Style.WINTER:
			_add("box", a, center, unit, yaw)
			_add("box", b, center + Vector3(0, h, 0), Vector3(full + 0.1, 0.35, t * 1.25), yaw)


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
	for j: int in _rows:
		for i: int in _cols:
			if i == 0:
				_mark_edge(dirs, Vector2i(i, j), Vector2i(i, j + 1))
			if i == _cols - 1 or _east[_idx(i, j)] == 1:
				_mark_edge(dirs, Vector2i(i + 1, j), Vector2i(i + 1, j + 1))
			if j == 0:
				_mark_edge(dirs, Vector2i(i, j), Vector2i(i + 1, j))
			if j == _rows - 1 or _south[_idx(i, j)] == 1:
				_mark_edge(dirs, Vector2i(i, j + 1), Vector2i(i + 1, j + 1))
	var half_w: float = _cols * _cs * 0.5
	var half_d: float = _rows * _cs * 0.5
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
			_add("cylinder", Color.WHITE, p, Vector3(0.25, h + 1.2, 0.25))
			_add("sphere", _accent(), p + Vector3(0, h + 1.3, 0), Vector3(1.2, 1.2, 0.5))
		LevelConfig.Style.FOREST:
			_add_tree(p, _rng.randf_range(1.1, 1.5))
		LevelConfig.Style.GARDEN:
			_add("sphere", config.wall_color_a.lightened(0.1), p + Vector3(0, h, 0), Vector3.ONE * t * 1.5)
		LevelConfig.Style.ROMAN:
			_add("box", config.wall_color_b, p, Vector3(t * 1.5, 0.3, t * 1.5))
			_add("cylinder", config.wall_color_b, p + Vector3(0, 0.3, 0), Vector3(t * 1.25, h + 0.3, t * 1.25))
			_add("box", config.wall_color_b, p + Vector3(0, h + 0.6, 0), Vector3(t * 1.5, 0.3, t * 1.5))
		LevelConfig.Style.EGYPT:
			_add("box", config.wall_color_a.darkened(0.1), p, Vector3(t * 1.5, h + 0.8, t * 1.5))
			_add("pyramid", config.accent_colors[0], p + Vector3(0, h + 0.8, 0), Vector3(t * 1.5, 0.9, t * 1.5))
		LevelConfig.Style.WINTER:
			_add("cylinder", config.wall_color_a.lightened(0.2), p, Vector3(t * 1.3, h + 0.5, t * 1.3))
			_add("sphere", Color.WHITE, p + Vector3(0, h + 0.5, 0), Vector3.ONE * t * 1.4)


func _add_tree(p: Vector3, s: float) -> void:
	var trunk: Color = Color(0.45, 0.3, 0.18)
	match config.style:
		LevelConfig.Style.WINTER:
			_add("cylinder", trunk, p, Vector3(0.35, 1.0, 0.35) * s)
			_add("cone", config.accent_colors[0], p + Vector3(0, 0.8 * s, 0), Vector3(2.4, 2.4, 2.4) * s)
			_add("cone", Color.WHITE, p + Vector3(0, 2.3 * s, 0), Vector3(1.4, 1.4, 1.4) * s)
		LevelConfig.Style.EGYPT:
			# Palm: tall thin trunk, flattened canopy.
			_add("cylinder", trunk, p, Vector3(0.35, 4.5, 0.35) * s)
			_add("sphere", config.accent_colors[1], p + Vector3(0, 4.6 * s, 0), Vector3(3.0, 0.8, 3.0) * s)
		LevelConfig.Style.ROMAN:
			# Cypress: tall dark cone.
			_add("cylinder", trunk, p, Vector3(0.3, 0.8, 0.3) * s)
			_add("cone", Color(0.2, 0.42, 0.25), p + Vector3(0, 0.6 * s, 0), Vector3(1.3, 5.0, 1.3) * s)
		_:
			_add("cylinder", trunk, p, Vector3(0.45, 1.6, 0.45) * s)
			var leaves: Color = config.wall_color_a if config.style == LevelConfig.Style.FOREST else Color(0.35, 0.7, 0.35)
			_add("cone", leaves, p + Vector3(0, 1.2 * s, 0), Vector3(2.6, 2.4, 2.6) * s)
			_add("cone", leaves.lightened(0.12), p + Vector3(0, 2.5 * s, 0), Vector3(1.9, 2.0, 1.9) * s)


# ─── Scenery & decorations ───────────────────────────────────────────────

## Large props in a ring outside the maze to sell the theme on the horizon.
func _build_scenery() -> void:
	var half: float = maxf(_cols, _rows) * _cs * 0.5
	for n: int in SCENERY_COUNT:
		var angle: float = _rng.randf() * TAU
		var dist: float = half + SCENERY_MARGIN + _rng.randf() * SCENERY_DEPTH
		var p: Vector3 = Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		var s: float = _rng.randf_range(1.5, 3.0)
		match config.style:
			LevelConfig.Style.CANDY:
				if n % 2 == 0:
					_add("cylinder", Color.WHITE, p, Vector3(0.5, 7.0, 0.5) * s)
					_add("sphere", _accent(), p + Vector3(0, 7.5 * s, 0), Vector3(4.0, 4.0, 1.6) * s, angle)
				else:
					_add("sphere", _accent(), p, Vector3(4.0, 3.0, 4.0) * s)
			LevelConfig.Style.EGYPT:
				if n % 5 == 0:
					_add("pyramid", config.wall_color_a, p * 1.6, Vector3(30, 22, 30) * (s * 0.6), PI * 0.25)
				elif n % 2 == 0:
					_add_tree(p, s * 0.7)
				else:
					_add("box", config.wall_color_a, p, Vector3(1.2, 9.0, 1.2) * s * 0.6)
					_add("pyramid", config.accent_colors[0], p + Vector3(0, 9.0 * s * 0.6, 0), Vector3(1.2, 1.4, 1.2) * s * 0.6)
			LevelConfig.Style.ROMAN:
				if n % 3 == 0:
					# Ruined column: base, shaft of random height, sometimes a capital.
					var col: Color = config.wall_color_b
					var shaft: float = _rng.randf_range(2.0, 8.0) * s * 0.6
					_add("box", col, p, Vector3(1.8, 0.5, 1.8) * s * 0.6)
					_add("cylinder", col, p, Vector3(1.2, shaft, 1.2) * s * 0.6)
					if shaft > 3.5:
						_add("box", col, p + Vector3(0, shaft, 0), Vector3(1.8, 0.5, 1.8) * s * 0.6)
				else:
					_add_tree(p, s * 0.8)
			LevelConfig.Style.GARDEN:
				if n % 3 == 0:
					_add("sphere", _accent(), p, Vector3(3.0, 2.0, 3.0) * s * 0.6)
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
		var c: Vector2i = Vector2i(_rng.randi() % _cols, _rng.randi() % _rows)
		if _ring(c) <= CENTER_PLAZA_RADIUS:
			continue  # Keep the plaza open.
		var corner: Vector3 = Vector3(1.0 if _rng.randf() < 0.5 else -1.0, 0.0, 1.0 if _rng.randf() < 0.5 else -1.0)
		var p: Vector3 = _cell_pos(c) + corner * inset
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
				_add("sphere", _accent(), p + Vector3(0, 0.3, 0), Vector3(0.7, 0.6, 0.7), 0.0, o)
			LevelConfig.Style.FOREST:
				_add("cylinder", Color(0.95, 0.92, 0.85), p, Vector3(0.25, 0.5, 0.25), 0.0, o)
				_add("sphere", Color(0.9, 0.2, 0.2), p + Vector3(0, 0.55, 0), Vector3(0.8, 0.45, 0.8), 0.0, o)
			LevelConfig.Style.GARDEN:
				for k: int in 3:
					var q: Vector3 = p + Vector3(_rng.randf_range(-0.3, 0.3), 0, _rng.randf_range(-0.3, 0.3))
					_add("cylinder", Color(0.3, 0.6, 0.3), q, Vector3(0.06, 0.5, 0.06), 0.0, o)
					_add("sphere", _accent(), q + Vector3(0, 0.55, 0), Vector3.ONE * 0.3, 0.0, o)
			LevelConfig.Style.ROMAN:
				_add("sphere", config.accent_colors[0], p + Vector3(0, 0.45, 0), Vector3(0.6, 0.8, 0.6), 0.0, o)
				_add("cylinder", config.accent_colors[0], p + Vector3(0, 0.8, 0), Vector3(0.25, 0.35, 0.25), 0.0, o)
			LevelConfig.Style.EGYPT:
				_add("cylinder", config.accent_colors[1], p, Vector3(0.5, 0.7, 0.5), 0.0, o)
				_add("sphere", config.accent_colors[1], p + Vector3(0, 0.7, 0), Vector3(0.55, 0.3, 0.55), 0.0, o)
			LevelConfig.Style.WINTER:
				_add("sphere", Color.WHITE, p + Vector3(0, 0.4, 0), Vector3.ONE * 0.8, 0.0, o)
				_add("sphere", Color.WHITE, p + Vector3(0, 1.0, 0), Vector3.ONE * 0.55, 0.0, o)
				_add("cone", Color(1.0, 0.55, 0.1), p + Vector3(0, 1.0, 0.25), Vector3(0.1, 0.3, 0.1), 0.0, o)

	# Golden circle on the floor marks the center where the golden gem appears.
	_add("cylinder", config.accent_colors[0], Vector3(0, 0.0, 0), Vector3(3.0, 0.06, 3.0))


# ─── Markers & props ──────────────────────────────────────────────────────

func _place_markers() -> void:
	var corners: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(_cols - 1, _rows - 1),
		Vector2i(_cols - 1, 0), Vector2i(0, _rows - 1),
	]
	for c: Vector2i in corners:
		var m: Marker3D = _marker(c, Constants.GROUP_SPAWN_POINTS)
		m.look_at(Vector3(0, MARKER_HEIGHT, 0), Vector3.UP)
		_used_cells[c] = true
	_used_cells[_center_cell()] = true

	for j: int in _rows:
		for i: int in _cols:
			var c: Vector2i = Vector2i(i, j)
			if not _used_cells.has(c):
				_marker(c, Constants.GROUP_GEM_SPAWNS)


func _marker(c: Vector2i, group: String) -> Marker3D:
	var m: Marker3D = Marker3D.new()
	m.add_to_group(group)
	add_child(m)
	m.position = _cell_pos(c) + Vector3(0, MARKER_HEIGHT, 0)
	return m


func _place_props() -> void:
	# Dead ends get trampolines: the way out is up and over the wall.
	var dead_ends: Array[Vector2i] = []
	var free_cells: Array[Vector2i] = []
	for j: int in _rows:
		for i: int in _cols:
			var c: Vector2i = Vector2i(i, j)
			if _used_cells.has(c):
				continue
			free_cells.append(c)
			if _wall_count(c) >= 3:
				dead_ends.append(c)
	dead_ends.shuffle()
	free_cells.shuffle()

	for n: int in mini(config.trampoline_count, dead_ends.size()):
		_spawn_at(TRAMPOLINE_SCENE, dead_ends[n])

	var boxes_left: int = config.surprise_box_count
	var spawns_left: int = POWERUP_SPAWN_COUNT
	var sprinklers_left: int = config.sprinkler_count
	var ice_left: int = config.ice_patch_count
	for c: Vector2i in free_cells:
		if _used_cells.has(c):
			continue
		if spawns_left > 0:
			_marker(c, Constants.GROUP_POWERUP_SPAWNS)
			spawns_left -= 1
			if boxes_left > 0:
				_spawn_at(SURPRISE_BOX_SCENE, c)
				boxes_left -= 1
			_used_cells[c] = true
		elif sprinklers_left > 0:
			_spawn_at(SPRINKLER_SCENE, c)
			sprinklers_left -= 1
		elif ice_left > 0:
			var patch: Node3D = _spawn_at(ICE_PATCH_SCENE, c)
			patch.set("duration", 0.0)
			ice_left -= 1
	_place_portals(free_cells)
	for c: Vector2i in _free(free_cells).slice(0, config.map_beacon_count):
		_add_feature(MapBeacon.new(), c)


## Each pair joins a random cell to the free cell farthest from it.
func _place_portals(cells: Array[Vector2i]) -> void:
	for n: int in config.portal_pairs:
		var free: Array[Vector2i] = _free(cells)
		if free.size() < 2:
			return
		var a: Vector2i = free[0]
		var b: Vector2i = free[1]
		for c: Vector2i in free:
			if Vector2(c - a).length() > Vector2(b - a).length():
				b = c
		var color: Color = PORTAL_COLORS[n % PORTAL_COLORS.size()]
		var portal_a: Portal = Portal.new()
		var portal_b: Portal = Portal.new()
		portal_a.color = color
		portal_b.color = color
		portal_a.partner = portal_b
		portal_b.partner = portal_a
		_add_feature(portal_a, a)
		_add_feature(portal_b, b)


func _free(cells: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Vector2i in cells:
		if not _used_cells.has(c):
			out.append(c)
	return out


func _add_feature(node: Node3D, c: Vector2i) -> void:
	add_child(node)
	node.position = _cell_pos(c)
	_used_cells[c] = true


func _spawn_at(scene: PackedScene, c: Vector2i) -> Node3D:
	var node: Node3D = scene.instantiate() as Node3D
	add_child(node)
	node.position = _cell_pos(c)
	_used_cells[c] = true
	return node
