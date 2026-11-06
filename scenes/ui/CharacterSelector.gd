## CharacterSelector.gd
## Per-quadrant character selection: each player browses archetypes with their
## own device and locks in independently.
##   Keyboard: the player's move left / right keys browse, jump locks in
##   (P0 also browses with the mouse wheel and locks with a click).
##   Gamepad: stick / D-pad to browse, A or Start to lock.
extends Control

signal character_locked(player_id: int, data: CharacterData)
signal character_previewed(player_id: int, data: CharacterData)

const CHARACTERS: Array[CharacterData] = [
	preload("res://resources/characters/dashy.tres"),
	preload("res://resources/characters/bouncer.tres"),
	preload("res://resources/characters/tanky.tres"),
	preload("res://resources/characters/tricky.tres"),
]

## Stick deflection that counts as one browse step; it must return below the
## release threshold before the next step, so holding the stick doesn't spin.
const STICK_PRESS: float = 0.6
const STICK_RELEASE: float = 0.3
## Keep the panel inside small (4-player) quadrants.
const FIT_MARGIN: float = 0.95

@onready var panel: PanelContainer = $Panel
@onready var player_title: Label = $Panel/VBox/PlayerTitle
@onready var preview_rig: Node3D = $Panel/VBox/CharacterPreview3D/SubViewport/PreviewRig
@onready var prev_btn: Button = $Panel/VBox/NameRow/PrevButton
@onready var next_btn: Button = $Panel/VBox/NameRow/NextButton
@onready var char_name: Label = $Panel/VBox/NameRow/CharName
@onready var char_bio: Label = $Panel/VBox/CharBio
@onready var char_trait: Label = $Panel/VBox/CharTrait
@onready var char_super: Label = $Panel/VBox/CharSuper
@onready var speed_bar: ProgressBar = $Panel/VBox/Stats/SpeedBar
@onready var jump_bar: ProgressBar = $Panel/VBox/Stats/JumpBar
@onready var defense_bar: ProgressBar = $Panel/VBox/Stats/DefenseBar
@onready var prompt_label: Label = $Panel/VBox/PromptLabel
@onready var ready_badge: Label = $Panel/VBox/ReadyBadge

var player_id: int = 0
var _index: int = 0
var _is_locked: bool = false
var _stick_latched: bool = false


func _ready() -> void:
	prev_btn.pressed.connect(_cycle.bind(-1))
	next_btn.pressed.connect(_cycle.bind(1))
	resized.connect(_fit_panel)
	panel.resized.connect(_fit_panel)


func setup(pid: int, color: Color, preselected: CharacterData = null) -> void:
	player_id = pid
	player_title.text = "%s  %s" % [tr("UI_PLAYER_SHORT").format([pid + 1]), tr("UI_SELECT_HERO")]
	player_title.modulate = color
	_index = CHARACTERS.find(preselected) if preselected else pid % CHARACTERS.size()
	if _index < 0:
		_index = 0
	if InputManager.has_pad(pid) or not InputManager.has_keyboard(pid):
		prompt_label.text = tr("UI_PROMPT_PAD")
	else:
		prompt_label.text = tr("UI_PROMPT_KB").format([InputManager.key_text(pid, "move_left"),
			InputManager.key_text(pid, "move_right"), InputManager.key_text(pid, "jump")])
	_update_display()


## Centers the panel in the quadrant and shrinks it to fit small (4-player) ones.
func _fit_panel() -> void:
	panel.size = Vector2.ZERO  # snap back to the content's minimum size
	var fit: Vector2 = size * FIT_MARGIN / panel.size.max(Vector2.ONE)
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2.ONE * minf(1.0, minf(fit.x, fit.y))
	panel.position = (size - panel.size) * 0.5


func _unhandled_input(event: InputEvent) -> void:
	if _is_locked:
		return
	var step: int = 0
	var lock: bool = false
	var joy: int = InputManager.player_joypad_map.get(player_id, -1)

	if joy >= 0:
		if event is InputEventJoypadButton and event.pressed and event.device == joy:
			match event.button_index:
				JOY_BUTTON_DPAD_LEFT: step = -1
				JOY_BUTTON_DPAD_RIGHT: step = 1
				JOY_BUTTON_A, JOY_BUTTON_START: lock = true
		elif event is InputEventJoypadMotion and event.device == joy and event.axis == JOY_AXIS_LEFT_X:
			if not _stick_latched and absf(event.axis_value) > STICK_PRESS:
				_stick_latched = true
				step = 1 if event.axis_value > 0.0 else -1
			elif absf(event.axis_value) < STICK_RELEASE:
				_stick_latched = false
	# Keyboard keeps working alongside a pad, as it does in game.
	if event is InputEventKey and not event.is_echo():
		if event.is_action_pressed(_action("move_left")): step = -1
		elif event.is_action_pressed(_action("move_right")): step = 1
		elif event.is_action_pressed(_action("jump")): lock = true
	elif player_id == 0 and event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP: step = -1
			MOUSE_BUTTON_WHEEL_DOWN: step = 1
			MOUSE_BUTTON_LEFT: lock = true

	if step != 0:
		_cycle(step)
	if lock:
		lock_in()
	if step != 0 or lock:
		get_viewport().set_input_as_handled()


func _action(name: String) -> String:
	return "p%d_%s" % [player_id, name]


func _cycle(dir: int) -> void:
	if _is_locked:
		return
	_index = posmod(_index + dir, CHARACTERS.size())
	AudioManager.play_sfx(AudioManager.SoundEffect.TIMER_TICK)
	_update_display()


func _update_display() -> void:
	var c: CharacterData = CHARACTERS[_index]
	char_name.text = tr(c.name_key)
	char_name.modulate = c.color
	char_bio.text = tr(c.bio_key)
	char_trait.text = tr(c.trait_key)
	var super_key: String = CharacterData.SUPER_KEYS.get(c.trait_type, "")
	char_super.text = "%s: %s" % [tr(super_key), tr(super_key + "_DESC")] if super_key else ""
	speed_bar.value = c.stat_speed
	jump_bar.value = c.stat_jump
	defense_bar.value = c.stat_defense
	preview_rig.set_character(c)
	character_previewed.emit(player_id, c)


func lock_in() -> void:
	if _is_locked:
		return
	_is_locked = true
	preview_rig.play_lock_animation()
	ready_badge.visible = true
	prompt_label.visible = false
	prev_btn.disabled = true
	next_btn.disabled = true
	AudioManager.play_sfx(AudioManager.SoundEffect.POWERUP_GRAB)
	character_locked.emit(player_id, CHARACTERS[_index])
