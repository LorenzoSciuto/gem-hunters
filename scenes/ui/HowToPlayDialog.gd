## HowToPlayDialog.gd
## Main-menu guide in four pages: the goal, the hunters and their superpowers,
## every gift-box item, and the arena features. Page buttons work with mouse,
## keyboard and gamepad focus.
extends Control

signal closed

const PAGE_KEYS: Array[String] = ["HELP_TAB_GOAL", "HELP_TAB_HUNTERS", "HELP_TAB_ITEMS", "HELP_TAB_ARENA"]
const HUNTERS: Array[CharacterData] = preload("res://scenes/ui/CharacterSelector.gd").CHARACTERS
const PAGE_WIDTH: float = 1000.0
const HUNTER_ICON_SIZE: float = 72.0
const ITEM_ICON_SIZE: float = 52.0
const SUPER_COLOR: Color = Color(0.55, 0.85, 1.0)

@onready var tabs: HBoxContainer = $Center/Panel/VBox/Tabs
@onready var page: VBoxContainer = $Center/Panel/VBox/Page
@onready var close_btn: Button = $Center/Panel/VBox/CloseButton

var _tab_buttons: Array[Button] = []


func _ready() -> void:
	var group: ButtonGroup = ButtonGroup.new()
	for i: int in PAGE_KEYS.size():
		var b: Button = Button.new()
		b.text = PAGE_KEYS[i]
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_show_page.bind(i))
		tabs.add_child(b)
		_tab_buttons.append(b)
	page.custom_minimum_size.x = PAGE_WIDTH
	close_btn.pressed.connect(func() -> void: closed.emit())


func open() -> void:
	visible = true
	_tab_buttons[0].button_pressed = true
	_show_page(0)
	_tab_buttons[0].grab_focus()


func _show_page(index: int) -> void:
	for child: Node in page.get_children():
		child.queue_free()
	match index:
		0: page.add_child(_text(tr("HELP_GOAL")))
		1: _build_hunters()
		2: _build_items()
		3: page.add_child(_text(tr("HELP_ARENA")))


func _build_hunters() -> void:
	page.add_child(_text(tr("HELP_HUNTERS_INTRO")))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	page.add_child(grid)
	for hunter: CharacterData in HUNTERS:
		var row: HBoxContainer = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(_icon(ItemCatalog.SUPER_ICONS[hunter.trait_type], HUNTER_ICON_SIZE))
		var info: VBoxContainer = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_label: Label = _text(tr(hunter.name_key), &"HeadingLabel")
		name_label.modulate = hunter.color
		info.add_child(name_label)
		info.add_child(_text(tr(hunter.trait_key), &"SubtleLabel"))
		var super_key: String = CharacterData.SUPER_KEYS[hunter.trait_type]
		# Name only: hunters share superpowers, the full description is on the selection card.
		var super_label: Label = _text(tr(super_key))
		super_label.modulate = SUPER_COLOR
		info.add_child(super_label)
		row.add_child(info)
		grid.add_child(row)


func _build_items() -> void:
	page.add_child(_text(tr("HELP_ITEMS_INTRO")))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	for type: int in ItemCatalog.ICONS:
		var cell: HBoxContainer = HBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_child(_icon(ItemCatalog.ICONS[type], ITEM_ICON_SIZE))
		var info: VBoxContainer = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(_text(tr(ItemCatalog.NAME_KEYS[type])))
		info.add_child(_text(tr(ItemCatalog.NAME_KEYS[type] + "_DESC"), &"SubtleLabel"))
		cell.add_child(info)
		grid.add_child(cell)
	page.add_child(grid)


func _text(text: String, variation: StringName = &"") -> Label:
	var label: Label = Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _icon(texture: Texture2D, side: float) -> TextureRect:
	var rect: TextureRect = TextureRect.new()
	rect.texture = texture
	rect.custom_minimum_size = Vector2.ONE * side
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return rect
