## Constants.gd
## Central repository for all project-wide constants, enums, and group names.
##
## Usage: Access via the Constants autoload singleton.
## e.g. Constants.MAX_PLAYERS, Constants.GameState.PLAYING
extends Node


# ─── Player configuration ──────────────────────────────────────────────────

## Maximum number of players supported in a single match.
const MAX_PLAYERS: int = 4

## Minimum number of players required to start a match.
const MIN_PLAYERS: int = 2

## Pastel/vivid player palette (Fall Guys / Splatoon style).
## Index corresponds to player_id (0–3).
## Display face for numbers, titles and in-world text (Label3D can't use the theme).
const DISPLAY_FONT: Font = preload("res://assets/fonts/LilitaOne.ttf")

const PLAYER_COLORS: Array[Color] = [
	Color(0.98, 0.42, 0.42, 1.0),  # P0 — Coral Red
	Color(0.42, 0.72, 0.98, 1.0),  # P1 — Sky Blue
	Color(0.52, 0.92, 0.45, 1.0),  # P2 — Lime Green
	Color(0.98, 0.85, 0.30, 1.0),  # P3 — Sunny Yellow
]


# ─── State machine ─────────────────────────────────────────────────────────

## All possible states for a game session.
enum GameState {
	LOBBY,      ## Players are selecting characters / waiting.
	COUNTDOWN,  ## Pre-match countdown (3-2-1-GO!).
	PLAYING,    ## Active gameplay.
	PAUSED,     ## Match paused (e.g. overlay menu).
	GAME_OVER,  ## Match ended; results screen visible.
}


# ─── Match goal ────────────────────────────────────────────────────────────

## How a match is won.
enum MatchMode {
	TIME,   ## Most gems when the clock runs out.
	SCORE,  ## First player to reach the gem target.
	LIVES,  ## Survival: everyone starts with START_LIVES; every attack costs a life; last one standing wins.
}

## Survival mode: lives at the start, and the floor the golden gem refills to
## (life gems and gems top it up to MAX_LIVES).
const START_LIVES: int = 3
## Survival: lives never go above this (life gems wait, gems stay unspent).
const MAX_LIVES: int = 5
const GOLDEN_REFILL_LIVES: int = 3
## Survival: after losing a life a hunter can't lose another for this long.
const LIFE_LOSS_GRACE: float = 3.0
## Survival mode gem economy: fewer, rarer gems, a slower golden gem, and a
## life gem now and then (at most LIFE_GEMS_MAX in the arena at once).
## Every GEMS_PER_LIFE gems a hunter holds are traded for a life.
const GEMS_PER_LIFE: int = 10
const SURVIVAL_MAX_GEMS: int = 8
const SURVIVAL_GEM_RESPAWN: float = 8.0
const SURVIVAL_GOLDEN_RESPAWN: float = 90.0
const LIFE_GEM_INTERVAL: float = 60.0
const LIFE_GEMS_MAX: int = 1

## Selectable durations for TIME mode (seconds).
const TIME_TARGETS: Array[int] = [90, 180, 300]

## Selectable gem targets for SCORE mode.
const SCORE_TARGETS: Array[int] = [30, 50, 80]

## SCORE mode safety cap so a match can never last forever (seconds).
const SCORE_MODE_TIME_CAP: float = 600.0

## Last language and match setup, restored at startup (controls live in user://controls.cfg).
const SETTINGS_PATH: String = "user://settings.cfg"

## Seconds of 3-2-1 countdown before play starts.
const COUNTDOWN_SECONDS: int = 3

## TIME mode: the frenzy starts when this many seconds remain.
const FRENZY_TIME_REMAINING: float = 30.0

## SCORE mode: the frenzy starts when the leader reaches this fraction of the target.
const FRENZY_SCORE_FRACTION: float = 0.75

## Gem value multiplier while the frenzy is active.
const FRENZY_MULTIPLIER: int = 2

## The clock ticks audibly during the last N seconds.
const TIMER_TICK_SECONDS: int = 10


# ─── Arenas ────────────────────────────────────────────────────────────────

## Selectable arenas, in menu order.
const LEVEL_CONFIGS: Array[String] = [
	"res://resources/levels/candy_kingdom.tres",
	"res://resources/levels/enchanted_forest.tres",
	"res://resources/levels/secret_garden.tres",
	"res://resources/levels/roman_colosseum.tres",
	"res://resources/levels/desert_temple.tres",
	"res://resources/levels/frozen_peaks.tres",
]


# ─── Power-up types ────────────────────────────────────────────────────────

## All power-up and trap types available in the game.
enum PowerUpType {
	NONE,                ## No power-up held.
	TRAP_CAKE,           ## Cake trap — leaves a splat on the floor.
	TRAP_WATER_BALLOON,  ## Water balloon trap — slips and slides.
	TRAP_SPEAKER,        ## Speaker trap — scare/pushback on proximity.
	ATTACK_SPRING_GLOVE, ## Launch target into the air (melee).
	ATTACK_MAGNET,       ## Pull nearby gems from opponents.
	ATTACK_TICKLE_RAY,   ## Ranged ray — target loses control briefly.
	UTILITY_SPRING_SHOES,## Double jump / high jumps.
	UTILITY_BUBBLE,      ## Protective bubble — negates one hit.
	TRAP_BANANA,         ## Banana peel — the victim slides out of control.
	ATTACK_SNOWBALL,     ## Thrown snowball — freezes the target (easy to rob).
	ATTACK_THUNDER,      ## Hits every rival at once: each drops a gem and giggles.
	UTILITY_JACKPOT,     ## A handful of gems, instantly.
	UTILITY_WARP,        ## Teleports to a random spot of the maze.
	UTILITY_RADAR,       ## Shows the map with every player for a few seconds.
	TRAP_BLACK_BOX,      ## Fake black gift box that blasts whoever opens it.
}

## Attack power-ups: aimed at rivals (the last-placed player gets them more often).
const ATTACK_TYPES: Array[PowerUpType] = [
	PowerUpType.ATTACK_SPRING_GLOVE, PowerUpType.ATTACK_MAGNET, PowerUpType.ATTACK_TICKLE_RAY,
	PowerUpType.ATTACK_SNOWBALL, PowerUpType.ATTACK_THUNDER,
]

## Items a player can carry; each slot has its own button.
const ITEM_SLOT_COUNT: int = 3

## Seconds a character's superpower needs to recharge.
const SUPERPOWER_COOLDOWN: float = 30.0


# ─── Debuff types ─────────────────────────────────────────────────────────

## Status effects that can be applied to players.
enum DebuffType {
	FROZEN,    ## Player cannot move (ice effect).
	INVERTED,  ## Controls are mirrored left/right.
	LAUGHING,  ## Player wiggles; cannot use power-up temporarily.
	ICE_SLIDE, ## Reduced friction; difficult to stop.
	SPLAT,     ## Screen covered in cake.
}


# ─── Gem types ────────────────────────────────────────────────────────────

## Gem rarity / value tiers.
enum GemType {
	STANDARD, ## Worth 1 point. Most common.
	RARE,     ## Worth 3 points. Uncommon.
	EPIC,     ## Worth 5 points. Rare.
	GOLDEN,   ## Worth 10 points. Only one exists at a time.
	LIFE,     ## Survival mode: gives one life instead of points.
}


# ─── Scene group names ────────────────────────────────────────────────────

## Godot group that all player nodes belong to.
const GROUP_PLAYERS: String = "players"

## Godot group that all player spawn-point nodes belong to.
const GROUP_SPAWN_POINTS: String = "spawn_points"

## Godot group that all gem spawn-point nodes belong to.
const GROUP_GEM_SPAWNS: String = "gem_spawns"

## Godot group that all power-up box spawn-point nodes belong to.
const GROUP_POWERUP_SPAWNS: String = "powerup_spawns"

## Godot group that all surprise boxes belong to.
const GROUP_SURPRISE_BOXES: String = "surprise_boxes"

## Godot group of the level's props (trampolines, sprinklers, portals, beacons,
## ice patches): gems never spawn on top of them.
const GROUP_PROPS: String = "props"
## Gems keep at least this far from props, boxes and traps.
const GEM_PROP_CLEARANCE: float = 2.2

## Godot group of every armed trap placed by a player.
const GROUP_TRAPS: String = "traps"


# ─── Physics collision layers (bit masks) ────────────────────────────────

## Layer 1 — static world geometry.
const LAYER_WORLD: int = 1 << 0

## Layer 2 — player bodies (what pickups and triggers watch for).
const LAYER_PLAYERS: int = 1 << 1

## Render layer of player N's floating name tag is NAME_TAG_LAYER_BASE + N,
## so each camera can hide its own player's tag.
const NAME_TAG_LAYER_BASE: int = 10

## Render layer of player N's own body is MODEL_LAYER_BASE + N, hidden from
## that player's camera while in first-person view.
const MODEL_LAYER_BASE: int = 14


# ─── Gem & spawn tuning ───────────────────────────────────────────────────

## Seconds between gem spawn attempts.
const GEM_RESPAWN_TIME: float = 4.0

## Seconds before a used surprise box reappears.
const POWERUP_BOX_RESPAWN: float = 12.0

## Maximum number of loose collectible gems in the world.
const MAX_GEMS_IN_WORLD: int = 20

## Minimum distance between two spawned gems (metres).
const MIN_GEM_SPAWN_DISTANCE: float = 2.0


# ─── Movement & camera ────────────────────────────────────────────────────

## Base walking speed (m/s).
const BASE_SPEED: float = 7.0

## Jump take-off velocity (m/s).
const JUMP_VELOCITY: float = 6.5

## Right-stick look speed (radians/s at full deflection).
const JOYSTICK_SENSITIVITY: float = 2.8

## Mouse look sensitivity (radians per pixel).
const MOUSE_SENSITIVITY: float = 0.0025

## Camera pitch limits (degrees) in third-person view.
const CAMERA_VERTICAL_MIN_DEG: float = -55.0
const CAMERA_VERTICAL_MAX_DEG: float = 30.0
## Camera pitch limits (degrees) in first-person view.
const CAMERA_FP_MIN_DEG: float = -75.0
const CAMERA_FP_MAX_DEG: float = 75.0

## Third-person camera distance and pivot height; first-person eye height.
const CAMERA_TP_DISTANCE: float = 4.5
const CAMERA_TP_HEIGHT: float = 2.0
const CAMERA_FP_HEIGHT: float = 1.15
## Initial downward tilt of the camera (degrees, negative looks down).
const CAMERA_START_PITCH_DEG: float = -20.0

## Stick dead zone.
const JOYSTICK_DEAD_ZONE: float = 0.15

## Laughing debuff camera wobble.
const CAMERA_LAUGHING_FREQUENCY: float = 18.0
const CAMERA_LAUGHING_AMPLITUDE: float = 12.0


# ─── Debuff & power-up durations (seconds) ────────────────────────────────

const DEBUFF_DURATION_INVERTED: float = 3.5
const DEBUFF_DURATION_LAUGHING: float = 3.0
const DEBUFF_DURATION_ICE_SLIDE: float = 3.5
## Main trap durations live in each trap scene (TrapBase.effect_duration).

const POWERUP_DURATION_SPRING_SHOES: float = 10.0
const POWERUP_DURATION_BUBBLE: float = 12.0
const POWERUP_DURATION_MAGNET: float = 4.0
const POWERUP_DURATION_TICKLE_RAY: float = 4.0

## Speed multiplier granted by spring shoes.
const SPRING_SHOES_SPEED_MULTIPLIER: float = 1.3

const DEBUFF_DURATION_SNOWBALL_FREEZE: float = 3.0
const DEBUFF_DURATION_THUNDER_LAUGH: float = 2.5
const POWERUP_DURATION_RADAR: float = 6.0
## Gems granted by the jackpot (inclusive range).
const JACKPOT_MIN_GEMS: int = 2
const JACKPOT_MAX_GEMS: int = 5


# ─── Arena features ───────────────────────────────────────────────────────

## Seconds a player ignores portals after teleporting (no instant bounce back).
const PORTAL_COOLDOWN: float = 1.5
## Seconds the map stays on screen after stepping on a map beacon.
const MAP_BEACON_REVEAL: float = 5.0
## Seconds before a used map beacon works again.
const MAP_BEACON_RECHARGE: float = 15.0
## A moving gate stays open or closed for a random time in this range (seconds).
const GATE_MIN_INTERVAL: float = 5.0
const GATE_MAX_INTERVAL: float = 11.0
## Chance that a gift box is a prank that bursts in the opener's face.
const BOX_PRANK_CHANCE: float = 0.12
## Chance that a gift box holds two items (if there is room).
const BOX_DOUBLE_CHANCE: float = 0.15


# ─── Physics & interaction tuning ─────────────────────────────────────────

## World gravity acceleration (m/s^2). Slightly heavier than real for snappy jumps.
const GRAVITY: float = 16.0

## Ground friction deceleration rate.
const FRICTION_GROUND: float = 40.0

## Slippery ice patch friction deceleration rate.
const FRICTION_ICE: float = 1.5

## Double jump velocity granted by spring shoes.
const SPRING_DOUBLE_JUMP_VELOCITY: float = 9.0

## Horizontal spread impulse when gems burst from a hit player.
const GEM_LOOSE_SPREAD_FORCE: float = 3.5

## Upward impulse when gems burst from a hit player.
const GEM_LOOSE_UP_FORCE: float = 4.0

## Push impulse when a bubble shield pops.
const BUBBLE_POP_PUSH_FORCE: float = 4.0

## Interval (seconds) for stealing gems by bumping into a stunned player.
const GEM_STEAL_INTERVAL: float = 0.5
