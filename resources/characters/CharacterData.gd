## CharacterData.gd
## Data resource for a playable character: look, superpower and the passive
## trait that sets it apart (every character tunes different fields below).
## Produced for Gem Hunters: Tag & Trap by Wennovate.
extends Resource
class_name CharacterData

## The superpower (shared by two characters each; their traits differ).
enum Superpower {
	NONE,
	TURBO,         ## A few seconds at top speed.
	GROUND_POUND,  ## Leap and slam: nearby rivals fly and drop gems.
	SHIELD,        ## Nothing can touch you for a while.
	SWAP,          ## Trade places with the leader.
}

## Superpower name key (description: same key + "_DESC").
const SUPER_KEYS: Dictionary = {
	Superpower.TURBO: "SUPER_TURBO",
	Superpower.GROUND_POUND: "SUPER_POUND",
	Superpower.SHIELD: "SUPER_SHIELD",
	Superpower.SWAP: "SUPER_SWAP",
}

@export var id: String = "dashy"
@export var name_key: String = "CHAR_DASHY_NAME"
@export var bio_key: String = "CHAR_DASHY_BIO"
@export var trait_key: String = "CHAR_DASHY_TRAIT"
@export var superpower: Superpower = Superpower.TURBO

@export var color: Color = Color(0.98, 0.85, 0.3)
@export var mesh_scale: Vector3 = Vector3(1.0, 1.0, 1.0)

@export_group("Trait")
@export var speed_multiplier: float = 1.0
@export var jump_multiplier: float = 1.0
## Extra jumps in mid-air (1 = double jump, 2 = triple jump).
@export var air_jumps: int = 0
@export var knockback_resistance: float = 1.0
@export var gem_loss_multiplier: float = 1.0
## Every debuff (freeze, confusion, splat...) lasts this much of its time.
@export var debuff_duration_multiplier: float = 1.0
## Ice slides last this much of their time (on top of the debuff multiplier).
@export var ice_recovery_multiplier: float = 1.0
## Superpower recharge time multiplier.
@export var super_cooldown_multiplier: float = 1.0
## Gems taken per steal when robbing a frozen/confused rival by contact.
@export var contact_steal_gems: int = 1
## Extra gems taken when landing on a rival's head.
@export var stomp_bonus_gems: int = 0

@export_group("Card")
## Display stat bars (1 to 5).
@export var stat_speed: int = 3
@export var stat_jump: int = 3
@export var stat_defense: int = 3
