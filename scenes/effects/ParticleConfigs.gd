## ParticleConfigs.gd
## Factory class providing pre-configured ParticleProcessMaterial instances
## for all visual effects in the game. Keeps particle configuration
## centralised and reusable (floating text lives in PopupText).
##
## Usage:
##   ParticleConfigs.spawn_burst(get_parent(), global_position, ParticleConfigs.gem_collect_burst())
##
## All methods are static — no instance is ever needed.
class_name ParticleConfigs
extends RefCounted

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

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
## Bright sparkle pop where a hunter loses gems. Soft round sparks that rise
## and vanish quickly: they must not look like gem pieces (the real loose gems
## are whole and collectible).
## Amount: 24 | Lifetime: 0.8 s.
static func gem_lost_burst() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.3
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 180.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 4.0
	mat.gravity = Vector3(0.0, -1.5, 0.0)
	mat.damping_min = 3.0
	mat.damping_max = 5.0
	mat.scale_min = 0.05
	mat.scale_max = 0.12
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(0.55, 0.95, 1.0, 0.9), Color(0.55, 0.95, 1.0, 0.0)])
	grad.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	mat.color_ramp = ramp
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


## Dizzy stars: flat five-pointed star facing the camera (stun / confusion).
const STAR_POINTS: int = 5
const STAR_OUTER: float = 0.16
const STAR_INNER: float = 0.07
const STAR_COLOR: Color = Color(1.0, 0.88, 0.25)

static var _star: ArrayMesh = null


## Five-pointed star mesh for particle draw passes, built once and shared.
static func star_mesh() -> ArrayMesh:
	if _star:
		return _star
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners: int = STAR_POINTS * 2
	for n: int in corners:
		var a0: float = TAU * n / corners + PI * 0.5
		var a1: float = TAU * (n + 1) / corners + PI * 0.5
		var r0: float = STAR_OUTER if n % 2 == 0 else STAR_INNER
		var r1: float = STAR_OUTER if (n + 1) % 2 == 0 else STAR_INNER
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(cos(a1) * r1, sin(a1) * r1, 0.0))
		st.add_vertex(Vector3(cos(a0) * r0, sin(a0) * r0, 0.0))
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.albedo_color = STAR_COLOR
	_star = st.commit()
	_star.surface_set_material(0, mat)
	return _star


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


## Camera-facing soft round sprite tinted by the particle colour: the draw
## pass for every burst and for looping emitters (sprinkler water, ...).
static func soft_quad() -> QuadMesh:
	var draw_mat := StandardMaterial3D.new()
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.vertex_color_use_as_albedo = true
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	draw_mat.billboard_keep_scale = true  # Without this the process scale is ignored.
	draw_mat.albedo_texture = _soft_dot_texture()
	var quad := QuadMesh.new()
	quad.material = draw_mat
	return quad


## water_jet
## Sprinkler stream: droplets shot forward in an arc that falls back to the ground.
static func water_jet() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 0.55, 1.0)
	mat.spread = 8.0
	mat.initial_velocity_min = 6.5
	mat.initial_velocity_max = 8.0
	mat.gravity = Vector3(0.0, -9.8, 0.0)
	mat.scale_min = 0.2
	mat.scale_max = 0.38
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0.6, 0.88, 1.0, 1.0), Color(0.15, 0.55, 1.0, 0.95), Color(0.15, 0.55, 1.0, 0.0)])
	grad.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	mat.color_ramp = ramp
	return mat


## Spawns a self-freeing one-shot particle burst at [param pos] under [param parent].
static func spawn_burst(parent: Node, pos: Vector3, process: ParticleProcessMaterial,
		amount: int = 24, lifetime: float = 0.8) -> void:
	var particles := GPUParticles3D.new()
	particles.process_material = process
	particles.draw_pass_1 = soft_quad()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 1.0
	parent.add_child(particles)
	particles.global_position = pos
	particles.emitting = true
	particles.finished.connect(particles.queue_free)
