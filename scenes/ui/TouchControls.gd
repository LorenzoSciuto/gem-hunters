## TouchControls.gd
## On-screen controls for P1 on a touch screen, over the whole match view:
##   left half   - a stick that appears under the thumb (move)
##   right half  - drag to look around
##   bottom right - the HUD's item pad, moved under the right thumb, enlarged
##                  and made tappable, with the jump button beside it
##   top centre  - pause
## The stick and the jump button press P1's own input actions, so the hunter
## code is the same as with a keyboard or a pad.
## SplitScreenManager adds it once InputManager.touch_active is set.
extends CanvasLayer
class_name TouchControls

signal pause_requested

const STICK_RADIUS: float = 120.0
const KNOB_RADIUS: float = 52.0
## Where the idle stick is drawn, from the bottom-left corner.
const STICK_REST: Vector2 = Vector2(230.0, 250.0)
const JUMP_RADIUS: float = 95.0
## The jump button sits this far left of the item pad and above the bottom edge.
const JUMP_GAP: float = 30.0
const JUMP_BOTTOM: float = 140.0
## The item pad grows to finger size and keeps this margin from the corner.
const PAD_SCALE: float = 1.6
const PAD_MARGIN: int = 24
const PAUSE_SIZE: Vector2 = Vector2(90.0, 64.0)
const PAUSE_TOP: float = 16.0
const FILL: Color = Color(1.0, 1.0, 1.0, 0.18)
const KNOB: Color = Color(1.0, 1.0, 1.0, 0.45)
const OUTLINE: Color = Color(1.0, 1.0, 1.0, 0.6)
const OUTLINE_WIDTH: float = 4.0
const NO_TOUCH: int = -1

var player: Player = null
## P1's item pad. shortcut: its place on screen is read as if P1's view filled
## the window, true for one human; a split-screen touch match needs a transform.
var item_pad: ItemPad = null

var _canvas: Control = null
var _jump: TouchScreenButton = null
var _pause: Button = null
var _stick_touch: int = NO_TOUCH
var _stick_origin: Vector2 = Vector2.ZERO
var _stick: Vector2 = Vector2.ZERO
var _look_touch: int = NO_TOUCH


func _ready() -> void:
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_controls)
	add_child(_canvas)

	_jump = TouchScreenButton.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = JUMP_RADIUS
	_jump.shape = circle
	_jump.action = _action("jump")
	add_child(_jump)

	_pause = Button.new()
	_pause.text = "II"
	_pause.focus_mode = Control.FOCUS_NONE
	_pause.size = PAUSE_SIZE
	_pause.pressed.connect(pause_requested.emit)
	add_child(_pause)

	item_pad.make_touchable()
	item_pad.pivot_offset = item_pad.size
	item_pad.scale = Vector2.ONE * PAD_SCALE
	item_pad.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_KEEP_SIZE, PAD_MARGIN)

	get_viewport().size_changed.connect(_layout)
	_layout()


func _exit_tree() -> void:
	_set_stick(Vector2.ZERO)


func _layout() -> void:
	var screen: Vector2 = _screen()
	_jump.position = _jump_center()
	_pause.position = Vector2((screen.x - PAUSE_SIZE.x) * 0.5, PAUSE_TOP)
	_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if not touch.pressed:
			_release(touch.index)
		elif _on_button(touch.position):
			pass  # The buttons handle their own touches.
		elif touch.position.x < _screen().x * 0.5:
			if _stick_touch == NO_TOUCH:
				_stick_touch = touch.index
				_stick_origin = touch.position
				_canvas.queue_redraw()
		elif _look_touch == NO_TOUCH:
			_look_touch = touch.index
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if drag.index == _stick_touch:
			_set_stick(((drag.position - _stick_origin) / STICK_RADIUS).limit_length(1.0))
		elif drag.index == _look_touch and player.controls_enabled:
			player.look.look_by(drag.relative)


func _release(index: int) -> void:
	if index == _stick_touch:
		_stick_touch = NO_TOUCH
		_set_stick(Vector2.ZERO)
	elif index == _look_touch:
		_look_touch = NO_TOUCH


## Presses P1's move actions as far as the stick is pushed.
func _set_stick(value: Vector2) -> void:
	_stick = value
	_press("move_left", -value.x)
	_press("move_right", value.x)
	_press("move_forward", -value.y)
	_press("move_back", value.y)
	if _canvas:
		_canvas.queue_redraw()


func _press(action: String, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(_action(action), strength)
	else:
		Input.action_release(_action(action))


func _action(action: String) -> String:
	return InputManager.action_name(InputManager.KEYBOARD_PLAYER, action)


func _screen() -> Vector2:
	return get_viewport().get_visible_rect().size


func _pad_rect() -> Rect2:
	var size: Vector2 = item_pad.size * PAD_SCALE
	return Rect2(_screen() - size - Vector2.ONE * PAD_MARGIN, size)


func _jump_center() -> Vector2:
	return Vector2(_pad_rect().position.x - JUMP_GAP - JUMP_RADIUS, _screen().y - JUMP_BOTTOM)


func _on_button(pos: Vector2) -> bool:
	return _pad_rect().has_point(pos) or pos.distance_to(_jump_center()) <= JUMP_RADIUS


func _draw_controls() -> void:
	var screen: Vector2 = _screen()
	var base: Vector2 = _stick_origin if _stick_touch != NO_TOUCH else Vector2(STICK_REST.x, screen.y - STICK_REST.y)
	_draw_button(base, STICK_RADIUS)
	_canvas.draw_circle(base + _stick * STICK_RADIUS, KNOB_RADIUS, KNOB)
	_draw_button(_jump_center(), JUMP_RADIUS)
	var text: String = tr("ACTION_JUMP")
	var font: Font = Constants.DISPLAY_FONT
	var font_size: int = int(JUMP_RADIUS * 0.38)
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	_canvas.draw_string(font, _jump_center() + Vector2(-text_size.x * 0.5, text_size.y * 0.3), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, OUTLINE)


func _draw_button(center: Vector2, radius: float) -> void:
	_canvas.draw_circle(center, radius, FILL)
	_canvas.draw_arc(center, radius, 0.0, TAU, 48, OUTLINE, OUTLINE_WIDTH, true)
