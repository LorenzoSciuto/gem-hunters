## MovingGate.gd
## A wall section that sinks into the floor and rises again at random times,
## opening and closing shortcuts through the maze. MazeLevel only places gates
## on walls the maze stays connected without, so a closed gate never traps anyone.
extends AnimatableBody3D
class_name MovingGate

const MOVE_TIME: float = 0.8
## Sunk this far below its height so nothing pokes out of the floor.
const SINK_MARGIN: float = 0.05

var gate_size: Vector3 = Vector3.ONE
var color: Color = Color(1.0, 0.8, 0.3)

var _open: bool = false


func _ready() -> void:
	collision_layer = Constants.LAYER_WORLD
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = gate_size
	shape.shape = box
	shape.position.y = gate_size.y * 0.5
	add_child(shape)
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = gate_size
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.mesh = mesh
	# Architecture: no ink outline (it breaks up on long thin boxes).
	visual.material_override = ToonMaterials.get_material(color, 0.0)
	visual.position.y = gate_size.y * 0.5
	add_child(visual)
	_cycle()


func _cycle() -> void:
	while is_inside_tree():
		await get_tree().create_timer(randf_range(Constants.GATE_MIN_INTERVAL, Constants.GATE_MAX_INTERVAL)).timeout
		if not is_inside_tree():
			return
		_open = not _open
		var target_y: float = -(gate_size.y + SINK_MARGIN) if _open else 0.0
		var tween: Tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		tween.tween_property(self, "position:y", target_y, MOVE_TIME).set_trans(Tween.TRANS_SINE)
		await tween.finished
