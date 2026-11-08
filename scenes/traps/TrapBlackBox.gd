## TrapBlackBox.gd
## "Black Box": a dark gift box that bobs like a real one. Whoever opens it
## (its owner included) is blasted into the air, loses every item it carries
## and has to wait for its superpower to recharge from zero.
extends TrapBase

const BLAST_UP: float = 10.0
const BLAST_SIDE: float = 5.0
const BOB_HEIGHT: float = 0.6
const BOB_AMPLITUDE: float = 0.15
const BOB_SPEED: float = 2.6
const SPIN_SPEED: float = 0.8

@onready var model: Node3D = $Model


func _process(delta: float) -> void:
	model.position.y = BOB_HEIGHT + sin(Time.get_ticks_msec() * 0.001 * BOB_SPEED) * BOB_AMPLITUDE
	model.rotate_y(SPIN_SPEED * delta)


func _apply_trap_effect(player: Player) -> void:
	var side: Vector3 = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
	player.apply_knockback(side * BLAST_SIDE + Vector3.UP * BLAST_UP)
	player.items.strip()
	model.visible = false
	ParticleConfigs.spawn_burst(get_parent(), global_position + Vector3.UP, ParticleConfigs.gem_lost_burst(), 40)


func _play_trap_sfx() -> void:
	AudioManager.play_sfx(AudioManager.SoundEffect.FART_HORN)
