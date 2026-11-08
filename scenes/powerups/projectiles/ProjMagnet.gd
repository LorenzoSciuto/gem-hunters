## ProjMagnet.gd
## "Giant Magnet": latches onto an opponent and pulls gems from them to the shooter.
extends Projectile


## Gems pulled per second while latched.
const PULL_RATE: float = 2.0


func _init() -> void:
	speed = 18.0
	lifetime = 2.5


func _on_hit_player(player: Player) -> void:
	_pull_gems(player)


## Override: the magnet stays alive (hidden) while it drains the target.
func _on_body_entered(body: Node3D) -> void:
	if body is Player and (body as Player).player_id != shooter_id:
		hide()
		set_physics_process(false)
		set_deferred("monitoring", false)
		(body as Player).take_hit()
		_on_hit_player(body as Player)
	elif not body is Player:
		_finish()


func _pull_gems(target: Player) -> void:
	AudioManager.play_sfx(AudioManager.SoundEffect.MAGNET_HUM)
	var shooter: Player = _find_shooter()
	var pulls: int = int(Constants.POWERUP_DURATION_MAGNET * PULL_RATE)
	for i: int in pulls:
		await get_tree().create_timer(1.0 / PULL_RATE, false).timeout
		if not is_instance_valid(target) or not is_instance_valid(shooter):
			break
		shooter.collect_gem(target.lose_gems(1, false), false)
	queue_free()
