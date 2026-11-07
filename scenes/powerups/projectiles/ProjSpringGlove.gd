## ProjSpringGlove.gd
## "Spring Glove": a cartoon punch that knocks the opponent back and makes them drop gems.
extends Projectile


const GEMS_KNOCKED: int = 5
const KNOCKBACK_FORCE: float = 14.0
const KNOCKBACK_LIFT: float = 0.5
## Dazed on top of the knockback's own short stun.
const GLOVE_STUN: float = 1.2


func _init() -> void:
	speed = 24.0
	lifetime = 1.2


func _on_hit_player(player: Player) -> void:
	player.lose_gems(GEMS_KNOCKED)
	player.apply_knockback((-global_transform.basis.z + Vector3.UP * KNOCKBACK_LIFT) * KNOCKBACK_FORCE)
	player.stun(GLOVE_STUN)
	AudioManager.play_sfx(AudioManager.SoundEffect.SPRING_BOING)
