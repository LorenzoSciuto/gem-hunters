## RenderQuality.gd
## Decides how much the renderer does. Phones and tablets get the lite
## profile; everything else keeps the full look.
##
## Lite: the 3D view is drawn at LITE_3D_SCALE of the screen resolution and
## upscaled, with no multisampling, bloom or sun shadows, and without the small
## lights on gems and gift boxes. On the Compatibility renderer (the one
## browsers use) every such light draws again all the geometry it reaches.
##
## The profile is applied here, to each node as it enters the tree, so scenes
## and scripts describe the full look only and never ask which profile is on.
extends Node

const LITE_3D_SCALE: float = 0.7

var lite: bool = false


func _ready() -> void:
	if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		enable_lite()


## Switches to the lite profile for everything added from now on (and the
## root viewport). There is no way back within a run.
func enable_lite() -> void:
	if lite:
		return
	lite = true
	_lighten(get_viewport())
	get_tree().node_added.connect(_lighten)


func _lighten(node: Node) -> void:
	if node is Viewport:
		(node as Viewport).msaa_3d = Viewport.MSAA_DISABLED
		(node as Viewport).scaling_3d_scale = LITE_3D_SCALE
	elif node is OmniLight3D:
		(node as OmniLight3D).visible = false
	elif node is DirectionalLight3D:
		(node as DirectionalLight3D).shadow_enabled = false
	elif node is WorldEnvironment:
		(node as WorldEnvironment).environment.glow_enabled = false
