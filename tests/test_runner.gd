extends SceneTree
## Headless smoke test suite for Not To Love.
##
## Run locally with:
##   GODOT_BIN=/path/to/godot ./tests/run_tests.sh
##
## The suite intentionally avoids instantiating the gameplay world so it never
## touches the player's save file or graphics settings.

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_project_settings()
	_test_autoload()
	_test_input_map()
	_test_project_structure()
	_test_scenes_and_scripts()
	_test_menu()
	_test_export_presets()
	print("TESTS: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _test_project_settings() -> void:
	var main_scene := str(ProjectSettings.get_setting("application/run/main_scene", ""))
	_expect(main_scene == "res://scenes/ui/menu.tscn", "main scene points at the menu")
	_expect(ResourceLoader.exists(main_scene), "main scene resource exists")
	_expect(
		str(ProjectSettings.get_setting("physics/3d/physics_engine", "")) == "Jolt Physics",
		"Jolt Physics is enabled",
	)
	_expect(
		int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 0)) == 60,
		"physics tick rate is set to the 60 Hz gameplay target",
	)


func _test_autoload() -> void:
	var game_state := root.get_node_or_null("GameState")
	_expect(game_state != null, "GameState autoload is registered")
	if game_state == null:
		return
	_expect(game_state.has_method("save_game"), "GameState exposes save_game")
	_expect(game_state.has_method("has_save"), "GameState exposes has_save")
	_expect(game_state.has_method("get_graphics_quality"), "GameState exposes graphics settings")
	_expect(game_state.has_method("apply_settings"), "GameState exposes settings application")


func _test_input_map() -> void:
	var actions := [
		"forward",
		"backward",
		"left",
		"right",
		"Jump",
		"Sprint",
		"flashlight",
		"interact",
		"pause",
	]
	for action in actions:
		_expect(InputMap.has_action(action), "input action exists: %s" % action)


func _test_project_structure() -> void:
	var required_dirs := [
		"res://assets",
		"res://materials",
		"res://resources",
		"res://scenes",
		"res://scripts",
		"res://tests",
	]
	for directory in required_dirs:
		_expect(
			DirAccess.dir_exists_absolute(directory), "project directory exists: %s" % directory
		)


func _test_scenes_and_scripts() -> void:
	var scenes: Array[String] = []
	_collect_files("res://scenes", ".tscn", scenes)
	_collect_files("res://assets", ".tscn", scenes)
	_expect(scenes.size() > 0, "at least one scene was found")
	for scene_path in scenes:
		var scene := load(scene_path) as PackedScene
		_expect(scene != null, "scene loads: %s" % scene_path)
		if scene != null:
			_expect(scene.can_instantiate(), "scene can instantiate: %s" % scene_path)

	var scripts: Array[String] = []
	_collect_files("res://scripts", ".gd", scripts)
	_expect(scripts.size() > 0, "at least one gameplay script was found")
	for script_path in scripts:
		var script := load(script_path) as Script
		_expect(script != null, "script compiles: %s" % script_path)

	var shaders: Array[String] = []
	_collect_files("res://materials", ".gdshader", shaders)
	for shader_path in shaders:
		_expect(load(shader_path) != null, "shader loads: %s" % shader_path)


func _test_menu() -> void:
	var menu := load("res://scenes/ui/menu.tscn") as PackedScene
	_expect(menu != null, "menu scene loads")
	if menu != null:
		_expect(menu.can_instantiate(), "menu scene can instantiate")


func _test_export_presets() -> void:
	var path := "res://export_presets.cfg"
	_expect(FileAccess.file_exists(path), "export presets are present")
	if not FileAccess.file_exists(path):
		return
	var contents := FileAccess.get_file_as_string(path)
	for preset_name in ["Windows Desktop", "macOS", "Linux"]:
		_expect(
			contents.contains('name="%s"' % preset_name),
			"export preset exists: %s" % preset_name,
		)


func _expect(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("FAIL: %s" % message)


func _collect_files(directory: String, extension: String, result: Array[String]) -> void:
	var dir := DirAccess.open(directory)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not file_name.begins_with("."):
			var path := directory.path_join(file_name)
			if dir.current_is_dir():
				_collect_files(path, extension, result)
			elif file_name.ends_with(extension):
				result.append(path)
		file_name = dir.get_next()
	dir.list_dir_end()
