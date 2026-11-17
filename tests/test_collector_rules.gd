## Collector mode rules, straight on GameManager: one gem per colour, wild
## gems, one gem per hit, the golden gem's reset and win.
extends "res://tests/match_test.gd"


func _run_test() -> void:
	var colors: int = constants.COLLECT_COLORS.size()
	game.configure(2, constants.MatchMode.COLLECT, 1, null)
	game._set_state(constants.GameState.PLAYING)
	var completed: Array[int] = []
	var resets: Array[int] = []
	game.collection_completed.connect(func(pid: int) -> void: completed.append(pid))
	game.collections_reset.connect(func(pid: int) -> void: resets.append(pid))

	expect(game.add_gems(0, 1, true, 2) == 1, "a new colour is collected")
	expect(game.add_gems(0, 1, true, 2) == 0, "a colour already held adds nothing")
	expect(game.add_gems(0, 5, false) == 1, "a wild gem fills exactly one missing colour")
	expect(game.get_score(0) == 2 and game.get_collection(0).size() == 2, "the score mirrors the collection")
	expect(game.remove_gems(0, 3) == 1 and game.get_collection(0).size() == 1, "a hit costs one gem")

	for color: int in colors:
		game.add_gems(0, 1, true, color)
	expect(game.has_full_collection(0) and completed == [0], "a full collection is announced once")

	game.add_gems(1, 1, true, 0)
	game.take_golden_gem(1)
	expect(resets == [1] and game.get_score(0) == 0 and game.get_score(1) == 0 and game.is_playing(),
		"the golden gem in incomplete hands empties every collection")

	for color: int in colors:
		game.add_gems(0, 1, true, color)
		game.add_gems(1, 1, true, color)
	game.take_golden_gem(1)
	expect(not game.is_playing() and game.get_leader() == 1, "the golden gem wins for a full collection, alone")
	finish()
