## MiniMap.gd
## Top-down arena map with a dot per hunter (this player's dot is bigger),
## faded in for a few seconds by the radar item or a map beacon.
extends PanelContainer
class_name MiniMap

const DOT_RADIUS: float = 9.0
const OWN_DOT_SCALE: float = 1.5
const DOT_OUTLINE: float = 2.0
const FADE: float = 0.3

@onready var _camera: Camera3D = $View/SubViewport/Camera
@onready var _dots: Control = $Dots

var player_id: int = 0
var _tween: Tween = null


func setup(pid: int, arena_size: float) -> void:
	player_id = pid
	_camera.frame_arena(arena_size)
	_dots.draw.connect(_draw_dots)


func show_for(duration: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	visible = true
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, FADE)
	_tween.tween_interval(duration)
	_tween.tween_property(self, "modulate:a", 0.0, FADE)
	_tween.tween_callback(hide)


func _process(_delta: float) -> void:
	if visible:
		_dots.queue_redraw()


func _draw_dots() -> void:
	var to_panel: Vector2 = _dots.size / Vector2(_camera.get_viewport().size)
	for node: Node in get_tree().get_nodes_in_group(Constants.GROUP_PLAYERS):
		var player: Player = node as Player
		var at: Vector2 = _camera.unproject_position(player.global_position) * to_panel
		var radius: float = DOT_RADIUS * (OWN_DOT_SCALE if player.player_id == player_id else 1.0)
		_dots.draw_circle(at, radius + DOT_OUTLINE, Color.BLACK)
		_dots.draw_circle(at, radius, Constants.PLAYER_COLORS[player.player_id])
