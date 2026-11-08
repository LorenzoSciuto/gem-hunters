## Scoreboard.gd
## Live standings + clock shown in the spare viewport in 3-player mode.
## Each row is a ScoreRow instance exposing set_data(rank, player_id, name, gems).
extends CenterContainer

@export var timer_label: Label
@export var row_container: VBoxContainer
@export var row_scene: PackedScene


func _ready() -> void:
	GameManager.score_updated.connect(func(_pid: int, _score: int) -> void: _refresh_rows())
	GameManager.lives_changed.connect(func(_pid: int, _lives: int) -> void: _refresh_rows())
	GameManager.timer_updated.connect(_on_timer_updated)
	_refresh_rows()


## Rows are created once and updated in place so frequent score changes don't churn nodes.
func _refresh_rows() -> void:
	var standings: Array = GameManager.get_standings()
	while row_container.get_child_count() < standings.size():
		row_container.add_child(row_scene.instantiate())
	for i: int in standings.size():
		var pid: int = standings[i]["player_id"]
		var row: Node = row_container.get_child(i)
		row.set_data(i + 1, pid, tr("UI_PLAYER_SHORT").format([pid + 1]), standings[i]["score"])
		if GameManager.is_survival():
			var lives: int = standings[i]["lives"]
			row.set_note(tr("UI_LIVES_N").format([lives]) if lives > 0 else tr("UI_KNOCKED_OUT"))


func _on_timer_updated(seconds: float) -> void:
	timer_label.text = GameManager.clock_text(seconds)
