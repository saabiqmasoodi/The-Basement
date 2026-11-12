extends Node3D

var playback: AnimationNodeStateMachinePlayback
var is_open := false


func _ready():
	playback = $AnimationTree.get("parameters/playback")


func toggle(_body):
	is_open = not is_open

	if is_open:
		playback.travel("DoorOpen")
	else:
		playback.travel("DoorClose")


func close_door(_body):
	if is_open:
		is_open = false
		playback.travel("DoorClose")
