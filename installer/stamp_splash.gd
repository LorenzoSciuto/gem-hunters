## stamp_splash.gd
## Writes the game version ("v1.2.3") next to "Wennovate" on the splash image,
## in place. The release workflow runs it after it has set config/version, so
## every build shows its own number while it loads:
##   godot --headless --path . -s installer/stamp_splash.gd
## The glyphs come from a strip image whose characters, in GLYPH_ORDER, are
## separated by fully transparent columns, so no font is needed here.
extends SceneTree

const SPLASH_PATH: String = "res://assets/ui/splash.png"
const GLYPHS_PATH: String = "res://installer/splash_version_glyphs.png"
const GLYPH_ORDER: String = "0123456789.v"
## Top-left corner of the version text on the splash (right of "Wennovate").
const ORIGIN: Vector2i = Vector2i(671, 672)
const GLYPH_SPACING: int = 2


func _initialize() -> void:
	var splash: Image = Image.load_from_file(ProjectSettings.globalize_path(SPLASH_PATH))
	var glyphs: Image = Image.load_from_file(ProjectSettings.globalize_path(GLYPHS_PATH))
	var rects: Array[Rect2i] = _glyph_rects(glyphs)
	var version: String = "v" + str(ProjectSettings.get_setting("application/config/version"))
	var x: int = ORIGIN.x
	for character: String in version:
		var index: int = GLYPH_ORDER.find(character)
		if index < 0 or index >= rects.size():
			printerr("stamp_splash: no glyph for '%s' in version %s" % [character, version])
			quit(1)
			return
		splash.blend_rect(glyphs, rects[index], Vector2i(x, ORIGIN.y))
		x += rects[index].size.x + GLYPH_SPACING
	quit(splash.save_png(ProjectSettings.globalize_path(SPLASH_PATH)))


## One rectangle per glyph: each run of columns holding any opaque pixel.
func _glyph_rects(strip: Image) -> Array[Rect2i]:
	var rects: Array[Rect2i] = []
	var run_start: int = -1
	for x: int in strip.get_width() + 1:
		var inked: bool = x < strip.get_width() and _column_inked(strip, x)
		if inked and run_start < 0:
			run_start = x
		elif not inked and run_start >= 0:
			rects.append(Rect2i(run_start, 0, x - run_start, strip.get_height()))
			run_start = -1
	return rects


func _column_inked(strip: Image, x: int) -> bool:
	for y: int in strip.get_height():
		if strip.get_pixel(x, y).a > 0.0:
			return true
	return false
