## MatchOverlay.gd
## Full-screen layer above the split-screen viewports: 3-2-1-GO countdown,
## the frenzy banner, and the pause menu. Keeps running while the tree is paused.
extends CanvasLayer

const MAIN_MENU_SCENE: String = "res://scenes/ui/MainMenu.tscn"
const POP_SCALE: float = 1.6
const POP_DURATION: float = 0.35
const GO_HOLD: float = 0.6
const BANNER_PULSE: float = 1.08

@onready var countdown_label: Label = $CountdownLabel
@onready var frenzy_banner: PanelContainer = $FrenzyBanner
@onready var pause_menu: Control = $PauseMenu
@onready var resume_button: Button = $PauseMenu/Panel/VBox/ResumeButton
@onready var menu_button: Button = $PauseMenu/Panel/VBox/MenuButton
@onready var quit_button: Button = $PauseMenu/Panel/VBox/QuitButton


func _ready() -> void:
	resume_button.pressed.connect(toggle_pause)
	menu_button.pressed.connect(_on_menu_pressed)
	quit_button.pressed.connect(func() -> void: get_tree().quit())


## [param seconds_left] 3, 2, 1 shows the number; 0 shows "GO!" then hides.
func show_countdown(seconds_left: int) -> void:
	countdown_label.visible = true
	countdown_label.text = str(seconds_left) if seconds_left > 0 else tr("MSG_GO")
	countdown_label.scale = Vector2.ONE * POP_SCALE
	var tween: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(countdown_label, "scale", Vector2.ONE, POP_DURATION)
	if seconds_left <= 0:
		tween.tween_interval(GO_HOLD)
		tween.tween_property(countdown_label, "modulate:a", 0.0, POP_DURATION)
		tween.tween_callback(func() -> void:
			countdown_label.visible = false
			countdown_label.modulate.a = 1.0)


## The banner stays up and pulses until the match ends.
func show_frenzy() -> void:
	frenzy_banner.visible = true
	var tween: Tween = create_tween().set_loops()
	tween.tween_property(frenzy_banner, "scale", Vector2.ONE * BANNER_PULSE, POP_DURATION)
	tween.tween_property(frenzy_banner, "scale", Vector2.ONE, POP_DURATION)


## Escape (keyboard) or Start (any gamepad) toggles pause during play.
## Handled here because this layer keeps processing while the tree is paused.
func _unhandled_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo \
		and (event as InputEventKey).keycode == KEY_ESCAPE) \
		or (event is InputEventJoypadButton and event.pressed \
		and (event as InputEventJoypadButton).button_index == JOY_BUTTON_START)
	if pressed and (GameManager.is_playing() or pause_menu.visible):
		toggle_pause()
		get_viewport().set_input_as_handled()


func toggle_pause() -> void:
	var pausing: bool = not pause_menu.visible
	pause_menu.visible = pausing
	get_tree().paused = pausing
	if pausing:
		GameManager.pause_match()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		resume_button.grab_focus()
	else:
		GameManager.resume_match()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_menu_pressed() -> void:
	get_tree().paused = false
	GameManager.reset_to_lobby()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
