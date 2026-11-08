## MeshBatcher.gd
## Collects many instances of a few unit meshes (box, sphere, cylinder, cone,
## pyramid) per colour and turns each (mesh, colour, outline) group into one
## MultiMeshInstance3D: thousands of maze pieces in a handful of draw calls,
## which matters with four split-screen cameras.
extends RefCounted
class_name MeshBatcher

## (mesh, colour, outline) → { mesh, color, outline, xforms }.
var _batches: Dictionary = {}
var _meshes: Dictionary = {}


## Queue one instance of a unit mesh: [param pos] is the bottom center for
## boxes/cylinders/cones, the center for spheres.
func add(mesh_name: String, color: Color, pos: Vector3, size: Vector3, yaw: float = 0.0, outline: float = 0.0) -> void:
	# Scale in the mesh's local frame, then rotate (Basis.scaled() would scale world axes).
	var basis: Basis = Basis(Vector3.UP, yaw) * Basis.from_scale(size)
	var offset: Vector3 = Vector3.ZERO if mesh_name == "sphere" else Vector3(0.0, size.y * 0.5, 0.0)
	var key: String = "%s|%s|%.3f" % [mesh_name, color.to_html(), outline]
	if not _batches.has(key):
		_batches[key] = { "mesh": mesh_name, "color": color, "outline": outline, "xforms": [] }
	_batches[key]["xforms"].append(Transform3D(basis, pos + offset))


## Adds one MultiMeshInstance3D per group under [param parent] and resets.
func flush(parent: Node3D) -> void:
	for key: String in _batches:
		var batch: Dictionary = _batches[key]
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _mesh(batch["mesh"])
		var xforms: Array = batch["xforms"]
		mm.instance_count = xforms.size()
		for n: int in xforms.size():
			mm.set_instance_transform(n, xforms[n])
		var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		mmi.multimesh = mm
		# Architecture has no ink outline (the hull trick breaks up on long thin
		# boxes); only small props ask for one.
		mmi.material_override = ToonMaterials.get_material(batch["color"], batch["outline"])
		parent.add_child(mmi)
	_batches.clear()


func _mesh(name: String) -> Mesh:
	if _meshes.has(name):
		return _meshes[name]
	var m: Mesh
	match name:
		"box":
			m = BoxMesh.new()
		"sphere":
			var s: SphereMesh = SphereMesh.new()
			s.radius = 0.5
			s.height = 1.0
			s.radial_segments = 16
			s.rings = 8
			m = s
		"cylinder":
			var c: CylinderMesh = CylinderMesh.new()
			c.top_radius = 0.5
			c.bottom_radius = 0.5
			c.height = 1.0
			c.radial_segments = 12
			m = c
		"cone":
			var c: CylinderMesh = CylinderMesh.new()
			c.top_radius = 0.0
			c.bottom_radius = 0.5
			c.height = 1.0
			c.radial_segments = 10
			m = c
		"pyramid":
			var c: CylinderMesh = CylinderMesh.new()
			c.top_radius = 0.0
			c.bottom_radius = 0.7071
			c.height = 1.0
			c.radial_segments = 4
			m = c
	_meshes[name] = m
	return m
