## PlayerLook.gd
## Where a hunter looks: stick, mouse and touch look (inverted / wobbling under
## debuffs), the first/third-person camera view, and P1's mouse buttons
## (wheel arms a slot, left click fires it, right click jumps).
## Child node "Look" of Player.
extends Node
class_name PlayerLook

## The camera switched between first-person (true) and third-person view.
signal view_changed(player_id: int, first_person: bool)

## Third-person camera sits slightly right of the head, over the shoulder.
const SHOULDER_OFFSET: float = 0.6
const LAUGH_YAW_FREQUENCY_SCALE: float = 0.5

@onready var player: Player = get_parent()
@onready var _camera_origin: Node3D = $"../CameraOrigin"
@onready var _spring_arm: SpringArm3D = $"../CameraOrigin/SpringArm3D"

var first_person: bool = false
var _uses_mouse: bool = false
var _laugh_time: float = 0.0


func setup() -> void:
	# Never let the camera arm collide with its own body.
	_spring_arm.add_excluded_object(player.get_rid())
	_camera_origin.rotation.x = deg_to_rad(Constants.CAMERA_START_PITCH_DEG)


## P1 without a pad plays with the mouse: capture it while controls are on.
func set_controls_enabled(enabled: bool) -> void:
	_uses_mouse = player.player_id == 0 and InputManager.player_joypad_map.get(0, -1) < 0 \
		and not InputManager.touch_active
	if _uses_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if enabled else Input.MOUSE_MODE_VISIBLE
		player.items.selection_changed.emit(player.player_id, player.items.selected_slot)


## Switches between the over-the-shoulder camera and the character's eyes.
func toggle_view() -> void:
	first_person = not first_person
	_spring_arm.spring_length = 0.0 if first_person else Constants.CAMERA_TP_DISTANCE
	_spring_arm.position.x = 0.0 if first_person else SHOULDER_OFFSET
	_camera_origin.position.y = Constants.CAMERA_FP_HEIGHT if first_person else Constants.CAMERA_TP_HEIGHT
	_apply_look(Vector2.ZERO)  # Re-clamp pitch to the new view's limits.
	view_changed.emit(player.player_id, first_person)


## Per physics frame while the hunter has control: right-stick look.
func update(delta: float) -> void:
	var look: Vector2 = player.stick("look_left", "look_right", "look_up", "look_down")
	if player.status.has(Constants.DebuffType.INVERTED):
		look = -look
	look *= Constants.JOYSTICK_SENSITIVITY * delta
	if player.status.has(Constants.DebuffType.LAUGHING):
		_laugh_time += delta
		var wobble: float = deg_to_rad(Constants.CAMERA_LAUGHING_AMPLITUDE) * delta
		look.y += sin(_laugh_time * Constants.CAMERA_LAUGHING_FREQUENCY) * wobble
		look.x += cos(_laugh_time * Constants.CAMERA_LAUGHING_FREQUENCY * LAUGH_YAW_FREQUENCY_SCALE) * wobble
	_apply_look(look)


func _unhandled_input(event: InputEvent) -> void:
	if not player.controls_enabled or not _uses_mouse:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look_by((event as InputEventMouseMotion).relative)
	elif event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			_handle_mouse_button(event.button_index)
		get_viewport().set_input_as_handled()


## Pointer look: a mouse move or a touch drag of [param pixels].
func look_by(pixels: Vector2) -> void:
	if player.status.has(Constants.DebuffType.FROZEN):
		return
	var look: Vector2 = pixels * Constants.MOUSE_SENSITIVITY
	_apply_look(-look if player.status.has(Constants.DebuffType.INVERTED) else look)


func _handle_mouse_button(button: MouseButton) -> void:
	match button:
		MOUSE_BUTTON_WHEEL_UP: player.items.cycle_selection(-1)
		MOUSE_BUTTON_WHEEL_DOWN: player.items.cycle_selection(1)
		MOUSE_BUTTON_LEFT:
			if not player.status.has(Constants.DebuffType.FROZEN):
				player.items.use_selected()
		MOUSE_BUTTON_RIGHT: player.jump()


## Yaw turns the whole body, pitch tilts the camera pivot.
func _apply_look(look: Vector2) -> void:
	player.rotate_y(-look.x)
	var min_deg: float = Constants.CAMERA_FP_MIN_DEG if first_person else Constants.CAMERA_VERTICAL_MIN_DEG
	var max_deg: float = Constants.CAMERA_FP_MAX_DEG if first_person else Constants.CAMERA_VERTICAL_MAX_DEG
	_camera_origin.rotation.x = clampf(_camera_origin.rotation.x - look.y, deg_to_rad(min_deg), deg_to_rad(max_deg))
