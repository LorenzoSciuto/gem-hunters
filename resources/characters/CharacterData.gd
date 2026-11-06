## CharacterData.gd
## Data resource defining a playable character archetype, personality, and gameplay stats.
## Produced for Gem Hunters: Tag & Trap by Wennovate.
extends Resource
class_name CharacterData

enum TraitType {
	NONE,
	SPEEDSTER,   ## Higher top speed, recovers quicker from slides.
	BOUNCER,     ## Higher jump velocity, built-in double jump.
	TANK,        ## High knockback resistance, loses fewer gems on hit.
	PRANKSTER,   ## Traps/powerups last longer, higher steal rate.
}

## Superpower name key per trait (description: same key + "_DESC").
const SUPER_KEYS: Dictionary = {
	TraitType.SPEEDSTER: "SUPER_TURBO",
	TraitType.BOUNCER: "SUPER_POUND",
	TraitType.TANK: "SUPER_SHIELD",
	TraitType.PRANKSTER: "SUPER_SWAP",
}

@export var id: String = "dashy"
@export var name_key: String = "CHAR_DASHY_NAME"
@export var bio_key: String = "CHAR_DASHY_BIO"
@export var trait_key: String = "CHAR_DASHY_TRAIT"
@export var trait_type: TraitType = TraitType.SPEEDSTER

@export var color: Color = Color(0.98, 0.85, 0.3)
@export var speed_multiplier: float = 1.2
@export var jump_multiplier: float = 1.0
@export var knockback_resistance: float = 0.8
@export var gem_loss_multiplier: float = 1.0
@export var mesh_scale: Vector3 = Vector3(1.0, 1.0, 1.0)

# Display stat bars (1 to 5)
@export var stat_speed: int = 5
@export var stat_jump: int = 3
@export var stat_defense: int = 2
@export var stat_tricks: int = 3
