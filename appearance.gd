extends Node
# Runtime material polish for the imported furniture and the Friend character.
# The source GLBs are left untouched. Incorrect or placeholder material
# assignments are corrected in memory so the scene keeps its original models,
# collisions and animations while gaining believable wood, fabric, stone and
# painted metal.

const FRIEND_SCENE := "res://Friend/friend.tscn"


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
				var overridden := _polish_material(mi.material_override as StandardMaterial3D, path_lower)
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
		if name.contains("handle") or name.contains("metal") or name.contains("steel") or name.contains("iron"):
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
	elif name.contains("tv_tv") or (name == "material.002" and path_lower.contains("staticbody3d3")):
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
	if path_lower.contains("staticbody3d2") and mat.albedo_texture == null and mat.albedo_color.r > 0.6:
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

	var skin := _friend_material(Color(0.63, 0.43, 0.33), 0.58, 0.0)
	skin.subsurf_scatter_enabled = true
	skin.subsurf_scatter_strength = 0.12
	skin.subsurf_scatter_skin_mode = true
	var eyes := _friend_material(Color(0.78, 0.74, 0.66), 0.16, 0.0)
	eyes.metallic_specular = 0.7
	var hair := _friend_material(Color(0.055, 0.042, 0.03), 0.62, 0.0)
	var jacket := _friend_material(Color(0.105, 0.125, 0.11), 0.74, 0.0)
	var pants := _friend_material(Color(0.075, 0.085, 0.105), 0.84, 0.0)
	var shoes := _friend_material(Color(0.028, 0.026, 0.024), 0.48, 0.15)

	for mi in friend.find_children("*", "MeshInstance3D", true, false):
		var key := mi.name.to_lower()
		var mat: StandardMaterial3D = null
		if key.contains("body") or key.contains("skin"):
			mat = skin
		elif key.contains("eye"):
			mat = eyes
		elif key.contains("hair"):
			mat = hair
		elif key.contains("jacket") or key.contains("coat"):
			mat = jacket
		elif key.contains("pant") or key.contains("trouser"):
			mat = pants
		elif key.contains("shoe") or key.contains("boot"):
			mat = shoes
		if mat != null:
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	# The FBX contains a stray imported lamp (energy 1000, range 0.06) far from
	# the character. Turn it off and add a controlled, warm fill instead.
	var stray := friend.get_node_or_null("Light") as Light3D
	if stray != null:
		stray.light_energy = 0.0
		stray.shadow_enabled = false

	var fill := OmniLight3D.new()
	fill.name = "CutsceneFill"
	fill.position = Vector3(0.35, 0.65, 0.15)
	fill.light_color = Color(1.0, 0.82, 0.65)
	fill.light_energy = 0.5
	fill.omni_range = 3.5
	fill.omni_attenuation = 1.4
	fill.light_specular = 0.3
	fill.light_volumetric_fog_energy = 0.0
	fill.shadow_enabled = false
	friend.add_child(fill)

	# Cool rim from the back separates the dark hair and jacket from the warm
	# room without adding a second frontal key.
	var rim := OmniLight3D.new()
	rim.name = "CutsceneRim"
	rim.position = Vector3(0.1, 0.65, -0.55)
	rim.light_color = Color(0.45, 0.6, 0.85)
	rim.light_energy = 0.4
	rim.omni_range = 2.5
	rim.omni_attenuation = 1.6
	rim.light_specular = 0.25
	rim.light_volumetric_fog_energy = 0.0
	rim.shadow_enabled = false
	friend.add_child(rim)


func _friend_material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	mat.metallic_specular = 0.35
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return mat
