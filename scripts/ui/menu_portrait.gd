extends SubViewport
# Live start-menu key art.
#
# The menu shows a duplicate of the normal Friend scene (the same model used in
# the game) standing against a basement wall. The duplicate's head is removed
# at runtime: head-weighted clothing/body triangles are filtered, a portrait
# shader clips everything above the neck, the eyes and hair are hidden, and the
# flush neck wound plus wall splatter are dressed with red blood. Nothing here
# touches the gameplay Friend instance.

const FRIEND_SCENE := "res://assets/models/characters/Friend/friend.tscn"
const WALL_TEXTURE := "res://assets/textures/environment/wall/concrete_wall_005_diff_4k.jpg"
const WALL_NORMAL := "res://materials/generated/wall_concrete_normal.png"
const WALL_ROUGH := "res://materials/generated/wall_concrete_roughness.png"
const FLOOR_TEXTURE := "res://assets/textures/environment/painted_concrete_02_diff_2k.jpg"
const FLOOR_NORMAL := "res://materials/generated/floor_basement_normal.png"
const BLOOD_TEXTURE := "res://materials/generated/decal_blood.png"
const BLOOD_SHADER := "res://materials/generated/wall_blood.gdshader"
const HEADLESS_SHADER := "res://materials/generated/headless_cut.gdshader"

const VIEW_SIZE := Vector2i(2560, 1440)

var _world: Node3D
var _friend: Node3D
var _skeleton: Skeleton3D
var _camera: Camera3D
var _camera_target := Vector3(0.12, 1.12, 0.10)
var _camera_home := Vector3(0.92, 1.52, 3.18)
var _blood: StandardMaterial3D
var _blood_dark: StandardMaterial3D
var _wall_blood_shader: Shader
var _wound_light: OmniLight3D
var _red_wash: SpotLight3D
var _time := 0.0
var _camera_time := 0.0
var _wound_bone := -1
var _spine_bone := -1
var _friend_home := Vector3(0.56, 0.0, 0.10)
var _friend_yaw := PI - 0.10


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	size = VIEW_SIZE
	own_world_3d = true
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	msaa_3d = Viewport.MSAA_2X
	_build_environment()
	_build_set()
	await _build_friend()
	_build_lights()
	_build_camera()
	# Run after the duplicate's AnimationTree has written the idle pose, so the
	# tiny wound twitch is additive rather than discarded by the animation.
	process_priority = 100
	set_process(true)


func _process(delta: float) -> void:
	if _camera == null:
		return
	_time += delta
	_camera_time += delta

	# Slow, deliberate camera movement: the menu should feel like a held breath,
	# not a slideshow. The dolly is large enough to read as a living camera while
	# the long periods keep the title and buttons perfectly steady.
	var drift := Vector3(
		sin(_camera_time * 0.19) * 0.055 + sin(_camera_time * 0.07 + 2.1) * 0.018,
		sin(_camera_time * 0.27 + 1.1) * 0.030 + sin(_camera_time * 0.09) * 0.010,
		sin(_camera_time * 0.13) * 0.105 + sin(_camera_time * 0.041 + 0.7) * 0.035
	)
	_camera.position = _camera_home + drift
	_camera.look_at(_camera_target + Vector3(
		sin(_camera_time * 0.13) * 0.022,
		sin(_camera_time * 0.19) * 0.016,
		0.0
	), Vector3.UP)

	# Let the whole body breathe against the wall. This is separate from the
	# imported idle so the silhouette keeps moving even in the quiet beats.
	if _friend != null:
		_friend.position = _friend_home + Vector3(
			sin(_time * 0.21) * 0.012,
			sin(_time * 0.37 + 0.4) * 0.006,
			sin(_time * 0.17 + 1.4) * 0.008
		)
		_friend.rotation.y = _friend_yaw + sin(_time * 0.19) * 0.010

	# The neck wound breathes like a dying emergency light.
	if _wound_light != null:
		var breath := 0.72 + 0.28 * sin(_time * 2.3 + sin(_time * 0.37) * 2.0)
		_wound_light.light_energy = 0.28 + breath * 0.20
	if _red_wash != null:
		var flicker := 0.82 + 0.18 * sin(_time * 7.3) * sin(_time * 0.91)
		_red_wash.light_energy = 2.0 + flicker * 0.35

	# A tiny headless twitch on top of the source idle animation. The animation
	# tree writes the pose first, then this additive shoulder/neck motion makes
	# the silhouette feel alive without disturbing the gameplay animation.
	if _skeleton != null and _wound_bone >= 0:
		var base := _skeleton.get_bone_pose_rotation(_wound_bone)
		var twitch := sin(_time * 0.83) * 0.016 + sin(_time * 2.17) * 0.007
		if fmod(_time, 6.0) < 0.16:
			twitch += 0.050 * sin((_time - floor(_time / 6.0) * 6.0) / 0.16 * PI)
		_skeleton.set_bone_pose_rotation(
			_wound_bone,
			base * Quaternion(Vector3.RIGHT, twitch)
		)
	if _skeleton != null and _spine_bone >= 0:
		var spine_base := _skeleton.get_bone_pose_rotation(_spine_bone)
		var breath := sin(_time * 0.55) * 0.006
		_skeleton.set_bone_pose_rotation(
			_spine_bone,
			spine_base * Quaternion(Vector3.RIGHT, breath)
		)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.003, 0.004, 0.005, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.060, 0.082, 0.080, 1.0)
	env.ambient_light_energy = 0.22
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.16
	env.tonemap_agx_white = 6.5
	env.tonemap_agx_contrast = 1.08
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.55
	env.ssao_power = 1.7
	env.glow_enabled = true
	env.glow_intensity = 0.30
	env.glow_strength = 0.8
	env.glow_bloom = 0.015
	env.glow_hdr_threshold = 1.24
	env.fog_enabled = true
	env.fog_light_color = Color(0.045, 0.065, 0.065, 1.0)
	env.fog_light_energy = 0.32
	env.fog_density = 0.0035
	env.volumetric_fog_enabled = false
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _make_materials() -> void:
	_wall_blood_shader = load(BLOOD_SHADER) as Shader
	_blood = StandardMaterial3D.new()
	_blood.albedo_color = Color(0.40, 0.006, 0.003)
	_blood.roughness = 0.12
	_blood.rim_enabled = true
	_blood.rim = 0.45
	_blood.rim_tint = 0.38
	_blood.emission_enabled = true
	_blood.emission = Color(0.50, 0.004, 0.002)
	_blood.emission_energy_multiplier = 0.75

	_blood_dark = StandardMaterial3D.new()
	_blood_dark.albedo_color = Color(0.15, 0.002, 0.001)
	_blood_dark.roughness = 0.25
	_blood_dark.emission_enabled = true
	_blood_dark.emission = Color(0.25, 0.002, 0.001)
	_blood_dark.emission_energy_multiplier = 0.4


func _build_set() -> void:
	_make_materials()
	_world = Node3D.new()
	_world.name = "PortraitWorld"
	add_child(_world)

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_texture = load(WALL_TEXTURE)
	wall_mat.albedo_color = Color(0.125, 0.145, 0.132)
	wall_mat.roughness = 0.90
	wall_mat.normal_texture = load(WALL_NORMAL)
	wall_mat.normal_enabled = true
	wall_mat.normal_scale = 0.7
	wall_mat.roughness_texture = load(WALL_ROUGH)
	wall_mat.texture_repeat = true
	wall_mat.uv1_scale = Vector3(2.4, 2.4, 1.0)
	wall_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

	var wall := MeshInstance3D.new()
	wall.name = "BackWall"
	var wall_mesh := PlaneMesh.new()
	wall_mesh.size = Vector2(6.8, 4.4)
	wall.mesh = wall_mesh
	wall.material_override = wall_mat
	wall.position = Vector3(0.0, 1.8, -1.28)
	_world.add_child(wall)

	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_texture = load(FLOOR_TEXTURE)
	floor_mat.albedo_color = Color(0.070, 0.082, 0.076)
	floor_mat.roughness = 0.78
	floor_mat.normal_texture = load(FLOOR_NORMAL)
	floor_mat.normal_enabled = true
	floor_mat.normal_scale = 0.55
	floor_mat.uv1_scale = Vector3(3.0, 3.0, 1.0)
	floor_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

	var floor := MeshInstance3D.new()
	floor.name = "Floor"
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(9.0, 9.0)
	floor.mesh = floor_mesh
	floor.material_override = floor_mat
	floor.rotation.x = -PI * 0.5
	floor.position = Vector3(0.0, 0.0, 1.2)
	_world.add_child(floor)

	# Dark service pipe silhouettes frame the figure without making the menu
	# look like a laboratory. They read as old basement plumbing.
	var pipe_mat := StandardMaterial3D.new()
	pipe_mat.albedo_color = Color(0.046, 0.054, 0.051)
	pipe_mat.roughness = 0.36
	pipe_mat.metallic = 0.72
	_cylinder(_world, 0.070, 3.9, Vector3(-1.62, 1.95, -1.16), Vector3.ZERO, pipe_mat, 14)
	_cylinder(_world, 0.050, 2.6, Vector3(1.72, 1.65, -1.15), Vector3.ZERO, pipe_mat, 12)

	# Wall blood is deliberately readable and strongly red. These unshaded
	# quads sit just in front of the concrete, so the mark never disappears in
	# a dark corner of the lighting; the neck wound provides the wet detail.
	_add_wall_blood(Vector3(0.56, 1.62, -1.165), Vector2(2.35, 2.30), 0.08, Color(0.68, 0.010, 0.006, 1.0))
	_add_wall_blood(Vector3(0.93, 2.03, -1.160), Vector2(1.18, 1.05), -0.36, Color(0.52, 0.006, 0.004, 1.0))
	_add_wall_blood(Vector3(-0.45, 1.35, -1.162), Vector2(0.92, 0.74), 0.44, Color(0.42, 0.005, 0.003, 1.0))
	# Long drips under the impact.
	for i in range(5):
		var x := -0.18 + float(i) * 0.24
		var drip_height := 0.58 + float(i % 3) * 0.22
		_add_wall_blood(
			Vector3(x, 1.62 - drip_height * 0.35, -1.158),
			Vector2(0.075, drip_height),
			0.0,
			Color(0.50, 0.006, 0.004, 1.0)
		)

	# A floor pool catches the red wash and grounds the body.
	_add_wall_blood(Vector3(0.16, 0.012, 0.34), Vector2(1.9, 0.7), 0.0, Color(0.28, 0.004, 0.003, 1.0), true)

	# No flat billboard dust here. Soft volumetric haze and practical light
	# do the atmosphere; hard square particles read as artifacts at menu size.


func _build_friend() -> void:
	var scene := load(FRIEND_SCENE) as PackedScene
	if scene == null:
		return
	_friend = scene.instantiate() as Node3D
	# The normal Friend scene auto-plays its cutscene walk. The menu duplicate
	# must stay still against the wall, so disable that route before _ready.
	_friend.set("auto_play", false)
	_friend.set("hide_when_done", false)
	_friend.name = "MenuFriend"
	_friend.position = Vector3(0.56, 0.0, 0.10)
	_friend.rotation.y = PI - 0.10
	_world.add_child(_friend)
	await get_tree().process_frame

	var at := _friend.find_child("AnimationTree", true, false) as AnimationTree
	if at != null:
		at.active = true
		var pb = at.get("parameters/playback")
		if pb != null:
			pb.start("standing_idle")
	var ap := _friend.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap != null:
		var idle := ap.get_animation("standing_idle")
		if idle != null:
			idle.loop_mode = Animation.LOOP_LINEAR
	await get_tree().process_frame

	_skeleton = _friend.find_child("Skeleton3D", true, false) as Skeleton3D
	_spine_bone = _skeleton.find_bone("mixamorig_Spine2") if _skeleton != null else -1
	_lift_friend_materials(_friend)
	_decapitate(_friend)
	_add_neck_wound(_friend)
	_add_drip_particles(_friend)


func _lift_friend_materials(friend: Node3D) -> void:
	var headless_shader := load(HEADLESS_SHADER) as Shader
	if headless_shader == null:
		return
	for mi in friend.find_children("*", "MeshInstance3D", true, false):
		var key := mi.name.to_lower()
		# Only meshes that carry head-weighted geometry need the portrait clip.
		# Pants and shoes keep their authored materials, and every clipped mesh
		# keeps the Friend's vertex colours instead of being tinted flat grey.
		if key != "body" and key != "jacket":
			continue
		var roughness := 0.78 if key == "body" else 0.88
		var m := ShaderMaterial.new()
		m.shader = headless_shader
		m.set_shader_parameter("albedo", Color(0.70, 0.70, 0.70) if key == "body" else Color(0.78, 0.78, 0.78))
		m.set_shader_parameter("emission_color", Color(0.008, 0.006, 0.005))
		m.set_shader_parameter("roughness", roughness)
		m.set_shader_parameter("rim_strength", 0.28)
		m.set_shader_parameter("cutoff_y", 1.49)
		mi.material_override = m


func _decapitate(friend: Node3D) -> void:
	var head_idx := _skeleton.find_bone("mixamorig_Head") if _skeleton != null else -1
	if head_idx < 0:
		return
	var removed_total := 0
	var kept_total := 0
	for mi in friend.find_children("*", "MeshInstance3D", true, false):
		var n := mi.name.to_lower()
		if n.contains("eye") or n.contains("hair"):
			mi.visible = false
			continue
		if mi.mesh == null or mi.mesh.get_surface_count() == 0:
			continue
		var arrays: Array = mi.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if bones.is_empty() or weights.is_empty() or indices.is_empty():
			continue
		# Godot can import 4 or 8 skin influences per vertex. Body and Jacket in
		# this model use 8; assuming 4 here silently misses half the skeleton and
		# leaves the head behind.
		var influence_stride: int = int(bones.size() / maxi(verts.size(), 1))
		if influence_stride < 1:
			continue
		# Each imported FBX mesh has its own Skin bind list. Pants/Shoes have
		# no head influence and must be left untouched; only meshes whose skin
		# includes the head are filtered.
		var skin: Skin = mi.skin
		var skin_has_head := false
		if skin != null:
			for bind in skin.get_bind_count():
				if str(skin.get_bind_name(bind)) == "mixamorig_Head":
					skin_has_head = true
					break
			if not skin_has_head:
				# Pants and Shoes share the same rig but have no head influence;
				# their local bind lists must not be indexed with the skeleton head.
				continue
		var kept := PackedInt32Array()
		var removed := 0
		for i in range(0, indices.size(), 3):
			var drop := false
			for k in range(3):
				var vi := indices[i + k]
				for w in range(influence_stride):
					var bi := vi * influence_stride + w
					if bi >= bones.size() or bi >= weights.size():
						continue
					if bones[bi] == head_idx and weights[bi] > 0.0001:
						drop = true
						break
				if drop:
					break
			if drop:
				removed += 1
			else:
				kept.append(indices[i])
				kept.append(indices[i + 1])
				kept.append(indices[i + 2])
		if removed == 0:
			kept_total += int(indices.size() / 3)
			continue
		arrays[Mesh.ARRAY_INDEX] = kept
		var new_mesh := ArrayMesh.new()
		new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		new_mesh.surface_set_material(0, mi.mesh.surface_get_material(0))
		mi.mesh = new_mesh
		removed_total += removed
		kept_total += int(kept.size() / 3)
		print("MenuPortrait: ", mi.name, " removed=", removed, " kept=", int(kept.size() / 3))
	print("MenuPortrait: removed_triangles=", removed_total, " kept=", kept_total)


func _add_neck_wound(friend: Node3D) -> void:
	var neck_idx := _skeleton.find_bone("mixamorig_Neck")
	var head_idx := _skeleton.find_bone("mixamorig_Head")
	if neck_idx < 0 or head_idx < 0:
		return
	_wound_bone = neck_idx
	var neck_pos := _skeleton.global_transform * _skeleton.get_bone_global_pose(neck_idx).origin
	var head_pos := _skeleton.global_transform * _skeleton.get_bone_global_pose(head_idx).origin
	var axis := (head_pos - neck_pos).normalized()
	if axis.length_squared() < 0.1:
		axis = Vector3.UP

	# Flush severed-neck wound, not a red stump. Head geometry is removed by the
	# weight filter and the portrait shader's world-space clip; this disc only
	# closes the open collar so the silhouette stays clean and no head-shaped
	# mass sits above the shoulders.
	var wound := MeshInstance3D.new()
	wound.name = "NeckWound"
	var disc := CylinderMesh.new()
	disc.top_radius = 0.082
	disc.bottom_radius = 0.104
	disc.height = 0.040
	disc.radial_segments = 32
	disc.rings = 1
	wound.mesh = disc
	wound.material_override = _blood_dark
	friend.add_child(wound)
	wound.global_position = neck_pos + axis * 0.012
	wound.basis = Basis(Quaternion(Vector3.UP, axis))

	for i in range(5):
		var drip := MeshInstance3D.new()
		drip.name = "ChestDrip%d" % i
		var dm := CylinderMesh.new()
		dm.top_radius = 0.006 + float(i % 2) * 0.002
		dm.bottom_radius = 0.010 + float(i % 2) * 0.003
		dm.height = 0.22 + float(i) * 0.045
		dm.radial_segments = 10
		drip.mesh = dm
		drip.material_override = _blood
		var side := -0.07 + float(i) * 0.035
		friend.add_child(drip)
		drip.global_position = Vector3(neck_pos.x + side, neck_pos.y - 0.17 - float(i) * 0.02, neck_pos.z + 0.10)

	_wound_light = OmniLight3D.new()
	_wound_light.name = "WoundLight"
	_wound_light.light_color = Color(0.82, 0.045, 0.020)
	_wound_light.light_energy = 0.40
	_wound_light.omni_range = 0.48
	_wound_light.omni_attenuation = 1.7
	_wound_light.shadow_enabled = false
	_world.add_child(_wound_light)
	_wound_light.global_position = Vector3(neck_pos.x, neck_pos.y - 0.04, neck_pos.z + 0.22)


func _add_drip_particles(friend: Node3D) -> void:
	var particles := GPUParticles3D.new()
	particles.name = "NeckDrips"
	particles.amount = 18
	particles.lifetime = 1.7
	particles.preprocess = 1.2
	particles.position = Vector3(0.0, 1.47, 0.24)
	particles.visibility_aabb = AABB(Vector3(-1, -2, -1), Vector3(2, 3, 2))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.07
	pm.direction = Vector3(0.0, -0.9, 0.15)
	pm.spread = 16.0
	pm.initial_velocity_min = 0.10
	pm.initial_velocity_max = 0.28
	pm.gravity = Vector3(0.0, -2.4, 0.0)
	pm.scale_min = 0.35
	pm.scale_max = 0.8
	pm.color = Color(0.45, 0.005, 0.002, 1.0)
	var drop := SphereMesh.new()
	drop.radius = 0.022
	drop.height = 0.045
	drop.radial_segments = 6
	drop.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.55, 0.006, 0.003, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.42, 0.003, 0.001)
	mat.emission_energy_multiplier = 0.7
	drop.material = mat
	particles.process_material = pm
	particles.draw_pass_1 = drop
	friend.add_child(particles)


func _build_lights() -> void:
	var key := SpotLight3D.new()
	key.name = "ColdKey"
	key.position = Vector3(-0.85, 2.2, 1.30)
	key.light_color = Color(0.46, 0.66, 0.65)
	key.light_energy = 5.2
	key.spot_range = 5.0
	key.spot_angle = 32.0
	key.spot_attenuation = 1.1
	key.shadow_enabled = true
	_world.add_child(key)
	key.look_at(Vector3(0.56, 1.10, 0.10), Vector3.UP)

	var rim := OmniLight3D.new()
	rim.name = "RedRim"
	rim.position = Vector3(1.38, 1.42, -0.55)
	rim.light_color = Color(0.95, 0.070, 0.026)
	rim.light_energy = 1.8
	rim.omni_range = 2.1
	rim.omni_attenuation = 1.5
	rim.shadow_enabled = true
	_world.add_child(rim)

	_red_wash = SpotLight3D.new()
	_red_wash.name = "BackWash"
	_red_wash.position = Vector3(1.35, 2.25, 0.25)
	_red_wash.light_color = Color(0.82, 0.030, 0.010)
	_red_wash.light_energy = 2.6
	_red_wash.spot_range = 4.8
	_red_wash.spot_angle = 38.0
	_red_wash.spot_attenuation = 1.35
	_red_wash.shadow_enabled = false
	_world.add_child(_red_wash)
	_red_wash.look_at(Vector3(0.55, 1.55, -1.20), Vector3.UP)

	var fill := OmniLight3D.new()
	fill.name = "PortraitFill"
	fill.position = Vector3(0.48, 1.38, 1.8)
	fill.light_color = Color(0.48, 0.62, 0.59)
	fill.light_energy = 3.2
	fill.omni_range = 2.2
	fill.omni_attenuation = 1.5
	fill.shadow_enabled = false
	_world.add_child(fill)

	var front := SpotLight3D.new()
	front.name = "CameraKey"
	front.position = Vector3(1.30, 1.90, 3.0)
	front.light_color = Color(0.56, 0.68, 0.64)
	front.light_energy = 5.8
	front.spot_range = 4.0
	front.spot_angle = 24.0
	front.spot_attenuation = 1.2
	front.shadow_enabled = false
	_world.add_child(front)
	front.look_at(Vector3(0.56, 1.12, 0.10), Vector3.UP)

	var top := SpotLight3D.new()
	top.name = "TopWoundLight"
	top.position = Vector3(0.72, 3.0, 0.15)
	top.light_color = Color(0.80, 0.16, 0.08)
	top.light_energy = 0.75
	top.spot_range = 3.5
	top.spot_angle = 19.0
	top.spot_attenuation = 1.4
	top.shadow_enabled = true
	_world.add_child(top)
	top.look_at(Vector3(0.56, 1.42, 0.10), Vector3.UP)


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "PortraitCamera"
	_camera.fov = 40.0
	_camera.near = 0.03
	_camera.position = _camera_home
	_world.add_child(_camera)
	_camera.current = true
	_camera.look_at(_camera_target, Vector3.UP)


func _add_wall_blood(pos: Vector3, size: Vector2, rotation: float, color: Color, floor := false) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = _wall_blood_shader
	mat.set_shader_parameter("blood_texture", load(BLOOD_TEXTURE))
	mat.set_shader_parameter("blood_color", color)
	mat.set_shader_parameter("opacity", 0.92)
	var quad := QuadMesh.new()
	quad.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = mat
	mi.position = pos
	if floor:
		mi.rotation.x = -PI * 0.5
	mi.rotation.z = rotation
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(mi)


func _cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, rot: Vector3, mat: Material, segments: int) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 2
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
