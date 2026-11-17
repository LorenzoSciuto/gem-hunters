## ScreenLayout.gd
## Keeps the 2D layer readable whichever way the screen is held. The project
## lays its UI out on a wide base canvas; on a tall window (a phone held
## upright) the base is turned on its side, so menus and the HUD fill the
## width instead of shrinking to a strip. Follows every resize and rotation.
extends Node


func _ready() -> void:
	get_window().size_changed.connect(_apply)
	_apply()


func _apply() -> void:
	var window: Window = get_window()
	var wide: Vector2i = Vector2i(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"))
	window.content_scale_size = wide if window.size.x >= window.size.y else Vector2i(wide.y, wide.x)
