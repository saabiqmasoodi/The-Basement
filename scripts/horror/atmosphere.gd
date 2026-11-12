extends Node
# Lightweight airborne dust around the player. The particles live in world
# space, so they drift naturally while the camera turns. Counts and sizes are
# deliberately small: this is atmosphere, not a snowstorm.

const DUST_AMOUNT := 120
const DUST_RADIUS := 7.0
const DUST_HEIGHT := 3.2


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var world := get_parent()
	var cam := world.get_node_or_null("Player/Head/Camera3D") as Camera3D
	if cam == null:
		return

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(DUST_RADIUS, DUST_HEIGHT, DUST_RADIUS)
	process.direction = Vector3(0, 1, 0)
	process.spread = 180.0
	process.initial_velocity_min = 0.008
	process.initial_velocity_max = 0.045
	process.gravity = Vector3(0, -0.0035, 0)
	process.scale_min = 0.002
	process.scale_max = 0.009
	process.color = Color(0.82, 0.78, 0.7, 0.3)
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.04
	process.turbulence_noise_scale = 4.0
	process.turbulence_influence_min = 0.01
	process.turbulence_influence_max = 0.05
	process.damping_min = 0.008
	process.damping_max = 0.04
	process.angle_min = 0.0
	process.angle_max = 360.0
	process.lifetime_randomness = 0.7

	var grad := Gradient.new()
	grad.colors = PackedColorArray([
		Color(1, 1, 1, 1),
		Color(1, 1, 1, 0.72),
		Color(1, 1, 1, 0.12),
		Color(1, 1, 1, 0),
	])
	grad.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])

	var sprite := GradientTexture2D.new()
	sprite.gradient = grad
	sprite.width = 64
	sprite.height = 64
	sprite.fill = GradientTexture2D.FILL_RADIAL
	sprite.fill_from = Vector2(0.5, 0.5)
	sprite.fill_to = Vector2(1.0, 0.5)

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = sprite
	mat.albedo_color = Color(1, 1, 1, 0.62)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	quad.material = mat

	var particles := GPUParticles3D.new()
	particles.name = "DustMotes"
	particles.amount = DUST_AMOUNT
	particles.lifetime = 10.0
	particles.preprocess = 5.0
	particles.fixed_fps = 30
	particles.interpolate = true
	particles.local_coords = false
	particles.visibility_aabb = AABB(Vector3(-DUST_RADIUS, -DUST_HEIGHT, -DUST_RADIUS), Vector3(DUST_RADIUS * 2.0, DUST_HEIGHT * 2.0, DUST_RADIUS * 2.0))
	particles.process_material = process
	particles.draw_pass_1 = quad
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cam.add_child(particles)
	particles.emitting = true
