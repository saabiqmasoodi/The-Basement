extends Node
# Runtime horror dressing.
#
# The source scene is intentionally kept intact: this node only adds surface
# storytelling and non-colliding set dressing at runtime. Everything is built
# from cheap primitives and the generated grunge textures, so the room reads as
# a wet, neglected service basement without shipping a pile of new models.
#
# Placement uses physics raycasts where possible. That keeps floor stains on
# the actual floor and wall marks on the actual wall, even if the room layout is
# adjusted later.

const TEX_WATER := preload("res://materials/generated/decal_water.png")
const TEX_RUST := preload("res://materials/generated/decal_rust.png")
const TEX_MOLD := preload("res://materials/generated/decal_mold.png")
const TEX_BLOOD := preload("res://materials/generated/decal_blood.png")
const TEX_HAND := preload("res://materials/generated/decal_handprint.png")
const TEX_PUDDLE := preload("res://materials/generated/decal_puddle.png")
const TEX_PUDDLE_NORMAL := preload("res://materials/generated/decal_puddle_normal.png")
const TEX_PUDDLE_ORM := preload("res://materials/generated/decal_puddle_orm.png")
const TEX_HAZARD := preload("res://materials/generated/decal_hazard.png")
const TEX_SCRATCHES := preload("res://materials/generated/decal_scratches.png")

const DECAL_DEPTH := 0.55
const DECAL_OFFSET := DECAL_DEPTH * 0.5

var _space: PhysicsDirectSpaceState3D
var _rust: StandardMaterial3D
var _dark_metal: StandardMaterial3D
var _wood: StandardMaterial3D
var _concrete: StandardMaterial3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_rng.seed = 0xBA5E
	_rust = _textured_metal("res://materials/generated/decal_rust.png", Color(0.42, 0.30, 0.20), 0.55)
	_dark_metal = _plain_material(Color(0.052, 0.058, 0.055), 0.42, 0.65)
	_wood = _plain_material(Color(0.075, 0.058, 0.042), 0.88, 0.0)
	_concrete = _plain_material(Color(0.20, 0.215, 0.205), 0.92, 0.0)
	call_deferred("_build")


func _build() -> void:
	await get_tree().physics_frame
	var world := get_viewport().find_world_3d()
	if world == null:
		return
	_space = world.direct_space_state
	if _space == null:
		return
	_build_decals()
	_build_pipes()
	_build_chains()
	_build_cage()
	_build_barrels_and_debris()
	_build_signs()
	_build_particles()
	_build_extra_lights()


# ---------------------------------------------------------------- surface marks

func _build_decals() -> void:
	# Living room. Damp tracks lead from the front door toward the back room.
	_floor_decal(-13.1, -6.1, 1.4, 1.8, "water", Vector2(1.7, 3.1), 0.12, Color(0.72, 0.84, 0.84), "DampEntry")
	_floor_decal(-1.9, -8.2, 1.4, 1.8, "puddle", Vector2(2.8, 2.3), -0.36, Color(0.78, 0.91, 0.91), "SofaPuddle")
	_floor_decal(8.7, -4.6, 1.4, 1.8, "blood", Vector2(1.0, 1.7), 0.65, Color(0.78, 0.72, 0.70), "OldSmear")
	_floor_decal(-13.1, 7.2, 1.4, 1.8, "hazard", Vector2(2.4, 0.86), 0.0, Color(0.72, 0.72, 0.68), "StairHazard")

	# Back room and the top of the stairs.
	_floor_decal(-13.1, 11.1, 1.4, 1.8, "water", Vector2(2.0, 3.1), -0.1, Color(0.72, 0.86, 0.85), "StairWater")
	_floor_decal(-7.1, 15.1, 1.4, 1.8, "mold", Vector2(1.8, 2.2), 0.4, Color(0.75, 0.86, 0.76), "BackRoomMold")

	# Basement floor. The wet trail continues under the door.
	_floor_decal(-13.1, 16.2, -0.68, 4.35, "puddle", Vector2(2.3, 2.6), 0.2, Color(0.82, 0.94, 0.94), "BasementPuddle")
	_floor_decal(-10.0, 22.3, -0.68, 4.35, "water", Vector2(3.0, 3.8), -0.2, Color(0.72, 0.85, 0.83), "LongWater")
	_floor_decal(3.3, 19.2, -0.68, 4.35, "blood", Vector2(1.4, 2.1), -0.5, Color(0.8, 0.7, 0.68), "FuseBlood")
	_floor_decal(-13.0, 31.0, -0.68, 4.35, "rust", Vector2(2.4, 2.6), 0.35, Color(0.72, 0.62, 0.50), "FloorRust")
	_floor_decal(-6.0, 26.0, -0.68, 4.35, "puddle", Vector2(2.6, 3.0), -0.8, Color(0.82, 0.94, 0.94), "GeneratorPuddle")
	_floor_decal(-8.6, 29.4, -0.68, 4.35, "hazard", Vector2(2.2, 1.1), 0.0, Color(0.68, 0.68, 0.64), "GeneratorHazard")
	_floor_decal(5.4, 24.7, -0.68, 4.35, "water", Vector2(1.8, 2.4), 0.7, Color(0.74, 0.88, 0.88), "RightRoomWater")
	_floor_decal(-11.8, 29.3, -0.68, 4.35, "scratches", Vector2(1.5, 2.1), 0.1, Color(0.62, 0.64, 0.60), "FloorScratches")

	# Handprints, blood and mold on the walls.
	_wall_decal(-7.1, 1.62, 3.55, Vector3(0, 0, -1), "hand", Vector2(0.70, 0.82), 0.08, Color(0.84, 0.78, 0.76), "WallHandprint")
	_wall_decal(-18.9, 1.25, 6.0, Vector3(1, 0, 0), "mold", Vector2(1.55, 2.3), -0.2, Color(0.76, 0.88, 0.76), "WestMold")
	_wall_decal(12.18, 1.8, 0.0, Vector3(-1, 0, 0), "scratches", Vector2(1.45, 1.1), 0.0, Color(0.72, 0.74, 0.70), "EastScratches")
	_wall_decal(-11.0, 1.18, -12.35, Vector3(0, 0, 1), "blood", Vector2(1.6, 2.1), 0.2, Color(0.80, 0.68, 0.66), "NorthBlood")
	_wall_decal(-13.0, -3.0, 14.98, Vector3(0, 0, 1), "hand", Vector2(0.78, 0.90), -0.18, Color(0.82, 0.76, 0.72), "StairHandprint")
	_wall_decal(7.97, -3.0, 22.0, Vector3(-1, 0, 0), "scratches", Vector2(1.8, 1.25), 0.0, Color(0.70, 0.72, 0.68), "FuseScratches")
	_wall_decal(-20.75, -3.0, 24.0, Vector3(1, 0, 0), "mold", Vector2(1.8, 2.7), 0.3, Color(0.74, 0.86, 0.74), "BasementMold")
	_wall_decal(-8.0, -3.2, 28.06, Vector3(0, 0, -1), "blood", Vector2(1.25, 1.8), -0.35, Color(0.80, 0.68, 0.66), "GeneratorBlood")


func _floor_decal(
	x: float,
	z: float,
	top: float,
	drop: float,
	kind: String,
	footprint: Vector2,
	rotation: float,
	modulate: Color,
	node_name: String
) -> void:
	var hit := _ray(Vector3(x, top, z), Vector3(x, top - drop, z))
	if hit.is_empty():
		return
	var normal: Vector3 = hit.normal
	if normal.dot(Vector3.UP) < 0.55:
		return
	_add_decal(hit.position, normal, kind, footprint, rotation, modulate, node_name)


func _wall_decal(
	x: float,
	y: float,
	z: float,
	normal: Vector3,
	kind: String,
	footprint: Vector2,
	rotation: float,
	modulate: Color,
	node_name: String
) -> void:
	var target := Vector3(x, y, z)
	var hit := _ray(target + normal * 1.35, target - normal * 1.35)
	if hit.is_empty():
		return
	if abs(hit.normal.dot(normal)) < 0.55:
		return
	_add_decal(hit.position, hit.normal, kind, footprint, rotation, modulate, node_name)


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	query.collide_with_areas = false
	return _space.intersect_ray(query)


func _add_decal(
	point: Vector3,
	normal: Vector3,
	kind: String,
	footprint: Vector2,
	rotation: float,
	modulate: Color,
	node_name: String
) -> void:
	var decal := Decal.new()
	decal.name = node_name
	decal.texture_albedo = _decal_texture(kind)
	decal.size = Vector3(footprint.x, DECAL_DEPTH, footprint.y)
	decal.modulate = modulate
	decal.albedo_mix = 0.92
	decal.normal_fade = 0.08
	decal.upper_fade = 0.18
	decal.lower_fade = 0.18
	if kind == "puddle":
		decal.texture_normal = TEX_PUDDLE_NORMAL
		decal.texture_orm = TEX_PUDDLE_ORM
		decal.normal_fade = 0.03
	decal.set("distance_fade_enabled", true)
	decal.set("distance_fade_begin", 15.0)
	decal.set("distance_fade_length", 9.0)
	decal.set("distance_fade_margin", 1.0)
	decal.set("texture_repeat", false)
	decal.set("texture_filter", BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC)
	var basis := Basis(Quaternion(Vector3.UP, normal)) * Basis(Vector3.UP, rotation)
	decal.global_transform = Transform3D(basis, point + normal * DECAL_OFFSET)
	add_child(decal)


func _decal_texture(kind: String) -> Texture2D:
	match kind:
		"water":
			return TEX_WATER
		"rust":
			return TEX_RUST
		"mold":
			return TEX_MOLD
		"blood":
			return TEX_BLOOD
		"hand":
			return TEX_HAND
		"puddle":
			return TEX_PUDDLE
		"hazard":
			return TEX_HAZARD
		"scratches":
			return TEX_SCRATCHES
	return TEX_WATER


# --------------------------------------------------------------------- pipes

func _build_pipes() -> void:
	var root := Node3D.new()
	root.name = "BuriedPipes"
	add_child(root)

	# Main overhead runs. They give the basement a low, industrial ceiling.
	_add_cylinder(root, "CeilingPipeA", 0.105, 16.0, Vector3(-8.3, -1.02, 22.5), Vector3(PI * 0.5, 0, 0), _rust, 16)
	_add_cylinder(root, "CeilingPipeB", 0.070, 12.4, Vector3(-2.9, -1.16, 27.9), Vector3(0, 0, PI * 0.5), _dark_metal, 12)
	_add_cylinder(root, "CeilingPipeC", 0.085, 10.1, Vector3(4.5, -1.18, 21.0), Vector3(PI * 0.5, 0, 0), _rust, 14)
	_add_cylinder(root, "DropPipe", 0.075, 3.8, Vector3(-12.9, -2.9, 27.0), Vector3.ZERO, _rust, 12)

	# Support brackets and collars.
	for z in [-9.0, -3.0, 1.0, 5.0]:
		_add_box(root, "PipeBracket", Vector3(0.12, 0.42, 0.10), Vector3(-8.3, -0.80, 22.5 + z), Vector3.ZERO, _dark_metal)
	for x in [-6.7, -3.0, 0.7]:
		_add_box(root, "PipeBracketB", Vector3(0.10, 0.34, 0.12), Vector3(x, -0.99, 27.9), Vector3.ZERO, _dark_metal)
	for z in [-2.8, 1.0, 4.6]:
		_add_box(root, "PipeBracketC", Vector3(0.11, 0.40, 0.10), Vector3(4.5, -0.98, 21.0 + z), Vector3.ZERO, _dark_metal)
	_add_cylinder(root, "PipeCollar", 0.145, 0.24, Vector3(-8.3, -1.02, 16.6), Vector3(PI * 0.5, 0, 0), _dark_metal, 10)
	_add_cylinder(root, "PipeCollar2", 0.145, 0.24, Vector3(-8.3, -1.02, 28.4), Vector3(PI * 0.5, 0, 0), _dark_metal, 10)


# -------------------------------------------------------------------- chains

func _build_chains() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.032
	torus.outer_radius = 0.064
	torus.rings = 8
	torus.ring_segments = 8

	var chains := [
		{"x": -9.1, "z": 21.0, "length": 2.7, "phase": 0.0},
		{"x": -17.8, "z": 24.6, "length": 2.2, "phase": 0.5},
		{"x": -18.0, "z": 31.5, "length": 1.4, "phase": 0.9},
	]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = torus
	var total := 0
	for chain in chains:
		total += int(float(chain["length"]) / 0.105)
	mm.instance_count = total

	var index := 0
	for chain in chains:
		var length: float = chain["length"]
		var count := int(length / 0.105)
		for i in range(count):
			var y := -0.72 - (float(i) * length / float(count))
			var turn := (PI * 0.5) if (i % 2 == 0) else 0.0
			var basis := Basis(Vector3(1, 0, 0), PI * 0.5)
			basis = basis * Basis(Vector3(0, 1, 0), turn + chain["phase"])
			mm.set_instance_transform(index, Transform3D(basis, Vector3(chain["x"], y, chain["z"])))
			index += 1

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "HangingChains"
	mmi.multimesh = mm
	mmi.material_override = _dark_metal
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mmi)


# ---------------------------------------------------------------------- cage

func _build_cage() -> void:
	var root := Node3D.new()
	root.name = "HangingCage"
	add_child(root)
	var center := Vector3(-18.0, -2.95, 31.5)
	var half_x := 0.62
	var half_z := 0.58
	var top := center.y + 1.0
	var bottom := center.y - 1.0

	for x in [-half_x, 0.0, half_x]:
		for z in [-half_z, half_z]:
			_add_cylinder(root, "CageBar", 0.018, 2.0, Vector3(x, center.y, z) + Vector3(center.x, 0, center.z), Vector3.ZERO, _dark_metal, 6)
	for x in [-half_x, half_x]:
		_add_cylinder(root, "CageBar", 0.018, 2.0, Vector3(center.x + x, center.y, center.z), Vector3.ZERO, _dark_metal, 6)
	for x in [-half_x, half_x]:
		_add_box(root, "CageTopRail", Vector3(0.035, 0.035, half_z * 2.0), Vector3(center.x + x, top, center.z), Vector3.ZERO, _dark_metal)
		_add_box(root, "CageBottomRail", Vector3(0.035, 0.035, half_z * 2.0), Vector3(center.x + x, bottom, center.z), Vector3.ZERO, _dark_metal)
	for z in [-half_z, half_z]:
		_add_box(root, "CageTopRail", Vector3(half_x * 2.0, 0.035, 0.035), Vector3(center.x, top, center.z + z), Vector3.ZERO, _dark_metal)
		_add_box(root, "CageBottomRail", Vector3(half_x * 2.0, 0.035, 0.035), Vector3(center.x, bottom, center.z + z), Vector3.ZERO, _dark_metal)

	# A weak red lamp inside the cage is the only light in that corner.
	var lamp := OmniLight3D.new()
	lamp.name = "CageGlow"
	lamp.position = center + Vector3(0, 0.2, 0)
	lamp.light_color = Color(0.62, 0.12, 0.075)
	lamp.light_energy = 0.55
	lamp.omni_range = 2.2
	lamp.omni_attenuation = 1.6
	lamp.light_volumetric_fog_energy = 0.2
	lamp.shadow_enabled = false
	add_child(lamp)


# ----------------------------------------------------------- barrels and junk

func _build_barrels_and_debris() -> void:
	var root := Node3D.new()
	root.name = "RustedJunk"
	add_child(root)

	_add_barrel(root, Vector3(-18.45, -4.40, 16.6), 0.2)
	_add_barrel(root, Vector3(-17.55, -4.40, 17.4), 1.1)
	_add_barrel(root, Vector3(6.15, -4.40, 28.1), -0.4)
	_add_barrel(root, Vector3(-19.2, -4.40, 30.7), 0.7)

	# Broken planks and collapsed crates.
	_add_box(root, "Plank", Vector3(0.16, 0.045, 1.45), Vector3(-11.5, -4.86, 24.2), Vector3(0.15, 0.55, 0.10), _wood)
	_add_box(root, "Plank", Vector3(0.14, 0.04, 1.1), Vector3(-10.9, -4.85, 24.6), Vector3(-0.1, 0.24, -0.08), _wood)
	_add_box(root, "Crate", Vector3(0.52, 0.48, 0.50), Vector3(-16.7, -4.66, 30.4), Vector3(0, 0.4, 0), _wood)
	_add_box(root, "Crate", Vector3(0.44, 0.40, 0.46), Vector3(-16.2, -4.70, 30.8), Vector3(0, -0.2, 0), _wood)
	_add_box(root, "Crate", Vector3(0.60, 0.55, 0.52), Vector3(6.9, -4.62, 18.0), Vector3(0, 1.0, 0), _wood)

	# A fallen bucket and a short length of pipe on the ground.
	_add_cylinder(root, "Bucket", 0.20, 0.34, Vector3(-15.9, -4.72, 24.0), Vector3(0.1, 0.0, 1.35), _dark_metal, 10)
	_add_cylinder(root, "LoosePipe", 0.055, 1.9, Vector3(-12.0, -4.85, 31.0), Vector3(0, 0.3, PI * 0.5), _rust, 10)


func _add_barrel(parent: Node3D, pos: Vector3, yaw: float) -> void:
	_add_cylinder(parent, "Barrel", 0.35, 1.0, pos, Vector3(0, yaw, 0), _rust, 14)
	_add_cylinder(parent, "BarrelRing", 0.37, 0.035, pos + Vector3(0, 0.29, 0), Vector3(0, yaw, 0), _dark_metal, 14)
	_add_cylinder(parent, "BarrelRing", 0.37, 0.035, pos + Vector3(0, -0.29, 0), Vector3(0, yaw, 0), _dark_metal, 14)
	_add_cylinder(parent, "BarrelLid", 0.31, 0.012, pos + Vector3(0, 0.504, 0), Vector3(0, yaw, 0), _dark_metal, 14)


# --------------------------------------------------------------------- signs

func _build_signs() -> void:
	var keep_out := Label3D.new()
	keep_out.name = "KeepOutSign"
	keep_out.text = "KEEP OUT"
	keep_out.font_size = 64
	keep_out.pixel_size = 0.006
	keep_out.outline_size = 10
	keep_out.modulate = Color(0.58, 0.075, 0.035, 1.0)
	keep_out.outline_modulate = Color(0.005, 0.005, 0.005, 1.0)
	keep_out.no_depth_test = false
	keep_out.double_sided = true
	keep_out.position = Vector3(-5.65, -2.45, 28.02)
	keep_out.rotation.y = PI
	add_child(keep_out)

	var generator := Label3D.new()
	generator.name = "GeneratorSign"
	generator.text = "GENERATOR 03"
	generator.font_size = 42
	generator.pixel_size = 0.0045
	generator.outline_size = 7
	generator.modulate = Color(0.36, 0.39, 0.34, 1.0)
	generator.outline_modulate = Color(0.004, 0.004, 0.004, 1.0)
	generator.double_sided = true
	generator.position = Vector3(-8.5, -2.05, 28.035)
	generator.rotation.y = PI
	add_child(generator)


# ----------------------------------------------------------------- particles

func _build_extra_lights() -> void:
	# A single failing work lamp over the generator. The old scene left the
	# generator in near-total darkness until it was repaired, which made the
	# focal prop unreadable. This light is a practical, not a gameplay switch:
	# it stays on and gives the steam, sparks and rust a legible silhouette.
	var lamp := OmniLight3D.new()
	lamp.name = "GeneratorWorkLight"
	lamp.position = Vector3(-8.4, -1.45, 27.1)
	lamp.light_color = Color(0.48, 0.70, 0.70)
	lamp.light_energy = 2.4
	lamp.omni_range = 8.0
	lamp.omni_attenuation = 1.12
	lamp.light_size = 0.04
	lamp.light_specular = 0.25
	lamp.light_volumetric_fog_energy = 0.9
	lamp.shadow_enabled = true
	lamp.shadow_bias = 0.06
	lamp.shadow_normal_bias = 1.0
	lamp.shadow_blur = 0.5
	var fixture := Node3D.new()
	fixture.name = "Fixture"
	fixture.set_script(load("res://scripts/world/light_fixture.gd"))
	fixture.set("style", "bare_bulb")
	fixture.set("cord_length", 0.88)
	fixture.set("bulb_color", Color(0.55, 0.78, 0.78, 1.0))
	fixture.set("shade_color", Color(0.04, 0.05, 0.045, 1.0))
	fixture.set("metal_color", Color(0.05, 0.055, 0.05, 1.0))
	fixture.set("cage", true)
	fixture.set("fixture_scale", 0.85)
	lamp.add_child(fixture)
	add_child(lamp)


func _build_particles() -> void:
	# Steam rolls off the generator housing. It is deliberately slow and thin so
	# it catches the cold practicals without fogging the whole room.
	var steam := _steam_particles(Vector3(-7.35, -3.25, 27.15), 42, 4.6)
	add_child(steam)

	# A short burst of electrical sparks near the generator terminal.
	var sparks := _spark_particles(Vector3(-7.7, -3.65, 27.35), 20, 0.9)
	add_child(sparks)

	# A leaking ceiling joint adds movement above the player's head.
	var leak := _steam_particles(Vector3(-7.0, -1.18, 22.8), 18, 3.2)
	leak.name = "CeilingSteam"
	add_child(leak)


func _steam_particles(pos: Vector3, amount: int, lifetime: float) -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(0.55, 0.18, 0.5)
	process.direction = Vector3(0, 1, 0)
	process.spread = 14.0
	process.initial_velocity_min = 0.18
	process.initial_velocity_max = 0.55
	process.gravity = Vector3(0.0, 0.055, 0.0)
	process.damping_min = 0.04
	process.damping_max = 0.16
	process.scale_min = 0.35
	process.scale_max = 1.05
	process.color = Color(0.34, 0.40, 0.38, 1.0)
	process.color_ramp = _fade_gradient(Color(0.34, 0.40, 0.38, 0.0), Color(0.34, 0.40, 0.38, 0.40))
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.35
	process.turbulence_noise_scale = 2.0
	process.turbulence_influence_min = 0.04
	process.turbulence_influence_max = 0.12

	var mesh := QuadMesh.new()
	mesh.size = Vector2(1.1, 1.1)
	mesh.material = _particle_material(Color(0.32, 0.37, 0.35, 0.30), false)

	var particles := GPUParticles3D.new()
	particles.name = "GeneratorSteam"
	particles.position = pos
	particles.amount = amount
	particles.lifetime = lifetime
	particles.preprocess = 2.4
	particles.process_material = process
	particles.draw_pass_1 = mesh
	particles.local_coords = false
	particles.visibility_aabb = AABB(Vector3(-12, -4, -12), Vector3(24, 12, 24))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.set("transform_align", 1)
	return particles


func _spark_particles(pos: Vector3, amount: int, lifetime: float) -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.10
	process.direction = Vector3(0, 1, 0)
	process.spread = 65.0
	process.initial_velocity_min = 1.1
	process.initial_velocity_max = 3.2
	process.gravity = Vector3(0, -9.8, 0)
	process.scale_min = 0.010
	process.scale_max = 0.032
	process.color = Color(1.0, 0.38, 0.055, 1.0)
	process.color_ramp = _fade_gradient(Color(1.0, 0.55, 0.12, 0.0), Color(1.0, 0.22, 0.02, 1.0))

	var mesh := QuadMesh.new()
	mesh.size = Vector2(1.0, 1.0)
	mesh.material = _particle_material(Color(1.0, 0.36, 0.035, 1.0), true)

	var particles := GPUParticles3D.new()
	particles.name = "GeneratorSparks"
	particles.position = pos
	particles.amount = amount
	particles.lifetime = lifetime
	particles.preprocess = 0.3
	particles.process_material = process
	particles.draw_pass_1 = mesh
	particles.local_coords = false
	particles.visibility_aabb = AABB(Vector3(-9, -5, -9), Vector3(18, 11, 18))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.set("transform_align", 1)
	return particles


func _fade_gradient(start: Color, mid: Color) -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.set_color(0, start)
	gradient.set_color(1, Color(start.r, start.g, start.b, 0.0))
	gradient.add_point(0.22, mid)
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture


func _particle_material(tint: Color, additive: bool) -> StandardMaterial3D:
	# Use Godot's particle billboard path and vertex colours so the
	# ParticleProcessMaterial colour ramp actually fades every particle. A raw
	# ShaderMaterial would ignore the per-instance colour and produce endless
	# opaque quads.
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = _radial_texture()
	material.albedo_color = tint
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material


func _radial_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 1),
		Color(1, 1, 1, 0.55),
		Color(1, 1, 1, 0.12),
		Color(1, 1, 1, 0),
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.32, 0.7, 1.0])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 64
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture


# ------------------------------------------------------------------ primitives

func _add_cylinder(
	parent: Node3D,
	label: String,
	radius: float,
	height: float,
	pos: Vector3,
	rotation: Vector3,
	material: Material,
	segments: int
) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 2
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	instance.rotation = rotation
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(instance)


func _add_box(
	parent: Node3D,
	label: String,
	size: Vector3,
	pos: Vector3,
	rotation: Vector3,
	material: Material
) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	instance.rotation = rotation
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(instance)


func _plain_material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return mat


func _textured_metal(path: String, tint: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(path) as Texture2D
	mat.albedo_color = tint
	mat.roughness = roughness
	mat.metallic = 0.55
	mat.texture_repeat = true
	mat.uv1_scale = Vector3(2.0, 2.0, 2.0)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return mat
