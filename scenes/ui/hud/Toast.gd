## Toast.gd
## The HUD's message toast: an optional icon beside the text, coloured by tone,
## popping in and fading out after a moment. Attached to the HUD's banner panel.
extends PanelContainer
class_name Toast

## Neutral (items, superpowers, events), good (hit landed), bad (hit taken, out).
enum Tone { NEUTRAL, GOOD, BAD }

const VARIATIONS: Array[StringName] = [&"BannerPanel", &"BannerPanelGood", &"BannerPanelBad"]
const HOLD: float = 2.0
const POP_START_SCALE: float = 0.6
const FADE_IN: float = 0.2
const POP_TIME: float = 0.25
const FADE_OUT: float = 0.4

@onready var label: Label = $Row/BannerLabel
@onready var icon: TextureRect = $Row/BannerIcon

var _tween: Tween = null


## Shows [param text] for [param hold] seconds (pass a long hold for messages
## that must stay up, e.g. being knocked out).
func show_message(text: String, texture: Texture2D = null, tone: Tone = Tone.NEUTRAL, hold: float = HOLD) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	label.text = text
	icon.texture = texture
	icon.visible = texture != null
	theme_type_variation = VARIATIONS[tone]
	visible = true
	modulate.a = 0.0
	pivot_offset = size * 0.5
	scale = Vector2.ONE * POP_START_SCALE
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, FADE_IN)
	_tween.parallel().tween_property(self, "scale", Vector2.ONE, POP_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(hold)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT)
	_tween.tween_callback(hide)
