## LightBeam.gd
## A tall translucent pillar of light, visible over the maze walls from
## anywhere: marks the leader and the Chaos Gem. Recolour it with [member color].
extends MeshInstance3D
class_name LightBeam

var color: Color:
	set(value):
		_material.albedo_color = value
	get:
		return _material.albedo_color

var _material: StandardMaterial3D = StandardMaterial3D.new()


## A beam [param height] tall and [param radius] wide, starting [param base] above its parent.
static func create(height: float, radius: float, tint: Color, base: float = 0.0) -> LightBeam:
	var beam: LightBeam = LightBeam.new()
	beam._material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam._material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam._material.albedo_color = tint
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.material = beam._material
	beam.mesh = cylinder
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.position.y = base + height * 0.5
	return beam
