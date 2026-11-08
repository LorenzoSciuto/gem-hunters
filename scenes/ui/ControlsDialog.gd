## ControlsDialog.gd
## Main-menu controls table: one column per input scheme (P1 keyboard, gamepads),
## the fixed controls first (move, look, pause; not rebindable, shown dimmed),
## then one row per button action. Pick a cell, then press the new
## key / mouse button / pad button; Escape cancels. Works with mouse, keyboard
## and gamepad navigation.
extends Control

const ACTION_KEYS: Dictionary = {
	"jump": "ACTION_JUMP", "item_1": "ACTION_ITEM_1",
	"item_2": "ACTION_ITEM_2", "item_3": "ACTION_ITEM_3", "super": "ACTION_SUPER",
	"toggle_view": "ACTION_VIEW",
}
const HEADER_KEYS: Array[String] = ["", "UI_SCHEME_P1", "UI_SCHEME_PAD"]
## Fixed controls: [action key, keyboard key, gamepad key].
const FIXED_ROWS: Array = [
	["ACTION_MOVE", "UI_KEYS_MOVE", "UI_PAD_MOVE"],
	["ACTION_LOOK", "UI_KEYS_LOOK", "UI_PAD_LOOK"],
	["ACTION_PAUSE", "UI_KEYS_PAUSE", "UI_PAD_PAUSE"],
]
const KEYBOARD_COLUMN: int = 0
const PAD_COLUMN: int = 1
const CELL_WIDTH: float = 190.0

@onready var grid: GridContainer = $Center/Panel/VBox/Grid
@onready var reset_btn: Button = $Center/Panel/VBox/Buttons/ResetButton

## Cell waiting for input, or null.
var _capturing: Button = null
var _capture_action: String = ""
var _capture_column: int = -1
var _cells: Dictionary = {}  # Button → [action, column]


func _ready() -> void:
	add_child(ModalFocus.new())
	grid.columns = HEADER_KEYS.size()
	for key: String in HEADER_KEYS:
		var header: Label = Label.new()
		header.theme_type_variation = &"HeadingLabel"
		header.text = key
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(header)
	for row: Array in FIXED_ROWS:
		for n: int in row.size():
			var label: Label = Label.new()
			label.text = row[n]
			label.theme_type_variation = &"" if n == 0 else &"SubtleLabel"
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if n == 0 else HORIZONTAL_ALIGNMENT_CENTER
			grid.add_child(label)
	for action: String in InputManager.BUTTON_ACTIONS:
		var name_label: Label = Label.new()
		name_label.text = ACTION_KEYS[action]
		grid.add_child(name_label)
		for column: int in [KEYBOARD_COLUMN, PAD_COLUMN]:
			var cell: Button = Button.new()
			cell.custom_minimum_size.x = CELL_WIDTH
			cell.pressed.connect(_start_capture.bind(cell, action, column))
			grid.add_child(cell)
			_cells[cell] = [action, column]
	reset_btn.pressed.connect(InputManager.reset_bindings)
	InputManager.bindings_changed.connect(refresh)
	refresh()


func refresh() -> void:
	for cell: Button in _cells:
		var action: String = _cells[cell][0]
		var column: int = _cells[cell][1]
		cell.text = InputManager.pad_text(action) if column == PAD_COLUMN else InputManager.key_text(action)


func _start_capture(cell: Button, action: String, column: int) -> void:
	_capturing = cell
	_capture_action = action
	_capture_column = column
	cell.text = tr("UI_PRESS_KEY")


## While capturing, the next matching press becomes the binding and never
## reaches menu navigation.
func _input(event: InputEvent) -> void:
	if _capturing == null or not event.is_pressed() or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	var cancel: bool = event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_ESCAPE
	if _capture_column == PAD_COLUMN and event is InputEventJoypadButton:
		InputManager.set_pad_binding(_capture_action, (event as InputEventJoypadButton).button_index)
	elif _capture_column == KEYBOARD_COLUMN and InputManager.is_keyboard_bindable(event):
		InputManager.set_key_binding(_capture_action, event)
	elif not cancel:
		return  # Wrong device for this column: keep waiting.
	var cell: Button = _capturing
	_capturing = null
	refresh()
	cell.grab_focus()
