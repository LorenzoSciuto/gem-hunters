## HowToPlayDialog.gd
## Main-menu guide in four pages: the goal and the gems, the hunters and their
## superpowers, every gift-box item, and the arena features. Page buttons work
## with mouse, keyboard and gamepad focus; up/down scroll a long page. Modal:
## focus can't reach the menu behind, and the page always fits the screen.
extends Control

signal closed

const PAGE_KEYS: Array[String] = ["HELP_TAB_GOAL", "HELP_TAB_HUNTERS", "HELP_TAB_ITEMS", "HELP_TAB_ARENA"]
const HUNTERS: Array[CharacterData] = preload("res://scenes/ui/CharacterSelector.gd").CHARACTERS
const PAGE_WIDTH: float = 1000.0
## Share of the screen the page may take; longer pages scroll.
const SCREEN_WIDTH_SHARE: float = 0.85
const SCREEN_HEIGHT_SHARE: float = 0.6
const SCROLL_STEP: int = 90
const GEM_ICON_SIZE: float = 56.0
const MAT_STANDARD: ShaderMaterial = preload("res://resources/materials/mat_gem_standard.tres")
const MAT_RARE: ShaderMaterial = preload("res://resources/materials/mat_gem_rare.tres")
const MAT_EPIC: ShaderMaterial = preload("res://resources/materials/mat_gem_epic.tres")
const MAT_GOLDEN: ShaderMaterial = preload("res://resources/materials/mat_gem_golden.tres")
const MAT_LIFE: ShaderMaterial = preload("res://resources/materials/mat_gem_life.tres")
const HUNTER_ICON_SIZE: float = 72.0
const ITEM_ICON_SIZE: float = 52.0
const SUPER_COLOR: Color = Color(0.55, 0.85, 1.0)

@onready var tabs: HBoxContainer = $Center/Panel/VBox/Tabs
@onready var scroll: ScrollContainer = $Center/Panel/VBox/Scroll
@onready var page: VBoxContainer = $Center/Panel/VBox/Scroll/Page
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
	add_child(ModalFocus.new())
	get_viewport().size_changed.connect(_fit_to_screen)
	close_btn.pressed.connect(func() -> void: closed.emit())


func open() -> void:
	visible = true
	_fit_to_screen()
	_tab_buttons[0].button_pressed = true
	_show_page(0)
	_tab_buttons[0].grab_focus()


func _fit_to_screen() -> void:
	var screen: Vector2 = get_viewport_rect().size
	var width: float = minf(PAGE_WIDTH, screen.x * SCREEN_WIDTH_SHARE)
	page.custom_minimum_size.x = width
	scroll.custom_minimum_size = Vector2(width, screen.y * SCREEN_HEIGHT_SHARE)


## Up/down scroll a long page first; at its ends they move focus as usual.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	var step: int = -SCROLL_STEP if event.is_action_pressed("ui_up") else SCROLL_STEP if event.is_action_pressed("ui_down") else 0
	if step == 0:
		return
	var before: int = scroll.scroll_vertical
	scroll.scroll_vertical += step
	if scroll.scroll_vertical != before:
		get_viewport().set_input_as_handled()


func _show_page(index: int) -> void:
	for child: Node in page.get_children():
		child.queue_free()
	scroll.scroll_vertical = 0
	match index:
		0:
			page.add_child(_text(tr("HELP_GOAL")))
			_build_gems()
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
		row.add_child(_icon(ItemCatalog.SUPER_ICONS[hunter.superpower], HUNTER_ICON_SIZE))
		var info: VBoxContainer = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_label: Label = _text(tr(hunter.name_key), &"HeadingLabel")
		name_label.modulate = hunter.color
		info.add_child(name_label)
		info.add_child(_text(tr(hunter.trait_key), &"SubtleLabel"))
		var super_key: String = CharacterData.SUPER_KEYS[hunter.superpower]
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


## Every kind of gem, drawn in its own colour, with what it's worth.
func _build_gems() -> void:
	var gems: Array = [
		[MAT_STANDARD.get_shader_parameter("base_color"), "HELP_GEM_1", false],
		[MAT_RARE.get_shader_parameter("base_color"), "HELP_GEM_3", false],
		[MAT_EPIC.get_shader_parameter("base_color"), "HELP_GEM_5", false],
		[MAT_GOLDEN.get_shader_parameter("gold_color"), "HELP_GEM_GOLDEN", false],
		[MAT_LIFE.get_shader_parameter("base_color"), "HELP_GEM_LIFE", false],
		[Color.WHITE, "HELP_GEM_CHAOS", true],
	]
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	for gem: Array in gems:
		var cell: HBoxContainer = HBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_child(GemIcon.create(gem[0], GEM_ICON_SIZE, gem[2]))
		var label: Label = _text(tr(gem[1]))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cell.add_child(label)
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
