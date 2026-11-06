## AudioManager.gd
## Autoload that plays one-shot sound effects through a small round-robin pool,
## so many overlapping sounds never cut each other off abruptly.
##
## Usage: AudioManager.play_sfx(AudioManager.SoundEffect.GEM_COLLECT)
extends Node


enum SoundEffect {
	GEM_COLLECT,    ## Played when a player picks up a gem.
	GEM_LOST,       ## Played when a player loses gems (hit/trap).
	CAKE_SPLAT,     ## Cake trap deployment / impact.
	FART_HORN,      ## Water-balloon trap comedic sound.
	BUBBLE_POP,     ## Bubble power-up protection popping.
	SPRING_BOING,   ## Spring shoes / spring glove launch.
	MAGNET_HUM,     ## Magnet power-up active hum loop.
	TICKLE_ZAP,     ## Tickle ray zap on target.
	SPEAKER_SCARE,  ## Speaker trap proximity scare sting.
	TIMER_TICK,     ## Last-10-seconds timer tick.
	MATCH_START,    ## "GO!" stinger at match start.
	MATCH_END,      ## End-of-match fanfare.
	POWERUP_GRAB,   ## Collecting a power-up box.
}

## Simultaneous sounds before the oldest one is reused.
const SFX_POOL_SIZE: int = 12

const SFX_PATHS: Dictionary = {
	SoundEffect.GEM_COLLECT:   "res://assets/audio/sfx/gem_collect.ogg",
	SoundEffect.GEM_LOST:      "res://assets/audio/sfx/gem_lost.ogg",
	SoundEffect.CAKE_SPLAT:    "res://assets/audio/sfx/cake_splat.ogg",
	SoundEffect.FART_HORN:     "res://assets/audio/sfx/fart_horn.ogg",
	SoundEffect.BUBBLE_POP:    "res://assets/audio/sfx/bubble_pop.ogg",
	SoundEffect.SPRING_BOING:  "res://assets/audio/sfx/spring_boing.ogg",
	SoundEffect.MAGNET_HUM:    "res://assets/audio/sfx/magnet_hum.ogg",
	SoundEffect.TICKLE_ZAP:    "res://assets/audio/sfx/tickle_zap.ogg",
	SoundEffect.SPEAKER_SCARE: "res://assets/audio/sfx/speaker_scare.ogg",
	SoundEffect.TIMER_TICK:    "res://assets/audio/sfx/timer_tick.ogg",
	SoundEffect.MATCH_START:   "res://assets/audio/sfx/match_start.ogg",
	SoundEffect.MATCH_END:     "res://assets/audio/sfx/match_end.ogg",
	SoundEffect.POWERUP_GRAB:  "res://assets/audio/sfx/powerup_grab.ogg",
}

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_pool_index: int = 0
var _sfx_cache: Dictionary = {}


func _ready() -> void:
	# Menus and the pause screen still make sounds while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i: int in SFX_POOL_SIZE:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(player)
		_sfx_pool.append(player)
	for effect: int in SFX_PATHS:
		_sfx_cache[effect] = load(SFX_PATHS[effect])


## Play [param effect], optionally adjusted by [param volume_db].
func play_sfx(effect: SoundEffect, volume_db: float = 0.0) -> void:
	var player: AudioStreamPlayer = _sfx_pool[_sfx_pool_index]
	_sfx_pool_index = (_sfx_pool_index + 1) % SFX_POOL_SIZE
	player.stream = _sfx_cache[effect]
	player.volume_db = volume_db
	player.play()
