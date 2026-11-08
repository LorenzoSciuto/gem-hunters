## ItemCatalog.gd
## Icons and name keys of every item and superpower, shared by the HUD and the
## How-to-play screen.
class_name ItemCatalog

const SUPER_ICONS: Dictionary = {
	CharacterData.Superpower.TURBO: preload("res://assets/ui/icons/super_turbo.png"),
	CharacterData.Superpower.GROUND_POUND: preload("res://assets/ui/icons/super_pound.png"),
	CharacterData.Superpower.SHIELD: preload("res://assets/ui/icons/super_shield.png"),
	CharacterData.Superpower.SWAP: preload("res://assets/ui/icons/super_swap.png"),
}
const ICONS: Dictionary = {
	Constants.PowerUpType.TRAP_CAKE: preload("res://assets/ui/icons/powerup_cake.png"),
	Constants.PowerUpType.TRAP_WATER_BALLOON: preload("res://assets/ui/icons/powerup_balloon.png"),
	Constants.PowerUpType.TRAP_SPEAKER: preload("res://assets/ui/icons/powerup_speaker.png"),
	Constants.PowerUpType.ATTACK_SPRING_GLOVE: preload("res://assets/ui/icons/powerup_glove.png"),
	Constants.PowerUpType.ATTACK_MAGNET: preload("res://assets/ui/icons/powerup_magnet.png"),
	Constants.PowerUpType.ATTACK_TICKLE_RAY: preload("res://assets/ui/icons/powerup_tickle.png"),
	Constants.PowerUpType.UTILITY_SPRING_SHOES: preload("res://assets/ui/icons/powerup_shoes.png"),
	Constants.PowerUpType.UTILITY_BUBBLE: preload("res://assets/ui/icons/powerup_bubble.png"),
	Constants.PowerUpType.TRAP_BANANA: preload("res://assets/ui/icons/powerup_banana.png"),
	Constants.PowerUpType.ATTACK_SNOWBALL: preload("res://assets/ui/icons/powerup_snowball.png"),
	Constants.PowerUpType.ATTACK_THUNDER: preload("res://assets/ui/icons/powerup_thunder.png"),
	Constants.PowerUpType.UTILITY_JACKPOT: preload("res://assets/ui/icons/powerup_jackpot.png"),
	Constants.PowerUpType.UTILITY_WARP: preload("res://assets/ui/icons/powerup_warp.png"),
	Constants.PowerUpType.UTILITY_RADAR: preload("res://assets/ui/icons/powerup_radar.png"),
	Constants.PowerUpType.TRAP_BLACK_BOX: preload("res://assets/ui/icons/powerup_blackbox.png"),
}
## Item name key; its description is the same key + "_DESC".
const NAME_KEYS: Dictionary = {
	Constants.PowerUpType.TRAP_CAKE: "UI_POWERUP_CAKE",
	Constants.PowerUpType.TRAP_WATER_BALLOON: "UI_POWERUP_BALLOON",
	Constants.PowerUpType.TRAP_SPEAKER: "UI_POWERUP_SPEAKER",
	Constants.PowerUpType.ATTACK_SPRING_GLOVE: "UI_POWERUP_GLOVE",
	Constants.PowerUpType.ATTACK_MAGNET: "UI_POWERUP_MAGNET",
	Constants.PowerUpType.ATTACK_TICKLE_RAY: "UI_POWERUP_TICKLE",
	Constants.PowerUpType.UTILITY_SPRING_SHOES: "UI_POWERUP_SHOES",
	Constants.PowerUpType.UTILITY_BUBBLE: "UI_POWERUP_BUBBLE",
	Constants.PowerUpType.TRAP_BANANA: "UI_POWERUP_BANANA",
	Constants.PowerUpType.ATTACK_SNOWBALL: "UI_POWERUP_SNOWBALL",
	Constants.PowerUpType.ATTACK_THUNDER: "UI_POWERUP_THUNDER",
	Constants.PowerUpType.UTILITY_JACKPOT: "UI_POWERUP_JACKPOT",
	Constants.PowerUpType.UTILITY_WARP: "UI_POWERUP_WARP",
	Constants.PowerUpType.UTILITY_RADAR: "UI_POWERUP_RADAR",
	Constants.PowerUpType.TRAP_BLACK_BOX: "UI_POWERUP_BLACKBOX",
}
