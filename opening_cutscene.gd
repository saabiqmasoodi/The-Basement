extends Node
# Opening cutscene director.
#
#  - Seats the frozen player on the sofa and frames the friend.
#  - Plays the friend's sit -> stand -> walk -> basement sequence.
#  - Shows the dialogue while the friend walks off.
#  - Runs the horror sound cue timing (scream at +5s, eating at +7.6s after
#    the friend has entered the basement) and slowly pans to the stairwell.
#  - Restores first-person control (or applies a loaded save on continue).

const SEAT_POS := Vector3(0.0, 2.71, -6.297)
const EXIT_POS := Vector3(2.45, 1.05, -6.30)
const EXIT_YAW := PI / 2.0

const DIALOGUE := "I forgot something in the basement. Let me get it quickly."

const SCREAM_DELAY := 5.0      # after the friend enters the basement
const EAT_DELAY := 2.6         # after the scream (=> ~7.6s)

const LOOK_HEIGHT := 1.25

var player
var head: Node3D
var camera_node: Camera3D
var friend: Node3D
var look_target: Marker3D

var scream: AudioStreamPlayer
var eat: AudioStreamPlayer
var dialogue_panel: Control
var dialogue_text: Label

var cutscene_active := false
var sway_time := 0.0


func _ready() -> void:
	player = get_parent().get_node_or_null("Player")
	friend = get_parent().get_node_or_null("Friend")
	look_target = get_parent().get_node_or_null("LookTarget")
	scream = get_parent().get_node_or_null("CutsceneAudio/Scream")
	eat = get_parent().get_node_or_null("CutsceneAudio/Eat")

	var ui: Node = get_parent().get_node_or_null("CutsceneUI")
	if ui:
		dialogue_panel = ui.get_node_or_null("DialoguePanel")
		dialogue_text = ui.get_node_or_null("DialoguePanel/Text")
		if dialogue_panel:
			dialogue_panel.visible = false
			dialogue_panel.modulate.a = 0.0

	if player and player.has_node("Head"):
		head = player.get_node("Head")
		camera_node = player.get_node("Head/Camera3D")

	call_deferred("_run")


func _run() -> void:
	await get_tree().process_frame

	if GameState.pending_start == "continue" and GameState.loaded_save != null:
		_restore_loaded_game(GameState.loaded_save)
		GameState.loaded_save = null
		return

	await _play_opening_cutscene()


# ------------------------------------------------------------------ cutscene

func _play_opening_cutscene() -> void:
	GameState.cutscene_done = false
	GameState.pending_start = "new_game"

	if friend:
		friend.visible = true

	# Seat the player and lock his pose/camera.
	player.call("enter_cutscene_pose", SEAT_POS, 0.0, 0.0)
	_aim_immediate()
	cutscene_active = true

	# Hide the gameplay HUD (crosshair) during the cinematic.
	if player and player.has_node("CanvasLayer"):
		player.get_node("CanvasLayer").visible = false

	await get_tree().create_timer(1.0, false).timeout
	_show_dialogue(DIALOGUE)

	await get_tree().create_timer(0.8, false).timeout
	if friend:
		friend.play_cutscene()

	await get_tree().create_timer(4.4, false).timeout
	_hide_dialogue()

	# Wait until he walks down into the basement.
	if friend:
		await friend.entered_basement

	# From here the camera slowly drifts to the stairwell entrance.
	await get_tree().create_timer(SCREAM_DELAY, false).timeout
	if scream:
		scream.play()

	await get_tree().create_timer(EAT_DELAY, false).timeout
	if eat:
		eat.play()

	await get_tree().create_timer(4.0, false).timeout
	_end_cutscene()


func _end_cutscene() -> void:
	cutscene_active = false
	player.call("exit_cutscene", EXIT_POS, EXIT_YAW)
	if player and player.has_node("CanvasLayer"):
		player.get_node("CanvasLayer").visible = true
	GameState.cutscene_done = true
	GameState.save_game()


# ------------------------------------------------------------------ continue

func _restore_loaded_game(data: Dictionary) -> void:
	GameState.apply_save(data)

	if friend:
		friend.visible = false

	# Remove already collected fuses.
	var collected: Array = GameState.get_collected_fuzes()
	var world := get_parent()
	for child in world.get_children():
		if collected.has(String(child.name)) and child.has_method("interact"):
			child.queue_free()

	var pos := Vector3.ZERO
	var p = data.get("position")
	if typeof(p) == TYPE_ARRAY and p.size() == 3:
		pos = Vector3(float(p[0]), float(p[1]), float(p[2]))
	else:
		pos = EXIT_POS
	var yaw: float = float(data.get("yaw", EXIT_YAW))

	player.call("exit_cutscene", pos, yaw)

	# Reveal the task HUD when resuming inside the basement.
	if player and player.has_node("CanvasLayer/TaskLabel"):
		var inside := pos.z > 13.5 or GameState.basement_seen or GameState.get_fuzes() > 0
		player.get_node("CanvasLayer/TaskLabel").visible = inside

	GameState.cutscene_done = true


# -------------------------------------------------------------- camera follow

func _focus_point() -> Vector3:
	if friend and friend.visible:
		if friend.has_method("get_head_position"):
			return friend.get_head_position()
		return friend.global_position + Vector3(0.0, LOOK_HEIGHT, 0.0)
	if look_target:
		return look_target.global_position
	return Vector3.ZERO


func _process(delta: float) -> void:
	if not cutscene_active or head == null or camera_node == null:
		return

	sway_time += delta

	var has_target := false
	if friend and friend.visible:
		has_target = true
	elif look_target:
		has_target = true

	if not has_target:
		return

	var target_point: Vector3 = _focus_point()

	var cam_pos: Vector3 = camera_node.global_position
	var dir: Vector3 = target_point - cam_pos
	var flat := Vector2(dir.x, dir.z).length()

	var want_yaw: float = atan2(-dir.x, -dir.z) - player.rotation.y
	want_yaw = wrapf(want_yaw, -PI, PI)
	var want_pitch: float = clampf(atan2(dir.y, maxf(flat, 0.001)), deg_to_rad(-55.0), deg_to_rad(45.0))

	# Subtle breathing / handheld sway.
	want_yaw += sin(sway_time * 0.5) * 0.006
	want_pitch += sin(sway_time * 0.34 + 0.6) * 0.005

	var blend := 1.0 - exp(-2.2 * delta)
	head.rotation.y = lerp_angle(head.rotation.y, want_yaw, blend)
	camera_node.rotation.x = lerp(camera_node.rotation.x, want_pitch, blend)


func _aim_immediate() -> void:
	if friend and head and camera_node:
		var target_point: Vector3 = _focus_point()
		var cam_pos: Vector3 = camera_node.global_position
		var dir: Vector3 = target_point - cam_pos
		var flat := Vector2(dir.x, dir.z).length()
		head.rotation.y = wrapf(atan2(-dir.x, -dir.z) - player.rotation.y, -PI, PI)
		camera_node.rotation.x = clampf(atan2(dir.y, maxf(flat, 0.001)), deg_to_rad(-55.0), deg_to_rad(45.0))


# ------------------------------------------------------------------ dialogue

func _show_dialogue(text: String) -> void:
	if dialogue_panel == null:
		return
	if dialogue_text:
		dialogue_text.text = text
	dialogue_panel.visible = true
	dialogue_panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(dialogue_panel, "modulate:a", 1.0, 0.45)


func _hide_dialogue() -> void:
	if dialogue_panel == null:
		return
	var tw := create_tween()
	tw.tween_property(dialogue_panel, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void:
		if dialogue_panel:
			dialogue_panel.visible = false
	)
