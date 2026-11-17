## PlayerBot.gd
## Plays a hunter with no human behind it. It walks the maze (shortest path on
## the MazeGrid) to the nearest gem or gift box, jumps when stuck or next to a
## rival, cracks the ice when frozen and fires items and the superpower when a
## rival is close. It steers through the hunter's own input actions, so speed,
## debuffs and stuns apply to it exactly as to a human.
## Added as a child of the bot's Player by SplitScreenManager.
extends Node
class_name PlayerBot

## Seconds between two looks around for a better goal.
const THINK_INTERVAL: float = 0.5
## Stick deflection: bots run a little slower than a human at full tilt.
const RUN_STRENGTH: float = 0.85
const TURN_SPEED: float = 9.0
## A path cell counts as reached within this fraction of a cell.
const CELL_REACHED: float = 0.35
## Moving less than STUCK_DISTANCE in STUCK_TIME means stuck: jump, then
## wander to a random cell for WANDER_TIME (a closed gate, a prop in the way).
const STUCK_TIME: float = 1.0
const STUCK_DISTANCE: float = 0.4
const WANDER_TIME: float = 3.0
## The golden gem looks this many times closer than it is.
const GOLDEN_PULL: float = 3.0
## Rivals within these ranges get an item / a jump on the head.
const ATTACK_RANGE: float = 8.0
const JUMP_RANGE: float = 2.5
const ITEM_DELAY_MIN: float = 2.0
const ITEM_DELAY_MAX: float = 6.0

var level: MazeLevel = null

@onready var player: Player = get_parent()

var _goal: Vector3 = Vector3.ZERO
var _path: Array[Vector2i] = []
var _think_in: float = 0.0
var _item_in: float = ITEM_DELAY_MAX
var _wander_until: float = 0.0
var _stuck_clock: float = 0.0
var _stuck_from: Vector3 = Vector3.ZERO


func _exit_tree() -> void:
	_run(0.0)


func _physics_process(delta: float) -> void:
	if not player.controls_enabled or not GameManager.is_alive(player.player_id):
		_run(0.0)
		return
	_think_in -= delta
	if _think_in <= 0.0:
		_think_in = THINK_INTERVAL
		_think()
	_check_stuck(delta)
	_use_items(delta)
	_steer(delta)


# ─── Deciding ─────────────────────────────────────────────────────────────

func _think() -> void:
	if player.status.has(Constants.DebuffType.FROZEN):
		player.jump()  # Cracks the ice.
	var rival: Player = _nearest_rival()
	if rival and _flat_distance(rival.global_position) < JUMP_RANGE and player.is_on_floor():
		player.jump()
	if GameManager.game_time() >= _wander_until:
		_goal = _pick_goal()
	_path = [] if _is_outside() else level.grid.path(level.grid.cell_at(player.global_position), level.grid.cell_at(_goal))


## Outside the walls: the return pad. Otherwise the nearest thing worth
## grabbing, or a random cell when there is nothing.
func _pick_goal() -> Vector3:
	var best: Vector3 = _random_cell()
	var best_distance: float = INF
	for node: Node in get_tree().get_nodes_in_group(Constants.GROUP_PROPS if _is_outside() else Constants.GROUP_PICKUPS):
		var distance: float = _worth(node)
		if distance < best_distance:
			best_distance = distance
			best = (node as Node3D).global_position
	if not _is_outside() and player.items.has_free_slot():
		for node: Node in get_tree().get_nodes_in_group(Constants.GROUP_SURPRISE_BOXES):
			# Boxes leave the group while they respawn.
			var distance: float = _flat_distance((node as Node3D).global_position)
			if distance < best_distance:
				best_distance = distance
				best = (node as Node3D).global_position
	return best


## How far [param node] feels (INF = not worth going to).
func _worth(node: Node) -> float:
	var distance: float = _flat_distance((node as Node3D).global_position)
	if _is_outside():
		var pad: Trampoline = node as Trampoline
		return distance if pad and pad.aimed else INF
	var gem: GemCollectible = node as GemCollectible
	if gem == null:
		return distance  # Loose gem or Chaos Gem.
	if gem.is_golden:
		return distance / GOLDEN_PULL
	if gem.gem_type == Constants.GemType.LIFE and GameManager.has_max_lives(player.player_id):
		return INF
	if gem.color_index in GameManager.get_collection(player.player_id):
		return INF
	return distance


func _random_cell() -> Vector3:
	return level.grid.cell_pos(Vector2i(randi() % level.grid.cols, randi() % level.grid.rows))


func _check_stuck(delta: float) -> void:
	_stuck_clock += delta
	if _stuck_clock < STUCK_TIME:
		return
	if _flat_distance(_stuck_from) < STUCK_DISTANCE and not player.status.has(Constants.DebuffType.FROZEN):
		player.jump()
		_goal = _random_cell()
		_wander_until = GameManager.game_time() + WANDER_TIME
		_think_in = 0.0
	_stuck_clock = 0.0
	_stuck_from = player.global_position


func _use_items(delta: float) -> void:
	_item_in -= delta
	var rival: Player = _nearest_rival()
	if _item_in > 0.0 or rival == null or _flat_distance(rival.global_position) > ATTACK_RANGE:
		return
	_item_in = randf_range(ITEM_DELAY_MIN, ITEM_DELAY_MAX)
	if player.items.super_ready_in() <= 0.0:
		player.items.use_superpower()
	else:
		player.items.use_item(randi() % Constants.ITEM_SLOT_COUNT)


# ─── Moving ───────────────────────────────────────────────────────────────

## Turns toward the next path cell (or straight to the goal once in its cell)
## and runs forward.
func _steer(delta: float) -> void:
	var grid: MazeGrid = level.grid
	while not _path.is_empty() and _flat_distance(grid.cell_pos(_path[0])) < grid.cell_size * CELL_REACHED:
		_path.pop_front()
	var to: Vector3 = (grid.cell_pos(_path[0]) if _path.size() > 1 else _goal) - player.global_position
	to.y = 0.0
	if to.length() < 0.1:
		_run(0.0)
		return
	player.rotation.y = rotate_toward(player.rotation.y, atan2(-to.x, -to.z), TURN_SPEED * delta)
	_run(RUN_STRENGTH)


func _run(strength: float) -> void:
	var action: String = "p%d_move_forward" % player.player_id
	if strength > 0.0:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _is_outside() -> bool:
	return MazeLevel.is_outside(player.global_position, level.config)


func _flat_distance(to: Vector3) -> float:
	return Vector2(to.x - player.global_position.x, to.z - player.global_position.z).length()


func _nearest_rival() -> Player:
	var nearest: Player = null
	for rival: Player in player.rivals():
		if GameManager.is_alive(rival.player_id) and (nearest == null \
				or _flat_distance(rival.global_position) < _flat_distance(nearest.global_position)):
			nearest = rival
	return nearest
