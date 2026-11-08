## ItemPad.gd
## The HUD's item slots, laid out like the pad's face buttons: X left, A bottom,
## B right (items 1-3), Y top (superpower). Each slot shows its key prompt; the
## superpower slot shows a recharge ring and countdown; a camera-view hint sits
## above. The mouse player's armed slot is enlarged.
extends Control
class_name ItemPad

const SLOT_SIZE: float = 86.0
## Round slot inside its grid cell; the gap between cells keeps them apart.
const SLOT_DIAMETER: float = 78.0
const SLOT_ICON_SIZE: float = 56.0
const SLOT_GRID_POS: Array[Vector2] = [Vector2(0, 1), Vector2(1, 2), Vector2(2, 1), Vector2(1, 0)]
const SLOT_ACTIONS: Array[String] = ["item_1", "item_2", "item_3", "super"]
const SUPER_SLOT: int = 3
## Key prompt chip, tucked on the slot's lower-right edge.
const KEY_CHIP_OFFSET: Vector2 = Vector2(46, 52)
const ARMED_SCALE: float = 1.25
const SUPER_COOLDOWN_ALPHA: float = 0.45
const RING_WIDTH: float = 6.0
const RING_SEGMENTS: int = 48
const RING_COLOR: Color = Color(1.0, 0.82, 0.3)
const RING_TRACK: Color = Color(1.0, 1.0, 1.0, 0.15)
## Camera-view hint ("LB  View") just above the pad.
const VIEW_HINT_POS: Vector2 = Vector2(0, -58)

var player_id: int = 0
var _slots: Array[PanelContainer] = []
var _icons: Array[TextureRect] = []
var _prompts: Array[Label] = []
var _view_prompt: Label = null
var _countdown: Label = null
var _ring: Control = null
var _super_ready_at: float = 0.0
var _super_cooldown: float = 1.0


func setup(pid: int) -> void:
	player_id = pid
	for slot: int in SLOT_GRID_POS.size():
		_add_slot(slot)
	_add_view_hint()
	_countdown = Label.new()
	_countdown.theme_type_variation = &"HudValueLabel"
	_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_slots[SUPER_SLOT].add_child(_countdown)
	# Sibling over the slot (a child would be pushed off-centre by the panel's margins).
	_ring = Control.new()
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(_draw_ring)
	add_child(_ring)
	set_items([])
	refresh_prompts()
	InputManager.bindings_changed.connect(refresh_prompts)


func _add_slot(slot: int) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.theme_type_variation = &"SuperSlot" if slot == SUPER_SLOT else &"ItemSlot"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = SLOT_GRID_POS[slot] * SLOT_SIZE + Vector2.ONE * (SLOT_SIZE - SLOT_DIAMETER) * 0.5
	panel.size = Vector2.ONE * SLOT_DIAMETER
	var icon: TextureRect = TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2.ONE * SLOT_ICON_SIZE
	panel.add_child(icon)
	add_child(panel)
	var prompt: Label = Label.new()
	prompt.theme_type_variation = &"KeyChip"
	prompt.position = panel.position + KEY_CHIP_OFFSET
	add_child(prompt)
	_slots.append(panel)
	_icons.append(icon)
	_prompts.append(prompt)


func _add_view_hint() -> void:
	var hint: PanelContainer = PanelContainer.new()
	hint.theme_type_variation = &"HudPanel"
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.position = VIEW_HINT_POS
	var row: HBoxContainer = HBoxContainer.new()
	_view_prompt = Label.new()
	_view_prompt.theme_type_variation = &"KeyChip"
	_view_prompt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_view_prompt)
	var text: Label = Label.new()
	text.theme_type_variation = &"SubtleLabel"
	text.text = "ACTION_VIEW"
	row.add_child(text)
	hint.add_child(row)
	add_child(hint)


## Key/button names follow the current bindings and device.
func refresh_prompts() -> void:
	for slot: int in _prompts.size():
		_prompts[slot].text = InputManager.prompt_text(player_id, SLOT_ACTIONS[slot])
	_view_prompt.text = InputManager.prompt_text(player_id, "toggle_view")


func prompt(slot: int) -> String:
	return _prompts[slot].text


## [param items] holds one PowerUpType per item slot (NONE = empty).
func set_items(items: Array) -> void:
	for slot: int in Constants.ITEM_SLOT_COUNT:
		var type: int = items[slot] if slot < items.size() else Constants.PowerUpType.NONE
		var empty: bool = type == Constants.PowerUpType.NONE
		_icons[slot].texture = null if empty else ItemCatalog.ICONS.get(type)
		_slots[slot].theme_type_variation = &"ItemSlot" if empty else &"ItemSlotFull"


func flash(slot: int) -> void:
	UiMotion.pulse(_slots[slot])


func set_superpower(trait_type: int, ready_in: float) -> void:
	_icons[SUPER_SLOT].texture = ItemCatalog.SUPER_ICONS.get(trait_type)
	_super_ready_at = GameManager.game_time() + ready_in
	_super_cooldown = ready_in


## Mouse player: enlarge the armed slot (SUPER_SLOT = superpower).
func set_armed(slot: int) -> void:
	for n: int in _slots.size():
		_slots[n].pivot_offset = _slots[n].size * 0.5
		_slots[n].scale = Vector2.ONE * (ARMED_SCALE if n == slot else 1.0)


func _process(_delta: float) -> void:
	var left: float = _super_ready_at - GameManager.game_time()
	var charging: bool = left > 0.0
	if not charging and _countdown.visible:
		flash(SUPER_SLOT)
	_countdown.visible = charging
	_countdown.text = str(ceili(left))
	_icons[SUPER_SLOT].modulate.a = SUPER_COOLDOWN_ALPHA if charging else 1.0
	var slot: PanelContainer = _slots[SUPER_SLOT]
	_ring.position = slot.position
	_ring.size = slot.size
	_ring.pivot_offset = slot.pivot_offset
	_ring.scale = slot.scale  # Follows the slot's pulse / armed enlargement.
	_ring.queue_redraw()


## Recharge progress as a ring that fills clockwise around the superpower slot.
func _draw_ring() -> void:
	var left: float = _super_ready_at - GameManager.game_time()
	if left <= 0.0:
		return
	var center: Vector2 = _ring.size * 0.5
	var radius: float = SLOT_DIAMETER * 0.5 - RING_WIDTH * 0.5
	var done: float = 1.0 - left / maxf(_super_cooldown, 0.01)
	_ring.draw_arc(center, radius, 0.0, TAU, RING_SEGMENTS, RING_TRACK, RING_WIDTH, true)
	_ring.draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * done, RING_SEGMENTS, RING_COLOR, RING_WIDTH, true)
