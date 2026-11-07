## SplitScreenManager.gd
## Composition root of a match.
##
##   _ready() → build arena + gem spawner → spawn players → cameras → HUDs
##            → overview panel (3P) → character selection (or reuse on rematch)
##            → GameManager countdown → PLAYING → match_ended → GameOverScreen
extends Node3D

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/Player.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/HUD.tscn")
const CAMERA_RIG_SCENE: PackedScene = preload("res://scenes/camera/CameraRig.tscn")
const SCOREBOARD_SCENE: PackedScene = preload("res://scenes/ui/Scoreboard.tscn")
const OVERVIEW_CAMERA_SCENE: PackedScene = preload("res://scenes/camera/OverviewCamera.tscn")
const CHARACTER_SELECTOR_SCENE: PackedScene = preload("res://scenes/ui/CharacterSelector.tscn")
const GEM_SPAWNER_SCENE: PackedScene = preload("res://scenes/gems/GemSpawner.tscn")
const GAME_OVER_SCENE: String = "res://scenes/ui/GameOverScreen.tscn"
const MAIN_MENU_SCENE: String = "res://scenes/ui/MainMenu.tscn"

const SLOT_COUNT: int = 4
## Pause after everyone is ready so the READY badges are visible.
const READY_DELAY: float = 0.8
## Celebration time on the arena before the results screen.
const WINNER_DISPLAY_DURATION: float = 3.5
## Camera jolt for the hunter who lands a hit and, harder, for the one hit.
const ATTACKER_SHAKE: float = 0.12
const VICTIM_SHAKE: float = 0.3
## 2D (HUD, selection cards) is drawn this much smaller in the quarter-screen
## views of a 3-4 player match, so it doesn't crowd the action.
const QUARTER_UI_SCALE: float = 0.68

@onready var world: Node3D = $World
@onready var viewport_grid: GridContainer = $ViewportGrid
@onready var overlay: CanvasLayer = $MatchOverlay
@onready var _sv_containers: Array[SubViewportContainer] = [
	$ViewportGrid/SVContainer0, $ViewportGrid/SVContainer1,
	$ViewportGrid/SVContainer2, $ViewportGrid/SVContainer3,
]
@onready var _subviewports: Array[SubViewport] = [
	$ViewportGrid/SVContainer0/SubViewport0, $ViewportGrid/SVContainer1/SubViewport1,
	$ViewportGrid/SVContainer2/SubViewport2, $ViewportGrid/SVContainer3/SubViewport3,
]

var _players: Array[Player] = []
var _huds: Array[CanvasLayer] = []
var _selectors: Array[Control] = []
var _cameras: Array[CameraRig] = []
## Bumped on every lock / unlock so a pending "everyone ready" start is dropped
## when someone changes their mind during READY_DELAY.
var _ready_token: int = 0


func _ready() -> void:
	_build_arena()
	InputManager.auto_configure_devices()
	var count: int = GameManager.get_num_players()
	_configure_layout(count)
	_spawn_players(count)
	_bind_huds()
	_setup_overview_panel()

	GameManager.countdown_tick.connect(overlay.show_countdown)
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.leader_changed.connect(_on_leader_changed)
	GameManager.frenzy_started.connect(_on_frenzy_started)
	GameManager.timer_updated.connect(_on_timer_updated)
	GameManager.match_ended.connect(_on_match_ended)
	GameManager.player_eliminated.connect(_on_player_eliminated)

	if GameManager.chosen_characters.size() == count:
		_start_with_chosen_characters()
	else:
		_setup_character_selectors()


func _build_arena() -> void:
	if GameManager.level_config == null:
		GameManager.level_config = load(Constants.LEVEL_CONFIGS[0]) as LevelConfig
	var level: MazeLevel = MazeLevel.new()
	level.config = GameManager.level_config
	world.add_child(level)
	# The spawner reads the level's gem markers in _ready, so it must come after.
	world.add_child(GEM_SPAWNER_SCENE.instantiate())


## 2 players: side by side. 3–4 players: 2×2 grid (slot 4 is the overview in 3P),
## with the 2D layer of each quarter rendered on a larger virtual canvas and
## scaled down (anchors keep working; the 3D view is unaffected).
func _configure_layout(num_players: int) -> void:
	viewport_grid.columns = 2
	for i: int in SLOT_COUNT:
		_sv_containers[i].visible = num_players > 2 or i < 2
		if num_players > 2:
			var viewport: SubViewport = _subviewports[i]
			viewport.size_2d_override_stretch = true
			viewport.size_changed.connect(func() -> void:
				viewport.size_2d_override = Vector2i(Vector2(viewport.size) / QUARTER_UI_SCALE))


func _spawn_players(count: int) -> void:
	var spawn_points: Array[Node] = get_tree().get_nodes_in_group(Constants.GROUP_SPAWN_POINTS)
	for i: int in count:
		var player: Player = PLAYER_SCENE.instantiate() as Player
		world.add_child(player)
		var spawn: Node3D = spawn_points[i % spawn_points.size()] as Node3D
		player.global_position = Vector3(spawn.global_position.x, 0.0, spawn.global_position.z)
		player.global_rotation = Vector3(0.0, spawn.global_rotation.y, 0.0)
		player.initialize(i, Constants.PLAYER_COLORS[i])
		_players.append(player)

		var viewport: SubViewport = _subviewports[i]
		viewport.world_3d = get_viewport().world_3d
		var camera_rig: CameraRig = CAMERA_RIG_SCENE.instantiate() as CameraRig
		viewport.add_child(camera_rig)
		camera_rig.set_target(player.get_camera_target())
		camera_rig.set_cull_mask_value(Constants.NAME_TAG_LAYER_BASE + i + 1, false)
		_cameras.append(camera_rig)


func _bind_huds() -> void:
	for i: int in _players.size():
		var player: Player = _players[i]
		var hud: CanvasLayer = HUD_SCENE.instantiate() as CanvasLayer
		_subviewports[i].add_child(hud)
		hud.setup(player, Constants.PLAYER_COLORS[i])
		hud.visible = false
		player.items.inventory_changed.connect(hud.update_inventory)
		player.items.item_received.connect(hud.show_item_received)
		player.items.powerup_activated.connect(hud.show_activated)
		player.items.superpower_changed.connect(hud.update_superpower)
		player.items.superpower_used.connect(hud.show_superpower_used)
		player.items.items_stripped.connect(hud.show_items_stripped)
		player.items.selection_changed.connect(hud.update_selection)
		player.map_reveal_requested.connect(hud.show_map)
		player.combat.impact.connect(_on_impact)
		player.status.screen_effect_requested.connect(hud.show_screen_effect)
		player.status.debuff_cleared.connect(hud.clear_screen_effect)
		player.notice_requested.connect(hud.show_notice)
		player.view_changed.connect(_on_view_changed)
		_huds.append(hud)


## In 3-player mode the spare slot shows a top-down view and the live standings.
func _setup_overview_panel() -> void:
	if _players.size() != 3:
		return
	var viewport: SubViewport = _subviewports[3]
	viewport.world_3d = get_viewport().world_3d
	var camera: Camera3D = OVERVIEW_CAMERA_SCENE.instantiate() as Camera3D
	viewport.add_child(camera)
	var config: LevelConfig = GameManager.level_config
	camera.frame_arena(maxf(config.columns, config.rows) * config.cell_size)
	_sv_containers[3].add_child(SCOREBOARD_SCENE.instantiate())


# ─── Character selection ──────────────────────────────────────────────────

func _setup_character_selectors() -> void:
	for i: int in _players.size():
		var selector: Control = CHARACTER_SELECTOR_SCENE.instantiate() as Control
		_sv_containers[i].add_child(selector)
		selector.setup(i, Constants.PLAYER_COLORS[i], GameManager.chosen_characters.get(i))
		selector.character_previewed.connect(func(pid: int, data: CharacterData) -> void:
			_players[pid].apply_character_data(data))
		selector.character_locked.connect(_on_character_locked)
		selector.character_unlocked.connect(_on_character_unlocked)
		selector.back_requested.connect(_on_selection_back)
		_selectors.append(selector)


func _on_character_locked(pid: int, data: CharacterData) -> void:
	_players[pid].apply_character_data(data)
	GameManager.chosen_characters[pid] = data
	_ready_token += 1
	if GameManager.chosen_characters.size() < _players.size():
		return
	var token: int = _ready_token
	await get_tree().create_timer(READY_DELAY).timeout
	if token != _ready_token:
		return  # Someone unlocked (or relocked) meanwhile.
	for selector: Control in _selectors:
		selector.queue_free()
	_selectors.clear()
	_begin_countdown()


func _on_character_unlocked(pid: int) -> void:
	GameManager.chosen_characters.erase(pid)
	_ready_token += 1


func _on_selection_back(_pid: int) -> void:
	GameManager.chosen_characters.clear()
	GameManager.reset_to_lobby()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


## Rematch: same characters, straight to the countdown.
func _start_with_chosen_characters() -> void:
	for i: int in _players.size():
		_players[i].apply_character_data(GameManager.chosen_characters[i])
	_begin_countdown()


func _begin_countdown() -> void:
	for hud: CanvasLayer in _huds:
		hud.visible = true
	GameManager.start_match()


# ─── Match flow ───────────────────────────────────────────────────────────

func _on_state_changed(state: int) -> void:
	if state == Constants.GameState.PLAYING:
		AudioManager.play_sfx(AudioManager.SoundEffect.MATCH_START)
		_set_controls(true)
		for hud: CanvasLayer in _huds:
			hud.show_tip()


## First person: hide the player's own body from their camera only, show a crosshair.
func _on_view_changed(pid: int, first_person: bool) -> void:
	_cameras[pid].set_cull_mask_value(Constants.MODEL_LAYER_BASE + pid + 1, not first_person)
	_huds[pid].set_crosshair_visible(first_person)


func _on_impact(attacker_id: int, victim_id: int, gems: int) -> void:
	_cameras[attacker_id].shake(ATTACKER_SHAKE)
	_cameras[victim_id].shake(VICTIM_SHAKE)
	_huds[attacker_id].show_impact(true, gems)
	_huds[victim_id].show_impact(false, gems)


## Survival: the knocked-out hunter disappears and their screen follows a survivor.
func _on_player_eliminated(pid: int) -> void:
	_players[pid].eliminate()
	_huds[pid].show_eliminated()
	_retarget_spectators()


## Every knocked-out screen watches the first hunter still standing.
func _retarget_spectators() -> void:
	var survivor: Player = null
	for player: Player in _players:
		if GameManager.is_alive(player.player_id):
			survivor = player
			break
	if survivor == null:
		return
	for player: Player in _players:
		if not GameManager.is_alive(player.player_id):
			_cameras[player.player_id].set_target(survivor.get_camera_target())


func _on_leader_changed(leader_id: int) -> void:
	for player: Player in _players:
		player.set_leader(player.player_id == leader_id)


func _on_frenzy_started() -> void:
	overlay.show_frenzy()
	AudioManager.play_sfx(AudioManager.SoundEffect.POWERUP_GRAB)


## Tick audibly through the last seconds of a timed match.
func _on_timer_updated(seconds: float) -> void:
	if GameManager.match_mode == Constants.MatchMode.TIME \
			and seconds > 0.0 and seconds <= Constants.TIMER_TICK_SECONDS:
		AudioManager.play_sfx(AudioManager.SoundEffect.TIMER_TICK)


func _on_match_ended(_results: Array) -> void:
	_set_controls(false)
	var winner_id: int = GameManager.get_leader()
	if winner_id >= 0:
		_players[winner_id].play_winner_animation()
	AudioManager.play_sfx(AudioManager.SoundEffect.MATCH_END)
	await get_tree().create_timer(WINNER_DISPLAY_DURATION).timeout
	get_tree().change_scene_to_file(GAME_OVER_SCENE)


func _set_controls(enabled: bool) -> void:
	for player: Player in _players:
		player.set_controls_enabled(enabled)

