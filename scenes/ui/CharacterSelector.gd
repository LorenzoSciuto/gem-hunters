## CharacterSelector.gd
## Per-quadrant character selection: each player browses archetypes with their
## own device and locks in independently.
##   Keyboard: the player's move left / right keys browse, jump locks in
##   (P0 also browses with the mouse wheel and locks with a click).
##   Gamepad: stick / D-pad to browse, A or Start to lock.
##   Back (pad B, Esc or right click for P0, or the
##   on-screen button): unlocks a locked choice, otherwise leaves to the menu.
extends Control

signal character_locked(player_id: int, data: CharacterData)
signal character_previewed(player_id: int, data: CharacterData)
## A locked player changed their mind and is browsing again.
signal character_unlocked(player_id: int)
## Back pressed while browsing: leave character selection.
signal back_requested(player_id: int)

const CHARACTERS: Array[CharacterData] = [
	preload("res://resources/characters/dashy.tres"),
	preload("res://resources/characters/bouncer.tres"),
	preload("res://resources/characters/tanky.tres"),
	preload("res://resources/characters/tricky.tres"),
	preload("res://resources/characters/sparkle.tres"),
	preload("res://resources/characters/bloom.tres"),
	preload("res://resources/characters/mimi.tres"),
	preload("res://resources/characters/coco.tres"),
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
@onready var super_heading: Label = $Panel/VBox/SuperRow/SuperInfo/SuperHeading
@onready var super_icon: TextureRect = $Panel/VBox/SuperRow/SuperIcon
@onready var super_name: Label = $Panel/VBox/SuperRow/SuperInfo/SuperName
@onready var super_desc: Label = $Panel/VBox/SuperRow/SuperInfo/SuperDesc
@onready var speed_bar: ProgressBar = $Panel/VBox/Stats/SpeedBar
@onready var jump_bar: ProgressBar = $Panel/VBox/Stats/JumpBar
@onready var defense_bar: ProgressBar = $Panel/VBox/Stats/DefenseBar
@onready var prompt_label: Label = $Panel/VBox/PromptLabel
@onready var ready_badge: Label = $Panel/VBox/ReadyBadge
@onready var back_btn: Button = $Panel/VBox/BackButton

var player_id: int = 0
var _index: int = 0
var _is_locked: bool = false
var _stick_latched: bool = false
var _card_size: Vector2 = Vector2.ZERO


func _ready() -> void:
	prev_btn.pressed.connect(_cycle.bind(-1))
	next_btn.pressed.connect(_cycle.bind(1))
	back_btn.pressed.connect(_back)
	resized.connect(_fit_panel)
	panel.resized.connect(_fit_panel)


func setup(pid: int, color: Color, preselected: CharacterData = null) -> void:
	player_id = pid
	player_title.text = "%s  %s" % [tr("UI_PLAYER_SHORT").format([pid + 1]), tr("UI_SELECT_HERO")]
	player_title.modulate = color
	_index = CHARACTERS.find(preselected) if preselected else pid % CHARACTERS.size()
	if _index < 0:
		_index = 0
	_update_prompt()
	_update_display()


func _uses_pad() -> bool:
	return InputManager.has_pad(player_id) or not InputManager.has_keyboard(player_id)


func _update_prompt() -> void:
	super_heading.text = tr("UI_SUPER_PRESS").format([InputManager.prompt_text(player_id, "super")])
	if _uses_pad():
		prompt_label.text = tr("UI_PROMPT_PAD_LOCKED" if _is_locked else "UI_PROMPT_PAD")
	elif _is_locked:
		prompt_label.text = tr("UI_PROMPT_KB_LOCKED").format([InputManager.back_key_text()])
	else:
		prompt_label.text = tr("UI_PROMPT_KB").format([InputManager.key_text("move_left"),
			InputManager.key_text("move_right"), InputManager.key_text("jump"),
			InputManager.back_key_text()])
	back_btn.text = "UI_CHANGE" if _is_locked else "UI_BACK"


## Centers the card in the quadrant and shrinks it to fit small (4-player) ones.
## The card only ever grows (to the largest content seen), so locking in or
## browsing to a shorter description never makes it jump smaller.
func _fit_panel() -> void:
	_card_size = _card_size.max(panel.get_combined_minimum_size())
	panel.size = _card_size
	var fit: Vector2 = size * FIT_MARGIN / panel.size.max(Vector2.ONE)
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2.ONE * minf(1.0, minf(fit.x, fit.y))
	panel.position = (size - panel.size) * 0.5


func _unhandled_input(event: InputEvent) -> void:
	if _is_back_event(event):
		get_viewport().set_input_as_handled()  # Before _back(): leaving frees this scene.
		_back()
		return
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


func _is_back_event(event: InputEvent) -> bool:
	var joy: int = InputManager.player_joypad_map.get(player_id, -1)
	if event is InputEventJoypadButton:
		return event.pressed and event.device == joy and event.button_index == InputManager.PAD_BACK_BUTTON
	if event is InputEventKey:
		return event.pressed and not event.is_echo() and InputManager.has_keyboard(player_id) \
			and (event as InputEventKey).keycode == InputManager.KEYBOARD_BACK_KEY
	if event is InputEventMouseButton:
		return player_id == 0 and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT
	return false


## Locked: reopen the choice. Browsing: ask to leave character selection.
func _back() -> void:
	if not _is_locked:
		back_requested.emit(player_id)
		return
	_is_locked = false
	_show_ready_badge(false)
	prev_btn.disabled = false
	next_btn.disabled = false
	_update_prompt()
	AudioManager.play_sfx(AudioManager.SoundEffect.TIMER_TICK)
	character_unlocked.emit(player_id)


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
	var super_key: String = CharacterData.SUPER_KEYS[c.superpower]
	super_icon.texture = ItemCatalog.SUPER_ICONS[c.superpower]
	super_name.text = tr(super_key)
	super_desc.text = tr(super_key + "_DESC")
	speed_bar.value = c.stat_speed
	jump_bar.value = c.stat_jump
	defense_bar.value = c.stat_defense
	preview_rig.set_character(c)
	character_previewed.emit(player_id, c)


## The badge always keeps its space (only its opacity changes), so the card's
## layout doesn't move when a player locks in.
func _show_ready_badge(shown: bool) -> void:
	ready_badge.modulate.a = 1.0 if shown else 0.0


func lock_in() -> void:
	if _is_locked:
		return
	_is_locked = true
	preview_rig.play_lock_animation()
	_show_ready_badge(true)
	prev_btn.disabled = true
	next_btn.disabled = true
	_update_prompt()
	AudioManager.play_sfx(AudioManager.SoundEffect.POWERUP_GRAB)
	character_locked.emit(player_id, CHARACTERS[_index])
