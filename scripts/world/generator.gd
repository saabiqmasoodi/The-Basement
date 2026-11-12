extends Interactable
# Basement generator. Requires all 3 fuses before it can restore electricity.
#
# The repair is deliberately loud and visible: the relay clicks, the basement
# lights stutter back to life and the generator's own lamp comes on.  Interact
# with E (or click the prompt) once all three fuses are in.

@export var display_name := "Generator"
@export var power_light_boost := 1.45

@onready var relay: AudioStreamPlayer3D = get_node_or_null("Relay")
@onready var power_light: OmniLight3D = get_node_or_null("PowerLight")


func _ready() -> void:
	# Belt and braces: connect here as well so the generator still works if
	# the scene's signal connection ever gets lost while editing.
	if not interacted.is_connected(_on_interacted):
		interacted.connect(_on_interacted)

	if power_light:
		power_light.light_energy = 0.0
	# Reflect a save that was loaded before this node existed.
	if GameState.electricity_on:
		if power_light:
			power_light.light_energy = 2.6


func get_promt() -> String:
	if GameState.electricity_on:
		return "Generator running"
	if GameState.get_fuzes() < GameState.MAX_FUZES:
		return (
			"%s: needs 3 fuses (%d/%d)" % [display_name, GameState.get_fuzes(), GameState.MAX_FUZES]
		)
	var key_name := ""
	for ev in InputMap.action_get_events(promt_input):
		if ev is InputEventKey:
			key_name = ev.as_text_physical_keycode()
			break
	return "Fix electricity\n[" + key_name + "] FIX   or Click"


func _on_interacted(_body):
	if GameState.electricity_on:
		return
	if GameState.get_fuzes() < GameState.MAX_FUZES:
		print("Generator: still missing fuses.")
		return
	GameState.complete_electricity()
	print("Generator: electricity restored.")
	_play_power_on()


# Relay click + basement light flicker, then settle at a brighter level.
func _play_power_on() -> void:
	if relay:
		relay.play()

	if power_light:
		power_light.light_energy = 2.6

	var lights := _basement_lights()
	var base: Dictionary = {}
	for light in lights:
		base[light] = light.light_energy

	for i in 6:
		var on := i % 2 == 0
		for light in lights:
			light.light_energy = float(base[light]) if on else 0.0
		await get_tree().create_timer(0.07, false).timeout

	# Hum back up slightly above normal so the change is unmistakable.
	for light in lights:
		light.light_energy = float(base[light]) * power_light_boost
	await get_tree().create_timer(0.4, false).timeout

	var settle := create_tween()
	settle.set_parallel(true)
	for light in lights:
		settle.tween_property(light, "light_energy", base[light], 1.0)


func _basement_lights() -> Array[OmniLight3D]:
	var out: Array[OmniLight3D] = []
	var scene := get_tree().current_scene
	if scene == null:
		return out
	for node in scene.find_children("*", "OmniLight3D", true, false):
		var light := node as OmniLight3D
		if light and light.global_position.y < 0.5:
			out.append(light)
	return out
