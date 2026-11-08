## GameOverScreen.gd
## Final standings over a backdrop of the arena just played.
## Rematch keeps the same players, goal, arena and characters; "change
## hunters" keeps the setup but reopens character selection.
extends Control

const MATCH_SCENE: String = "res://scenes/main/Main.tscn"
const MENU_SCENE: String = "res://scenes/ui/MainMenu.tscn"
const BAR_SIZE: Vector2 = Vector2(260, 22)
const ROW_STAGGER: float = 0.15

@onready var backdrop: Node = $ArenaBackdrop
@onready var winner_label: Label = $Center/Panel/VBox/WinnerLabel
@onready var standings_grid: GridContainer = $Center/Panel/VBox/Standings
@onready var rematch_btn: Button = $Center/Panel/VBox/Buttons/RematchButton
@onready var change_btn: Button = $Center/Panel/VBox/Buttons/ChangeButton
@onready var menu_btn: Button = $Center/Panel/VBox/Buttons/MenuButton
@onready var quit_btn: Button = $Center/Panel/VBox/Buttons/QuitButton


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if GameManager.level_config:
		backdrop.show_arena(GameManager.level_config)
	rematch_btn.pressed.connect(func() -> void: get_tree().change_scene_to_file(MATCH_SCENE))
	change_btn.pressed.connect(func() -> void:
		GameManager.chosen_characters.clear()
		get_tree().change_scene_to_file(MATCH_SCENE))
	menu_btn.pressed.connect(_on_menu_pressed)
	quit_btn.pressed.connect(get_tree().quit)
	_display_results()
	rematch_btn.grab_focus()


func _display_results() -> void:
	var standings: Array = GameManager.get_standings()
	var leader: int = GameManager.get_leader()
	if leader < 0:
		winner_label.text = tr("MSG_DRAW")
	else:
		winner_label.text = tr("MSG_WINNER").format([tr("UI_PLAYER_SHORT").format([leader + 1])])
		winner_label.modulate = Constants.PLAYER_COLORS[leader]

	var best: int = maxi(standings[0]["score"], 1)
	for i: int in standings.size():
		var pid: int = standings[i]["player_id"]
		var score: int = standings[i]["score"]
		var character: CharacterData = GameManager.chosen_characters.get(pid)
		var cells: Array[Control] = []

		var rank: Label = Label.new()
		rank.theme_type_variation = &"HeadingLabel"
		rank.text = "#%d" % (i + 1)
		cells.append(rank)

		var name_label: Label = Label.new()
		name_label.theme_type_variation = &"HeadingLabel"
		name_label.text = tr("UI_PLAYER_SHORT").format([pid + 1])
		if character:
			name_label.text += "  " + tr(character.name_key)
		name_label.modulate = Constants.PLAYER_COLORS[pid]
		cells.append(name_label)

		var bar: ProgressBar = ProgressBar.new()
		bar.custom_minimum_size = BAR_SIZE
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.show_percentage = false
		bar.max_value = best
		bar.modulate = Constants.PLAYER_COLORS[pid]
		cells.append(bar)

		var score_label: Label = Label.new()
		score_label.theme_type_variation = &"HeadingLabel"
		score_label.text = "%d ◆" % score
		if GameManager.is_survival():
			var lives: int = standings[i]["lives"]
			score_label.text += "   " + (tr("UI_LIVES_N").format([lives]) if lives > 0 else tr("UI_KNOCKED_OUT"))
		cells.append(score_label)

		for c: Control in cells:
			c.modulate.a = 0.0
			standings_grid.add_child(c)
		var tween: Tween = create_tween()
		tween.tween_interval(i * ROW_STAGGER)
		for c: Control in cells:
			tween.parallel().tween_property(c, "modulate:a", 1.0, 0.3)
		tween.parallel().tween_property(bar, "value", score, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_menu_pressed() -> void:
	GameManager.reset_to_lobby()
	get_tree().change_scene_to_file(MENU_SCENE)
