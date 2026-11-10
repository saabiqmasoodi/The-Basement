extends Node
# Applies the Low / Medium / High / Very High graphics presets to the active
# World. The expensive feature switches live here (instead of in every scene)
# so the menu can change quality while the world is running and the result is
# immediately visible.
#
# The target is deliberately conservative on Apple Silicon:
#   Low       - fastest, still readable horror (fog, practicals, post grade)
#   Medium    - 60 FPS default on 720p/1080p, decals and glow return
#   High      - shadows + volumetric fog + SSAO; the "scary" mode
#   Very High - SDFGI + SSR + full atmosphere; the clean showpiece mode

const PRESETS := {
	"low": {
		"sdfgi": false,
		"ssr": false,
		"ssao": false,
		"ssao_intensity": 1.7,
		"ssr_steps": 16,
		"glow": false,
		"glow_intensity": 0.30,
		"volumetric": false,
		"volumetric_density": 0.0,
		"volumetric_length": 28.0,
		"volumetric_gi": 0.0,
		"fog_density": 0.0026,
		"saturation": 0.88,
		"shadows": false,
		"decals": false,
		"particles": false,
		"post_grain": 0.018,
		"post_chromatic": 0.0007,
		"post_lens": 0.045,
		"post_desaturation": 0.22,
		"post_contrast": 1.06,
	},
	"medium": {
		"sdfgi": false,
		"ssr": false,
		"ssao": false,
		"ssao_intensity": 1.9,
		"ssr_steps": 20,
		"glow": true,
		"glow_intensity": 0.38,
		"volumetric": false,
		"volumetric_density": 0.0,
		"volumetric_length": 30.0,
		"volumetric_gi": 0.0,
		"fog_density": 0.0042,
		"saturation": 0.84,
		"shadows": true,
		"decals": true,
		"particles": false,
		"post_grain": 0.022,
		"post_chromatic": 0.0009,
		"post_lens": 0.075,
		"post_desaturation": 0.24,
		"post_contrast": 1.08,
	},
	"high": {
		"sdfgi": false,
		"ssr": false,
		"ssao": true,
		"ssao_intensity": 2.15,
		"ssr_steps": 24,
		"glow": true,
		"glow_intensity": 0.48,
		"volumetric": true,
		"volumetric_density": 0.0095,
		"volumetric_length": 36.0,
		"volumetric_gi": 0.22,
		"fog_density": 0.0048,
		"saturation": 0.82,
		"shadows": true,
		"decals": true,
		"particles": true,
		"post_grain": 0.028,
		"post_chromatic": 0.0011,
		"post_lens": 0.10,
		"post_desaturation": 0.26,
		"post_contrast": 1.10,
	},
	"very_high": {
		"sdfgi": true,
		"ssr": true,
		"ssao": true,
		"ssao_intensity": 2.45,
		"ssr_steps": 28,
		"glow": true,
		"glow_intensity": 0.56,
		"volumetric": true,
		"volumetric_density": 0.0125,
		"volumetric_length": 44.0,
		"volumetric_gi": 0.35,
		"fog_density": 0.0052,
		"saturation": 0.80,
		"shadows": true,
		"decals": true,
		"particles": true,
		"post_grain": 0.031,
		"post_chromatic": 0.0012,
		"post_lens": 0.12,
		"post_desaturation": 0.27,
		"post_contrast": 1.11,
	},
}

var _world: Node
var _environment: Environment
var _grade_material: ShaderMaterial
var _lights: Array[Light3D] = []
var _decals: Array[Decal] = []
var _particles: Array[GPUParticles3D] = []
var _shadow_original: Dictionary = {}
var _visible_original: Dictionary = {}
var _applying := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_world = get_parent()
	var world_environment := _world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_environment != null:
		_environment = world_environment.environment
	var grade := _world.get_node_or_null("PostFX/Grade") as ColorRect
	if grade != null and grade.material is ShaderMaterial:
		_grade_material = grade.material as ShaderMaterial
	GameState.settings_changed.connect(_queue_apply)
	call_deferred("_queue_apply")


func _queue_apply() -> void:
	if _applying:
		return
	_applying = true
	# Let HorrorDressing finish its deferred build before the first pass.
	await get_tree().process_frame
	await get_tree().process_frame
	_applying = false
	_apply_preset()


func _collect_scene_nodes() -> void:
	_lights.clear()
	_decals.clear()
	_particles.clear()
	for node in _world.find_children("*", "Light3D", true, false):
		var light := node as Light3D
		if light == null:
			continue
		_lights.append(light)
		var key := light.get_instance_id()
		if not _shadow_original.has(key):
			_shadow_original[key] = light.shadow_enabled
	for node in _world.find_children("*", "Decal", true, false):
		var decal := node as Decal
		if decal == null:
			continue
		_decals.append(decal)
		var key := decal.get_instance_id()
		if not _visible_original.has(key):
			_visible_original[key] = decal.visible
	for node in _world.find_children("*", "GPUParticles3D", true, false):
		var particles := node as GPUParticles3D
		if particles == null:
			continue
		_particles.append(particles)
		var key := particles.get_instance_id()
		if not _visible_original.has(key):
			_visible_original[key] = particles.visible


func _apply_preset() -> void:
	if not is_inside_tree():
		return
	var quality := GameState.get_graphics_quality()
	var preset: Dictionary = PRESETS.get(quality, PRESETS["high"])
	_collect_scene_nodes()

	if _environment != null:
		_environment.sdfgi_enabled = bool(preset["sdfgi"])
		_environment.ssr_enabled = bool(preset["ssr"])
		_environment.ssao_enabled = bool(preset["ssao"])
		_environment.ssao_intensity = float(preset["ssao_intensity"])
		_environment.ssr_max_steps = int(preset["ssr_steps"])
		_environment.glow_enabled = bool(preset["glow"])
		_environment.glow_intensity = float(preset["glow_intensity"])
		_environment.volumetric_fog_enabled = bool(preset["volumetric"])
		_environment.volumetric_fog_density = float(preset["volumetric_density"])
		_environment.volumetric_fog_length = float(preset["volumetric_length"])
		_environment.volumetric_fog_gi_inject = float(preset["volumetric_gi"])
		_environment.fog_density = float(preset["fog_density"])
		_environment.adjustment_saturation = float(preset["saturation"])

	for light in _lights:
		if not is_instance_valid(light):
			continue
		var key := light.get_instance_id()
		light.shadow_enabled = bool(preset["shadows"]) and bool(_shadow_original.get(key, true))

	for decal in _decals:
		if not is_instance_valid(decal):
			continue
		var key := decal.get_instance_id()
		decal.visible = bool(preset["decals"]) and bool(_visible_original.get(key, true))

	for particles in _particles:
		if not is_instance_valid(particles):
			continue
		var key := particles.get_instance_id()
		particles.visible = bool(preset["particles"]) and bool(_visible_original.get(key, true))

	if _grade_material != null:
		_grade_material.set_shader_parameter("grain_amount", float(preset["post_grain"]))
		_grade_material.set_shader_parameter("chromatic_aberration", float(preset["post_chromatic"]))
		_grade_material.set_shader_parameter("lens_dirt_amount", float(preset["post_lens"]))
		_grade_material.set_shader_parameter("desaturation", float(preset["post_desaturation"]))
		_grade_material.set_shader_parameter("contrast", float(preset["post_contrast"]))

	print("GraphicsQuality: ", GameState.get_graphics_quality(), " preset applied.")
