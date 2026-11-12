extends Interactable

func _on_interacted(_body):
	if GameState.add_fuze(name):
		queue_free()
