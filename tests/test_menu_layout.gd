## The main menu card keeps one size whatever is picked, in both languages:
## on a desktop, and on a phone held either way.
extends "res://tests/match_test.gd"

const MENU_SCENE: String = "res://scenes/ui/MainMenu.tscn"
const PHONE_DENSITY: float = 2.0
## [handheld, window size] of each screen checked.
const SCREENS: Array[Array] = [
	[false, Vector2i(1920, 1080)], [true, Vector2i(1280, 720)], [true, Vector2i(720, 1280)],
]
## Presses per row: more than any row has options, so each one wraps around.
const STEPS_PER_ROW: int = 7


func _run_test() -> void:
	var layout: Node = root.get_node("ScreenLayout")
	layout.density = PHONE_DENSITY
	for screen: Array in SCREENS:
		var window_size: Vector2i = screen[1]
		layout.handheld = screen[0]
		root.size = window_size
		change_scene_to_file(MENU_SCENE)
		await wait(SCENE_SETTLE_TIME)
		var menu: Node = current_scene
		var card: Control = menu.get_node("Margin/Column/Card")
		var size: Vector2 = card.size
		expect(layout.portrait == (window_size.y > window_size.x), "orientation follows the window %s" % window_size)
		for _language: int in 2:
			for row: Node in [menu.players_stepper, menu.bots_stepper, menu.arena_stepper, menu.mode_stepper, menu.target_stepper]:
				for _step: int in STEPS_PER_ROW:
					row.focus_target().pressed.emit()
					await process_frame
					await process_frame
					if not card.size.is_equal_approx(size):
						expect(false, "the card went from %s to %s stepping %s (%s)" % [size, card.size, row.name, window_size])
						size = card.size
			menu.lang_btn.pressed.emit()
			await process_frame
			await process_frame
			expect(card.size.is_equal_approx(size), "the card went from %s to %s with the language (%s)" % [size, card.size, window_size])
			size = card.size
	finish()
