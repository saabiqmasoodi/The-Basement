
extends CharacterBody3D

var speed: float
const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.0
const JUMP_VELOCITY = 4.5
const SENSITIVITY = 0.003

# Set this to false when the opening cutscene begins.
var controls_enabled := true

# While true the whole physics controller is bypassed (no gravity / movement /
# collision). Used during the opening cutscene so the director owns the pose.
var cutscene_frozen := false

# Head height from the untouched Player.tscn (the World scene lowers it for the
# sitting cutscene); restored to this value after the cutscene.
const NORMAL_HEAD_HEIGHT := 0.85498893

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var flashlight: SpotLight3D = $Head/Camera3D/SpotLight3D

# Remember the camera position set in the editor.
var camera_start_position: Vector3

const FOV_CHANGE = 1.5

var gravity: float = 9.8


func _ready() -> void:
	camera_start_position = camera.position
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


# Poses used by the opening cutscene. position is the player's global
# position for the "sitting on the sofa" shot; look_yaw/look_pitch seed the
# camera before the director takes over.
func enter_cutscene_pose(pos: Vector3, look_yaw: float, look_pitch: float) -> void:
	cutscene_frozen = true
	controls_enabled = false
	velocity = Vector3.ZERO
	global_position = pos
	head.position.y = -0.5792575 # sofa-height head (value saved in World.tscn)
	head.rotation.y = look_yaw
	camera.rotation.x = look_pitch
	camera.fov = GameState.get_setting("fov")


# Ends the cutscene: restores the normal gameplay camera height and rotations,
# leaves the player in full first-person control.
func exit_cutscene(spawn_pos: Vector3, spawn_yaw: float) -> void:
	cutscene_frozen = false
	controls_enabled = true
	global_position = spawn_pos
	rotation.y = spawn_yaw
	head.position.y = NORMAL_HEAD_HEIGHT
	head.rotation.y = 0.0
	camera.rotation.x = 0.0
	camera.fov = GameState.get_setting("fov")
	velocity = Vector3.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return

	if event is InputEventMouseMotion:
		var sens: float = SENSITIVITY * float(GameState.get_setting("mouse_sensitivity"))
		head.rotate_y(-event.relative.x * sens)
		var pitch_delta: float = -event.relative.y * sens
		if bool(GameState.get_setting("invert_y")):
			pitch_delta = -pitch_delta
		camera.rotate_x(pitch_delta)
		camera.rotation.x = clamp(
			camera.rotation.x,
			deg_to_rad(-40),
			deg_to_rad(60)
		)


func _physics_process(delta: float) -> void:
	# Director owns the pose completely during the cutscene (no gravity /
	# collision / depenetration at all).
	if cutscene_frozen:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	# Freeze player controls during a cutscene.
	if not controls_enabled:
		velocity.x = 0.0
		velocity.z = 0.0
		camera.position = camera_start_position
		move_and_slide()
		return

	# Jump
	if Input.is_action_just_pressed("Jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Sprint
	if Input.is_action_pressed("Sprint"):
		speed = SPRINT_SPEED
	else:
		speed = WALK_SPEED

	# Flashlight
	if Input.is_action_just_pressed("flashlight"):
		flashlight.visible = not flashlight.visible

	# WASD movement relative to the player's actual facing direction.
	var input_dir := Input.get_vector(
		"left", "right", "forward", "backward"
	)

	var direction := head.global_basis * Vector3(
		input_dir.x, 0.0, input_dir.y
	)

	direction.y = 0.0
	direction = direction.normalized()

	if is_on_floor():
		if direction.length() > 0.0:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = move_toward(velocity.x, 0.0, speed * delta * 7.0)
			velocity.z = move_toward(velocity.z, 0.0, speed * delta * 7.0)
	else:
		velocity.x = move_toward(velocity.x, direction.x * speed, delta * 3.0)
		velocity.z = move_toward(velocity.z, direction.z * speed, delta * 3.0)

	move_and_slide()

	# FOV
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var base_fov: float = float(GameState.get_setting("fov"))
	var target_fov := base_fov + FOV_CHANGE * (horizontal_speed / SPRINT_SPEED)
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)
