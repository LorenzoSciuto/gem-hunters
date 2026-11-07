## ParticleConfigs.gd
## Factory class providing pre-configured ParticleProcessMaterial instances
## for all visual effects in the game. Keeps particle configuration
## centralised and reusable.
##
## Usage:
##   ParticleConfigs.spawn_burst(get_parent(), global_position, ParticleConfigs.gem_collect_burst())
##
## All methods are static — no instance is ever needed.
class_name ParticleConfigs
extends RefCounted

## Floating popup text (spawn_popup_text).
const POPUP_FONT_SIZE: int = 160
const POPUP_OUTLINE_SIZE: int = 22
const POPUP_START_SCALE: float = 0.4
const POPUP_POP_TIME: float = 0.18
const POPUP_PIXEL_SIZE: float = 0.008
const POPUP_RISE: float = 1.6
const POPUP_DURATION: float = 1.1

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

## Creates a gradient texture that wraps a single Color as a constant curve.
## Used for simple solid-colour particle tinting.
static func _solid_color_texture(color: Color) -> GradientTexture1D:
	var grad := Gradient.new()
	grad.colors = PackedColorArray([color, color])
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	var tex := GradientTexture1D.new()
	tex.gradient = grad
	return tex


## Creates a gradient texture that fades from `color` to transparent.
## Gives particles a natural fade-out without touching ALPHA on the material.
static func _fade_out_texture(color: Color) -> GradientTexture1D:
	var start := color
	var end   := Color(color.r, color.g, color.b, 0.0)
	var grad  := Gradient.new()
	grad.colors  = PackedColorArray([start, end])
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	var tex := GradientTexture1D.new()
	tex.gradient = grad
	return tex


## Creates a rainbow gradient texture cycling R→G→B→transparent.
static func _rainbow_fade_texture() -> GradientTexture1D:
	var grad := Gradient.new()
	grad.colors = PackedColorArray([
		Color(1.0, 0.3, 0.3, 1.0),
		Color(1.0, 1.0, 0.1, 1.0),
		Color(0.3, 1.0, 0.3, 1.0),
		Color(0.2, 0.8, 1.0, 1.0),
		Color(0.8, 0.3, 1.0, 0.0),
	])
	grad.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	var tex := GradientTexture1D.new()
	tex.gradient = grad
	return tex


# ---------------------------------------------------------------------------
# Public factory methods
# ---------------------------------------------------------------------------

## gem_collect_burst
## Burst of coloured sparkles fired upward when a gem is collected.
## Amount: 32 | Lifetime: 0.6 s | One-shot burst.
static func gem_collect_burst() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()

	# Emit from a small sphere centred on the gem
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.15

	# Shoot upward with a wide spread
	mat.direction          = Vector3(0.0, 1.0, 0.0)
	mat.spread             = 60.0
	mat.initial_velocity_min = 2.5
	mat.initial_velocity_max = 5.0

	# Slight downward gravity so sparks arc naturally
	mat.gravity = Vector3(0.0, -4.0, 0.0)

	# Particle size
	mat.scale_min = 0.08
	mat.scale_max = 0.18

	# Colour: rainbow fade-out
	mat.color_ramp = _rainbow_fade_texture()

	# Damping so they don't fly forever
	mat.damping_min = 2.0
	mat.damping_max = 4.0

	return mat


## gem_lost_burst
## Raining gem fragment pieces downward when a player drops their gems.
## Amount: 24 | Lifetime: 0.9 s.
static func gem_lost_burst() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()

	# Point source; fragments scatter in all directions then fall
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.2

	mat.direction          = Vector3(0.0, -1.0, 0.0)
	mat.spread             = 80.0
	mat.initial_velocity_min = 1.5
	mat.initial_velocity_max = 3.5

	# Strong gravity — fragments fall fast
	mat.gravity = Vector3(0.0, -9.8, 0.0)

	mat.scale_min = 0.06
	mat.scale_max = 0.14

	# Desaturated cyan → transparent (gem shards losing colour)
	mat.color_ramp = _fade_out_texture(Color(0.4, 0.9, 1.0, 1.0))

	# Spin fragments as they fall
	mat.angular_velocity_min = -180.0
	mat.angular_velocity_max =  180.0

	return mat


## bubble_pop_burst
## Expanding soap bubble ring popping outward in all directions.
## Amount: 20 | Lifetime: 0.5 s.
static func bubble_pop_burst() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()

	# Start from a ring (box emission flattened on Y gives a disc-ish shape)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(0.1, 0.02, 0.1)

	# Fly radially outward (direction + full spread = sphere)
	mat.direction = Vector3(0.0, 0.0, 1.0)
	mat.spread    = 180.0

	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 4.5

	# Very light gravity — bubbles almost float
	mat.gravity = Vector3(0.0, -0.5, 0.0)

	# Bubbles start large and shrink as they pop
	mat.scale_min = 0.20
	mat.scale_max = 0.35

	# White-blue iridescent → transparent
	mat.color_ramp = _fade_out_texture(Color(0.85, 0.95, 1.0, 0.9))

	mat.damping_min = 5.0
	mat.damping_max = 8.0

	return mat


## freeze_puff
## Icy snow/frost puff when the ice power-up is activated.
## Amount: 40 | Lifetime: 0.8 s.
static func freeze_puff() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()

	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.3

	# Drift upward and outward from impact
	mat.direction          = Vector3(0.0, 1.0, 0.0)
	mat.spread             = 90.0
	mat.initial_velocity_min = 0.5
	mat.initial_velocity_max = 2.0

	# Slight float — ice particles hang momentarily
	mat.gravity = Vector3(0.0, 0.5, 0.0)

	mat.scale_min = 0.05
	mat.scale_max = 0.12

	# Ice-blue to white to transparent
	var grad := Gradient.new()
	grad.colors  = PackedColorArray([
		Color(0.6, 0.9, 1.0, 1.0),
		Color(1.0, 1.0, 1.0, 0.8),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	mat.color_ramp = ramp

	mat.damping_min = 1.5
	mat.damping_max = 3.0

	return mat


## spring_launch
## Spring coil / boing particles when a spring trap launches a player.
## Amount: 16 | Lifetime: 0.4 s.
static func spring_launch() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()

	# Emit along a vertical line (spring column)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(0.05, 0.3, 0.05)

	mat.direction          = Vector3(0.0, 1.0, 0.0)
	mat.spread             = 25.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 7.0

	mat.gravity = Vector3(0.0, -4.0, 0.0)

	# Coil rings: medium-large yellow-green
	mat.scale_min = 0.10
	mat.scale_max = 0.20

	# Bright yellow-green → transparent
	mat.color_ramp = _fade_out_texture(Color(0.7, 1.0, 0.1, 1.0))

	mat.angular_velocity_min = 90.0
	mat.angular_velocity_max = 360.0

	return mat




## confetti_shower
## Colourful winner celebration confetti raining down from above.
## Amount: 120 | Lifetime: 2.5 s.
static func confetti_shower() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()

	# Broad horizontal area above the players
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(5.0, 0.1, 5.0)

	mat.direction          = Vector3(0.0, -1.0, 0.0)
	mat.spread             = 20.0
	mat.initial_velocity_min = 1.0
	mat.initial_velocity_max = 3.0

	# Realistic confetti fall speed
	mat.gravity = Vector3(0.0, -4.0, 0.0)

	# Flat rectangular confetti pieces (non-square scale)
	mat.scale_min = 0.08
	mat.scale_max = 0.18

	# Full rainbow confetti — stays opaque until near lifetime end
	var grad := Gradient.new()
	grad.colors = PackedColorArray([
		Color(1.0, 0.3, 0.3, 1.0),  # coral
		Color(1.0, 0.85, 0.1, 1.0), # yellow
		Color(0.3, 0.9, 0.4, 1.0),  # mint
		Color(0.3, 0.7, 1.0, 1.0),  # sky
		Color(0.9, 0.4, 1.0, 1.0),  # purple
		Color(1.0, 0.3, 0.3, 0.0),  # fade out at end
	])
	grad.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	mat.color_ramp = ramp

	# Spinning confetti pieces
	mat.angular_velocity_min = -270.0
	mat.angular_velocity_max =  270.0

	# Slight flutter turbulence
	mat.turbulence_enabled        = true
	mat.turbulence_noise_strength = 0.8
	mat.turbulence_noise_speed    = Vector3(0.5, 0.2, 0.5)

	return mat


## dust_puff
## Soft ground dust kicked up by running feet and landings; [param color] tints it
## (the arena floor colour reads best).
static func dust_puff(color: Color = Color(1.0, 0.97, 0.92, 0.7)) -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_axis = Vector3.UP
	mat.emission_ring_radius = 0.3
	mat.emission_ring_inner_radius = 0.1
	mat.emission_ring_height = 0.02
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 75.0
	mat.initial_velocity_min = 0.6
	mat.initial_velocity_max = 1.6
	mat.gravity = Vector3(0.0, 0.4, 0.0)
	mat.damping_min = 2.0
	mat.damping_max = 3.0
	mat.scale_min = 0.25
	mat.scale_max = 0.5
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.4))
	grow.add_point(Vector2(1.0, 1.0))
	var grow_tex := CurveTexture.new()
	grow_tex.curve = grow
	mat.scale_curve = grow_tex
	mat.color_ramp = _fade_out_texture(color)
	return mat


static var _dot: GradientTexture2D = null


## Round soft-edged sprite shared by every burst.
static func _soft_dot_texture() -> GradientTexture2D:
	if _dot:
		return _dot
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	_dot = GradientTexture2D.new()
	_dot.gradient = grad
	_dot.fill = GradientTexture2D.FILL_RADIAL
	_dot.fill_from = Vector2(0.5, 0.5)
	_dot.fill_to = Vector2(1.0, 0.5)
	return _dot


## Spawns a self-freeing one-shot particle burst at [param pos] under [param parent].
static func spawn_burst(parent: Node, pos: Vector3, process: ParticleProcessMaterial,
		amount: int = 24, lifetime: float = 0.8) -> void:
	var draw_mat := StandardMaterial3D.new()
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.vertex_color_use_as_albedo = true
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	draw_mat.billboard_keep_scale = true  # Without this the process scale is ignored.
	draw_mat.albedo_texture = _soft_dot_texture()
	var quad := QuadMesh.new()
	quad.material = draw_mat
	var particles := GPUParticles3D.new()
	particles.process_material = process
	particles.draw_pass_1 = quad
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 1.0
	parent.add_child(particles)
	particles.global_position = pos
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


## Big floating text (e.g. "+2") that rises and fades out, seen on every screen.
static func spawn_popup_text(parent: Node, pos: Vector3, text: String, color: Color) -> void:
	var label: Label3D = Label3D.new()
	label.text = text
	label.font = Constants.DISPLAY_FONT
	label.modulate = color
	label.outline_modulate = Color(0.1, 0.06, 0.15)
	label.font_size = POPUP_FONT_SIZE
	label.outline_size = POPUP_OUTLINE_SIZE
	label.pixel_size = POPUP_PIXEL_SIZE
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)
	label.global_position = pos
	var tween: Tween = label.create_tween().set_parallel()
	label.scale = Vector3.ONE * POPUP_START_SCALE
	tween.tween_property(label, "scale", Vector3.ONE, POPUP_POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "global_position:y", pos.y + POPUP_RISE, POPUP_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, POPUP_DURATION).set_delay(POPUP_DURATION * 0.5)
	tween.chain().tween_callback(label.queue_free)
