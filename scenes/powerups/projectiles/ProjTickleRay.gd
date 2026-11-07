## ProjTickleRay.gd
## "Tickle Ray": the victim giggles uncontrollably — wobbly camera, no power-ups.
extends Projectile

## Gems the victim drops while doubled over laughing.
const GEMS_KNOCKED: int = 2


func _init() -> void:
	speed = 22.0
	lifetime = 1.5


func _on_hit_player(player: Player) -> void:
	player.lose_gems(GEMS_KNOCKED)
	if player.apply_debuff(Constants.DebuffType.LAUGHING, Constants.POWERUP_DURATION_TICKLE_RAY):
		AudioManager.play_sfx(AudioManager.SoundEffect.TICKLE_ZAP)
