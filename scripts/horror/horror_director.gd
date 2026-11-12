extends Node
# Drives the post-process dread layer from the player's actual situation.
# Nothing here changes gameplay. It only lets the grade breathe harder as the
# player goes deeper, restores the generator and collects fuses.

var _grade: ColorRect
var _material: ShaderMaterial
var _player: Node3D
var _time := 0.0
var _danger := 0.0


func _ready() -> void:
	var world := get_parent()
	_grade = world.get_node_or_null("PostFX/Grade") as ColorRect
	_player = world.get_node_or_null("Player") as Node3D
	if _grade != null and _grade.material is ShaderMaterial:
		_material = _grade.material as ShaderMaterial


func _process(delta: float) -> void:
	if _material == null:
		return
	_time += delta

	var depth := 0.0
	if _player != null:
		depth = clampf((1.0 - _player.global_position.y) / 5.8, 0.0, 1.0)
	var progress := clampf(float(GameState.get_fuzes()) / 3.0, 0.0, 1.0)
	var target := depth * 0.58 + progress * 0.22
	if GameState.basement_seen:
		target += 0.14
	if GameState.electricity_on:
		target += 0.10
	target = clampf(target, 0.0, 1.0)
	_danger = lerpf(_danger, target, 1.0 - exp(-delta * 0.8))

	var breath := 0.5 + 0.5 * sin(_time * 1.35 + sin(_time * 0.31) * 1.8)
	var pulse := breath * _danger
	_material.set_shader_parameter("pulse", pulse)
	_material.set_shader_parameter("danger", _danger)
