## MazeProps.gd
## Fills a built maze with what players interact with: spawn points (corners),
## gem and power-up markers, trampolines in dead ends, gift boxes, sprinklers,
## ice patches, portal pairs, map beacons, and the single golden return pad
## outside the outer wall. Every prop joins Constants.GROUP_PROPS so gems never
## spawn on top of it.
extends RefCounted
class_name MazeProps

const SURPRISE_BOX_SCENE: PackedScene = preload("res://scenes/powerups/SurpriseBox.tscn")
const TRAMPOLINE_SCENE: PackedScene = preload("res://scenes/level/Trampoline.tscn")
const SPRINKLER_SCENE: PackedScene = preload("res://scenes/level/Sprinkler.tscn")
const ICE_PATCH_SCENE: PackedScene = preload("res://scenes/effects/FX_IcePatch.tscn")
## Height of spawn markers above the floor.
const MARKER_HEIGHT: float = 1.0
## Number of candidate power-up locations.
const POWERUP_SPAWN_COUNT: int = 14
## The single golden return pad outside the perimeter: distance from the outer
## wall, margin kept from the corners (landmarks), cap colour, landing point.
const RETURN_PAD_OFFSET: float = 3.5
const RETURN_PAD_CORNER_MARGIN: float = 8.0
const RETURN_PAD_COLOR: Color = Color(1.0, 0.8, 0.2)
const RETURN_LANDING: Vector3 = Vector3(0.0, 0.5, 0.0)
## Portal pair colors, cycled.
const PORTAL_COLORS: Array[Color] = [Color(0.6, 0.35, 1.0), Color(0.2, 0.85, 1.0), Color(1.0, 0.45, 0.8)]

var _level: Node3D
var _grid: MazeGrid
var _config: LevelConfig
var _rng: RandomNumberGenerator
## Cells already holding a spawn point or a prop.
var _used_cells: Dictionary = {}


func _init(level: Node3D, grid: MazeGrid, config: LevelConfig, rng: RandomNumberGenerator) -> void:
	_level = level
	_grid = grid
	_config = config
	_rng = rng


func place() -> void:
	_place_markers()
	_place_props()


func _place_markers() -> void:
	var corners: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(_grid.cols - 1, _grid.rows - 1),
		Vector2i(_grid.cols - 1, 0), Vector2i(0, _grid.rows - 1),
	]
	for c: Vector2i in corners:
		var m: Marker3D = _marker(c, Constants.GROUP_SPAWN_POINTS)
		m.look_at(Vector3(0, MARKER_HEIGHT, 0), Vector3.UP)
		_used_cells[c] = true
	_used_cells[_grid.center()] = true

	for j: int in _grid.rows:
		for i: int in _grid.cols:
			var c: Vector2i = Vector2i(i, j)
			if not _used_cells.has(c):
				_marker(c, Constants.GROUP_GEM_SPAWNS)


func _marker(c: Vector2i, group: String) -> Marker3D:
	var m: Marker3D = Marker3D.new()
	m.add_to_group(group)
	_level.add_child(m)
	m.position = _grid.cell_pos(c) + Vector3(0, MARKER_HEIGHT, 0)
	return m


func _place_props() -> void:
	# Dead ends get trampolines: the way out is up and over the wall.
	var dead_ends: Array[Vector2i] = []
	var free_cells: Array[Vector2i] = []
	for j: int in _grid.rows:
		for i: int in _grid.cols:
			var c: Vector2i = Vector2i(i, j)
			if _used_cells.has(c):
				continue
			free_cells.append(c)
			if _grid.wall_count(c) >= 3:
				dead_ends.append(c)
	dead_ends.shuffle()
	free_cells.shuffle()

	for n: int in mini(_config.trampoline_count, dead_ends.size()):
		_spawn_at(TRAMPOLINE_SCENE, dead_ends[n])

	var boxes_left: int = _config.surprise_box_count
	var spawns_left: int = POWERUP_SPAWN_COUNT
	var sprinklers_left: int = _config.sprinkler_count
	var ice_left: int = _config.ice_patch_count
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
			var patch: IcePatch = _spawn_at(ICE_PATCH_SCENE, c) as IcePatch
			patch.duration = 0.0  # A level hazard never melts.
			ice_left -= 1
	_place_return_pad()
	_place_portals(free_cells)
	for c: Vector2i in _free(free_cells).slice(0, _config.map_beacon_count):
		_add_feature(MapBeacon.new(), c)


## One golden trampoline just outside a random stretch of the outer wall: a
## hunter who ends up outside must find it to bounce back to the plaza.
func _place_return_pad() -> void:
	var half: Vector2 = Vector2(_grid.cols, _grid.rows) * _grid.cell_size * 0.5
	var side: int = _rng.randi() % 4
	var along_x: bool = side < 2
	var span: float = (half.x if along_x else half.y) - RETURN_PAD_CORNER_MARGIN
	var t: float = _rng.randf_range(-span, span)
	var out: float = (half.y if along_x else half.x) + RETURN_PAD_OFFSET
	var sign_: float = 1.0 if side % 2 == 0 else -1.0
	var pad: Trampoline = TRAMPOLINE_SCENE.instantiate() as Trampoline
	pad.aimed = true
	pad.launch_target = RETURN_LANDING
	_level.add_child(pad)
	pad.position = Vector3(t, 0.0, out * sign_) if along_x else Vector3(out * sign_, 0.0, t)
	pad.set_cap_color(RETURN_PAD_COLOR)


## Each pair joins a random cell to the free cell farthest from it.
func _place_portals(cells: Array[Vector2i]) -> void:
	for n: int in _config.portal_pairs:
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
	node.add_to_group(Constants.GROUP_PROPS)
	_level.add_child(node)
	node.position = _grid.cell_pos(c)
	_used_cells[c] = true


func _spawn_at(scene: PackedScene, c: Vector2i) -> Node3D:
	var node: Node3D = scene.instantiate() as Node3D
	node.add_to_group(Constants.GROUP_PROPS)
	_level.add_child(node)
	node.position = _grid.cell_pos(c)
	_used_cells[c] = true
	return node
