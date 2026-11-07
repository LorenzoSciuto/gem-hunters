## ArenaEnvironment.gd
## Lighting for an arena: painterly sky, sky-tinted ambient, filmic tone
## mapping, SSAO, soft glow, distance haze and a soft-shadowed sun, all driven
## by the LevelConfig colours.
class_name ArenaEnvironment

const SHADER_SKY: Shader = preload("res://shaders/stylized_sky.gdshader")
const SUN_SHADOW_DISTANCE: float = 80.0
## Post-processing shared by every arena: crisp contrast and a bit more colour.
const SSAO_RADIUS: float = 1.0
const SSAO_INTENSITY: float = 2.0
const SSAO_LIGHT_AFFECT: float = 0.2
const GRADE_CONTRAST: float = 1.06
const GRADE_SATURATION: float = 1.12
const TONEMAP_WHITE: float = 6.0
const TONEMAP_EXPOSURE: float = 1.0
const GLOW_INTENSITY: float = 0.6
const GLOW_BLOOM: float = 0.05
const GLOW_THRESHOLD: float = 0.95
## Share of the ambient light taken from the sky (the rest is the arena tint).
const AMBIENT_SKY_SHARE: float = 0.45
const CLOUD_WHITENESS: float = 0.75
## Minimum distance haze, even in arenas without fog.
const HAZE_DENSITY: float = 0.0012
const FOG_SKY_AFFECT: float = 0.15
const FOG_AERIAL: float = 0.25
const SUN_SHADOW_BLUR: float = 2.0
const SUN_ANGULAR_SIZE: float = 1.5


## Adds the sky, ambient, post-processing and sun for [param config] under [param parent].
static func build(parent: Node3D, config: LevelConfig) -> void:
	var sky_mat: ShaderMaterial = ShaderMaterial.new()
	sky_mat.shader = SHADER_SKY
	sky_mat.set_shader_parameter("top_color", config.sky_top_color)
	sky_mat.set_shader_parameter("horizon_color", config.sky_horizon_color)
	sky_mat.set_shader_parameter("ground_color", config.outer_ground_color)
	sky_mat.set_shader_parameter("cloud_color", config.sky_horizon_color.lerp(Color.WHITE, CLOUD_WHITENESS))
	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat

	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# Ambient = the arena's tint blended with the sky, so shaded sides stay colourful.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = config.ambient_color
	env.ambient_light_sky_contribution = AMBIENT_SKY_SHARE
	env.ambient_light_energy = config.ambient_energy
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = TONEMAP_WHITE
	env.tonemap_exposure = TONEMAP_EXPOSURE
	env.ssao_enabled = true
	env.ssao_radius = SSAO_RADIUS
	env.ssao_intensity = SSAO_INTENSITY
	env.ssao_light_affect = SSAO_LIGHT_AFFECT
	env.glow_enabled = true
	env.glow_intensity = GLOW_INTENSITY
	env.glow_bloom = GLOW_BLOOM
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = GLOW_THRESHOLD
	env.adjustment_enabled = true
	env.adjustment_contrast = GRADE_CONTRAST
	env.adjustment_saturation = GRADE_SATURATION
	# Distance haze in the horizon colour gives depth to the maze and scenery.
	env.fog_enabled = true
	env.fog_light_color = config.fog_color if config.fog_density > 0.0 else config.sky_horizon_color
	env.fog_density = maxf(config.fog_density, HAZE_DENSITY)
	env.fog_sky_affect = FOG_SKY_AFFECT
	env.fog_aerial_perspective = FOG_AERIAL
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = env
	parent.add_child(world_env)

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.light_color = config.sun_color
	sun.light_energy = config.sun_energy
	sun.shadow_enabled = true
	sun.shadow_blur = SUN_SHADOW_BLUR
	sun.light_angular_distance = SUN_ANGULAR_SIZE
	sun.directional_shadow_max_distance = SUN_SHADOW_DISTANCE
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.rotation_degrees = Vector3(-50.0, 35.0, 0.0)
	parent.add_child(sun)
