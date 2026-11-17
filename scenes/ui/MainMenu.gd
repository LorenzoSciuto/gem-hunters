## MainMenu.gd
## Lobby: choose players and bots, the arena, the match goal and its target,
## then play. Every choice is an OptionStepper row, so the card has the same
## size whatever is picked. The two halves of the card sit side by side on a
## wide screen and stack on a tall one (see ScreenLayout).
## Works with mouse, keyboard, gamepad and touch (standard ui_* focus navigation).
extends Control

const MATCH_SCENE: String = "res://scenes/main/Main.tscn"
## Width of the menu column on a wide screen: what the smallest wide canvas
## leaves between the margins. On a tall screen the column fills the width.
const WIDE_COLUMN_WIDTH: float = 1184.0
## Lines kept for the descriptions (the longest ones, in either language).
const MODE_DESC_LINES: int = 3
const ARENA_DESC_LINES: int = 1

@onready var backdrop: Node = $ArenaBackdrop
@onready var column: VBoxContainer = $Margin/Column
@onready var header: BoxContainer = $Margin/Column/Header
@onready var sections: BoxContainer = $Margin/Column/Card/Sections
@onready var players_stepper: OptionStepper = $Margin/Column/Card/Sections/Who/Players
@onready var bots_stepper: OptionStepper = $Margin/Column/Card/Sections/Who/Bots
@onready var arena_stepper: OptionStepper = $Margin/Column/Card/Sections/Who/Arena
@onready var arena_desc: Label = $Margin/Column/Card/Sections/Who/ArenaDescBox/ArenaDesc
@onready var mode_stepper: OptionStepper = $Margin/Column/Card/Sections/Goal/Mode
@onready var target_stepper: OptionStepper = $Margin/Column/Card/Sections/Goal/Target
@onready var mode_desc: Label = $Margin/Column/Card/Sections/Goal/ModeDescBox/ModeDesc
@onready var start_btn: Button = $Margin/Column/StartButton
@onready var help_btn: Button = $Margin/Column/Header/Utility/HelpButton
@onready var help_dialog: Control = $HowToPlayDialog
@onready var controls_btn: Button = $Margin/Column/Header/Utility/ControlsButton
@onready var lang_btn: Button = $Margin/Column/Header/Utility/LangButton
@onready var quit_btn: Button = $Margin/Column/Header/Utility/QuitButton
@onready var gamepad_status_label: Label = $Margin/Column/GamepadStatusLabel
@onready var controls_dialog: Control = $ControlsDialog
@onready var close_controls_btn: Button = $ControlsDialog/Center/Panel/VBox/Buttons/CloseButton

var _levels: Array[LevelConfig] = []
## Humans; with _bots they make the MIN_PLAYERS..MAX_PLAYERS hunters of a match.
var _players: int = 2
var _bots: int = 0
var _mode: Constants.MatchMode = Constants.MatchMode.TIME
var _target: int = Constants.TIME_TARGETS[1]
var _level: LevelConfig = null


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for path: String in Constants.LEVEL_CONFIGS:
		_levels.append(load(path) as LevelConfig)

	# Restore the previous session's choices when coming back from a match.
	_players = GameManager.get_num_humans()
	_bots = GameManager.get_num_players() - _players
	_mode = GameManager.match_mode
	_target = GameManager.match_target
	_level = GameManager.level_config if GameManager.level_config else _levels[0]
	if _target not in _targets():
		_target = _default_target()

	players_stepper.changed.connect(func(index: int) -> void:
		_players = index + 1
		_bots = _bot_choices()[0] if _bots not in _bot_choices() else _bots
		_refresh_texts())
	bots_stepper.changed.connect(func(index: int) -> void: _bots = _bot_choices()[index])
	arena_stepper.changed.connect(func(index: int) -> void: _select_arena(_levels[index]))
	mode_stepper.changed.connect(func(index: int) -> void:
		_mode = index as Constants.MatchMode
		_target = _default_target()
		_refresh_texts())
	target_stepper.changed.connect(func(index: int) -> void:
		_target = _targets()[index]
		_refresh_texts())

	start_btn.pressed.connect(_on_start_pressed)
	quit_btn.pressed.connect(get_tree().quit)
	quit_btn.visible = not OS.has_feature("web")  # A browser tab can't be quit from inside.
	# A handheld has no keys or pads to remap or report.
	controls_btn.visible = not ScreenLayout.handheld
	gamepad_status_label.visible = not ScreenLayout.handheld
	lang_btn.pressed.connect(_on_lang_pressed)
	controls_btn.pressed.connect(_show_controls.bind(true))
	help_btn.pressed.connect(help_dialog.open)
	help_dialog.closed.connect(_close_help)
	close_controls_btn.pressed.connect(_show_controls.bind(false))
	LocalizationManager.language_changed.connect(func(_l: int) -> void: _refresh_texts())
	InputManager.gamepad_connected.connect(func(_id: int, _n: String) -> void: _refresh_texts())
	InputManager.gamepad_disconnected.connect(func(_id: int) -> void: _refresh_texts())

	_reserve_lines(mode_desc, MODE_DESC_LINES)
	_reserve_lines(arena_desc, ARENA_DESC_LINES)
	ScreenLayout.layout_changed.connect(_arrange)
	_arrange()
	_select_arena(_level)
	start_btn.grab_focus()


## A description sits in a box of fixed height (its parent), so no text can
## resize the card: the box is as tall as [param lines] lines of the label.
func _reserve_lines(description: Label, lines: int) -> void:
	# Measured without wrapping: a wrapping label has no width yet, and
	# reports far more height than its lines take.
	var wrap: TextServer.AutowrapMode = description.autowrap_mode
	description.autowrap_mode = TextServer.AUTOWRAP_OFF
	description.text = "A\n".repeat(lines)
	(description.get_parent() as Control).custom_minimum_size.y = description.get_minimum_size().y
	description.autowrap_mode = wrap


## The two halves of the card side by side on a wide screen, stacked on a tall one.
func _arrange() -> void:
	var tall: bool = ScreenLayout.portrait
	header.vertical = tall
	sections.vertical = tall
	column.size_flags_horizontal = Control.SIZE_FILL if tall else Control.SIZE_SHRINK_BEGIN
	column.custom_minimum_size.x = 0.0 if tall else WIDE_COLUMN_WIDTH


## Bot counts that keep humans + bots within MIN_PLAYERS..MAX_PLAYERS.
func _bot_choices() -> Array[int]:
	var choices: Array[int] = []
	choices.assign(range(maxi(Constants.MIN_PLAYERS - _players, 0), Constants.MAX_PLAYERS - _players + 1))
	return choices


## What the goal is played to: seconds or gems to choose from, or the one
## number a goal without a choice is played with (lives, colours).
func _targets() -> Array[int]:
	match _mode:
		Constants.MatchMode.TIME: return Constants.TIME_TARGETS
		Constants.MatchMode.SCORE: return Constants.SCORE_TARGETS
		Constants.MatchMode.COLLECT: return [Constants.COLLECT_COLORS.size()]
	return [Constants.START_LIVES]


func _default_target() -> int:
	var targets: Array[int] = _targets()
	return targets[mini(1, targets.size() - 1)]


func _target_text(target: int) -> String:
	match _mode:
		Constants.MatchMode.TIME: return "%d:%02d" % [target / 60, target % 60]
		Constants.MatchMode.SCORE: return tr("UI_TARGET_GEMS").format([target])
		Constants.MatchMode.COLLECT: return tr("UI_COLORS_N").format([target])
	return tr("UI_LIVES_N").format([target])


## Every pick regenerates the backdrop, so the arena behind the menu is the one chosen.
func _select_arena(config: LevelConfig) -> void:
	_level = config
	backdrop.show_arena(config)
	_refresh_texts()


func _refresh_texts() -> void:
	var steppers: Dictionary = {
		players_stepper: "UI_SELECT_PLAYERS", bots_stepper: "UI_BOTS", arena_stepper: "UI_SELECT_ARENA",
		mode_stepper: "UI_SELECT_MODE", target_stepper: "UI_SELECT_TARGET",
	}
	# Every title takes the widest one's width, so the arrows line up.
	var title_width: float = 0.0
	for stepper: OptionStepper in steppers:
		stepper.set_title(tr(steppers[stepper]), 0.0)
		title_width = maxf(title_width, stepper.natural_title_width())
	for stepper: OptionStepper in steppers:
		stepper.set_title(tr(steppers[stepper]), title_width)

	players_stepper.set_options(_numbers(range(1, Constants.MAX_PLAYERS + 1)), _players - 1)
	bots_stepper.set_options(_numbers(_bot_choices()), _bot_choices().find(_bots))
	var arena_names: Array[String] = []
	for level: LevelConfig in _levels:
		arena_names.append(tr(level.name_key))
	arena_stepper.set_options(arena_names, _levels.find(_level))
	mode_stepper.set_options([tr("UI_MODE_TIME"), tr("UI_MODE_SCORE"), tr("UI_MODE_LIVES"), tr("UI_MODE_COLLECT")], _mode)
	var target_texts: Array[String] = []
	for target: int in _targets():
		target_texts.append(_target_text(target))
	target_stepper.set_options(target_texts, _targets().find(_target))

	match _mode:
		Constants.MatchMode.TIME: mode_desc.text = tr("UI_MODE_TIME_DESC")
		Constants.MatchMode.SCORE: mode_desc.text = tr("UI_MODE_SCORE_DESC").format([_target])
		Constants.MatchMode.COLLECT: mode_desc.text = tr("UI_MODE_COLLECT_DESC").format([_target])
		_: mode_desc.text = tr("UI_MODE_LIVES_DESC").format([_target, Constants.GEMS_PER_LIFE])
	arena_desc.text = tr(_level.description_key)

	var pads: Array[String] = InputManager.get_connected_names()
	gamepad_status_label.text = tr("UI_GAMEPADS_NONE") if pads.is_empty() \
		else tr("UI_GAMEPADS_FOUND").format([", ".join(pads)])


func _numbers(values: Array) -> Array[String]:
	var texts: Array[String] = []
	for value: int in values:
		texts.append(str(value))
	return texts


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
	GameManager.configure(_players + _bots, _mode, _target, _level, _bots)
	GameManager.chosen_characters.clear()
	get_tree().change_scene_to_file(MATCH_SCENE)


func _on_lang_pressed() -> void:
	var next: LocalizationManager.Language = LocalizationManager.Language.IT \
		if LocalizationManager.get_current_language() == LocalizationManager.Language.EN \
		else LocalizationManager.Language.EN
	LocalizationManager.set_language(next)
