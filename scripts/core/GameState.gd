extends Node
# GameState is a project autoload (see project.godot).
# Holds shared game progression, save/load and persistent settings.

signal fuzes_changed(count)
signal electricity_restored
signal game_saved
signal settings_changed

const MAX_FUZES := 3
const SAVE_PATH := "user://save_game.json"
const SETTINGS_PATH := "user://settings.json"

# Legacy generic state storage kept intact (fuze counter lives here).
var state := {
	"fuze": 0
}

# Progression tracked for task HUD + saves.
var collected_fuzes: Array[String] = []
var electricity_on := false
var cutscene_done := false
var basement_seen := false

# How the world should start: "new_game" (opening cutscene) or "continue".
var pending_start := "new_game"

# ---------------------------------- fuzes ----------------------------------

func get_value(key: String):
	if state.has(key):
		return state[key]
	printerr("Key not present in state: ", key)
	return null


func set_value(key: String, value) -> void:
	state[key] = value


func get_fuzes() -> int:
	return get_value("fuze") if state.has("fuze") else 0

# Returns true if the fuse was accepted (not yet at 3, not already collected).
func add_fuze(fuze_name: String) -> bool:
	if get_fuzes() >= MAX_FUZES:
		return false
	if collected_fuzes.has(fuze_name) or fuze_name == "":
		return false
	collected_fuzes.append(fuze_name)
	state["fuze"] = get_fuzes() + 1
	fuzes_changed.emit(get_fuzes())
	if get_fuzes() >= MAX_FUZES:
		save_game() # progress checkpoint
	return true

func get_collected_fuzes() -> Array[String]:
	return collected_fuzes

# --------------------------------- tasks ------------------------------------

func complete_electricity():
	if electricity_on:
		return
	electricity_on = true
	electricity_restored.emit()
	save_game()

# ------------------------ new game / load game flow --------------------------

func start_new_game():
	_reset_run_state()
	pending_start = "new_game"

func start_loaded_game(data: Dictionary):
	_reset_run_state()
	pending_start = "continue"
	loaded_save = data

func _reset_run_state():
	state["fuze"] = 0
	collected_fuzes.clear()
	electricity_on = false
	cutscene_done = false
	basement_seen = false
	loaded_save = null

# ------------------------------- save system --------------------------------

# Set when continuing a saved game; applied by the world's cutscene director.
var loaded_save: Variant = null


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game():
	if not cutscene_done:
		return # never checkpoint the unfinished opening cutscene
	var world = get_tree().current_scene if get_tree() != null else null
	if world == null or not world.has_node("Player"):
		return # menu / no playable world active
	var data := {
		"scene": "res://scenes/world/World.tscn",
	}
	if world and world.has_node("Player"):
		var player: Node3D = world.get_node("Player")
		data["player_position"] = [player.global_position.x, player.global_position.y, player.global_position.z]
		data["player_yaw"] = player.rotation.y
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({
		"fuzes": get_fuzes(),
		"collected_fuzes": collected_fuzes,
		"electricity_restored": electricity_on,
		"basement_seen": basement_seen,
		"position": data.get("player_position"),
		"yaw": data.get("player_yaw"),
		"scene": data["scene"],
	}))
	f.close()
	print("GameState: game saved.")
	game_saved.emit()


func read_save() -> Dictionary:
	if not has_save():
		return {}
	var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		return parsed
	return {}


func apply_save(data: Dictionary) -> void:
	_reset_run_state()
	state["fuze"] = int(data.get("fuzes", 0)) if data.get("fuzes", null) != null else 0
	var collected = data.get("collected_fuzes", [])
	if typeof(collected) == TYPE_ARRAY:
		for c in collected:
			collected_fuzes.append(str(c))
	electricity_on = bool(data.get("electricity_restored", false))
	basement_seen = bool(data.get("basement_seen", false))
	cutscene_done = true # a save implies the opening cutscene was already seen
	# Notify any listeners (task HUD) that the restored values are in place.
	fuzes_changed.emit(get_fuzes())
	if electricity_on:
		electricity_restored.emit()

# --------------------------------- settings ---------------------------------

# Defaults for every supported setting.
var settings := {
	"master_volume": 1.0,
	"music_volume": 1.0,
	"sfx_volume": 1.0,
	"fullscreen": false,
	"window_width": 1280,
	"window_height": 720,
	"vsync": true,
	"msaa": 0, # 0, 2, 4
	"graphics_quality": "high", # low, medium, high, very_high
	"mouse_sensitivity": 1.0,   # multiplier applied to the existing 0.003 step
	"invert_y": false,
	"fov": 75.0,
	"keybinds": {},             # {"action": physical_keycode}
}

const SETTINGS_SAVE_FORMAT := "{settings}"

const GRAPHICS_QUALITY_ORDER := ["low", "medium", "high", "very_high"]
const GRAPHICS_QUALITY_LABELS := {
	"low": "Low",
	"medium": "Medium",
	"high": "High",
	"very_high": "Very High",
}
const GRAPHICS_QUALITY_MSAA := {
	"low": 0,
	"medium": 0,
	"high": 0,
	"very_high": 2,
}


func get_setting(key: String):
	return settings.get(key)


func get_graphics_quality() -> String:
	var quality := str(settings.get("graphics_quality", "high"))
	return quality if GRAPHICS_QUALITY_ORDER.has(quality) else "high"


func set_graphics_quality(quality: String) -> void:
	quality = quality if GRAPHICS_QUALITY_ORDER.has(quality) else "high"
	settings["graphics_quality"] = quality
	# The quality preset also chooses a sensible anti-aliasing baseline. The
	# separate MSAA control can still override it afterwards.
	settings["msaa"] = int(GRAPHICS_QUALITY_MSAA[quality])
	save_settings()
	apply_settings()


func _quality_render_scale(target_width: int, quality: String) -> float:
	if target_width >= 3200:
		return {
			"low": 0.50,
			"medium": 0.65,
			"high": 0.80,
			"very_high": 1.00,
		}.get(quality, 0.80)
	if target_width >= 2400:
		return {
			"low": 0.60,
			"medium": 0.75,
			"high": 0.88,
			"very_high": 1.00,
		}.get(quality, 0.88)
	if target_width >= 1800:
		return {
			"low": 0.80,
			"medium": 0.90,
			"high": 1.00,
			"very_high": 1.00,
		}.get(quality, 1.0)
	if target_width >= 1500:
		return {
			"low": 0.90,
			"medium": 0.96,
			"high": 1.00,
			"very_high": 1.00,
		}.get(quality, 1.0)
	return 1.0


func set_setting(key: String, value) -> void:
	settings[key] = value
	save_settings()
	apply_settings()


func has_keybind(action: String) -> bool:
	return settings["keybinds"].has(action) and settings["keybinds"][action] != null


func rebind_key(action: String, physical_keycode: int) -> void:
	if InputMap.has_action(action) == false:
		return
	InputMap.action_erase_events(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = physical_keycode
	InputMap.action_add_event(action, ev)
	settings["keybinds"][action] = physical_keycode
	save_settings()


func reset_keybinds() -> void:
	settings["keybinds"].clear()
	for action in ["forward", "backward", "left", "right", "Jump", "Sprint", "flashlight", "interact"]:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
			var ev := InputEventKey.new()
			var default_codes := {
				"forward": KEY_W, "backward": KEY_S, "left": KEY_A, "right": KEY_D,
				"Jump": KEY_SPACE, "Sprint": KEY_SHIFT, "flashlight": KEY_F, "interact": KEY_E,
			}
			ev.physical_keycode = default_codes[action]
			InputMap.action_add_event(action, ev)
	save_settings()


func load_settings():
	var f = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if not f:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for key in settings.keys():
		if parsed.has(key):
			if key == "keybinds" and typeof(parsed[key]) == TYPE_DICTIONARY:
				var kb: Dictionary = {}
				for k in parsed[key]:
					kb[k] = int(parsed[key][k])
				settings["keybinds"] = kb
			elif key == "graphics_quality":
				var quality := str(parsed[key])
				if GRAPHICS_QUALITY_ORDER.has(quality):
					settings[key] = quality
			else:
				settings[key] = parsed[key]


func save_settings():
	var f = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings))
		f.close()


func apply_settings():
	# Audio buses
	_set_bus_volume("Master", settings["master_volume"])
	_set_bus_volume("Music", settings["music_volume"])
	_set_bus_volume("SFX", settings["sfx_volume"])
	# Display
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if settings["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
	if not settings["fullscreen"]:
		DisplayServer.window_set_size(Vector2i(int(settings["window_width"]), int(settings["window_height"])))
	var vsync_mode := DisplayServer.VSYNC_ENABLED if settings["vsync"] else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vsync_mode)
	# Graphics quality: MSAA is optional; the TAA in project.godot handles normal
	# edge quality. Keep the 3D at native resolution on small windows, but scale
	# the 3D internally on high-DPI / 4K displays so the M2 Pro stays smooth.
	# The UI and post-processing remain full-resolution.
	var level: int = int(settings["msaa"])
	var vp := get_viewport()
	if vp and level == 0:
		vp.msaa_3d = Viewport.MSAA_DISABLED
	elif vp and level > 0:
		vp.msaa_3d = Viewport.MSAA_2X if level == 2 else Viewport.MSAA_4X
	if vp:
		var target_w := int(settings["window_width"])
		var quality := get_graphics_quality()
		var render_scale := _quality_render_scale(target_w, quality)
		vp.scaling_3d_scale = render_scale
		if render_scale < 1.0 and OS.get_name() == "macOS":
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_METALFX_SPATIAL
		else:
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	# Input (apply stored keybinds directly; rebind_key() saves without
	# re-entering apply_settings to avoid recursion).
	for action in settings["keybinds"].keys():
		if not InputMap.has_action(str(action)):
			continue
		InputMap.action_erase_events(str(action))
		var ev := InputEventKey.new()
		ev.physical_keycode = int(settings["keybinds"][action])
		InputMap.action_add_event(str(action), ev)
	settings_changed.emit()


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	linear = clampf(linear, 0.0001, 1.0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(linear))


func _ready():
	load_settings()
	apply_settings()

# quick save key (F5)
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F5 or event.physical_keycode == KEY_F5:
			save_game()
