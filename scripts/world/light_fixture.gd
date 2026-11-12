extends Node3D
# Adds a visible, era-appropriate light fixture to its parent Light3D.
# The parent light remains the actual light source; this only builds the
# bulb, cord, shade and cage so the illumination has a believable origin.
#
# Add this node as a child of an OmniLight3D and choose a style. Distances are
# measured from the light itself (the bulb), so cord_length should reach the
# ceiling above it.

@export_enum("bare_bulb", "pendant", "ceiling", "floor_lamp") var style := "bare_bulb"
## Distance from the bulb up to the ceiling. Ignored for floor lamps.
@export var cord_length := 1.0
@export var bulb_color := Color(1.0, 0.78, 0.52)
@export var shade_color := Color(0.075, 0.06, 0.045)
@export var metal_color := Color(0.06, 0.055, 0.05)
@export var cage := true
@export var fixture_scale := 1.0

var _bulb_mat: StandardMaterial3D
var _shade_mat: StandardMaterial3D
var _metal_mat: StandardMaterial3D
var _rim_mat: StandardMaterial3D


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if not (get_parent() is Light3D):
		push_warning("LightFixture must be a child of a Light3D")
		return
	scale = Vector3.ONE * fixture_scale
	_make_materials()
	match style:
		"pendant":
			_build_pendant()
		"ceiling":
			_build_ceiling()
		"floor_lamp":
			_build_floor_lamp()
		_:
			_build_bare_bulb()


func _make_materials() -> void:
	_bulb_mat = StandardMaterial3D.new()
	_bulb_mat.albedo_color = bulb_color
	_bulb_mat.roughness = 0.35
	_bulb_mat.metallic_specular = 0.4
	_bulb_mat.emission_enabled = true
	_bulb_mat.emission = bulb_color
	_bulb_mat.emission_energy_multiplier = 4.0

	_shade_mat = StandardMaterial3D.new()
	_shade_mat.albedo_color = shade_color
	_shade_mat.roughness = 0.82
	_shade_mat.metallic = 0.05
	_shade_mat.metallic_specular = 0.35
	_shade_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_shade_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

	_metal_mat = StandardMaterial3D.new()
	_metal_mat.albedo_color = metal_color
	_metal_mat.metallic = 0.72
	_metal_mat.roughness = 0.38
	_metal_mat.metallic_specular = 0.6

	_rim_mat = StandardMaterial3D.new()
	_rim_mat.albedo_color = Color(0.11, 0.085, 0.06)
	_rim_mat.metallic = 0.45
	_rim_mat.roughness = 0.55


func _build_bare_bulb() -> void:
	if cord_length > 0.02:
		_add_cylinder("Cord", 0.006, cord_length, Vector3(0, 0.06 + cord_length * 0.5, 0), _metal_mat)
		_add_cylinder("CeilingRose", 0.055, 0.022, Vector3(0, cord_length + 0.06, 0), _metal_mat)
	_add_cylinder("Socket", 0.035, 0.09, Vector3(0, 0.07, 0), _metal_mat)
	_add_sphere("Bulb", 0.052, 0.104, Vector3.ZERO, _bulb_mat, false)
	if cage:
		_add_torus("CageRingA", 0.085, 0.105, 12, 6, Vector3(0, 0.0, 0), _rim_mat)
		_add_torus("CageRingB", 0.085, 0.105, 12, 6, Vector3(0, -0.075, 0), _rim_mat)
		for i in 4:
			var a := TAU * float(i) / 4.0
			var m := _add_cylinder(
				"CageBar%d" % i, 0.004, 0.17,
				Vector3(cos(a) * 0.095, -0.037, sin(a) * 0.095), _rim_mat
			)
			m.rotation = Vector3(0, a, 0)


func _build_pendant() -> void:
	if cord_length > 0.02:
		_add_cylinder("Cord", 0.007, cord_length, Vector3(0, 0.05 + cord_length * 0.5, 0), _metal_mat)
		_add_cylinder("CeilingRose", 0.06, 0.024, Vector3(0, cord_length + 0.05, 0), _metal_mat)
	_add_cylinder("Socket", 0.033, 0.09, Vector3(0, 0.07, 0), _metal_mat)
	_add_sphere("Bulb", 0.05, 0.10, Vector3.ZERO, _bulb_mat, false)
	_add_cone("Shade", 0.12, 0.3, 0.24, Vector3(0, 0.2, 0), _shade_mat)
	_add_torus("ShadeRim", 0.29, 0.305, 24, 8, Vector3(0, 0.08, 0), _rim_mat)


func _build_ceiling() -> void:
	_add_cylinder("CeilingPlate", 0.19, 0.035, Vector3(0, 0.04, 0), _metal_mat)
	_add_cylinder("Diffuser", 0.16, 0.03, Vector3(0, 0.015, 0), _shade_mat)
	_add_sphere("Bulb", 0.045, 0.09, Vector3(0, -0.035, 0), _bulb_mat, false)
	_add_torus("PlateRim", 0.175, 0.19, 24, 8, Vector3(0, 0.022, 0), _rim_mat)


func _build_floor_lamp() -> void:
	var pole_height := 2.2
	_add_cylinder("Pole", 0.022, pole_height, Vector3(0, -pole_height * 0.5, 0), _metal_mat)
	_add_cylinder("Foot", 0.2, 0.045, Vector3(0, -pole_height, 0), _metal_mat)
	_add_cylinder("Socket", 0.034, 0.09, Vector3(0, 0.07, 0), _metal_mat)
	_add_sphere("Bulb", 0.05, 0.10, Vector3.ZERO, _bulb_mat, false)
	_add_cone("Shade", 0.13, 0.28, 0.25, Vector3(0, 0.19, 0), _shade_mat)
	_add_torus("ShadeRim", 0.27, 0.285, 24, 8, Vector3(0, 0.065, 0), _rim_mat)


func _add_cylinder(node_name: String, radius: float, height: float, pos: Vector3, mat: Material, shadows := true) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 1
	return _add_mesh(node_name, mesh, pos, Vector3.ZERO, mat, shadows)


func _add_cone(node_name: String, top_radius: float, bottom_radius: float, height: float, pos: Vector3, mat: Material, shadows := true) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 24
	mesh.rings = 1
	mesh.cap_top = false
	mesh.cap_bottom = false
	return _add_mesh(node_name, mesh, pos, Vector3.ZERO, mat, shadows)


func _add_sphere(node_name: String, radius: float, height: float, pos: Vector3, mat: Material, shadows := true) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	mesh.rings = 10
	return _add_mesh(node_name, mesh, pos, Vector3.ZERO, mat, shadows)


func _add_torus(node_name: String, inner: float, outer: float, rings: int, segments: int, pos: Vector3, mat: Material, shadows := true) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = rings
	mesh.ring_segments = segments
	return _add_mesh(node_name, mesh, pos, Vector3.ZERO, mat, shadows)


func _add_mesh(node_name: String, mesh: Mesh, pos: Vector3, rot: Vector3, mat: Material, shadows := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi
