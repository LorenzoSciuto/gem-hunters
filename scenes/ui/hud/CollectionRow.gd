## CollectionRow.gd
## Collector mode: one gem per colour to collect, bright when this hunter
## holds it and faded when it is still missing.
extends HBoxContainer
class_name CollectionRow

const GEM_SIZE: float = 30.0
const MISSING_ALPHA: float = 0.2

var player_id: int = 0


func setup(pid: int) -> void:
	player_id = pid
	for color: Color in Constants.COLLECT_COLORS:
		add_child(GemIcon.create(color, GEM_SIZE))
	GameManager.score_updated.connect(func(changed: int, _score: int) -> void:
		if changed == player_id:
			_refresh())
	_refresh()


func _refresh() -> void:
	var held: Array = GameManager.get_collection(player_id)
	for index: int in get_child_count():
		(get_child(index) as GemIcon).modulate.a = 1.0 if index in held else MISSING_ALPHA
