## ControlsDialog.gd
## Main-menu controls table: one column for P1's keyboard and one per connected
## gamepad (each pad model keeps its own layout), the fixed controls first
## (move, look, pause; not rebindable, shown dimmed), then one row per button
## action. Pick a cell, then press the new key / mouse button / button on that
## same pad; Escape cancels. Works with mouse, keyboard
## and gamepad navigation.
extends Control

const ACTION_KEYS: Dictionary = {
	"jump": "ACTION_JUMP", "item_1": "ACTION_ITEM_1",
	"item_2": "ACTION_ITEM_2", "item_3": "ACTION_ITEM_3", "super": "ACTION_SUPER",
	"toggle_view": "ACTION_VIEW",
}
## Fixed controls: [action key, keyboard key, gamepad key].
const FIXED_ROWS: Array = [
	["ACTION_MOVE", "UI_KEYS_MOVE", "UI_PAD_MOVE"],
	["ACTION_LOOK", "UI_KEYS_LOOK", "UI_PAD_LOOK"],
	["ACTION_PAUSE", "UI_KEYS_PAUSE", "UI_PAD_PAUSE"],
]
## Column device for the keyboard; pad columns use the pad's device id.
const KEYBOARD: int = -1
const CELL_WIDTH: float = 190.0

@onready var grid: GridContainer = $Center/Panel/VBox/Grid
@onready var reset_btn: Button = $Center/Panel/VBox/Buttons/ResetButton

## Cell waiting for input, or null.
var _capturing: Button = null
var _capture_action: String = ""
var _capture_device: int = KEYBOARD
var _cells: Dictionary = {}  # Button → [action, device]


func _ready() -> void:
	add_child(ModalFocus.new())
	reset_btn.pressed.connect(InputManager.reset_bindings)
	InputManager.bindings_changed.connect(refresh)
	InputManager.gamepad_connected.connect(func(_id: int, _name: String) -> void: _rebuild())
	InputManager.gamepad_disconnected.connect(func(_id: int) -> void: _rebuild())
	_rebuild()


## One column for the keyboard, then one per connected pad (each its own layout).
func _rebuild() -> void:
	_capturing = null
	_cells.clear()
	for child: Node in grid.get_children():
		child.queue_free()
	var devices: Array[int] = [KEYBOARD]
	devices.append_array(Input.get_connected_joypads())
	grid.columns = devices.size() + 1
	_add_label("", &"HeadingLabel")
	for device: int in devices:
		_add_label(tr("UI_SCHEME_P1") if device == KEYBOARD else InputManager.pad_name(device), &"HeadingLabel")
	for row: Array in FIXED_ROWS:
		_add_label(row[0], &"", HORIZONTAL_ALIGNMENT_LEFT)
		for device: int in devices:
			_add_label(row[1] if device == KEYBOARD else row[2], &"SubtleLabel")
	for action: String in InputManager.BUTTON_ACTIONS:
		_add_label(ACTION_KEYS[action], &"", HORIZONTAL_ALIGNMENT_LEFT)
		for device: int in devices:
			var cell: Button = Button.new()
			cell.custom_minimum_size.x = CELL_WIDTH
			cell.pressed.connect(_start_capture.bind(cell, action, device))
			grid.add_child(cell)
			_cells[cell] = [action, device]
	refresh()


func _add_label(text: String, variation: StringName, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var label: Label = Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.horizontal_alignment = align
	grid.add_child(label)


func refresh() -> void:
	for cell: Button in _cells:
		var action: String = _cells[cell][0]
		var device: int = _cells[cell][1]
		cell.text = InputManager.key_text(action) if device == KEYBOARD else InputManager.pad_text(action, device)


func _start_capture(cell: Button, action: String, device: int) -> void:
	_capturing = cell
	_capture_action = action
	_capture_device = device
	cell.text = tr("UI_PRESS_KEY")


## While capturing, the next matching press becomes the binding and never
## reaches menu navigation. A pad column only listens to its own pad.
func _input(event: InputEvent) -> void:
	if _capturing == null or not event.is_pressed() or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	var cancel: bool = event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_ESCAPE
	if _capture_device != KEYBOARD and event is InputEventJoypadButton and event.device == _capture_device:
		InputManager.set_pad_binding(_capture_device, _capture_action, (event as InputEventJoypadButton).button_index)
	elif _capture_device == KEYBOARD and InputManager.is_keyboard_bindable(event):
		InputManager.set_key_binding(_capture_action, event)
	elif not cancel:
		return  # Wrong device for this column: keep waiting.
	var cell: Button = _capturing
	_capturing = null
	refresh()
	cell.grab_focus()
