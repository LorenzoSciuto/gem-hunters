## CharacterPreview3D.gd
## Spinning character showcase rendered in an isolated SubViewport for character selection.
extends Node3D

const ROTATION_SPEED: float = 1.4
const BOB_FREQUENCY: float = 3.2
const BOB_AMPLITUDE: float = 0.05
const SWITCH_POP_SCALE: float = 0.7
const SWITCH_DURATION: float = 0.25
## The camera in CharacterPreview3D.tscn frames the tallest model (Bouncer) at
## the peak of the lock hop; raise these and it clips again.
const LOCK_HOP_HEIGHT: float = 0.15
const LOCK_POP_SCALE: float = 1.1

@onready var spin: Node3D = $Spin
@onready var model: CharacterModel = $Spin/CharacterModel

var _time: float = 0.0
var _tween: Tween = null


func _process(delta: float) -> void:
	_time += delta
	spin.rotate_y(ROTATION_SPEED * delta)
	spin.position.y = sin(_time * BOB_FREQUENCY) * BOB_AMPLITUDE


func set_character(data: CharacterData) -> void:
	model.set_character(data)
	_restart_tween()
	spin.scale = Vector3.ONE * SWITCH_POP_SCALE
	_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(spin, "scale", Vector3.ONE, SWITCH_DURATION)


## Hop and full spin when the player locks in.
func play_lock_animation() -> void:
	_restart_tween()
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(model, "position:y", model.position.y + LOCK_HOP_HEIGHT, 0.2)
	_tween.parallel().tween_property(spin, "rotation:y", spin.rotation.y + TAU, 0.45)
	_tween.parallel().tween_property(spin, "scale", Vector3.ONE * LOCK_POP_SCALE, 0.2)
	_tween.chain().set_ease(Tween.EASE_IN)
	_tween.tween_property(model, "position:y", model.position.y, 0.2)
	_tween.parallel().tween_property(spin, "scale", Vector3.ONE, 0.2)


func _restart_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
