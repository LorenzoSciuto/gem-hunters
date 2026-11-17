## GraphicsProbe.gd
## Finds which part of the 3D rendering a browser cannot take. Some browsers
## (the Xbox one) drop the WebGL context on the game's first 3D frame; this
## scene turns the rendering on one step at a time, a few seconds apart, and
## names the step on screen and to the page (window.graphicsProbeStep), which
## adds it to the context-loss report. The last step named is the culprit.
## The web release serves it as probe.html (installer/version_web_build.sh),
## which starts the game on this scene instead of the menu.
extends Control

signal finished

const ARENA: LevelConfig = preload("res://resources/levels/candy_kingdom.tres")
const BACKDROP: PackedScene = preload("res://scenes/ui/ArenaBackdrop.tscn")
const CAMERA_POSITION: Vector3 = Vector3(0.0, 30.0, 40.0)
const SHAPE_SIZE: float = 10.0
const LABEL_FONT_SIZE: int = 48

## Seconds each step stays on screen before the next one starts.
var step_seconds: float = 4.0

var _label: Label = Label.new()
## Everything the steps add to the 3D world, so a step can start from scratch.
var _world: Node3D = Node3D.new()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_world)
	_label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	_label.z_index = 1
	add_child(_label)
	var steps: Array[Array] = [
		["1 - 2D only", Callable()],
		["2 - empty 3D view", _add_camera],
		["3 - unshaded box", _add_unshaded_box],
		["4 - lit sphere", _add_lit_sphere],
		["5 - plain sky", _add_plain_sky],
		["6 - arena sky, fog and colour grading", _add_arena_environment],
		["7 - arena", _add_arena],
		["8 - arena in its own view (the menu backdrop)", _add_backdrop],
	]
	for step: Array in steps:
		_announce(step[0])
		# Named a frame before it is drawn, so a loss on its first frame reports it.
		await get_tree().process_frame
		if (step[1] as Callable).is_valid():
			(step[1] as Callable).call()
		await get_tree().create_timer(step_seconds).timeout
	_announce("every step passed")
	finished.emit()


func _announce(step: String) -> void:
	_label.text = "Graphics probe: %s" % step
	print(_label.text)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.graphicsProbeStep = %s" % JSON.stringify(step))


func _add_camera() -> void:
	var camera: Camera3D = Camera3D.new()
	_world.add_child(camera)
	camera.look_at_from_position(CAMERA_POSITION, Vector3.ZERO)


func _add_unshaded_box() -> void:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3.ONE * SHAPE_SIZE
	box.material = material
	_add_mesh(box, Vector3.LEFT * SHAPE_SIZE)


func _add_lit_sphere() -> void:
	_world.add_child(DirectionalLight3D.new())
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = SHAPE_SIZE * 0.5
	sphere.height = SHAPE_SIZE
	_add_mesh(sphere, Vector3.RIGHT * SHAPE_SIZE)


func _add_mesh(mesh: Mesh, at: Vector3) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	_world.add_child(instance)


func _add_plain_sky() -> void:
	var sky: Sky = Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.name = "PlainSky"
	world_environment.environment = environment
	_world.add_child(world_environment)


func _add_arena_environment() -> void:
	_world.get_node("PlainSky").free()
	ArenaEnvironment.build(_world, ARENA)


## From here on the arena brings its own environment and sun.
func _add_arena() -> void:
	for child: Node in _world.get_children():
		if child is not Camera3D:
			child.free()
	var level: MazeLevel = MazeLevel.new()
	level.config = ARENA
	_world.add_child(level)


func _add_backdrop() -> void:
	_world.free()
	var backdrop: Node = BACKDROP.instantiate()
	add_child(backdrop)
	move_child(backdrop, 0)
	backdrop.call("show_arena", ARENA)
