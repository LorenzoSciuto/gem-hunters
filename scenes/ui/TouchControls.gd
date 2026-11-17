## TouchControls.gd
## On-screen controls for P1 on a touch screen, over the whole match view:
##   left half   - a stick that appears under the thumb (move)
##   right half  - a second stick (look around), like a pad's right stick
##   bottom right - the HUD's item pad, moved under the right thumb, enlarged
##                  and made tappable, with the jump button beside it
##   top right   - pause, under the clock
## The sticks and the jump button press P1's own input actions, so the hunter
## code is the same as with a keyboard or a pad.
## SplitScreenManager adds it once InputManager.touch_active is set.
extends CanvasLayer
class_name TouchControls

signal pause_requested

## Sizes are in canvas pixels, which ScreenLayout already enlarges on a phone.
const STICK_RADIUS: float = 105.0
const KNOB_RADIUS: float = 46.0
## Where the idle move stick is drawn, from the bottom-left corner.
const STICK_REST: Vector2 = Vector2(130.0, 190.0)
## The idle look stick sits this far above the item pad.
const LOOK_STICK_GAP: float = 24.0
const JUMP_RADIUS: float = 70.0
## The jump button sits this far left of the item pad and above the bottom edge.
const JUMP_GAP: float = 20.0
const JUMP_BOTTOM: float = 110.0
## The item pad grows a little and keeps this margin from the corner.
const PAD_SCALE: float = 1.2
const PAD_MARGIN: int = 16
const PAUSE_SIZE: Vector2 = Vector2(90.0, 64.0)
## Pause button, from the top-right corner: just under the clock.
const PAUSE_OFFSET: Vector2 = Vector2(16.0, 104.0)
const FILL: Color = Color(1.0, 1.0, 1.0, 0.18)
const KNOB: Color = Color(1.0, 1.0, 1.0, 0.45)
const OUTLINE: Color = Color(1.0, 1.0, 1.0, 0.6)
const OUTLINE_WIDTH: float = 4.0
const NO_TOUCH: int = -1


## One stick: the finger holding it, where that finger landed, how far it is
## pushed (length 0..1) and the four P1 actions it presses.
class Stick:
	var touch: int = NO_TOUCH
	var origin: Vector2 = Vector2.ZERO
	var value: Vector2 = Vector2.ZERO
	var left: String
	var right: String
	var up: String
	var down: String

	func _init(left_action: String, right_action: String, up_action: String, down_action: String) -> void:
		left = left_action
		right = right_action
		up = up_action
		down = down_action


## P1's item pad. shortcut: its place on screen is read as if P1's view filled
## the window, true for one human; a split-screen touch match needs a transform.
var item_pad: ItemPad = null

var _canvas: Control = null
var _jump: TouchScreenButton = null
var _pause: Button = null
var _move: Stick = Stick.new("move_left", "move_right", "move_forward", "move_back")
var _look: Stick = Stick.new("look_left", "look_right", "look_up", "look_down")
var _sticks: Array[Stick] = [_move, _look]


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
	for stick: Stick in _sticks:
		_set_stick(stick, Vector2.ZERO)


func _layout() -> void:
	var screen: Vector2 = _screen()
	_jump.position = _jump_center()
	_pause.position = Vector2(screen.x - PAUSE_SIZE.x - PAUSE_OFFSET.x, PAUSE_OFFSET.y)
	_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if not touch.pressed:
			_release(touch.index)
		elif not _on_button(touch.position):  # The buttons handle their own touches.
			var stick: Stick = _move if touch.position.x < _screen().x * 0.5 else _look
			if stick.touch == NO_TOUCH:
				stick.touch = touch.index
				stick.origin = touch.position
				_canvas.queue_redraw()
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		for stick: Stick in _sticks:
			if drag.index == stick.touch:
				_set_stick(stick, ((drag.position - stick.origin) / STICK_RADIUS).limit_length(1.0))


func _release(index: int) -> void:
	for stick: Stick in _sticks:
		if index == stick.touch:
			stick.touch = NO_TOUCH
			_set_stick(stick, Vector2.ZERO)


## Presses the stick's actions as far as it is pushed.
func _set_stick(stick: Stick, value: Vector2) -> void:
	stick.value = value
	_press(stick.left, -value.x)
	_press(stick.right, value.x)
	_press(stick.up, -value.y)
	_press(stick.down, value.y)
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


## Where a stick is drawn: under its finger, or at rest (move in the bottom-left
## corner, look above the item pad).
func _stick_base(stick: Stick) -> Vector2:
	if stick.touch != NO_TOUCH:
		return stick.origin
	if stick == _move:
		return Vector2(STICK_REST.x, _screen().y - STICK_REST.y)
	var pad: Rect2 = _pad_rect()
	return Vector2(pad.get_center().x, pad.position.y - LOOK_STICK_GAP - STICK_RADIUS)


func _on_button(pos: Vector2) -> bool:
	return _pad_rect().has_point(pos) or pos.distance_to(_jump_center()) <= JUMP_RADIUS


func _draw_controls() -> void:
	for stick: Stick in _sticks:
		var base: Vector2 = _stick_base(stick)
		_draw_button(base, STICK_RADIUS)
		_canvas.draw_circle(base + stick.value * STICK_RADIUS, KNOB_RADIUS, KNOB)
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
