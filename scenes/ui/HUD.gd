## HUD.gd
## One hunter's heads-up display inside their split-screen view: gems, rank,
## zone, goal bar, clock and (survival) lives, plus the components
##   ItemPad (item slots + superpower), Toast (messages), MiniMap (radar),
##   DebuffOverlay (full-screen debuff effects), LivesRow (hearts),
##   CollectionRow (collector mode colours).
## SplitScreenManager connects only this hunter's signals to it; GameManager
## drives scores, lives, the clock and match-wide events.
extends CanvasLayer

const LOW_TIME_COLOR: Color = Color(1.0, 0.35, 0.35)
const LEADER_COLOR: Color = Color(1.0, 0.85, 0.3)
const RANK_COLOR: Color = Color(0.85, 0.85, 0.95)
const ZONE_LIGHTEN: float = 0.25
## Zone index shown while the hunter is outside the outer walls.
const ZONE_OUTSIDE: int = -2
const OUTSIDE_COLOR: Color = Color(1.0, 0.8, 0.2)
## The knocked-out message stays up for the rest of the match.
const ELIMINATED_HOLD: float = 3600.0
## Touch screens: the item pad moves to the right thumb and grows to finger size.
const TOUCH_PAD_SCALE: float = 1.6
const TOUCH_PAD_MARGIN: float = 24.0

@onready var overlay: DebuffOverlay = $EffectOverlay
@onready var badge: Label = $ScorePanel/VBox/Row/Badge
@onready var gem_count_label: Label = $ScorePanel/VBox/Row/GemCount
@onready var rank_label: Label = $ScorePanel/VBox/Row/Rank
@onready var goal_bar: ProgressBar = $ScorePanel/VBox/GoalBar
@onready var zone_label: Label = $ScorePanel/VBox/ZoneLabel
@onready var timer_label: Label = $TimerPanel/TimerLabel
@onready var item_pad: ItemPad = $ItemPad
@onready var mini_map: MiniMap = $MiniMap
@onready var toast: Toast = $BannerContainer/PowerupBanner
@onready var crosshair: Label = $Crosshair

var player_id: int = 0
var _player: Player = null
var _zone: int = -1


func setup(player: Player, color: Color) -> void:
	_player = player
	player_id = player.player_id
	badge.text = tr("UI_PLAYER_SHORT").format([player_id + 1])
	badge.modulate = color
	# Survival: the bar fills toward the next life bought with gems.
	goal_bar.visible = GameManager.match_mode == Constants.MatchMode.SCORE or GameManager.is_survival()
	goal_bar.max_value = Constants.GEMS_PER_LIFE if GameManager.is_survival() else GameManager.match_target
	_on_timer_updated(float(GameManager.match_target) if GameManager.match_mode == Constants.MatchMode.TIME else 0.0)
	if GameManager.is_survival():
		var lives: LivesRow = LivesRow.new()
		lives.setup(player_id)
		zone_label.add_sibling(lives)
		zone_label.get_parent().move_child(lives, zone_label.get_index())
	if GameManager.is_collector():
		var collection: CollectionRow = CollectionRow.new()
		collection.setup(player_id)
		goal_bar.add_sibling(collection)
		GameManager.collection_completed.connect(_on_collection_completed)
		GameManager.collections_reset.connect(_on_collections_reset)
	item_pad.setup(player_id)
	if InputManager.touch_active and player_id == InputManager.KEYBOARD_PLAYER:
		item_pad.make_touchable()
		item_pad.pivot_offset = item_pad.size
		item_pad.scale = Vector2.ONE * TOUCH_PAD_SCALE
		item_pad.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_KEEP_SIZE, int(TOUCH_PAD_MARGIN))
	var config: LevelConfig = GameManager.level_config
	mini_map.setup(player_id, maxf(config.columns, config.rows) * config.cell_size)
	_on_score_updated(player_id, 0)
	GameManager.score_updated.connect(_on_score_updated)
	GameManager.lives_changed.connect(func(_pid: int, _lives: int) -> void: _update_rank())
	GameManager.timer_updated.connect(_on_timer_updated)
	GameManager.chaos_gem_appeared.connect(func() -> void: toast.show_message(tr("MSG_CHAOS_APPEARED")))
	GameManager.chaos_gem_taken.connect(_on_chaos_gem_taken)


func set_crosshair_visible(shown: bool) -> void:
	crosshair.visible = shown


func _process(_delta: float) -> void:
	_update_zone()


# ─── Score, rank, clock, zone ─────────────────────────────────────────────

func _on_score_updated(pid: int, new_score: int) -> void:
	if pid == player_id:
		gem_count_label.text = str(new_score)
		goal_bar.value = new_score
		UiMotion.pulse(gem_count_label)
	_update_rank()


## Tied hunters share a rank: 1 + number strictly ahead (on lives first in
## survival, then gems).
func _update_rank() -> void:
	var survival: bool = GameManager.is_survival()
	var my_lives: int = GameManager.get_lives(player_id)
	var my_gems: int = GameManager.get_score(player_id)
	var ahead: int = 0
	for entry: Dictionary in GameManager.get_standings():
		if survival and entry["lives"] != my_lives:
			ahead += 1 if entry["lives"] > my_lives else 0
		elif entry["score"] > my_gems:
			ahead += 1
	rank_label.text = "#%d" % (ahead + 1)
	rank_label.modulate = LEADER_COLOR if GameManager.get_leader() == player_id else RANK_COLOR


func _on_timer_updated(seconds: float) -> void:
	timer_label.text = GameManager.clock_text(seconds)
	if GameManager.is_frenzy():
		timer_label.text += tr("HUD_FRENZY_TAG")
	var low: bool = GameManager.match_mode == Constants.MatchMode.TIME and seconds <= Constants.FRENZY_TIME_REMAINING
	timer_label.modulate = LOW_TIME_COLOR if low else Color.WHITE


## Names the zone this hunter is in, in its colour, so rivals can read it at a glance.
func _update_zone() -> void:
	if _player == null or not _player.is_inside_tree():
		return
	var level: LevelConfig = GameManager.level_config
	var zone: int = ZONE_OUTSIDE if MazeLevel.is_outside(_player.global_position, level) \
		else MazeLevel.zone_of(_player.global_position, level)
	if zone == _zone:
		return
	_zone = zone
	if zone == ZONE_OUTSIDE:
		zone_label.text = tr("ZONE_OUTSIDE")
		zone_label.modulate = OUTSIDE_COLOR
		toast.show_message(tr("MSG_OUTSIDE"), null, Toast.Tone.BAD)
	else:
		zone_label.text = tr(MazeLevel.ZONE_KEYS[zone])
		zone_label.modulate = MazeLevel.ZONE_COLORS[zone].lightened(ZONE_LIGHTEN)
	UiMotion.pulse(zone_label)


# ─── Items & superpower (PlayerItems signals) ─────────────────────────────

func update_inventory(_pid: int, slots: Array) -> void:
	item_pad.set_items(slots)


## A gift box filled [param slot]: announce the item and what it does.
func show_item_received(_pid: int, slot: int, type: int) -> void:
	item_pad.flash(slot)
	var name: String = tr(ItemCatalog.NAME_KEYS[type])
	toast.show_message("%s  [%s]\n%s" % [name, item_pad.prompt(slot), tr(ItemCatalog.NAME_KEYS[type] + "_DESC")],
		ItemCatalog.ICONS.get(type))


func show_activated(_pid: int, type: int) -> void:
	toast.show_message(tr(ItemCatalog.NAME_KEYS[type]), ItemCatalog.ICONS.get(type))


func update_superpower(_pid: int, superpower: int, ready_in: float) -> void:
	item_pad.set_superpower(superpower, ready_in)


func show_superpower_used(_pid: int, superpower: int) -> void:
	toast.show_message(tr(CharacterData.SUPER_KEYS[superpower]), ItemCatalog.SUPER_ICONS.get(superpower))


func show_items_stripped(_pid: int) -> void:
	toast.show_message(tr("MSG_ITEMS_STRIPPED"), null, Toast.Tone.BAD)


func update_selection(_pid: int, slot: int) -> void:
	item_pad.set_armed(slot)


# ─── Status (PlayerStatus signals) ────────────────────────────────────────

func show_screen_effect(_pid: int, debuff_type: int, duration: float) -> void:
	overlay.show_effect(debuff_type, duration)
	if debuff_type == Constants.DebuffType.FROZEN:
		toast.show_message(tr("MSG_BREAK_FREE").format([InputManager.prompt_text(player_id, "jump")]), null, Toast.Tone.BAD)


## Broke free of the ice: drop the frost now, unless an ice slide keeps it up.
func clear_screen_effect(_pid: int, debuff_type: int) -> void:
	if debuff_type == Constants.DebuffType.FROZEN and not _player.status.has(Constants.DebuffType.ICE_SLIDE):
		overlay.clear_frost()


# ─── Messages ─────────────────────────────────────────────────────────────

## A hit this hunter gave ([param attacker]) or took, with the gems involved.
func show_impact(attacker: bool, gems: int) -> void:
	var title: String = tr("MSG_HIT") if attacker else tr("MSG_HIT_TAKEN")
	if gems > 0:
		title += "  %s%d" % ["+" if attacker else "-", gems]
	toast.show_message(title, null, Toast.Tone.GOOD if attacker else Toast.Tone.BAD)


func show_notice(_pid: int, message_key: String, good: bool) -> void:
	toast.show_message(tr(message_key), null, Toast.Tone.GOOD if good else Toast.Tone.BAD)


func show_map(_pid: int, duration: float) -> void:
	mini_map.show_for(duration)


## Shown at "GO!": how to tackle.
func show_tip() -> void:
	toast.show_message(tr("MSG_TACKLE_TIP"))


## Survival: this hunter is out; the screen now follows a survivor.
## Match over, on this hunter's own screen: won, lost or a draw ([param winner_id] -1).
func show_result(winner_id: int, hold: float) -> void:
	if winner_id < 0:
		toast.show_message(tr("MSG_DRAW"), null, Toast.Tone.NEUTRAL, hold)
	elif winner_id == player_id:
		toast.show_message(tr("MSG_YOU_WIN"), null, Toast.Tone.GOOD, hold)
	else:
		toast.show_message(tr("MSG_YOU_LOSE"), null, Toast.Tone.BAD, hold)


func show_eliminated() -> void:
	toast.show_message(tr("MSG_ELIMINATED"), null, Toast.Tone.BAD, ELIMINATED_HOLD)


func _on_collection_completed(pid: int) -> void:
	if pid == player_id:
		toast.show_message(tr("MSG_COLLECT_COMPLETE_MINE"), null, Toast.Tone.GOOD)
	else:
		toast.show_message(tr("MSG_COLLECT_COMPLETE_THEIRS").format([pid + 1]), null, Toast.Tone.BAD)


func _on_collections_reset(pid: int) -> void:
	toast.show_message(tr("MSG_COLLECT_RESET").format([pid + 1]), null,
		Toast.Tone.GOOD if pid == player_id else Toast.Tone.BAD)


func _on_chaos_gem_taken(finder_id: int, lost: Dictionary) -> void:
	if finder_id == player_id:
		toast.show_message(tr("MSG_CHAOS_MINE"), null, Toast.Tone.GOOD)
	else:
		toast.show_message(tr("MSG_CHAOS_THEIRS").format([finder_id + 1, lost.get(player_id, 0)]), null, Toast.Tone.BAD)
