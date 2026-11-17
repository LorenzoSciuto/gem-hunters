## OptionStepper.gd
## One menu choice on one row: a title, then "<  value  >" to step through the
## options (wrapping around). The row keeps its size whatever the value says,
## and its arrows are large enough for a thumb. With a single option the
## arrows switch off and the row just states the value.
extends HBoxContainer
class_name OptionStepper

## The player stepped to the option at [param index].
signal changed(index: int)

const ARROW_SIZE: Vector2 = Vector2(76.0, 68.0)

var _title: Label = null
var _value: Label = null
var _arrows: Array[Button] = []
var _options: Array[String] = []
var _selected: int = 0


func _init() -> void:
	_title = Label.new()
	_title.theme_type_variation = &"HeadingLabel"
	add_child(_title)
	_add_arrow("<", -1)
	_value = Label.new()
	_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_value)
	_add_arrow(">", 1)


func _add_arrow(text: String, step: int) -> void:
	var arrow: Button = Button.new()
	arrow.text = text
	arrow.custom_minimum_size = ARROW_SIZE
	arrow.pressed.connect(_step.bind(step))
	add_child(arrow)
	_arrows.append(arrow)


## [param width] lines this row's arrows up with its neighbours'.
func set_title(text: String, width: float) -> void:
	_title.text = text
	_title.custom_minimum_size.x = width


## Width the title needs by itself.
func natural_title_width() -> float:
	return _title.get_minimum_size().x


func set_options(options: Array[String], selected: int) -> void:
	_options = options
	_selected = clampi(selected, 0, options.size() - 1)
	_value.text = options[_selected]
	for arrow: Button in _arrows:
		arrow.disabled = options.size() < 2


## The first arrow, for a screen that wants to put the focus on this row.
func focus_target() -> Button:
	return _arrows[0]


func _step(step: int) -> void:
	_selected = posmod(_selected + step, _options.size())
	_value.text = _options[_selected]
	AudioManager.play_sfx(AudioManager.SoundEffect.TIMER_TICK)
	changed.emit(_selected)
