## LivesRow.gd
## Survival mode: one heart per life (a "+N" after HEARTS_SHOWN), redrawn and
## pulsed whenever this hunter's lives change.
extends Control
class_name LivesRow

const HEART_SIZE: float = 26.0
const HEART_GAP: float = 6.0
const HEART_COLOR: Color = Color(1.0, 0.32, 0.45)
const HEART_OUTLINE: Color = Color(0.25, 0.04, 0.1)
const HEART_OUTLINE_WIDTH: float = 2.0
const HEARTS_SHOWN: int = 5
const HEART_POINTS: int = 28
## The parametric heart curve spans about this many units across.
const CURVE_SPAN: float = 34.0
const EXTRA_TEXT_BASELINE: float = 0.85
const EXTRA_TEXT_SIZE: float = 0.9

var player_id: int = 0


func setup(pid: int) -> void:
	player_id = pid
	custom_minimum_size = Vector2((HEART_SIZE + HEART_GAP) * (HEARTS_SHOWN + 1), HEART_SIZE)
	GameManager.lives_changed.connect(func(changed: int, _lives: int) -> void:
		if changed == player_id:
			queue_redraw()
			UiMotion.pulse(self))


func _draw() -> void:
	var count: int = GameManager.get_lives(player_id)
	for n: int in mini(count, HEARTS_SHOWN):
		_draw_heart(Vector2(n * (HEART_SIZE + HEART_GAP) + HEART_SIZE * 0.5, HEART_SIZE * 0.5))
	if count > HEARTS_SHOWN:
		draw_string(get_theme_font(&"font", &"Label"),
			Vector2(HEARTS_SHOWN * (HEART_SIZE + HEART_GAP), HEART_SIZE * EXTRA_TEXT_BASELINE),
			"+%d" % (count - HEARTS_SHOWN), HORIZONTAL_ALIGNMENT_LEFT, -1, int(HEART_SIZE * EXTRA_TEXT_SIZE), HEART_COLOR)


## Classic parametric heart curve, scaled to HEART_SIZE.
func _draw_heart(center: Vector2) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var unit: float = HEART_SIZE / CURVE_SPAN
	for n: int in HEART_POINTS:
		var t: float = TAU * n / HEART_POINTS
		var x: float = 16.0 * pow(sin(t), 3)
		var y: float = -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		points.append(center + Vector2(x, y) * unit)
	draw_colored_polygon(points, HEART_COLOR)
	points.append(points[0])
	draw_polyline(points, HEART_OUTLINE, HEART_OUTLINE_WIDTH, true)
