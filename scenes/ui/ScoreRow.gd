## ScoreRow.gd
## One row of the live Scoreboard: rank, player name, gem score.
extends HBoxContainer

@onready var rank_label: Label = $RankLabel
@onready var name_label: Label = $NameLabel
@onready var score_label: Label = $ScoreLabel


func set_data(rank: int, player_id: int, player_name: String, score: int) -> void:
	rank_label.text = "#%d" % rank
	name_label.text = player_name
	name_label.modulate = Constants.PLAYER_COLORS[player_id]
	score_label.text = "%d \u25c6" % score
