## GemSpawner.gd
## Manages procedural, balanced spawning of collectible gems across the level.
## Uses Marker3D children as candidate spawn positions.
##
## Anti-clustering algorithm:
##   _find_valid_spawn_point() scores every candidate against existing live gems
##   and excludes any candidate within min_spawn_distance of an occupied point.
##   The remaining candidates are sampled with equal probability so gems spread
##   evenly across the arena.
##
## Golden gem:
##   At most one golden gem at a time, at the arena center: the first appears
##   GOLDEN_GEM_RESPAWN seconds into the match, and each one taken is replaced
##   after the same delay.
##
## Gems never spawn on top of props, gift boxes or traps (GEM_PROP_CLEARANCE).
##
## Chaos Gem: exactly once per match, part-way through (see CHAOS_*), at a
## random free gem spot; GameManager announces it to every HUD.
##
## Survival mode: fewer and rarer gems (traded for lives, see GEMS_PER_LIFE),
## a slower golden gem, no Chaos Gem, and a life gem every LIFE_GEM_INTERVAL.
extends Node3D

# ---------------------------------------------------------------------------
# Preloads
# ---------------------------------------------------------------------------
const GEM_SCENE: PackedScene = preload("res://scenes/gems/GemCollectible.tscn")


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
## Probability weights for value tiers. Must sum to 100.
const WEIGHT_VALUE_1: int = 70
const WEIGHT_VALUE_3: int = 20
const WEIGHT_VALUE_5: int = 10
const WEIGHT_TOTAL: int = WEIGHT_VALUE_1 + WEIGHT_VALUE_3 + WEIGHT_VALUE_5

const GOLDEN_GEM_VALUE: int = 10
## Seconds before the first golden gem, and between one being taken and the next.
const GOLDEN_GEM_RESPAWN: float = 45.0

## Chaos Gem timing: in a timed match it appears between these fractions of the
## clock; in a race to N gems, between these many seconds after the start.
const CHAOS_TIME_FRACTION_MIN: float = 0.35
const CHAOS_TIME_FRACTION_MAX: float = 0.6
const CHAOS_SCORE_DELAY_MIN: float = 40.0
const CHAOS_SCORE_DELAY_MAX: float = 70.0

## Fraction of max_gems_in_world placed at game start.
const INITIAL_FILL_FRACTION: float = 0.5

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------
@export var max_gems_in_world: int = Constants.MAX_GEMS_IN_WORLD
@export var spawn_interval: float = Constants.GEM_RESPAWN_TIME
@export var min_spawn_distance: float = Constants.MIN_GEM_SPAWN_DISTANCE

# ---------------------------------------------------------------------------
# Node references
# ---------------------------------------------------------------------------
## The Marker3D that defines the arena center — golden gem always spawns here.
@onready var golden_gem_marker: Marker3D = $GoldenGemMarker

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------
var _spawn_points: Array[Marker3D] = []
var _active_gems: Array[WeakRef] = []
var _golden_gem_active: bool = false
var _golden_scheduled: bool = false
var _golden_respawn: float = GOLDEN_GEM_RESPAWN
var _life_gems: Array[WeakRef] = []
var _spawn_timer: Timer

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	if GameManager.is_survival():
		max_gems_in_world = Constants.SURVIVAL_MAX_GEMS
		spawn_interval = Constants.SURVIVAL_GEM_RESPAWN
		_golden_respawn = Constants.SURVIVAL_GOLDEN_RESPAWN
	_collect_spawn_points()
	_create_spawn_timer()
	_initial_fill()
	GameManager.state_changed.connect(_on_state_changed)


## The golden gem's clock starts with the match (not during character selection).
func _on_state_changed(state: int) -> void:
	if state == Constants.GameState.PLAYING and not _golden_scheduled:
		_golden_scheduled = true
		_schedule_golden_gem()
		if GameManager.is_survival():
			_run_life_gems()
		else:
			_schedule_chaos_gem()


func _schedule_chaos_gem() -> void:
	var delay: float = randf_range(CHAOS_SCORE_DELAY_MIN, CHAOS_SCORE_DELAY_MAX)
	if GameManager.match_mode == Constants.MatchMode.TIME:
		delay = GameManager.match_target * randf_range(CHAOS_TIME_FRACTION_MIN, CHAOS_TIME_FRACTION_MAX)
	await get_tree().create_timer(delay, false).timeout
	if not is_inside_tree() or not GameManager.is_playing():
		return
	var point: Marker3D = _find_valid_spawn_point()
	if point == null:
		point = _spawn_points.pick_random()
	if point == null:
		return
	var chaos: ChaosGem = ChaosGem.new()
	add_child(chaos)
	chaos.global_position = Vector3(point.global_position.x, 0.0, point.global_position.z)
	GameManager.chaos_gem_appeared.emit()


## Survival: a life gem appears every LIFE_GEM_INTERVAL (one at a time).
func _run_life_gems() -> void:
	while is_inside_tree():
		await get_tree().create_timer(Constants.LIFE_GEM_INTERVAL, false).timeout
		if not is_inside_tree() or not GameManager.is_playing():
			return
		_life_gems = _life_gems.filter(func(w: WeakRef) -> bool: return w.get_ref() != null)
		if _life_gems.size() >= Constants.LIFE_GEMS_MAX:
			continue
		var point: Marker3D = _find_valid_spawn_point()
		if point == null:
			continue
		var gem: GemCollectible = GEM_SCENE.instantiate() as GemCollectible
		gem.gem_type = Constants.GemType.LIFE
		gem.value = 0
		add_child(gem)
		gem.global_position = point.global_position
		_life_gems.append(weakref(gem))


func _schedule_golden_gem() -> void:
	await get_tree().create_timer(_golden_respawn, false).timeout
	if is_inside_tree():
		_spawn_golden_gem()


## Gather all Marker3D candidate points (direct children and level gem spawn group).
func _collect_spawn_points() -> void:
	for child: Node in get_children():
		if child is Marker3D and child != golden_gem_marker:
			_spawn_points.append(child as Marker3D)

	for node: Node in get_tree().get_nodes_in_group(Constants.GROUP_GEM_SPAWNS):
		if node is Marker3D and not _spawn_points.has(node):
			_spawn_points.append(node as Marker3D)

	if _spawn_points.is_empty():
		push_warning("GemSpawner: no Marker3D spawn points found — no gems will spawn.")



## Create and start the repeating Timer node.
func _create_spawn_timer() -> void:
	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = spawn_interval
	_spawn_timer.autostart = true
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(_spawn_timer)


# ---------------------------------------------------------------------------
# Filling logic
# ---------------------------------------------------------------------------

## Place roughly half the maximum gem count on match start.
func _initial_fill() -> void:
	var target: int = int(max_gems_in_world * INITIAL_FILL_FRACTION)
	for _i: int in range(target):
		_try_spawn_gem()


# ---------------------------------------------------------------------------
# Timer callback
# ---------------------------------------------------------------------------

func _on_spawn_timer_timeout() -> void:
	_try_spawn_gem()


# ---------------------------------------------------------------------------
# Spawn pipeline
# ---------------------------------------------------------------------------

## Attempt to place one new gem. Skips silently if at capacity or no valid point.
func _try_spawn_gem() -> void:
	_clean_dead_refs()

	if _active_gems.size() >= max_gems_in_world:
		return

	var point: Marker3D = _find_valid_spawn_point()
	if not point:
		return

	var gem_value: int = _pick_gem_value()
	var gem: GemCollectible = GEM_SCENE.instantiate() as GemCollectible
	gem.value = gem_value
	gem.gem_type = _value_to_gem_type(gem_value)
	add_child(gem)
	gem.global_position = point.global_position

	_active_gems.append(weakref(gem))


## Return a spawn Marker3D that is at least min_spawn_distance away from all
## existing live gems. Returns null if no valid candidate exists.
func _find_valid_spawn_point() -> Marker3D:
	# Build list of positions of currently active gems.
	var occupied_positions: Array[Vector3] = []
	for wr: WeakRef in _active_gems:
		var gem: Object = wr.get_ref()
		if gem and gem is Node3D:
			occupied_positions.append((gem as Node3D).global_position)

	var props: Array[Vector3] = []
	for group: String in [Constants.GROUP_PROPS, Constants.GROUP_SURPRISE_BOXES, Constants.GROUP_TRAPS]:
		for node: Node in get_tree().get_nodes_in_group(group):
			props.append((node as Node3D).global_position)

	# Filter candidates.
	var valid_points: Array[Marker3D] = []
	for point: Marker3D in _spawn_points:
		var too_close: bool = false
		for pos: Vector3 in occupied_positions:
			if point.global_position.distance_to(pos) < min_spawn_distance:
				too_close = true
				break
		for pos: Vector3 in props:
			var flat: Vector3 = point.global_position - pos
			if Vector2(flat.x, flat.z).length() < Constants.GEM_PROP_CLEARANCE:
				too_close = true
				break
		if not too_close:
			valid_points.append(point)

	if valid_points.is_empty():
		return null

	# Uniform random selection among valid candidates.
	return valid_points[randi() % valid_points.size()]


## Weighted random gem value: 70% → 1pt, 20% → 3pt, 10% → 5pt.
func _pick_gem_value() -> int:
	var roll: int = randi() % WEIGHT_TOTAL
	if roll < WEIGHT_VALUE_1:
		return 1
	elif roll < WEIGHT_VALUE_1 + WEIGHT_VALUE_3:
		return 3
	return 5


## Map a gem point-value to its GemType enum variant.
func _value_to_gem_type(gem_value: int) -> Constants.GemType:
	match gem_value:
		1:
			return Constants.GemType.STANDARD
		3:
			return Constants.GemType.RARE
		5:
			return Constants.GemType.EPIC
		_:
			return Constants.GemType.STANDARD


# ---------------------------------------------------------------------------
# Golden gem
# ---------------------------------------------------------------------------

## Instantiate the unique golden gem at the arena center marker.
func _spawn_golden_gem() -> void:
	if _golden_gem_active:
		return
	if not golden_gem_marker:
		push_warning("GemSpawner: GoldenGemMarker not found — skipping golden gem.")
		return

	_golden_gem_active = true
	var golden_gem: GemCollectible = GEM_SCENE.instantiate() as GemCollectible
	golden_gem.is_golden = true
	golden_gem.value = GOLDEN_GEM_VALUE
	golden_gem.gem_type = Constants.GemType.GOLDEN
	add_child(golden_gem)
	golden_gem.global_position = golden_gem_marker.global_position
	golden_gem.collected.connect(_on_golden_gem_collected)


## Called when the golden gem is picked up. Re-spawns after GOLDEN_GEM_RESPAWN seconds.
func _on_golden_gem_collected(_player_id: int, _gem_value: int) -> void:
	_golden_gem_active = false
	_schedule_golden_gem()


# ---------------------------------------------------------------------------
# Housekeeping
# ---------------------------------------------------------------------------

## Remove expired WeakRefs from _active_gems to keep the list accurate.
func _clean_dead_refs() -> void:
	var alive: Array[WeakRef] = []
	for wr: WeakRef in _active_gems:
		if wr.get_ref() != null:
			alive.append(wr)
	_active_gems = alive
