## ProjSnowball.gd
## "Snowball": freezes the target solid for a moment, so anyone can bump it to steal gems.
extends Projectile


func _init() -> void:
	speed = 24.0
	lifetime = 1.6


func _on_hit_player(player: Player) -> void:
	player.apply_debuff(Constants.DebuffType.FROZEN, Constants.DEBUFF_DURATION_SNOWBALL_FREEZE)
