## GameManager.gd
## Singleton (autoload) that owns the authoritative match state machine.
##
## Responsibilities:
##   - Track current GameState (LOBBY → COUNTDOWN → PLAYING → GAME_OVER).
##   - Own the match clock, the win condition (time or gem target) and the frenzy.
##   - Own every player's gem score. Players never keep their own copy.
##
## All other systems communicate with this manager through its signals;
## they must NOT mutate internal state directly.
extends Node


# ─── Signals ──────────────────────────────────────────────────────────────

## Emitted whenever the GameState transitions.
signal state_changed(new_state: int)

## Emitted once per second during COUNTDOWN with 3, 2, 1, then 0 for "GO!".
signal countdown_tick(seconds_left: int)

## Emitted every second while PLAYING. In TIME mode the value is the time
## remaining, in SCORE mode the time elapsed.
signal timer_updated(seconds: float)

## Emitted whenever a player's gem score changes.
signal score_updated(player_id: int, new_score: int)

## Emitted when the player in first place changes (-1 = tie / nobody).
signal leader_changed(player_id: int)

## Emitted once when the final frenzy (double gems) begins.
signal frenzy_started

## Emitted when the match ends. [code]results[/code] is an Array of
## Dictionaries sorted descending by score: [code]{ "player_id": int, "score": int }[/code]
signal match_ended(results: Array)

## Survival mode: [param player_id] now has [param lives] lives.
signal lives_changed(player_id: int, lives: int)

## Survival mode: [param player_id] ran out of lives and is out of the match.
signal player_eliminated(player_id: int)

## The once-per-match Chaos Gem appeared somewhere in the arena.
signal chaos_gem_appeared

## [param player_id] took the Chaos Gem: every rival lost half their gems
## ([param lost] maps rival player_id → gems lost).
signal chaos_gem_taken(player_id: int, lost: Dictionary)


# ─── Configuration (read by the match scene and the menus) ────────────────

var match_mode: Constants.MatchMode = Constants.MatchMode.TIME

## Seconds in TIME mode, gems in SCORE mode.
var match_target: int = Constants.TIME_TARGETS[1]

## Arena to generate for the next match.
var level_config: LevelConfig = null

## Character chosen per player in the last character selection (player_id → CharacterData).
var chosen_characters: Dictionary = {}


# ─── Internal state ───────────────────────────────────────────────────────

var _num_players: int = 2
var _clock: float = 0.0
var _tick_accumulator: float = 0.0
var _countdown_left: int = 0
var _current_state: Constants.GameState = Constants.GameState.LOBBY
var _frenzy: bool = false
var _leader: int = -1
## Seconds of actual play this match: frozen in countdown, pause and game over.
var _play_time: float = 0.0

## Per-player gem counts. Keys are player_id (int), values are score (int).
var scores: Dictionary = {}
## Survival mode: player_id → lives left.
var lives: Dictionary = {}
## Survival mode: player_ids in the order they were knocked out.
var _eliminated: Array[int] = []


# ─── Lifecycle ────────────────────────────────────────────────────────────

func _ready() -> void:
	_load_last_setup()
	_reset_scores()


## Restores the last configured match; anything missing or invalid keeps the default.
func _load_last_setup() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(Constants.SETTINGS_PATH) != OK:
		return
	_num_players = clampi(int(cfg.get_value("match", "players", _num_players)), Constants.MIN_PLAYERS, Constants.MAX_PLAYERS)
	var mode: int = int(cfg.get_value("match", "mode", match_mode))
	if mode in Constants.MatchMode.values():
		match_mode = mode as Constants.MatchMode
	if match_mode != Constants.MatchMode.LIVES:
		var targets: Array[int] = Constants.TIME_TARGETS if match_mode == Constants.MatchMode.TIME else Constants.SCORE_TARGETS
		var target: int = int(cfg.get_value("match", "target", match_target))
		match_target = target if target in targets else targets[1]
	var arena: String = str(cfg.get_value("match", "arena", ""))
	if arena in Constants.LEVEL_CONFIGS:
		level_config = load(arena) as LevelConfig


func _save_last_setup() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(Constants.SETTINGS_PATH)  # keep the other sections (missing file is fine)
	cfg.set_value("match", "players", _num_players)
	cfg.set_value("match", "mode", match_mode)
	cfg.set_value("match", "target", match_target)
	cfg.set_value("match", "arena", level_config.resource_path if level_config else "")
	cfg.save(Constants.SETTINGS_PATH)


func _process(delta: float) -> void:
	if _current_state == Constants.GameState.PLAYING:
		_play_time += delta
	if _current_state == Constants.GameState.COUNTDOWN or _current_state == Constants.GameState.PLAYING:
		_tick(delta)


## Gameplay clock (seconds): every debuff, cooldown and grace period is measured
## on this, so pausing the game also pauses them.
func game_time() -> float:
	return _play_time


# ─── Public API ───────────────────────────────────────────────────────────

## Configure the next match. [param target] is seconds (TIME) or gems (SCORE).
func configure(num_players: int, mode: Constants.MatchMode, target: int, config: LevelConfig) -> void:
	_num_players = clampi(num_players, Constants.MIN_PLAYERS, Constants.MAX_PLAYERS)
	match_mode = mode
	match_target = maxi(target, 1)
	level_config = config
	_reset_scores()
	_save_last_setup()


func get_num_players() -> int:
	return _num_players


## Begin the 3-2-1 countdown; PLAYING follows automatically.
func start_match() -> void:
	if _current_state == Constants.GameState.COUNTDOWN or _current_state == Constants.GameState.PLAYING:
		push_warning("GameManager.start_match() called while a match is running.")
		return
	_reset_scores()
	_frenzy = false
	_leader = -1
	_play_time = 0.0
	_clock = float(match_target) if match_mode == Constants.MatchMode.TIME else 0.0
	_tick_accumulator = 0.0
	_countdown_left = Constants.COUNTDOWN_SECONDS
	_set_state(Constants.GameState.COUNTDOWN)
	countdown_tick.emit(_countdown_left)


## Return to the lobby state (used when leaving a match scene).
func reset_to_lobby() -> void:
	_set_state(Constants.GameState.LOBBY)


func pause_match() -> void:
	if _current_state == Constants.GameState.PLAYING:
		_set_state(Constants.GameState.PAUSED)


func resume_match() -> void:
	if _current_state == Constants.GameState.PAUSED:
		_set_state(Constants.GameState.PLAYING)


## End the match immediately and emit [signal match_ended] with sorted standings.
func end_match() -> void:
	if _current_state == Constants.GameState.GAME_OVER:
		return
	_set_state(Constants.GameState.GAME_OVER)
	match_ended.emit(get_standings())


func is_playing() -> bool:
	return _current_state == Constants.GameState.PLAYING


func is_frenzy() -> bool:
	return _frenzy


## Add gems. Pickups pass [param boost] = true so the frenzy doubles them;
## transfers between players do not, so stealing never creates gems.
## Returns the amount actually added.
func add_gems(player_id: int, amount: int, boost: bool = true) -> int:
	if not _is_valid_player(player_id) or not is_playing():
		return 0
	var gained: int = maxi(amount, 0) * (Constants.FRENZY_MULTIPLIER if _frenzy and boost else 1)
	if gained == 0:
		return 0
	scores[player_id] = (scores[player_id] as int) + gained
	if is_survival():
		_trade_gems_for_lives(player_id)
	score_updated.emit(player_id, scores[player_id])
	_after_score_change()
	return gained


## Survival: every GEMS_PER_LIFE gems held become a life, up to MAX_LIVES.
func _trade_gems_for_lives(player_id: int) -> void:
	while is_alive(player_id) and not has_max_lives(player_id) and (scores[player_id] as int) >= Constants.GEMS_PER_LIFE:
		scores[player_id] = (scores[player_id] as int) - Constants.GEMS_PER_LIFE
		add_life(player_id)


## Remove up to [param amount] gems. Returns the amount actually removed.
func remove_gems(player_id: int, amount: int) -> int:
	if not _is_valid_player(player_id) or not is_playing():
		return 0
	var removed: int = mini(maxi(amount, 0), scores[player_id] as int)
	if removed == 0:
		return 0
	scores[player_id] = (scores[player_id] as int) - removed
	score_updated.emit(player_id, scores[player_id])
	_after_score_change()
	return removed


func is_survival() -> bool:
	return match_mode == Constants.MatchMode.LIVES


func get_lives(player_id: int) -> int:
	return lives.get(player_id, 0) as int


## Still in the match (always true outside survival mode).
func is_alive(player_id: int) -> bool:
	return not is_survival() or get_lives(player_id) > 0


## Survival: any attack costs a life; at zero the player is out, and
## when one hunter is left standing the match ends. Returns the lives left.
func lose_life(player_id: int) -> int:
	if not is_survival() or not is_playing() or get_lives(player_id) <= 0:
		return get_lives(player_id)
	_set_lives(player_id, get_lives(player_id) - 1)
	if get_lives(player_id) == 0:
		_eliminated.append(player_id)
		player_eliminated.emit(player_id)
		if lives.values().filter(func(l: int) -> bool: return l > 0).size() <= 1:
			end_match()
	return get_lives(player_id)


## Survival: +[param amount] lives, never above MAX_LIVES.
func add_life(player_id: int, amount: int = 1) -> void:
	if is_survival() and is_playing() and is_alive(player_id) and not has_max_lives(player_id):
		_set_lives(player_id, mini(get_lives(player_id) + amount, Constants.MAX_LIVES))


func has_max_lives(player_id: int) -> bool:
	return get_lives(player_id) >= Constants.MAX_LIVES


## Survival: golden gem — back up to at least [param minimum] lives.
func refill_lives(player_id: int, minimum: int) -> void:
	if is_survival() and is_playing() and is_alive(player_id) and get_lives(player_id) < minimum:
		_set_lives(player_id, minimum)


func _set_lives(player_id: int, value: int) -> void:
	lives[player_id] = value
	lives_changed.emit(player_id, value)
	_update_leader()


## Chaos Gem: every player except [param finder_id] loses half their gems
## (rounded down). Returns rival player_id → gems lost.
func halve_rivals(finder_id: int) -> Dictionary:
	var lost: Dictionary = {}
	for pid: int in scores:
		if pid != finder_id:
			lost[pid] = remove_gems(pid, (scores[pid] as int) / 2)
	chaos_gem_taken.emit(finder_id, lost)
	return lost


func get_score(player_id: int) -> int:
	return scores.get(player_id, 0) as int


## Returns standings sorted by score descending; ties keep the lower player_id first.
## Survival ranks survivors first (most lives), then the knocked-out in reverse
## order of elimination; gems break ties.
func get_standings() -> Array:
	var entries: Array = []
	for pid: int in scores:
		entries.append({ "player_id": pid, "score": scores[pid] as int, "lives": get_lives(pid),
			"out_rank": _eliminated.find(pid) })
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if is_survival() and a["lives"] != b["lives"]:
			return a["lives"] > b["lives"]
		if is_survival() and a["out_rank"] != b["out_rank"]:
			return a["out_rank"] > b["out_rank"]
		if a["score"] == b["score"]:
			return a["player_id"] < b["player_id"]
		return a["score"] > b["score"]
	)
	return entries


## Returns the sole leader's player_id, or -1 when nobody leads (tie or all zero).
## Survival: the hunter with the most lives.
func get_leader() -> int:
	var standings: Array = get_standings()
	if is_survival():
		if standings.size() > 1 and standings[1]["lives"] == standings[0]["lives"]:
			return -1
		return standings[0]["player_id"]
	if standings.is_empty() or standings[0]["score"] == 0:
		return -1
	if standings.size() > 1 and standings[1]["score"] == standings[0]["score"]:
		return -1
	return standings[0]["player_id"]


func get_state() -> Constants.GameState:
	return _current_state


# ─── Private helpers ──────────────────────────────────────────────────────

func _tick(delta: float) -> void:
	_tick_accumulator += delta
	if _tick_accumulator < 1.0:
		if _current_state == Constants.GameState.PLAYING:
			_advance_clock(delta)
		return
	_tick_accumulator -= 1.0

	if _current_state == Constants.GameState.COUNTDOWN:
		_countdown_left -= 1
		countdown_tick.emit(_countdown_left)
		if _countdown_left <= 0:
			_set_state(Constants.GameState.PLAYING)
			timer_updated.emit(_clock)
		return

	_advance_clock(delta)
	timer_updated.emit(_clock)


func _advance_clock(delta: float) -> void:
	if match_mode == Constants.MatchMode.TIME:
		_clock = maxf(_clock - delta, 0.0)
		if not _frenzy and _clock <= Constants.FRENZY_TIME_REMAINING:
			_start_frenzy()
		if _clock <= 0.0:
			end_match()
	else:
		_clock += delta
		if _clock >= Constants.SCORE_MODE_TIME_CAP:
			end_match()


func _update_leader() -> void:
	var leader: int = get_leader()
	if leader != _leader:
		_leader = leader
		leader_changed.emit(leader)


func _after_score_change() -> void:
	_update_leader()
	if match_mode != Constants.MatchMode.SCORE:
		return
	var best: int = get_standings()[0]["score"]
	if not _frenzy and best >= int(match_target * Constants.FRENZY_SCORE_FRACTION):
		_start_frenzy()
	if best >= match_target:
		end_match()


func _start_frenzy() -> void:
	_frenzy = true
	frenzy_started.emit()


func _set_state(new_state: Constants.GameState) -> void:
	_current_state = new_state
	state_changed.emit(new_state)


func _reset_scores() -> void:
	scores.clear()
	lives.clear()
	_eliminated.clear()
	for i: int in range(_num_players):
		scores[i] = 0
		if is_survival():
			lives[i] = Constants.START_LIVES


func _is_valid_player(player_id: int) -> bool:
	return player_id >= 0 and player_id < _num_players
