## MazeGrid.gd
## The maze as data, no visuals: a grid of square cells centered on the origin
## with walls on cell edges (east[i] = wall on the +X side of cell i, south[i]
## on its +Z side; the perimeter is always closed). generate() builds a layout
## (CLASSIC / ROOMS / RINGS), opens the center plaza, repairs connectivity and
## picks interior walls to become moving gates (opened here, so the maze never
## depends on them). Odd sizes keep a cell at the origin.
extends RefCounted
class_name MazeGrid

## Cells within this Chebyshev radius of the center form an open plaza.
const CENTER_PLAZA_RADIUS: int = 1
## Rings layout: gaps per ring boundary grow from this base.
const RING_GAP_BASE: int = 2
## Rooms layout: room side, in cells.
const ROOM_MIN_SIDE: int = 2
const ROOM_MAX_SIDE: int = 3

var cols: int = 0
var rows: int = 0
var cell_size: float = 0.0
var east: PackedByteArray = PackedByteArray()
var south: PackedByteArray = PackedByteArray()
## Wall edges ([cell_a, cell_b]) turned into moving gates.
var gate_edges: Array = []
var rng: RandomNumberGenerator = null


func _init(level: LevelConfig, random: RandomNumberGenerator) -> void:
	cols = level.columns | 1
	rows = level.rows | 1
	cell_size = level.cell_size
	rng = random
	east.resize(cols * rows)
	south.resize(cols * rows)


func generate(level: LevelConfig) -> void:
	match level.layout:
		LevelConfig.Layout.CLASSIC:
			_generate_classic(level)
		LevelConfig.Layout.ROOMS:
			_generate_classic(level)
			_carve_rooms(level)
		LevelConfig.Layout.RINGS:
			_generate_rings()
	_carve_center_plaza()
	_ensure_connected()
	_pick_gates(level)


## Flat index of cell (i, j).
func idx(i: int, j: int) -> int:
	return i + j * cols


func center() -> Vector2i:
	return Vector2i(cols / 2, rows / 2)


func ring_of(c: Vector2i) -> int:
	var center: Vector2i = center()
	return maxi(absi(c.x - center.x), absi(c.y - center.y))


func cell_pos(c: Vector2i) -> Vector3:
	var center: Vector2i = center()
	return Vector3((c.x - center.x) * cell_size, 0.0, (c.y - center.y) * cell_size)


func in_grid(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows


## True if a wall separates two orthogonally adjacent cells.
func wall_between(a: Vector2i, b: Vector2i) -> bool:
	if a.x != b.x:
		return east[idx(mini(a.x, b.x), a.y)] == 1
	return south[idx(a.x, mini(a.y, b.y))] == 1


func set_wall(a: Vector2i, b: Vector2i, value: bool) -> void:
	var v: int = 1 if value else 0
	if a.x != b.x:
		east[idx(mini(a.x, b.x), a.y)] = v
	else:
		south[idx(a.x, mini(a.y, b.y))] = v


func neighbors(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		if in_grid(c + d):
			out.append(c + d)
	return out


## Every interior edge as [cell_a, cell_b] (each edge listed once).
func interior_edges() -> Array:
	var edges: Array = []
	for j: int in rows:
		for i: int in cols:
			if i + 1 < cols:
				edges.append([Vector2i(i, j), Vector2i(i + 1, j)])
			if j + 1 < rows:
				edges.append([Vector2i(i, j), Vector2i(i, j + 1)])
	return edges


func wall_count(c: Vector2i) -> int:
	var walls: int = 4 - neighbors(c).size()  # perimeter sides
	for n: Vector2i in neighbors(c):
		if wall_between(c, n):
			walls += 1
	return walls


## Recursive-backtracker perfect maze, then random walls removed to add loops.
func _generate_classic(level: LevelConfig) -> void:
	east.fill(1)
	south.fill(1)
	var visited: Dictionary = {}
	var stack: Array[Vector2i] = [center()]
	visited[center()] = true
	while not stack.is_empty():
		var current: Vector2i = stack.back()
		var options: Array[Vector2i] = []
		for n: Vector2i in neighbors(current):
			if not visited.has(n):
				options.append(n)
		if options.is_empty():
			stack.pop_back()
			continue
		var next: Vector2i = options[rng.randi() % options.size()]
		set_wall(current, next, false)
		visited[next] = true
		stack.append(next)

	for edge: Array in interior_edges():
		if wall_between(edge[0], edge[1]) and rng.randf() < level.loop_chance:
			set_wall(edge[0], edge[1], false)


## Clears all walls inside a few random rectangles to create plazas.
func _carve_rooms(level: LevelConfig) -> void:
	for _r: int in level.room_count:
		var w: int = rng.randi_range(ROOM_MIN_SIDE, ROOM_MAX_SIDE)
		var h: int = rng.randi_range(ROOM_MIN_SIDE, ROOM_MAX_SIDE)
		var x0: int = rng.randi_range(1, cols - w - 1)
		var y0: int = rng.randi_range(1, rows - h - 1)
		_clear_rect(x0, y0, w, h)


func _carve_center_plaza() -> void:
	var c: Vector2i = center()
	var size: int = CENTER_PLAZA_RADIUS * 2 + 1
	_clear_rect(c.x - CENTER_PLAZA_RADIUS, c.y - CENTER_PLAZA_RADIUS, size, size)


func _clear_rect(x0: int, y0: int, w: int, h: int) -> void:
	for j: int in range(y0, y0 + h):
		for i: int in range(x0, x0 + w):
			var c: Vector2i = Vector2i(i, j)
			if i + 1 < x0 + w:
				set_wall(c, c + Vector2i.RIGHT, false)
			if j + 1 < y0 + h:
				set_wall(c, c + Vector2i.DOWN, false)


## Concentric square rings around the center, each with a few gaps, plus a
## couple of radial walls per corridor so it is not just a racetrack.
func _generate_rings() -> void:
	east.fill(0)
	south.fill(0)
	var boundaries: Dictionary = {}  # ring k → edges between ring k and k+1
	var corridors: Dictionary = {}   # ring k → edges inside ring k
	for edge: Array in interior_edges():
		var ra: int = ring_of(edge[0])
		var rb: int = ring_of(edge[1])
		if ra != rb:
			var k: int = mini(ra, rb)
			if k >= 1:
				set_wall(edge[0], edge[1], true)
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
			set_wall(edges[g][0], edges[g][1], false)

	for k: int in corridors:
		var edges: Array = corridors[k]
		edges.shuffle()
		for g: int in mini(1 + k / 3, edges.size()):
			set_wall(edges[g][0], edges[g][1], true)


## Flood fill from the center; knock down walls until every cell is reachable.
func _ensure_connected() -> void:
	var reached: Dictionary = {}
	var frontier: Array[Vector2i] = [center()]
	reached[center()] = true
	while true:
		while not frontier.is_empty():
			var c: Vector2i = frontier.pop_back()
			for n: Vector2i in neighbors(c):
				if not reached.has(n) and not wall_between(c, n):
					reached[n] = true
					frontier.append(n)
		if reached.size() == cols * rows:
			return
		var candidates: Array = []
		for c: Vector2i in reached:
			for n: Vector2i in neighbors(c):
				if not reached.has(n):
					candidates.append([c, n])
		var pick: Array = candidates[rng.randi() % candidates.size()]
		set_wall(pick[0], pick[1], false)
		reached[pick[1]] = true
		frontier.append(pick[1])


## Any interior wall can become a gate: the maze is already connected without
## them, so a closed gate only ever blocks a shortcut.
func _pick_gates(level: LevelConfig) -> void:
	var walls: Array = []
	for edge: Array in interior_edges():
		if wall_between(edge[0], edge[1]):
			walls.append(edge)
	walls.shuffle()
	gate_edges = walls.slice(0, mini(level.gate_count, walls.size()))
	for edge: Array in gate_edges:
		set_wall(edge[0], edge[1], false)
