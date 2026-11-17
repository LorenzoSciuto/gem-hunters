## One human and three bots play a whole timed match: every bot keeps moving
## and the bots collect gems.
extends "res://tests/match_test.gd"

const BOTS: int = 3
const TIME_SCALE: float = 4.0
const SAMPLE_INTERVAL: float = 2.0
## A bot covers far more than this in a match unless it is stuck.
const MIN_DISTANCE: float = 60.0


func _run_test() -> void:
	var players: Array[Node] = await start_match(BOTS + 1, constants.MatchMode.TIME, BOTS)
	Engine.time_scale = TIME_SCALE
	var last: Array[Vector3] = []
	var travelled: Array[float] = []
	for player: Node3D in players:
		last.append(player.global_position)
		travelled.append(0.0)
	while game.is_playing():
		await wait(SAMPLE_INTERVAL)
		for i: int in players.size():
			var at: Vector3 = (players[i] as Node3D).global_position
			travelled[i] += last[i].distance_to(at)
			last[i] = at
	Engine.time_scale = 1.0

	var bot_gems: int = 0
	for i: int in range(1, players.size()):
		expect(game.is_bot(i), "player %d is a bot" % i)
		expect(travelled[i] > MIN_DISTANCE, "bot %d only moved %.0f m" % [i, travelled[i]])
		bot_gems += game.get_score(i)
	expect(not game.is_bot(0), "player 0 is human")
	expect(bot_gems > 0, "the bots collected no gems")
	finish()
