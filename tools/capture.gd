extends SceneTree
# Standalone visual capture harness for The Basement.
# Run, for example:
#   Godot --path . -s res://tools/capture.gd -- menu
#   Godot --path . -s res://tools/capture.gd -- living
#   Godot --path . -s res://tools/capture.gd -- basement
#   Godot --path . -s res://tools/capture.gd -- cutscene
# The script keeps the real root window so lighting and post-processing match
# the shipping game. It writes PNGs to /private/var/tmp/opencode/shots.

const OUT_DIR := "/private/var/tmp/opencode/shots"

var mode := "menu"
var no_post := false
var no_dress := false


func _initialize() -> void:
	seed(9173)
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		mode = String(args[0])
	no_post = OS.get_environment("CAPTURE_NO_POST") == "1"
	no_dress = OS.get_environment("CAPTURE_NO_DRESS") == "1"
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_position(Vector2i(80, 80))
	root.scaling_3d_scale = 1.0
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR

	if mode == "menu":
		change_scene_to_file("res://menu.tscn")
		await _wait(50)
		await _shot("horror_menu")
		quit()
		return

	change_scene_to_file("res://World.tscn")
	await _wait(12)

	var world := current_scene
	if world == null:
		push_error("World scene failed to load")
		quit(1)
		return

	if no_post:
		var post := world.get_node_or_null("PostFX")
		if post:
			post.visible = false
	if no_dress:
		var dressing := world.get_node_or_null("HorrorDressing")
		if dressing:
			dressing.queue_free()

	var director := world.get_node_or_null("OpeningCutscene")
	var player := world.get_node_or_null("Player")
	var friend := world.get_node_or_null("Friend")

	if mode == "cutscene":
		await _wait(120)
		await _shot("horror_cutscene")
		quit()
		return

	if mode == "probe":
		var cam := Camera3D.new()
		cam.name = "ProbeCamera"
		world.add_child(cam)
		cam.global_position = Vector3(-2.0, 3.3, -2.0)
		cam.look_at(Vector3(-10.0, 1.0, -2.0), Vector3.UP)
		cam.current = true
		await _wait(20)
		await _shot("horror_probe")
		quit()
		return

	if director != null:
		director.queue_free()
	await _wait(3)
	if friend != null:
		friend.visible = false
	if player != null:
		player.call("exit_cutscene", Vector3(2.45, 1.05, -6.30), PI / 2.0)
		var head := player.get_node("Head") as Node3D
		var cam := player.get_node("Head/Camera3D") as Camera3D
		var flash := player.get_node("Head/FlashlightPivot/SpotLight3D") as SpotLight3D
		if flash != null:
			flash.visible = true

		if mode == "living":
			# Actual post-cutscene eye line, looking across the living room.
			player.global_position = Vector3(2.45, 1.05, -6.30)
			player.rotation.y = PI * 0.5
			head.rotation.y = 0.0
			cam.rotation.x = -0.03
			cam.fov = 78.0
			await _wait(20)
			await _shot("horror_living")
		elif mode == "basement":
			# Looking down the length of the service basement toward the props.
			player.global_position = Vector3(-12.6, -3.55, 16.2)
			player.rotation.y = PI
			head.rotation.y = 0.0
			cam.rotation.x = 0.0
			cam.fov = 78.0
			await _wait(20)
			await _shot("horror_basement")
		elif mode == "generator":
			# Facing the generator and the red emergency light behind it.
			player.global_position = Vector3(-8.8, -3.55, 23.4)
			player.rotation.y = PI
			head.rotation.y = 0.05
			cam.rotation.x = -0.03
			cam.fov = 78.0
			await _wait(20)
			await _shot("horror_generator")
		else:
			await _wait(20)
			await _shot("horror_world")

	quit()


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if no_post:
		name += "_raw"
	if no_dress:
		name += "_nodress"
	var path := OUT_DIR + "/" + name + ".png"
	var err := img.save_png(path)
	print("CAPTURE ", path, " err=", err, " size=", img.get_width(), "x", img.get_height())
