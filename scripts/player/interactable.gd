extends CollisionObject3D
class_name Interactable

signal interacted(body)

@export var promt_message = "Interact"
@export var promt_input = "interact"


func get_promt():
	var key_name = ""
	for action in InputMap.action_get_events(promt_input):
		if action is InputEventKey:
			key_name = action.as_text_physical_keycode()
			break

	return promt_message + "\n[" + key_name + "]"


func interact(body):
	interacted.emit(body)
