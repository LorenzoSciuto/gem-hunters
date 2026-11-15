## PopupText.gd
## Big floating text over the arena ("+2", "+1 LIFE", "PRANK!") that pops in,
## rises and fades out, seen on every screen. Static helper, never instanced.
class_name PopupText
extends RefCounted

## Height over a hunter's feet and the shared gain / loss colours.
const HEIGHT: float = 2.4
const GAIN_COLOR: Color = Color(0.5, 1.0, 0.55)
const LOSS_COLOR: Color = Color(1.0, 0.4, 0.35)
const FONT_SIZE: int = 160
const OUTLINE_SIZE: int = 22
const START_SCALE: float = 0.4
const POP_TIME: float = 0.18
## Word popups ("+1 LIFE", "PRANK!") are smaller than number popups ("+2").
const WORD_SCALE: float = 0.5
const PIXEL_SIZE: float = 0.008
const RISE: float = 1.6
const DURATION: float = 1.1
const OUTLINE_COLOR: Color = Color(0.1, 0.06, 0.15)
## The text starts fading this far into its rise.
const FADE_START: float = 0.5


## Big floating text (e.g. "+2") that rises and fades out, seen on every screen.
## Text with letters (not just a number) is drawn smaller so it doesn't fill the view.
static func spawn(parent: Node, pos: Vector3, text: String, color: Color) -> void:
	var word: bool = text.to_upper() != text.to_lower()
	var label: Label3D = Label3D.new()
	label.text = text
	label.font = Constants.DISPLAY_FONT
	label.modulate = color
	label.outline_modulate = OUTLINE_COLOR
	label.font_size = FONT_SIZE
	label.outline_size = OUTLINE_SIZE
	label.pixel_size = PIXEL_SIZE * (WORD_SCALE if word else 1.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)
	label.global_position = pos
	var tween: Tween = label.create_tween().set_parallel()
	label.scale = Vector3.ONE * START_SCALE
	tween.tween_property(label, "scale", Vector3.ONE, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "global_position:y", pos.y + RISE, DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, DURATION).set_delay(DURATION * FADE_START)
	tween.chain().tween_callback(label.queue_free)
