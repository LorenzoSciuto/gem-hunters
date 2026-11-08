## FX_IcePatch.gd
## Slippery puddle created by water balloons or garden sprinklers.
## Players entering this area get the ice slide debuff.
extends Area3D
class_name IcePatch

## Seconds before the patch melts. 0 = permanent (level hazard).
@export var duration: float = 8.0
@export var slide_duration: float = 3.0

var _timer: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if duration <= 0.0:
		return
	_timer += delta
	if _timer >= duration:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		(body as Player).status.apply_debuff(Constants.DebuffType.ICE_SLIDE, slide_duration)
