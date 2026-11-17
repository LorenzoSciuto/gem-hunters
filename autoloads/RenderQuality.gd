## RenderQuality.gd
## Decides how much the renderer does. Handheld devices (ScreenLayout.handheld)
## and console browsers get the lite profile; everything else keeps the full
## look. A console browser gives a page little graphics memory: with the full
## look (multisampled views, bloom and shadow buffers) it drops the WebGL
## context, which ends the game.
##
## Lite: the 3D view is drawn at LITE_3D_SCALE of the screen resolution and
## upscaled, with no multisampling, bloom or sun shadows, and without the small
## lights on gems and gift boxes. On the Compatibility renderer (the one
## browsers use) every such light draws again all the geometry it reaches.
## Ambient light is a flat colour instead of being sampled from the sky (no
## sky radiance maps to build), and a view is never taller than
## LITE_MAX_VIEW_LINES: a 4K screen renders its views at half size.
##
## The profile is applied here, to each node as it enters the tree, so scenes
## and scripts describe the full look only and never ask which profile is on.
extends Node

const LITE_3D_SCALE: float = 0.7
const LITE_MAX_VIEW_LINES: float = 1080.0
## Browser user agents that name a console.
const CONSOLE_USER_AGENTS: Array[String] = ["Xbox", "PlayStation", "Nintendo"]

var lite: bool = false


func _ready() -> void:
	if ScreenLayout.handheld or _is_console_browser():
		enable_lite()


func _is_console_browser() -> bool:
	if not OS.has_feature("web"):
		return false
	var user_agent: String = str(JavaScriptBridge.eval("navigator.userAgent"))
	return CONSOLE_USER_AGENTS.any(func(console: String) -> bool: return user_agent.contains(console))


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
	elif node is SubViewportContainer:
		var short_side: int = mini(get_window().size.x, get_window().size.y)
		(node as SubViewportContainer).stretch_shrink = ceili(short_side / LITE_MAX_VIEW_LINES)
	elif node is WorldEnvironment:
		var environment: Environment = (node as WorldEnvironment).environment
		environment.glow_enabled = false
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
