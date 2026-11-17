## InputManager.gd
## Autoload that owns every per-player p{N}_* input action.
##
## One keyboard scheme (P0 = WASD + mouse; everyone else plays with a pad) and
## one button layout per gamepad model (keyed by its GUID, so a pad finds its
## layout again when plugged back in; a new model starts from the default
## layout). The button actions can be rebound from the Controls menu; changes
## are saved to user://controls.cfg.
##
## Gamepads go to P1, P2, P3 in connection order, so a pad never changes player
## when another one is plugged in. Only a pad left over once every other player
## has one goes to P0 (which keeps the keyboard too).
extends Node

signal gamepad_connected(device_id: int, device_name: String)
signal gamepad_disconnected(device_id: int)
## A binding changed (rebind or reset); prompts showing keys should refresh.
signal bindings_changed

const SAVE_PATH: String = "user://controls.cfg"
## Saved-file section of the keyboard scheme (named from when P1 had one too).
const KEYBOARD_SECTION: String = "keyboard_0"
## Saved-file section of the default pad layout, and prefix of each model's own.
const PAD_SECTION: String = "gamepad"
const PAD_MODEL_PREFIX: String = "gamepad_"
## A pad's name is cut to this many characters in the Controls table.
const PAD_NAME_LENGTH: int = 18
const ACTION_DEADZONE: float = 0.2
## InputEvent device id that matches every device.
const ALL_DEVICES: int = -1

const MOVE_ACTIONS: Array[String] = [
	"move_left", "move_right", "move_forward", "move_back",
	"look_left", "look_right", "look_up", "look_down",
]
## Actions the player can rebind, in menu order.
const BUTTON_ACTIONS: Array[String] = [
	"jump", "item_1", "item_2", "item_3", "super", "toggle_view",
]
## Item slot actions, in slot order.
const ITEM_ACTIONS: Array[String] = ["item_1", "item_2", "item_3"]

## The keyboard player.
const KEYBOARD_PLAYER: int = 0
## Keyboard scheme: physical keycode, or -mouse_button for mouse buttons.
const KEYBOARD_DEFAULTS: Dictionary = {
	"move_left": KEY_A, "move_right": KEY_D, "move_forward": KEY_W, "move_back": KEY_S,
	"look_left": KEY_J, "look_right": KEY_L, "look_up": KEY_I, "look_down": KEY_K,
	"jump": KEY_SPACE,
	"item_1": KEY_Q, "item_2": KEY_E, "item_3": KEY_R, "super": KEY_F, "toggle_view": KEY_V,
}
## Menu "back" key (character selection: unlock / leave).
const KEYBOARD_BACK_KEY: Key = KEY_ESCAPE
const PAD_BACK_BUTTON: JoyButton = JOY_BUTTON_B
## Gamepad layout: face buttons fire, shoulders jump.
const PAD_DEFAULTS: Dictionary = {
	"jump": JOY_BUTTON_RIGHT_SHOULDER,
	"item_1": JOY_BUTTON_X, "item_2": JOY_BUTTON_A, "item_3": JOY_BUTTON_B,
	"super": JOY_BUTTON_Y, "toggle_view": JOY_BUTTON_LEFT_SHOULDER,
}
## Saved-file version. v1 put the camera view on R3, which players click by
## accident while turning the camera; loading a v1 file moves it to the new default.
const SAVE_VERSION: int = 2
const LEGACY_VIEW_BUTTON: JoyButton = JOY_BUTTON_RIGHT_STICK
## The right trigger always doubles the jump button.
const PAD_TRIGGERS: Dictionary = {"jump": JOY_AXIS_TRIGGER_RIGHT}
const PAD_BUTTON_NAMES: Dictionary = {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_BACK: "Back", JOY_BUTTON_START: "Start", JOY_BUTTON_GUIDE: "Home",
	JOY_BUTTON_DPAD_UP: "INPUT_DPAD_UP", JOY_BUTTON_DPAD_DOWN: "INPUT_DPAD_DOWN",
	JOY_BUTTON_DPAD_LEFT: "INPUT_DPAD_LEFT", JOY_BUTTON_DPAD_RIGHT: "INPUT_DPAD_RIGHT",
}

## SDL mappings for pads missing from Godot's database (measured on real
## hardware). Unknown pads report raw button numbers, so their layout is scrambled.
const EXTRA_PAD_MAPPINGS: Array[String] = [
	"03000000790000000600000010010000,DragonRise Generic USB Joystick,a:b2,b:b1,x:b3,y:b0,leftshoulder:b6,rightshoulder:b7,lefttrigger:b4,righttrigger:b5,back:b9,start:b8,leftstick:b10,rightstick:b11,leftx:a0,lefty:a1,rightx:a3,righty:a4,dpup:h0.1,dpright:h0.2,dpdown:h0.4,dpleft:h0.8,platform:Linux,",
]

## player_id → joypad device id (-1 = keyboard only).
var player_joypad_map: Dictionary = {}
## True once the screen has been touched (phone, tablet): the match then shows
## TouchControls for P1, who stops using the mouse.
var touch_active: bool = false

var _keyboard: Dictionary = {}
## Default layout for pad models without their own (and the HUD of a padless player).
var _pad: Dictionary = {}
## Pad GUID → its own layout.
var _pad_models: Dictionary = {}


func _ready() -> void:
	for mapping: String in EXTRA_PAD_MAPPINGS:
		Input.add_joy_mapping(mapping, true)
	_add_menu_pad_buttons()
	_reset_to_defaults()
	_load()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	auto_configure_devices()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		touch_active = true


## Godot's ui_accept / ui_cancel only know the keyboard; menus need the pad too.
func _add_menu_pad_buttons() -> void:
	for pair: Array in [["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B]]:
		var ev: InputEventJoypadButton = InputEventJoypadButton.new()
		ev.device = ALL_DEVICES
		ev.button_index = pair[1]
		InputMap.action_add_event(pair[0], ev)


func auto_configure_devices() -> void:
	var pads: Array[int] = Input.get_connected_joypads()
	var players: int = GameManager.get_num_humans()
	for pid: int in Constants.MAX_PLAYERS:
		# Pad i drives player (i + 1) % players: P1..P(n-1) first, P0 last.
		var pad_index: int = (pid + players - 1) % players
		player_joypad_map[pid] = pads[pad_index] if pid < players and pad_index < pads.size() else -1
	_apply()


func get_connected_names() -> Array[String]:
	var names: Array[String] = []
	for id: int in Input.get_connected_joypads():
		names.append(Input.get_joy_name(id))
	return names


func has_pad(player_id: int) -> bool:
	return player_joypad_map.get(player_id, -1) >= 0


func has_keyboard(player_id: int) -> bool:
	return player_id == KEYBOARD_PLAYER


# ─── Bindings ─────────────────────────────────────────────────────────────

## Display text of a keyboard binding.
func key_text(action: String) -> String:
	var code: int = _keyboard[action]
	if code < 0:
		return _translated("INPUT_MOUSE_%d" % -code, tr("INPUT_MOUSE_BUTTON").format([-code]))
	return _key_name(DisplayServer.keyboard_get_keycode_from_physical(code))


## Display text of the menu "back" key.
func back_key_text() -> String:
	return _key_name(KEYBOARD_BACK_KEY)


## The OS name of a key; the named ones the game shows (Space, Escape, arrows...)
## have an INPUT_KEY_* translation.
func _key_name(keycode: Key) -> String:
	var name: String = OS.get_keycode_string(keycode)
	return _translated("INPUT_KEY_" + name.to_upper(), name)


## [param key] translated, or [param fallback] when the table has no such key.
func _translated(key: String, fallback: String) -> String:
	var text: String = tr(key)
	return fallback if text == key else text


## Button for [param action] on pad [param device] (-1: the default layout).
func pad_text(action: String, device: int = -1) -> String:
	var button: int = _layout(device)[action]
	if PAD_BUTTON_NAMES.has(button):
		return tr(PAD_BUTTON_NAMES[button])
	return tr("INPUT_PAD_BUTTON").format([button])


## A connected pad's name, short enough for a table header.
static func pad_name(device: int) -> String:
	var name: String = " ".join(Input.get_joy_name(device).split(" ", false))  # Some pads pad their name with spaces.
	return name if name.length() <= PAD_NAME_LENGTH else name.left(PAD_NAME_LENGTH - 1) + "."


## What to press for [param action], as shown to [param player_id] in the HUD.
func prompt_text(player_id: int, action: String) -> String:
	if has_pad(player_id) or not has_keyboard(player_id):
		return pad_text(action, player_joypad_map.get(player_id, -1))
	return key_text(action)


## Rebinds a keyboard action to a key or mouse button. An action already using
## that input takes over the old one, so nothing is lost.
func set_key_binding(action: String, event: InputEvent) -> void:
	_swap_into(_keyboard, action, _event_code(event))
	_save_and_apply()


## Rebinds [param action] on pad [param device]'s model only.
func set_pad_binding(device: int, action: String, button: JoyButton) -> void:
	_swap_into(_layout(device, true), action, button)
	_save_and_apply()


## The layout pad [param device] uses: its model's own, else the default. With
## [param own], the model gets its own copy first (so a rebind stays on it).
func _layout(device: int, own: bool = false) -> Dictionary:
	if device < 0:
		return _pad
	var guid: String = Input.get_joy_guid(device)
	if own and not _pad_models.has(guid):
		_pad_models[guid] = _pad.duplicate()
	return _pad_models.get(guid, _pad)


func reset_bindings() -> void:
	_reset_to_defaults()
	_save_and_apply()


## True if [param event] can be bound on the keyboard scheme.
static func is_keyboard_bindable(event: InputEvent) -> bool:
	return (event is InputEventKey and (event as InputEventKey).physical_keycode != KEY_ESCAPE) \
		or event is InputEventMouseButton


static func _event_code(event: InputEvent) -> int:
	if event is InputEventMouseButton:
		return -(event as InputEventMouseButton).button_index
	return (event as InputEventKey).physical_keycode


static func _swap_into(map: Dictionary, action: String, value: int) -> void:
	for other: String in map:
		if other != action and map[other] == value:
			map[other] = map[action]
	map[action] = value


func _reset_to_defaults() -> void:
	_keyboard = KEYBOARD_DEFAULTS.duplicate()
	_pad = PAD_DEFAULTS.duplicate()
	_pad_models.clear()


func _save_and_apply() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	for action: String in BUTTON_ACTIONS:
		cfg.set_value(KEYBOARD_SECTION, action, _keyboard[action])
		cfg.set_value(PAD_SECTION, action, _pad[action])
		for guid: String in _pad_models:
			cfg.set_value(PAD_MODEL_PREFIX + guid, action, _pad_models[guid][action])
	cfg.set_value("meta", "version", SAVE_VERSION)
	cfg.save(SAVE_PATH)
	_apply()
	bindings_changed.emit()


func _load() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for action: String in BUTTON_ACTIONS:
		_keyboard[action] = int(cfg.get_value(KEYBOARD_SECTION, action, _keyboard[action]))
		_pad[action] = int(cfg.get_value(PAD_SECTION, action, _pad[action]))
	for section: String in cfg.get_sections():
		if section.begins_with(PAD_MODEL_PREFIX):
			var layout: Dictionary = _pad.duplicate()
			for action: String in BUTTON_ACTIONS:
				layout[action] = int(cfg.get_value(section, action, layout[action]))
			_pad_models[section.trim_prefix(PAD_MODEL_PREFIX)] = layout
	if int(cfg.get_value("meta", "version", 1)) < SAVE_VERSION and _pad["toggle_view"] == LEGACY_VIEW_BUTTON:
		_swap_into(_pad, "toggle_view", PAD_DEFAULTS["toggle_view"])
		_save_and_apply()  # Re-saves as the current version.


## The InputMap action of [param action] ("jump", "move_left"...) for one player.
func action_name(player_id: int, action: String) -> String:
	return "p%d_%s" % [player_id, action]


## Rebuilds every p{N}_* action from the keyboard scheme and assigned pads.
func _apply() -> void:
	for pid: int in Constants.MAX_PLAYERS:
		var joy: int = player_joypad_map.get(pid, -1)
		for action: String in MOVE_ACTIONS + BUTTON_ACTIONS:
			var name: String = action_name(pid, action)
			if not InputMap.has_action(name):
				InputMap.add_action(name, ACTION_DEADZONE)
			InputMap.action_erase_events(name)
			if has_keyboard(pid):
				InputMap.action_add_event(name, _keyboard_event(_keyboard[action]))
			if joy >= 0:
				_bind_pad_action(name, action, joy)


func _keyboard_event(code: int) -> InputEvent:
	if code < 0:
		var mouse: InputEventMouseButton = InputEventMouseButton.new()
		mouse.device = ALL_DEVICES
		mouse.button_index = -code as MouseButton
		return mouse
	var key: InputEventKey = InputEventKey.new()
	key.device = ALL_DEVICES
	key.physical_keycode = code as Key
	return key


func _bind_pad_action(name: String, action: String, joy: int) -> void:
	match action:
		"move_left": _add_motion(name, joy, JOY_AXIS_LEFT_X, -1.0, JOY_BUTTON_DPAD_LEFT)
		"move_right": _add_motion(name, joy, JOY_AXIS_LEFT_X, 1.0, JOY_BUTTON_DPAD_RIGHT)
		"move_forward": _add_motion(name, joy, JOY_AXIS_LEFT_Y, -1.0, JOY_BUTTON_DPAD_UP)
		"move_back": _add_motion(name, joy, JOY_AXIS_LEFT_Y, 1.0, JOY_BUTTON_DPAD_DOWN)
		"look_left": _add_motion(name, joy, JOY_AXIS_RIGHT_X, -1.0)
		"look_right": _add_motion(name, joy, JOY_AXIS_RIGHT_X, 1.0)
		"look_up": _add_motion(name, joy, JOY_AXIS_RIGHT_Y, -1.0)
		"look_down": _add_motion(name, joy, JOY_AXIS_RIGHT_Y, 1.0)
		_:
			_add_button(name, joy, _layout(joy)[action])
			if PAD_TRIGGERS.has(action):
				_add_motion(name, joy, PAD_TRIGGERS[action], 1.0)


func _add_button(action: String, device: int, button: JoyButton) -> void:
	var ev: InputEventJoypadButton = InputEventJoypadButton.new()
	ev.device = device
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _add_motion(action: String, device: int, axis: JoyAxis, value: float, dpad: int = -1) -> void:
	var ev: InputEventJoypadMotion = InputEventJoypadMotion.new()
	ev.device = device
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)
	if dpad >= 0:
		_add_button(action, device, dpad as JoyButton)


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	auto_configure_devices()
	if connected:
		gamepad_connected.emit(device, Input.get_joy_name(device))
	else:
		gamepad_disconnected.emit(device)
