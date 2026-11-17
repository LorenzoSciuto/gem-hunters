## ScreenLayout.gd
## Keeps the 2D layer readable on any screen, and tells the UI how it is held.
##   - A tall window (a phone held upright) turns the wide base canvas on its
##     side, so menus and the HUD fill the width instead of shrinking to a strip.
##   - A handheld device draws the whole UI larger, the more so the smaller its
##     screen, so text can be read and buttons hit with a thumb. A phone gets
##     HANDHELD_MAX_SCALE, a tablet stays at 1.
## Screens that arrange themselves differently per shape read [member portrait]
## and listen to [signal layout_changed]. Every screen must fit the smallest
## canvases: MIN_CANVAS_WIDE and its transpose.
extends Node

## The orientation or the UI scale changed.
signal layout_changed

const HANDHELD_MAX_SCALE: float = 1.5
## Short side, in CSS pixels (device pixels / density), at or below which a
## handheld gets HANDHELD_MAX_SCALE: a large phone. Wider screens scale less.
const PHONE_SHORT_SIDE: float = 430.0
## Smallest wide canvas a screen has to fit: a 16:9 phone at HANDHELD_MAX_SCALE.
const MIN_CANVAS_WIDE: Vector2 = Vector2(1280.0, 720.0)

## Phone or tablet. Set once at startup; tests switch it to check both layouts.
var handheld: bool = false:
	set(value):
		handheld = value
		_apply()
## Device pixels per CSS pixel. Read from the display at startup; tests set it.
var density: float = 1.0:
	set(value):
		density = value
		_apply()
## The window is taller than wide.
var portrait: bool = false


func _ready() -> void:
	get_window().size_changed.connect(_apply)
	density = DisplayServer.screen_get_scale()
	handheld = OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


func _apply() -> void:
	if not is_inside_tree():
		return
	var window: Window = get_window()
	var wide: Vector2i = Vector2i(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"))
	portrait = window.size.y > window.size.x
	window.content_scale_size = Vector2i(wide.y, wide.x) if portrait else wide
	window.content_scale_factor = _ui_scale(window)
	layout_changed.emit()


func _ui_scale(window: Window) -> float:
	if not handheld:
		return 1.0
	var short_side: float = mini(window.size.x, window.size.y) / density
	return clampf(HANDHELD_MAX_SCALE * PHONE_SHORT_SIDE / short_side, 1.0, HANDHELD_MAX_SCALE)
