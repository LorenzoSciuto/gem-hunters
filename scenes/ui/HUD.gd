## HUD.gd
## Per-player heads-up display inside one split-screen SubViewport:
## gem count, rank, current arena zone, goal progress, clock, item slots + superpower (laid out like
## the pad's face buttons; the mouse player's armed slot is enlarged), the reveal mini-map and debuff overlays.
## Purely reactive: SplitScreenManager wires the player's signals in, and the
## HUD listens to GameManager for scores and the clock.
extends CanvasLayer

const SHADER_SPLAT: Shader = preload("res://shaders/splat_overlay.gdshader")
const SHADER_ICE: Shader = preload("res://shaders/ice_overlay.gdshader")
## Item slots and the superpower sit like the pad's face buttons:
## X left, A bottom, B right (items 1-3), Y top (superpower).
const SLOT_SIZE: float = 86.0
## Round slot inside its grid cell; the gap between cells keeps them apart.
const SLOT_DIAMETER: float = 78.0
const SLOT_ICON_SIZE: float = 56.0
## Key prompt chip, tucked on the slot's lower-right edge.
const KEY_CHIP_OFFSET: Vector2 = Vector2(46, 52)
## Superpower recharge ring drawn over the super slot.
const SUPER_RING_WIDTH: float = 6.0
const SUPER_RING_COLOR: Color = Color(1.0, 0.82, 0.3)
const SUPER_RING_TRACK: Color = Color(1.0, 1.0, 1.0, 0.15)
const SLOT_GRID_POS: Array[Vector2] = [Vector2(0, 1), Vector2(1, 2), Vector2(2, 1), Vector2(1, 0)]
const SLOT_ACTIONS: Array[String] = ["item_1", "item_2", "item_3", "super"]
const SUPER_SLOT: int = 3
## Camera-view hint ("LB  View") just above the item pad.
const VIEW_HINT_POS: Vector2 = Vector2(0, -58)
const SELECTED_SLOT_SCALE: float = 1.25
const SUPER_COOLDOWN_ALPHA: float = 0.45
const MAP_DOT_RADIUS: float = 9.0
const MAP_FADE: float = 0.3

const PULSE_SCALE: float = 1.35
const PULSE_DURATION: float = 0.15
const BANNER_HOLD: float = 2.0
## Banner styles by tone: neutral (items, superpowers), good (hits landed), bad (hits taken).
enum Tone { NEUTRAL, GOOD, BAD }
const BANNER_VARIATIONS: Array[StringName] = [&"BannerPanel", &"BannerPanelGood", &"BannerPanelBad"]
const LOW_TIME_COLOR: Color = Color(1.0, 0.35, 0.35)
const LEADER_COLOR: Color = Color(1.0, 0.85, 0.3)
const RANK_COLOR: Color = Color(0.85, 0.85, 0.95)
const COLOR_LAUGHING: Color = Color(1.0, 0.9, 0.2, 0.25)
const COLOR_CONFUSED: Color = Color(0.5, 0.2, 0.8, 0.35)
const OVERLAY_FADE: float = 0.25

@onready var effect_overlay: ColorRect = $EffectOverlay
@onready var badge: Label = $ScorePanel/VBox/Row/Badge
@onready var gem_count_label: Label = $ScorePanel/VBox/Row/GemCount
@onready var rank_label: Label = $ScorePanel/VBox/Row/Rank
@onready var goal_bar: ProgressBar = $ScorePanel/VBox/GoalBar
@onready var zone_label: Label = $ScorePanel/VBox/ZoneLabel
@onready var timer_label: Label = $TimerPanel/TimerLabel
@onready var item_pad: Control = $ItemPad
@onready var mini_map: Control = $MiniMap
@onready var map_camera: Camera3D = $MiniMap/View/SubViewport/Camera
@onready var map_dots: Control = $MiniMap/Dots
@onready var banner_panel: PanelContainer = $BannerContainer/PowerupBanner
@onready var banner_label: Label = $BannerContainer/PowerupBanner/Row/BannerLabel
@onready var banner_icon: TextureRect = $BannerContainer/PowerupBanner/Row/BannerIcon
@onready var crosshair: Label = $Crosshair

var player_id: int = 0
var _effect_tween: Tween = null
var _banner_tween: Tween = null
var _map_tween: Tween = null
var _slot_panels: Array[PanelContainer] = []
var _slot_icons: Array[TextureRect] = []
var _slot_labels: Array[Label] = []
var _super_timer: Label = null
var _super_ring: Control = null
var _super_cooldown: float = 1.0
var _view_chip: Label = null
var _super_ready_at: float = 0.0
var _player: Player = null
var _zone: int = -1


func _ready() -> void:
	effect_overlay.modulate.a = 0.0
	GameManager.score_updated.connect(_on_score_updated)
	GameManager.timer_updated.connect(_on_timer_updated)
	InputManager.bindings_changed.connect(_refresh_slot_labels)
	map_dots.draw.connect(_draw_map_dots)
	_build_item_pad()


func setup(pid: int, color: Color) -> void:
	player_id = pid
	badge.text = tr("UI_PLAYER_SHORT").format([pid + 1])
	badge.modulate = color
	var score_mode: bool = GameManager.match_mode == Constants.MatchMode.SCORE
	goal_bar.visible = score_mode
	goal_bar.max_value = GameManager.match_target
	_on_timer_updated(float(GameManager.match_target) if not score_mode else 0.0)
	_on_score_updated(pid, 0)
	_refresh_slot_labels()
	var config: LevelConfig = GameManager.level_config
	map_camera.frame_arena(maxf(config.columns, config.rows) * config.cell_size)


func set_crosshair_visible(shown: bool) -> void:
	crosshair.visible = shown


# ─── Score & clock ────────────────────────────────────────────────────────

func _on_score_updated(pid: int, new_score: int) -> void:
	if pid == player_id:
		gem_count_label.text = str(new_score)
		goal_bar.value = new_score
		_pulse(gem_count_label)
	# Tied players share a rank: 1 + number of players strictly ahead.
	var mine: int = GameManager.get_score(player_id)
	var ahead: int = 0
	for entry: Dictionary in GameManager.get_standings():
		if entry["score"] > mine:
			ahead += 1
	rank_label.text = "#%d" % (ahead + 1)
	rank_label.modulate = LEADER_COLOR if GameManager.get_leader() == player_id else RANK_COLOR


func _on_timer_updated(seconds: float) -> void:
	var total: int = int(ceilf(seconds))
	timer_label.text = "%d:%02d" % [total / 60, total % 60]
	var low: bool = GameManager.match_mode == Constants.MatchMode.TIME \
		and seconds <= Constants.FRENZY_TIME_REMAINING
	timer_label.modulate = LOW_TIME_COLOR if low else Color.WHITE


func _pulse(control: Control) -> void:
	control.pivot_offset = control.size * 0.5
	var tween: Tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(control, "scale", Vector2.ONE * PULSE_SCALE, PULSE_DURATION * 0.5)
	tween.tween_property(control, "scale", Vector2.ONE, PULSE_DURATION * 0.5)


# ─── Items & superpower ───────────────────────────────────────────────────

func _build_item_pad() -> void:
	var inset: float = (SLOT_SIZE - SLOT_DIAMETER) * 0.5
	for slot: int in SLOT_GRID_POS.size():
		var panel: PanelContainer = PanelContainer.new()
		panel.theme_type_variation = &"SuperSlot" if slot == SUPER_SLOT else &"ItemSlot"
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.position = SLOT_GRID_POS[slot] * SLOT_SIZE + Vector2.ONE * inset
		panel.size = Vector2.ONE * SLOT_DIAMETER
		var icon: TextureRect = TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2.ONE * SLOT_ICON_SIZE
		panel.add_child(icon)
		item_pad.add_child(panel)
		var label: Label = Label.new()
		label.theme_type_variation = &"KeyChip"
		label.position = panel.position + KEY_CHIP_OFFSET
		item_pad.add_child(label)
		_slot_panels.append(panel)
		_slot_icons.append(icon)
		_slot_labels.append(label)
	var hint: PanelContainer = PanelContainer.new()
	hint.theme_type_variation = &"HudPanel"
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.position = VIEW_HINT_POS
	var row: HBoxContainer = HBoxContainer.new()
	_view_chip = Label.new()
	_view_chip.theme_type_variation = &"KeyChip"
	_view_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_view_chip)
	var hint_text: Label = Label.new()
	hint_text.theme_type_variation = &"SubtleLabel"
	hint_text.text = "ACTION_VIEW"
	row.add_child(hint_text)
	hint.add_child(row)
	item_pad.add_child(hint)
	_super_timer = Label.new()
	_super_timer.theme_type_variation = &"HudValueLabel"
	_super_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_super_timer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_super_timer.visible = false
	_slot_panels[SUPER_SLOT].add_child(_super_timer)
	_super_ring = Control.new()
	_super_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_super_ring.draw.connect(_draw_super_ring)
	_slot_panels[SUPER_SLOT].add_child(_super_ring)
	update_inventory(player_id, [])


## Recharge progress as a ring that fills clockwise around the super slot.
func _draw_super_ring() -> void:
	var left: float = _super_ready_at - Time.get_ticks_msec() / 1000.0
	if left <= 0.0:
		return
	var center: Vector2 = _super_ring.size * 0.5
	var radius: float = SLOT_DIAMETER * 0.5 - SUPER_RING_WIDTH * 0.5
	var done: float = 1.0 - left / maxf(_super_cooldown, 0.01)
	_super_ring.draw_arc(center, radius, 0.0, TAU, 48, SUPER_RING_TRACK, SUPER_RING_WIDTH, true)
	_super_ring.draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * done, 48, SUPER_RING_COLOR, SUPER_RING_WIDTH, true)


func _refresh_slot_labels() -> void:
	for slot: int in _slot_labels.size():
		_slot_labels[slot].text = InputManager.prompt_text(player_id, SLOT_ACTIONS[slot])
	_view_chip.text = InputManager.prompt_text(player_id, "toggle_view")


## Player.inventory_changed: redraw the three item slots.
func update_inventory(pid: int, slots: Array) -> void:
	if pid != player_id:
		return
	for slot: int in Constants.ITEM_SLOT_COUNT:
		var type: int = slots[slot] if slot < slots.size() else Constants.PowerUpType.NONE
		var empty: bool = type == Constants.PowerUpType.NONE
		_slot_icons[slot].texture = null if empty else ItemCatalog.ICONS.get(type)
		_slot_panels[slot].theme_type_variation = &"ItemSlot" if empty else &"ItemSlotFull"


## Player.item_received: announce the new item and what it does.
func show_item_received(pid: int, slot: int, type: int) -> void:
	if pid != player_id:
		return
	_pulse(_slot_panels[slot])
	_show_banner("%s  [%s]\n%s" % [tr(ItemCatalog.NAME_KEYS[type]), _slot_labels[slot].text,
		tr(ItemCatalog.NAME_KEYS[type] + "_DESC")], ItemCatalog.ICONS.get(type))


## Player.powerup_activated: a utility item took effect.
func show_activated(pid: int, type: int) -> void:
	if pid == player_id:
		_show_banner(tr(ItemCatalog.NAME_KEYS[type]), ItemCatalog.ICONS.get(type))


## Player.superpower_changed: set the icon and start the recharge countdown.
func update_superpower(pid: int, trait_type: int, ready_in: float) -> void:
	if pid != player_id:
		return
	_slot_icons[SUPER_SLOT].texture = ItemCatalog.SUPER_ICONS.get(trait_type)
	_super_ready_at = Time.get_ticks_msec() / 1000.0 + ready_in
	_super_cooldown = ready_in


func show_superpower_used(pid: int, trait_type: int) -> void:
	if pid == player_id:
		_show_banner(tr(CharacterData.SUPER_KEYS[trait_type]), ItemCatalog.SUPER_ICONS.get(trait_type))


func show_items_stripped(pid: int) -> void:
	if pid == player_id:
		_show_banner(tr("MSG_ITEMS_STRIPPED"), null, Tone.BAD)


## A hit this hunter gave ([param attacker]) or took, with the gems involved.
func show_impact(attacker: bool, gems: int) -> void:
	var title: String = tr("MSG_HIT") if attacker else tr("MSG_HIT_TAKEN")
	if gems > 0:
		title += "  %s%d" % ["+" if attacker else "-", gems]
	_show_banner(title, null, Tone.GOOD if attacker else Tone.BAD)


## Shown at "GO!": how to tackle.
func show_tip() -> void:
	_show_banner(tr("MSG_TACKLE_TIP"))


## Player.selection_changed: the mouse wheel armed another slot (3 = superpower).
func update_selection(pid: int, slot: int) -> void:
	if pid != player_id:
		return
	for n: int in _slot_panels.size():
		_slot_panels[n].pivot_offset = _slot_panels[n].size * 0.5
		_slot_panels[n].scale = Vector2.ONE * (SELECTED_SLOT_SCALE if n == slot else 1.0)


func _process(_delta: float) -> void:
	var left: float = _super_ready_at - Time.get_ticks_msec() / 1000.0
	var charging: bool = left > 0.0
	if not charging and _super_timer.visible:
		_pulse(_slot_panels[SUPER_SLOT])
	_super_timer.visible = charging
	_super_timer.text = str(ceili(left))
	_slot_icons[SUPER_SLOT].modulate.a = SUPER_COOLDOWN_ALPHA if charging else 1.0
	_super_ring.size = _slot_panels[SUPER_SLOT].size
	_super_ring.queue_redraw()
	if mini_map.visible:
		map_dots.queue_redraw()
	_update_zone()


## Names the zone this player is in, in its color, so rivals can read it at a glance.
func _update_zone() -> void:
	if _player == null:
		for node: Node in get_tree().get_nodes_in_group(Constants.GROUP_PLAYERS):
			if (node as Player).player_id == player_id:
				_player = node as Player
		return
	var zone: int = MazeLevel.zone_of(_player.global_position, GameManager.level_config)
	if zone == _zone:
		return
	_zone = zone
	zone_label.text = tr(MazeLevel.ZONE_KEYS[zone])
	zone_label.modulate = MazeLevel.ZONE_COLORS[zone].lightened(0.25)
	_pulse(zone_label)


# ─── Mini-map ─────────────────────────────────────────────────────────────

## Player.map_reveal_requested: show the top-down map with everyone on it.
func show_map(pid: int, duration: float) -> void:
	if pid != player_id:
		return
	if _map_tween and _map_tween.is_valid():
		_map_tween.kill()
	mini_map.visible = true
	_map_tween = create_tween()
	_map_tween.tween_property(mini_map, "modulate:a", 1.0, MAP_FADE)
	_map_tween.tween_interval(duration)
	_map_tween.tween_property(mini_map, "modulate:a", 0.0, MAP_FADE)
	_map_tween.tween_callback(func() -> void: mini_map.visible = false)


func _draw_map_dots() -> void:
	var view: Vector2 = Vector2(map_camera.get_viewport().size)
	var scale_to_panel: Vector2 = map_dots.size / view
	for node: Node in get_tree().get_nodes_in_group(Constants.GROUP_PLAYERS):
		var player: Player = node as Player
		var at: Vector2 = map_camera.unproject_position(player.global_position) * scale_to_panel
		var radius: float = MAP_DOT_RADIUS * (1.5 if player.player_id == player_id else 1.0)
		map_dots.draw_circle(at, radius + 2.0, Color.BLACK)
		map_dots.draw_circle(at, radius, Constants.PLAYER_COLORS[player.player_id])


## Toast under the top bar: [param icon] (optional) beside the text, colour by [param tone].
func _show_banner(text: String, icon: Texture2D = null, tone: Tone = Tone.NEUTRAL) -> void:
	if _banner_tween and _banner_tween.is_valid():
		_banner_tween.kill()
	banner_label.text = text
	banner_icon.texture = icon
	banner_icon.visible = icon != null
	banner_panel.theme_type_variation = BANNER_VARIATIONS[tone]
	banner_panel.visible = true
	banner_panel.modulate.a = 0.0
	banner_panel.pivot_offset = banner_panel.size * 0.5
	banner_panel.scale = Vector2.ONE * 0.6
	_banner_tween = create_tween()
	_banner_tween.tween_property(banner_panel, "modulate:a", 1.0, 0.2)
	_banner_tween.parallel().tween_property(banner_panel, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_interval(BANNER_HOLD)
	_banner_tween.tween_property(banner_panel, "modulate:a", 0.0, 0.4)
	_banner_tween.tween_callback(func() -> void: banner_panel.visible = false)


# ─── Debuff overlays ──────────────────────────────────────────────────────

## Player.debuff_cleared: broke free of the ice early, so drop the frost now
## (unless an ice slide still keeps it up).
func clear_screen_effect(pid: int, debuff_type: int) -> void:
	if pid != player_id or debuff_type != Constants.DebuffType.FROZEN or _player == null \
			or _player.has_debuff(Constants.DebuffType.ICE_SLIDE) or effect_overlay.material == null:
		return
	if _effect_tween and _effect_tween.is_valid():
		_effect_tween.kill()
	var mat: ShaderMaterial = effect_overlay.material as ShaderMaterial
	_effect_tween = create_tween()
	_effect_tween.tween_method(func(v: float) -> void: mat.set_shader_parameter("intensity", v), 1.0, 0.0, OVERLAY_FADE)
	_effect_tween.tween_callback(func() -> void:
		effect_overlay.material = null
		effect_overlay.modulate.a = 0.0)

## Player.screen_effect_requested: fade a full-screen overlay in and out.
func show_screen_effect(pid: int, debuff_type: int, duration: float) -> void:
	if pid != player_id:
		return
	if _effect_tween and _effect_tween.is_valid():
		_effect_tween.kill()
	_effect_tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	var shader_param: String = ""
	var mat: ShaderMaterial = null
	match debuff_type:
		Constants.DebuffType.SPLAT:
			mat = ShaderMaterial.new()
			mat.shader = SHADER_SPLAT
			mat.set_shader_parameter("tint_color", Color(1.0, 0.45, 0.75, 1.0))
			shader_param = "progress"
		Constants.DebuffType.FROZEN, Constants.DebuffType.ICE_SLIDE:
			if debuff_type == Constants.DebuffType.FROZEN:
				_show_banner(tr("MSG_BREAK_FREE").format([InputManager.prompt_text(player_id, "jump")]), null, Tone.BAD)
			mat = ShaderMaterial.new()
			mat.shader = SHADER_ICE
			mat.set_shader_parameter("frost_color", Color(0.65, 0.9, 1.0, 0.85))
			shader_param = "intensity"

	if mat:
		mat.set_shader_parameter(shader_param, 1.0)
		effect_overlay.material = mat
		effect_overlay.modulate.a = 1.0
		_effect_tween.tween_interval(maxf(0.0, duration - 1.0))
		_effect_tween.tween_method(func(v: float) -> void: mat.set_shader_parameter(shader_param, v), 1.0, 0.0, 1.0)
		_effect_tween.tween_callback(func() -> void:
			effect_overlay.material = null
			effect_overlay.modulate.a = 0.0)
		return

	effect_overlay.material = null
	var tint: Color = COLOR_LAUGHING if debuff_type == Constants.DebuffType.LAUGHING else COLOR_CONFUSED
	effect_overlay.color = Color(tint, 1.0)
	_effect_tween.tween_property(effect_overlay, "modulate:a", tint.a, OVERLAY_FADE)
	_effect_tween.tween_interval(maxf(0.0, duration - OVERLAY_FADE * 2.0))
	_effect_tween.tween_property(effect_overlay, "modulate:a", 0.0, OVERLAY_FADE)
