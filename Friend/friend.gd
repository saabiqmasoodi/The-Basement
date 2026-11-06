extends Node3D
# Friend cutscene character.
#
# Choreography requested by the player:
#   1. sit on the sofa, facing forward (+Z)
#   2. stand up (lean forward, slide off the sofa edge onto the floor)
#   3. walk forward to the corner (-1, -1)
#   4. exact 90 degree Y turn
#   5. walk again, in front of the stair block (CSGBox3D11)
#   6. exact 90 degree Y turn, walk forward down the stairs
#   7. play the idle animation at the bottom
#
# The Mixamo clips contain baked root motion (the hips translate ~1.65 units
# per walk cycle and ~0.43 units during "Stand Up").  We flatten that
# translation so the node itself can be tweened along the route; otherwise the
# character double-moves and snaps back every loop.  The walk speed is matched
# to the clip's own stride so the feet do not slide.

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var playback: AnimationNodeStateMachinePlayback

signal entered_basement   # friend finished walking down into the basement
signal sequence_finished  # whole cutscene route done

# CUTSCENE SETTINGS (legacy straight-walk mode kept for compatibility)
@export var first_walk_distance: float = 3.0
@export var second_walk_distance: float = 5.0

@export var first_walk_duration: float = 3.0
@export var second_walk_duration: float = 5.0

@export var turn_duration: float = 0.7
@export var sitting_wait: float = 1.4

# Waypoint mode: global-space targets, one Vector3 per leg.
@export var waypoint_route: PackedVector3Array = PackedVector3Array()
@export var waypoint_leg_times: PackedFloat32Array = PackedFloat32Array()
@export var walk_speed: float = 1.55
@export var auto_play: bool = true
@export var hide_when_done: bool = true

# Use the walk clip's own stride to pick the walking speed (no foot sliding).
@export var match_walk_speed_to_animation: bool = true

# Standing up from the sofa: the animation keeps the feet at the node origin,
# so while it plays we move the node forwards off the sofa edge and down to
# the floor.  stand_ground_y is the node height that puts the soles on floor 0.
@export var stand_forward: float = 0.95
@export var stand_ground_y: float = 0.0
@export var stand_move_delay: float = 0.55
@export var stand_move_time: float = 1.9

var _stand_target := Vector3.ZERO
var _walk_cycle_speed := 0.0


func _ready() -> void:
	animation_tree.active = true
	playback = animation_tree.get("parameters/playback")

	# Measure the stride before removing the baked root motion.
	_walk_cycle_speed = _measure_walk_speed()
	_make_in_place("walking")
	_make_in_place("standing up")

	var walk_anim := animation_player.get_animation("walking")
	if walk_anim:
		walk_anim.loop_mode = Animation.LOOP_LINEAR

	if match_walk_speed_to_animation and _walk_cycle_speed > 0.05:
		walk_speed = _walk_cycle_speed

	if auto_play:
		play_cutscene()


func play_cutscene() -> void:
	# 1. Sit on the sofa.
	playback.start("sitting_idle")
	await get_tree().create_timer(sitting_wait, false).timeout

	# 2. Stand up and step forward off the sofa edge, down onto the floor.
	_stand_target = Vector3(global_position.x, stand_ground_y, global_position.z + stand_forward)
	playback.travel("standing up")

	var stand_len := 2.8
	var stand_anim := animation_player.get_animation("standing up")
	if stand_anim:
		stand_len = stand_anim.length

	var move := create_tween()
	if stand_move_delay > 0.0:
		move.tween_interval(stand_move_delay)
	move.tween_property(self, "global_position", _stand_target, stand_move_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Play the whole stand-up clip; only then blend into the idle pose.
	await get_tree().create_timer(stand_len, false).timeout
	playback.travel("standing_idle")
	if move.is_running():
		await move.finished
	await get_tree().create_timer(0.2, false).timeout
	global_position = _stand_target

	# 3-7. Walk the route.
	if waypoint_route.is_empty():
		await _play_legacy_route()
	else:
		await _play_waypoint_route()

	sequence_finished.emit()


func _play_legacy_route() -> void:
	await turn_friend(90.0)
	await walk_friend(first_walk_distance, first_walk_duration)
	playback.travel("standing_idle")
	await get_tree().create_timer(0.7, false).timeout
	await turn_friend(90.0)
	await walk_friend(second_walk_distance, second_walk_duration)
	playback.travel("standing_idle")


func _play_waypoint_route() -> void:
	var last := waypoint_route.size() - 1
	for i in waypoint_route.size():
		var target: Vector3 = waypoint_route[i]

		# Turn towards the next leg before walking it (first leg is straight ahead).
		if i > 0:
			await _face_target(target)

		await _walk_to_global(target, i)

		# Only stop at real corners; keep the descent fluid.
		if i < last:
			var next_yaw := _yaw_to(waypoint_route[i + 1])
			if absf(wrapf(next_yaw - rotation.y, -PI, PI)) > 0.02:
				playback.travel("standing_idle")
				await get_tree().create_timer(0.22, false).timeout

	# 7. Arrived in the basement: play the idle animation, then disappear.
	playback.travel("standing_idle")
	entered_basement.emit()

	if hide_when_done:
		await get_tree().create_timer(1.2, false).timeout
		visible = false


# ------------------------------------------------------------------ movement

func _yaw_to(target: Vector3) -> float:
	var dir := target - global_position
	dir.y = 0.0
	if dir.length() < 0.001:
		return rotation.y
	# The route corners are right angles; snap so every turn is a clean 90.
	var want := atan2(dir.x, dir.z)
	return roundf(want / (PI * 0.5)) * (PI * 0.5)


func _face_target(target: Vector3) -> void:
	var wanted := _yaw_to(target)
	var delta := wrapf(wanted - rotation.y, -PI, PI)
	if absf(delta) < 0.01:
		return
	await _turn_yaw(rotation.y + delta)


func _walk_to_global(target: Vector3, leg_index: int) -> void:
	playback.travel("walking")

	var duration: float
	if leg_index < waypoint_leg_times.size():
		duration = waypoint_leg_times[leg_index]
	else:
		var dist := global_position.distance_to(target)
		duration = dist / maxf(walk_speed, 0.01)

	var tween := create_tween()
	tween.tween_property(self, "global_position", target, duration)
	await tween.finished


func walk_friend(distance: float, duration: float) -> void:
	playback.travel("walking")
	var direction := global_transform.basis.z
	var destination := global_position + direction * distance
	var tween := create_tween()
	tween.tween_property(self, "global_position", destination, duration)
	await tween.finished
	playback.travel("standing_idle")


func turn_friend(degrees: float) -> void:
	await _turn_yaw(rotation.y + deg_to_rad(degrees))


func _turn_yaw(target_yaw: float) -> void:
	var delta := wrapf(target_yaw - rotation.y, -PI, PI)
	if absf(delta) < 0.002:
		return
	var tween := create_tween()
	tween.tween_property(self, "rotation:y", rotation.y + delta, turn_duration)
	await tween.finished


# ------------------------------------------------------------------ helpers

func get_head_position() -> Vector3:
	var skel := get_node_or_null("Skeleton3D") as Skeleton3D
	if skel:
		var idx := skel.find_bone("mixamorig_Head")
		if idx >= 0:
			return skel.global_transform * skel.get_bone_global_pose(idx).origin
	return global_position + Vector3(0.0, 1.6, 0.0)


# Remove the baked forward translation from the hips track so looping the clip
# does not teleport the character.  Vertical hip motion (rise / bob) is kept.
func _make_in_place(anim_name: String) -> void:
	var anim := animation_player.get_animation(anim_name)
	if anim == null:
		return
	for i in anim.get_track_count():
		if anim.track_get_type(i) != Animation.TYPE_POSITION_3D:
			continue
		if not String(anim.track_get_path(i)).ends_with("mixamorig_Hips"):
			continue
		var count := anim.track_get_key_count(i)
		if count == 0:
			continue
		var base_z: float = (anim.track_get_key_value(i, 0) as Vector3).z
		for k in count:
			var v: Vector3 = anim.track_get_key_value(i, k)
			v.z = base_z
			anim.track_set_key_value(i, k, v)


# Metres / second the clip travels at its authored speed.
func _measure_walk_speed() -> float:
	var anim := animation_player.get_animation("walking")
	if anim == null:
		return 0.0
	var scale_z := global_transform.basis.get_scale().z
	for i in anim.get_track_count():
		if anim.track_get_type(i) != Animation.TYPE_POSITION_3D:
			continue
		if not String(anim.track_get_path(i)).ends_with("mixamorig_Hips"):
			continue
		var count := anim.track_get_key_count(i)
		if count < 2:
			continue
		var first: Vector3 = anim.track_get_key_value(i, 0)
		var last: Vector3 = anim.track_get_key_value(i, count - 1)
		return absf(last.z - first.z) * scale_z / maxf(anim.length, 0.001)
	return 0.0
