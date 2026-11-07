## ProjSnowball.gd
## "Snowball": freezes the target solid for a moment, so anyone can bump it to steal gems.
extends Projectile

## Gems knocked loose by the hit (anyone can grab them while the victim is frozen).
const GEMS_KNOCKED: int = 2


func _init() -> void:
	speed = 24.0
	lifetime = 1.6


func _on_hit_player(player: Player) -> void:
	player.lose_gems(GEMS_KNOCKED)
	player.apply_debuff(Constants.DebuffType.FROZEN, Constants.DEBUFF_DURATION_SNOWBALL_FREEZE)
