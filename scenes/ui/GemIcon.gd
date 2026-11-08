## GemIcon.gd
## A gem drawn in 2D (crown + pavilion with lit and shaded facets), in the
## colour of a gem tier, or in rainbow facets for the Chaos Gem. Used by the guide.
extends Control
class_name GemIcon

const CROWN_HEIGHT: float = 0.32
const TABLE_WIDTH: float = 0.5
const LIGHT: float = 0.35
const SHADE: float = 0.3
const OUTLINE: Color = Color(0.1, 0.06, 0.15)
const OUTLINE_WIDTH: float = 2.0
const RAINBOW_STEP: float = 1.0 / 7.0

var color: Color = Color.WHITE
var rainbow: bool = false


static func create(gem_color: Color, side: float, is_rainbow: bool = false) -> GemIcon:
	var icon: GemIcon = GemIcon.new()
	icon.color = gem_color
	icon.rainbow = is_rainbow
	icon.custom_minimum_size = Vector2.ONE * side
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return icon


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var top: float = h * 0.12
	var girdle: float = top + h * CROWN_HEIGHT
	var left: Vector2 = Vector2(0.0, girdle)
	var right: Vector2 = Vector2(w, girdle)
	var table_l: Vector2 = Vector2(w * (0.5 - TABLE_WIDTH * 0.5), top)
	var table_r: Vector2 = Vector2(w * (0.5 + TABLE_WIDTH * 0.5), top)
	var mid: Vector2 = Vector2(w * 0.5, girdle)
	var tip: Vector2 = Vector2(w * 0.5, h * 0.95)
	var facets: Array[PackedVector2Array] = [
		PackedVector2Array([left, table_l, mid]),
		PackedVector2Array([table_l, table_r, mid]),
		PackedVector2Array([table_r, right, mid]),
		PackedVector2Array([left, mid, tip]),
		PackedVector2Array([mid, right, tip]),
	]
	var tones: Array[Color] = [
		color.lightened(LIGHT * 0.5), color.lightened(LIGHT), color, color.darkened(SHADE * 0.5), color.darkened(SHADE),
	]
	for n: int in facets.size():
		var fill: Color = Color.from_hsv(n * RAINBOW_STEP * 1.4, 0.75, 1.0) if rainbow else tones[n]
		draw_colored_polygon(facets[n], fill)
	draw_polyline(PackedVector2Array([left, table_l, table_r, right, tip, left]), OUTLINE, OUTLINE_WIDTH, true)
	draw_line(left, right, OUTLINE, OUTLINE_WIDTH * 0.5, true)
