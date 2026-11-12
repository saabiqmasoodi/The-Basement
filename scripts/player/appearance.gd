extends Node
# Runtime material polish for the imported furniture and the Friend character.
# The source GLBs are left untouched. Incorrect or placeholder material
# assignments are corrected in memory so the scene keeps its original models,
# collisions and animations while gaining believable wood, fabric, stone and
# painted metal.

const FRIEND_SCENE := "res://assets/models/characters/Friend/friend.tscn"


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var world := get_parent()
	var friend := _find_friend(world)
	_polish_imported_materials(world, friend)
	_dress_friend(friend)


func _find_friend(world: Node) -> Node:
	for n in world.find_children("*", "Node3D", true, false):
		if n.scene_file_path == FRIEND_SCENE or n.name == "Friend":
			return n
	return null


func _polish_imported_materials(world: Node, friend: Node) -> void:
	var friend_path := ""
	if friend != null:
		friend_path = String(friend.get_path()) + "/"
	for mi in world.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var path := String(mi.get_path())
		var path_lower := path.to_lower()
		if friend_path != "" and path.begins_with(friend_path):
			continue

		# A MeshInstance3D material_override takes precedence over every surface.
		# Use it as the source so textures authored on the override are kept.
		if mi.material_override != null:
			if mi.material_override is StandardMaterial3D:
				var overridden := _polish_material(
					mi.material_override as StandardMaterial3D, path_lower
				)
				if overridden != null:
					mi.material_override = overridden
			continue

		for surface in mi.mesh.get_surface_count():
			var base: Material = mi.get_surface_override_material(surface)
			if base == null:
				base = mi.mesh.surface_get_material(surface)
			if not (base is StandardMaterial3D):
				continue
			var polished := _polish_material(base as StandardMaterial3D, path_lower)
			if polished != null:
				mi.set_surface_override_material(surface, polished)


func _polish_material(source: StandardMaterial3D, path_lower: String) -> StandardMaterial3D:
	var mat := source.duplicate() as StandardMaterial3D
	var name := source.resource_name.to_lower()
	var changed := false

	# Imported textures look much better with anisotropic filtering.
	if mat.albedo_texture != null or mat.normal_texture != null or mat.orm_texture != null:
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		changed = true
	if mat.normal_texture != null and not mat.normal_enabled:
		mat.normal_enabled = true
		changed = true

	# A mirror-like non-metal surface is almost always an import mistake.
	if mat.metallic < 0.5 and mat.roughness < 0.05:
		mat.roughness = 0.28
		changed = true

	# Numerous Sketchfab exports tag every surface as rough metal.
	if mat.metallic >= 0.95 and mat.roughness >= 0.95:
		if (
			name.contains("handle")
			or name.contains("metal")
			or name.contains("steel")
			or name.contains("iron")
		):
			mat.metallic = 1.0
			mat.roughness = 0.32
		else:
			mat.metallic = 0.0
			mat.roughness = 0.62
			mat.metallic_specular = 0.5
		changed = true

	if name.contains("chair"):
		mat.metallic = 0.0
		mat.roughness = 0.58
		mat.metallic_specular = 0.45
		changed = true
	elif name.contains("table") and not name.contains("stand"):
		mat.metallic = 0.0
		mat.roughness = 0.44
		mat.metallic_specular = 0.55
		mat.clearcoat_enabled = true
		mat.clearcoat = 0.12
		mat.clearcoat_roughness = 0.4
		changed = true
	elif name.contains("cloth") or name.contains("fabric"):
		mat.metallic = 0.0
		mat.roughness = 0.95
		mat.metallic_specular = 0.25
		changed = true
	elif name.contains("counter"):
		mat.metallic = 0.0
		mat.roughness = 0.32
		mat.metallic_specular = 0.6
		mat.clearcoat_enabled = true
		mat.clearcoat = 0.2
		mat.clearcoat_roughness = 0.2
		changed = true
	elif name.contains("woodbase") or name.contains("wood_base"):
		mat.metallic = 0.0
		mat.roughness = 0.62
		mat.metallic_specular = 0.45
		changed = true
	elif name.contains("handle"):
		mat.metallic = 1.0
		mat.roughness = 0.28
		mat.metallic_specular = 0.7
		changed = true
	elif (
		name.contains("tv_tv") or (name == "material.002" and path_lower.contains("staticbody3d3"))
	):
		mat.metallic = 0.12
		mat.roughness = 0.32
		mat.metallic_specular = 0.6
		changed = true
	elif name.contains("wood_tv_stand"):
		mat.metallic = 0.0
		mat.roughness = 0.5
		mat.metallic_specular = 0.45
		changed = true
	elif name.contains("scene_-_root"):
		mat.metallic = 0.0
		mat.roughness = 0.88
		mat.metallic_specular = 0.3
		changed = true
	elif name.begins_with("blinn") or name.contains("initialshadinggroup"):
		mat.metallic = 0.2
		mat.roughness = 0.6
		mat.metallic_specular = 0.5
		changed = true

	# The fridge's outer shell is a light painted finish, not chalk.
	if (
		path_lower.contains("staticbody3d2")
		and mat.albedo_texture == null
		and mat.albedo_color.r > 0.6
	):
		mat.albedo_color = Color(0.66, 0.68, 0.66, 1)
		mat.metallic = 0.12
		mat.roughness = 0.32
		mat.metallic_specular = 0.55
		changed = true

	# The metal door should have a painted-steel response. Match the actual door
	# node, not the separate door-button model whose path also contains "door".
	if path_lower.contains("/door/") or path_lower.ends_with("/door"):
		mat.metallic = 0.45
		mat.roughness = 0.4
		mat.metallic_specular = 0.6
		changed = true

	return mat if changed else null


func _dress_friend(friend: Node) -> void:
	if friend == null:
		return

	# The FBX ships with untextured, evenly lit materials. Keep the silhouette
	# and animations, but replace the cheerful placeholder colours with a pale,
	# dirty, physically plausible set. The jacket and trousers get a woven
	# albedo/normal/roughness set so he no longer reads as a plastic doll.
	var fabric_albedo := load("res://materials/generated/friend_fabric_albedo.png") as Texture2D
	var fabric_normal := load("res://materials/generated/friend_fabric_normal.png") as Texture2D
	var fabric_rough := load("res://materials/generated/friend_fabric_roughness.png") as Texture2D

	var skin := _friend_material(Color(0.52, 0.43, 0.38), 0.62, 0.0)
	skin.subsurf_scatter_enabled = true
	skin.subsurf_scatter_strength = 0.08
	skin.subsurf_scatter_skin_mode = true
	skin.rim_enabled = true
	skin.rim = 0.25
	skin.rim_tint = 0.35

	var eyes := _friend_material(Color(0.18, 0.22, 0.13), 0.2, 0.0)
	eyes.emission_enabled = true
	eyes.emission = Color(0.58, 0.83, 0.38)
	eyes.emission_energy_multiplier = 1.45
	eyes.metallic_specular = 0.65

	var hair := _friend_material(Color(0.018, 0.016, 0.014), 0.72, 0.0)
	hair.rim_enabled = true
	hair.rim = 0.22
	hair.rim_tint = 0.45

	var jacket := _fabric_material(
		Color(0.27, 0.30, 0.25), fabric_albedo, fabric_normal, fabric_rough
	)
	var pants := _fabric_material(
		Color(0.22, 0.25, 0.26), fabric_albedo, fabric_normal, fabric_rough
	)
	var shoe_upper := _friend_material(Color(0.020, 0.018, 0.016), 0.44, 0.12)
	var shoe_sole := _friend_material(Color(0.032, 0.030, 0.027), 0.8, 0.0)

	for mi in friend.find_children("*", "MeshInstance3D", true, false):
		var key := mi.name.to_lower()
		var mat: StandardMaterial3D = null
		if key.contains("eye"):
			mat = eyes
		elif key.contains("hair"):
			mat = hair
		elif key.contains("jacket") or key.contains("coat"):
			mat = jacket
		elif key.contains("pant") or key.contains("trouser"):
			mat = pants
		elif key.contains("shoe") or key.contains("boot"):
			mat = shoe_upper
		elif key.contains("body") or key.contains("skin"):
			mat = skin

		if mat != null:
			if key.contains("shoe") and mi.mesh != null and mi.mesh.get_surface_count() > 1:
				mi.set_surface_override_material(0, shoe_upper)
				mi.set_surface_override_material(1, shoe_sole)
			else:
				mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	# The FBX contains a stray imported lamp (energy 1000, range 0.06) far from
	# the character. Turn it off and add controlled, cold fill and a red edge.
	var stray := friend.get_node_or_null("Light") as Light3D
	if stray != null:
		stray.light_energy = 0.0
		stray.shadow_enabled = false

	var fill := OmniLight3D.new()
	fill.name = "CutsceneFill"
	fill.position = Vector3(0.35, 0.65, 0.15)
	fill.light_color = Color(0.55, 0.70, 0.66)
	fill.light_energy = 0.34
	fill.omni_range = 3.2
	fill.omni_attenuation = 1.5
	fill.light_specular = 0.26
	fill.light_volumetric_fog_energy = 0.0
	fill.shadow_enabled = false
	friend.add_child(fill)

	# A red edge from behind makes his silhouette feel staged and wrong without
	# adding a second frontal key that would flatten the face.
	var rim := OmniLight3D.new()
	rim.name = "CutsceneRim"
	rim.position = Vector3(0.1, 0.65, -0.55)
	rim.light_color = Color(0.88, 0.10, 0.035)
	rim.light_energy = 0.45
	rim.omni_range = 2.3
	rim.omni_attenuation = 1.7
	rim.light_specular = 0.2
	rim.light_volumetric_fog_energy = 0.0
	rim.shadow_enabled = false
	friend.add_child(rim)


func _fabric_material(
	color: Color, albedo: Texture2D, normal_map: Texture2D, roughness_map: Texture2D
) -> StandardMaterial3D:
	var mat := _friend_material(color, 0.92, 0.0)
	mat.albedo_texture = albedo
	mat.normal_texture = normal_map
	mat.normal_enabled = true
	mat.normal_scale = 0.85
	mat.roughness_texture = roughness_map
	mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE
	mat.texture_repeat = true
	mat.uv1_scale = Vector3(2.6, 2.6, 2.6)
	return mat


func _friend_material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	mat.metallic_specular = 0.35
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return mat
