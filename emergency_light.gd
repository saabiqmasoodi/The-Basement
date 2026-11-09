extends OmniLight3D
# Slow, failing emergency beacon. It breathes red light into the basement and
# occasionally stutters, which gives the generator room a living, unstable feel
# without strobing hard enough to hurt readability.

@export var pulse_speed := 1.15
@export var pulse_min := 0.22
@export var pulse_max := 1.0
@export var stutter_amount := 0.16
@export var stutter_speed := 13.0

var _base_energy := 1.0
var _time := 0.0


func _ready() -> void:
	_base_energy = light_energy


func _process(delta: float) -> void:
	_time += delta
	var breath := (sin(_time * pulse_speed * TAU) * 0.5 + 0.5)
	breath = smoothstep(0.0, 1.0, breath)
	var stutter := sin(_time * stutter_speed + sin(_time * 3.7) * 2.0) * stutter_amount
	light_energy = _base_energy * lerpf(pulse_min, pulse_max, breath) * (1.0 + stutter)
