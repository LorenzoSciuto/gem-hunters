## MainMenu.gd
## Lobby: choose player count, match goal (time, gem target, survival or collector) and arena, then play.
## Works with mouse, keyboard and gamepad (standard ui_* focus navigation).
extends Control

const MATCH_SCENE: String = "res://scenes/main/Main.tscn"

@onready var backdrop: Node = $ArenaBackdrop
@onready var players_row: HBoxContainer = $Margin/VBox/Panel/Options/PlayersRow
@onready var mode_row: HBoxContainer = $Margin/VBox/Panel/Options/ModeRow
@onready var target_row: HBoxContainer = $Margin/VBox/Panel/Options/TargetRow
@onready var mode_desc: Label = $Margin/VBox/Panel/Options/ModeDesc
@onready var arena_grid: GridContainer = $Margin/VBox/Panel/Options/ArenaGrid
@onready var arena_desc: Label = $Margin/VBox/Panel/Options/ArenaDesc
@onready var start_btn: Button = $Margin/VBox/StartButton
@onready var help_btn: Button = $Margin/VBox/BottomRow/HelpButton
@onready var help_dialog: Control = $HowToPlayDialog
@onready var controls_btn: Button = $Margin/VBox/BottomRow/ControlsButton
@onready var lang_btn: Button = $Margin/VBox/BottomRow/LangButton
@onready var quit_btn: Button = $Margin/VBox/BottomRow/QuitButton
@onready var gamepad_status_label: Label = $Margin/VBox/GamepadStatusLabel
@onready var controls_dialog: Control = $ControlsDialog
@onready var close_controls_btn: Button = $ControlsDialog/Center/Panel/VBox/Buttons/CloseButton

var _levels: Array[LevelConfig] = []
var _players: int = 2
var _mode: Constants.MatchMode = Constants.MatchMode.TIME
var _target: int = Constants.TIME_TARGETS[1]
var _level: LevelConfig = null

var _player_buttons: Array[Button] = []
var _mode_buttons: Array[Button] = []
var _target_buttons: Array[Button] = []
var _arena_buttons: Array[Button] = []


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for path: String in Constants.LEVEL_CONFIGS:
		_levels.append(load(path) as LevelConfig)

	# Restore the previous session's choices when coming back from a match.
	_players = GameManager.get_num_players()
	_mode = GameManager.match_mode
	_target = GameManager.match_target
	_level = GameManager.level_config if GameManager.level_config else _levels[0]

	_player_buttons = _make_toggles(players_row, range(Constants.MIN_PLAYERS, Constants.MAX_PLAYERS + 1), _select_players)
	_mode_buttons = _make_toggles(mode_row, Constants.MatchMode.values(), _select_mode)
	_arena_buttons = _make_toggles(arena_grid, range(_levels.size()), func(i: int) -> void: _select_arena(_levels[i]))

	start_btn.pressed.connect(_on_start_pressed)
	quit_btn.pressed.connect(get_tree().quit)
	quit_btn.visible = not OS.has_feature("web")  # A browser tab can't be quit from inside.
	lang_btn.pressed.connect(_on_lang_pressed)
	controls_btn.pressed.connect(_show_controls.bind(true))
	help_btn.pressed.connect(help_dialog.open)
	help_dialog.closed.connect(_close_help)
	close_controls_btn.pressed.connect(_show_controls.bind(false))
	LocalizationManager.language_changed.connect(func(_l: int) -> void: _refresh_texts())
	InputManager.gamepad_connected.connect(func(_id: int, _n: String) -> void: _refresh_texts())
	InputManager.gamepad_disconnected.connect(func(_id: int) -> void: _refresh_texts())

	_select_mode(_mode, _target)
	_select_arena(_level)
	_refresh_texts()
	start_btn.grab_focus()


## Creates one toggle button per value in a shared ButtonGroup.
func _make_toggles(parent: Container, values: Array, on_pick: Callable) -> Array[Button]:
	var group: ButtonGroup = ButtonGroup.new()
	var buttons: Array[Button] = []
	for value: Variant in values:
		var b: Button = Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			AudioManager.play_sfx(AudioManager.SoundEffect.TIMER_TICK)
			on_pick.call(value))
		parent.add_child(b)
		buttons.append(b)
	return buttons


func _select_players(count: int) -> void:
	_players = count


## Switching mode rebuilds the target buttons (seconds or gems); survival has
## no target (everyone starts with Constants.START_LIVES).
func _select_mode(mode: Constants.MatchMode, keep_target: int = -1) -> void:
	_mode = mode
	var targets: Array[int] = _targets_for(mode)
	_target = keep_target if keep_target in targets else (targets[1] if not targets.is_empty() else Constants.START_LIVES)
	target_row.visible = not targets.is_empty()
	for b: Button in _target_buttons:
		b.queue_free()
	_target_buttons = _make_toggles(target_row, targets, func(t: int) -> void:
		_target = t
		_refresh_texts())
	_refresh_texts()


func _targets_for(mode: Constants.MatchMode) -> Array[int]:
	match mode:
		Constants.MatchMode.TIME: return Constants.TIME_TARGETS
		Constants.MatchMode.SCORE: return Constants.SCORE_TARGETS
	return []


## Every pick regenerates the backdrop, so re-pressing previews a fresh maze.
func _select_arena(config: LevelConfig) -> void:
	_level = config
	backdrop.show_arena(config)
	_refresh_texts()


func _refresh_texts() -> void:
	for i: int in _player_buttons.size():
		var count: int = Constants.MIN_PLAYERS + i
		_player_buttons[i].text = tr("UI_PLAYERS_N").format([count])
		_player_buttons[i].set_pressed_no_signal(count == _players)

	_mode_buttons[0].text = tr("UI_MODE_TIME")
	_mode_buttons[1].text = tr("UI_MODE_SCORE")
	_mode_buttons[2].text = tr("UI_MODE_LIVES")
	_mode_buttons[3].text = tr("UI_MODE_COLLECT")
	for i: int in _mode_buttons.size():
		_mode_buttons[i].set_pressed_no_signal(i == _mode)

	var targets: Array[int] = _targets_for(_mode)
	for i: int in _target_buttons.size():
		var t: int = targets[i]
		_target_buttons[i].text = "%d:%02d" % [t / 60, t % 60] if _mode == Constants.MatchMode.TIME \
			else tr("UI_TARGET_GEMS").format([t])
		_target_buttons[i].set_pressed_no_signal(t == _target)
	match _mode:
		Constants.MatchMode.TIME: mode_desc.text = tr("UI_MODE_TIME_DESC")
		Constants.MatchMode.SCORE: mode_desc.text = tr("UI_MODE_SCORE_DESC").format([_target])
		Constants.MatchMode.COLLECT: mode_desc.text = tr("UI_MODE_COLLECT_DESC").format([Constants.COLLECT_COLORS.size()])
		_: mode_desc.text = tr("UI_MODE_LIVES_DESC").format([Constants.START_LIVES, Constants.GEMS_PER_LIFE])

	for i: int in _arena_buttons.size():
		_arena_buttons[i].text = tr(_levels[i].name_key)
		_arena_buttons[i].set_pressed_no_signal(_levels[i] == _level)
	arena_desc.text = tr(_level.description_key)

	var pads: Array[String] = InputManager.get_connected_names()
	gamepad_status_label.text = tr("UI_GAMEPADS_NONE") if pads.is_empty() \
		else tr("UI_GAMEPADS_FOUND").format([", ".join(pads)])


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_START and not controls_dialog.visible and not help_dialog.visible:
			get_viewport().set_input_as_handled()  # Before starting: the scene change leaves the tree.
			_on_start_pressed()
	if event.is_action_pressed("ui_cancel") and controls_dialog.visible:
		_show_controls(false)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and help_dialog.visible:
		_close_help()
		get_viewport().set_input_as_handled()


func _show_controls(shown: bool) -> void:
	controls_dialog.visible = shown
	if shown:
		controls_dialog.refresh()
		close_controls_btn.grab_focus()
	else:
		controls_btn.grab_focus()


func _close_help() -> void:
	help_dialog.visible = false
	help_btn.grab_focus()


func _on_start_pressed() -> void:
	GameManager.configure(_players, _mode, _target, _level)
	GameManager.chosen_characters.clear()
	get_tree().change_scene_to_file(MATCH_SCENE)


func _on_lang_pressed() -> void:
	var next: LocalizationManager.Language = LocalizationManager.Language.IT \
		if LocalizationManager.get_current_language() == LocalizationManager.Language.EN \
		else LocalizationManager.Language.EN
	LocalizationManager.set_language(next)
