extends RayCast3D
# Crosshair interaction.  The prompt is a small button-style panel built from
# a keycap + action text + hint.  It can be triggered with the configured key
# (E) or by clicking with the mouse.
#
# Interactables that return a single line (for example "Generator running" or
# "needs 3 fuses") are treated as status messages: the keycap and click hint
# are hidden so the UI never promises an action that is not available.

@onready var prompt: PanelContainer = $Promt
@onready var keycap: PanelContainer = $Promt/Row/KeyCap
@onready var key_label: Label = $Promt/Row/KeyCap/Key
@onready var action_label: Label = $Promt/Row/Text/Action
@onready var hint_label: Label = $Promt/Row/Text/Hint
@onready var crosshair: Control = $"../../../CanvasLayer/crosshair"

var _click_was_down := false


func _ready() -> void:
	prompt.visible = false


func _physics_process(_delta: float) -> void:
	prompt.visible = false
	crosshair.visible = true

	var click_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

	if is_colliding():
		var collider = get_collider()

		if collider is Interactable:
			var raw: String = collider.get_promt()
			if raw.strip_edges() != "":
				_show_prompt(raw)
				crosshair.visible = false

				if Input.is_action_just_pressed(collider.promt_input):
					collider.interact(owner)
				elif click_down and not _click_was_down:
					collider.interact(owner)

	_click_was_down = click_down


func _show_prompt(raw: String) -> void:
	var parts := raw.split("\n", true, 1)
	action_label.text = parts[0].strip_edges()

	# The second line is "[E]" or "[E] FIX or Click" for actionable prompts;
	# status messages have no second line at all.
	var key := ""
	if parts.size() > 1:
		var second: String = parts[1]
		var open := second.find("[")
		var close := second.find("]")
		if open != -1 and close > open + 1:
			key = second.substr(open + 1, close - open - 1).strip_edges()

	var actionable := key != ""
	keycap.visible = actionable
	hint_label.visible = actionable
	if actionable:
		key_label.text = key
		hint_label.text = "PRESS OR CLICK"

	prompt.visible = true
