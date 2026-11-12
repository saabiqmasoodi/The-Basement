extends OmniLight3D
# Barely-there bulb instability for the living room lamps.  Deliberately
# subtle so it reads as "old wiring" rather than a disco strobe.  The
# basement lights are owned by generator.gd and must not use this script.

@export var flicker_amount := 0.06
@export var flicker_speed := 4.0
## Average seconds between a short brown-out.  0 disables the deep dips.
@export var dip_interval := 34.0
@export var dip_strength := 0.45

var _base_energy := 1.0
var _time := 0.0
var _dip := 0.0


func _ready() -> void:
	_base_energy = light_energy


func _process(delta: float) -> void:
	_time += delta

	var wobble := (
		sin(_time * flicker_speed * 0.53) * 0.45
		+ sin(_time * flicker_speed * 1.37 + 1.7) * 0.33
		+ sin(_time * flicker_speed * 2.91 + 0.4) * 0.22
	)
	var level := 1.0 + wobble * flicker_amount

	if _dip > 0.0:
		# Quick fall, slightly slower recovery.
		_dip = maxf(_dip - delta * 5.5, 0.0)
	elif dip_interval > 0.0 and randf() < delta / dip_interval:
		_dip = 1.0
	level *= 1.0 - _dip * dip_strength

	light_energy = _base_energy * level
