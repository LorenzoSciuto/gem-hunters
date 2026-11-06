## CharacterModel.gd
## Visual body of a character: toon-shaded capsule, face, per-archetype accessory
## and the leader crown. Shared by the in-game Player and the selection preview.
## Origin is at the feet; the model faces +Z.
extends Node3D
class_name CharacterModel

const BODY_OUTLINE_WIDTH: float = 0.025

@onready var rig: Node3D = $Rig
@onready var body_mesh: MeshInstance3D = $Rig/BodyMesh
@onready var crown: Node3D = $Rig/Crown
@onready var accessories: Dictionary = {
	"dashy": $Rig/Accessories/DashyHeadband,
	"bouncer": $Rig/Accessories/BouncerSpring,
	"tanky": $Rig/Accessories/TankyArmor,
	"tricky": $Rig/Accessories/TrickyHorns,
}


## Applies color, scale and accessory for [param data].
func set_character(data: CharacterData) -> void:
	if data == null:
		return
	body_mesh.set_surface_override_material(0, ToonMaterials.get_material(data.color, BODY_OUTLINE_WIDTH))
	rig.scale = data.mesh_scale
	for id: String in accessories:
		(accessories[id] as Node3D).visible = id == data.id


func set_crown_visible(shown: bool) -> void:
	crown.visible = shown


## Moves every mesh of the model onto one render layer (bit index [param layer]).
func set_render_layer(layer: int) -> void:
	for node: Node in find_children("*", "VisualInstance3D", true, false):
		(node as VisualInstance3D).layers = 1 << layer
