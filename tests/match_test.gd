## match_test.gd
## Base of the headless checks in tests/ (see tests/run.sh). A check extends
## this script, overrides _run_test(), calls expect() for each thing that must
## hold and ends with finish(). Run one with:
##   godot --headless --path . -s tests/test_<name>.gd
## These scripts compile before the autoloads exist, so they reach them through
## the tree and never name a project class.
extends SceneTree

const MATCH_SCENE: String = "res://scenes/main/Main.tscn"
const OK_MARK: String = "TEST OK"
const MATCH_SECONDS: int = 90
const SCENE_SETTLE_TIME: float = 1.0

var game: Node = null
var constants: Node = null
var input: Node = null
var _failures: int = 0


func _initialize() -> void:
	game = root.get_node("GameManager")
	constants = root.get_node("Constants")
	input = root.get_node("InputManager")
	_begin()


## The autoloads are in the tree but not ready yet: the check starts a frame later.
func _begin() -> void:
	await process_frame
	_run_test()


## Virtual: the check itself.
func _run_test() -> void:
	finish()


func expect(condition: bool, what: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAILED: " + what)


func finish() -> void:
	if _failures == 0:
		print(OK_MARK)
	quit(mini(_failures, 1))


func wait(seconds: float) -> void:
	await create_timer(seconds).timeout


## Starts a timed match and returns its hunters once play begins. Real
## gamepads are detached so a pad on the desk can't steer a test player.
func start_match(players: int, mode: int, bots: int, arena: int = 0) -> Array[Node]:
	game.configure(players, mode, MATCH_SECONDS, load(constants.LEVEL_CONFIGS[arena]), bots)
	change_scene_to_file(MATCH_SCENE)
	await wait(SCENE_SETTLE_TIME)
	for pid: int in input.player_joypad_map:
		input.player_joypad_map[pid] = -1
	input._apply()
	for selector: Node in root.find_children("*", "CharacterSelector", true, false):
		selector.lock_in()
	while not game.is_playing():
		await process_frame
	return get_nodes_in_group(constants.GROUP_PLAYERS)
