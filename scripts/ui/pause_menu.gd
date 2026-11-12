extends CanvasLayer
# In-game pause menu.  Lives in World.tscn and works at any point in the run,
# including during the opening cutscene: the scene tree is paused, the backdrop
# is blurred, and this CanvasLayer keeps processing so the menu stays alive.
#
# Owns a compact settings panel (audio / display / camera / controls) so the
# player never has to leave the game to adjust things.

const MAIN_MENU_SCENE := "res://scenes/ui/menu.tscn"

const ACTIONS := [
	["forward", "Move forward"],
	["backward", "Move backward"],
	["left", "Move left"],
	["right", "Move right"],
	["Jump", "Jump"],
	["Sprint", "Sprint"],
	["flashlight", "Flashlight"],
	["interact", "Interact"],
]

@onready var panel: PanelContainer = $Center/Panel
@onready var resume_button: Button = $Center/Panel/VBox/Resume
@onready var settings_button: Button = $Center/Panel/VBox/Settings
@onready var menu_button: Button = $Center/Panel/VBox/MainMenu
@onready var quit_button: Button = $Center/Panel/VBox/Quit
@onready var click_player: AudioStreamPlayer = $ClickPlayer

var _settings_root: Control = null
var _settings_panel: PanelContainer = null
var _rebind_buttons: Dictionary = {}
var _awaiting_action := ""
var _awaiting_button: Button = null
var _msaa_option: OptionButton = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	panel.modulate.a = 1.0

	resume_button.pressed.connect(_resume)
	settings_button.pressed.connect(_open_settings)
	menu_button.pressed.connect(_to_main_menu)
	quit_button.pressed.connect(_quit_to_desktop)


# --------------------------------------------------------------------- input


func _input(event: InputEvent) -> void:
	# A key is being captured for a control rebind.
	if _awaiting_action != "":
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
				_awaiting_button.text = _key_text(_awaiting_action)
			else:
				GameState.rebind_key(_awaiting_action, event.physical_keycode)
				_awaiting_button.text = _key_text(_awaiting_action)
			_awaiting_action = ""
			_awaiting_button = null
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("pause"):
		_on_escape()
		get_viewport().set_input_as_handled()
		return

	# Safety net: Escape always toggles pause even if the action is unbound.
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
			_on_escape()
			get_viewport().set_input_as_handled()


func _on_escape() -> void:
	if _settings_root != null and _settings_root.visible:
		_close_settings()
	elif visible:
		_resume()
	else:
		_open()


# ---------------------------------------------------------------------- open


func _open() -> void:
	visible = true
	panel.visible = true
	if _settings_root:
		_settings_root.visible = false

	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Soft fade-in; the menu is PROCESS_MODE_ALWAYS so the tween runs while
	# the rest of the tree is frozen.
	panel.modulate.a = 0.0
	var tw := panel.create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.16)

	resume_button.grab_focus()


func _resume() -> void:
	visible = false
	_awaiting_action = ""
	if _settings_root:
		_settings_root.visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _to_main_menu() -> void:
	_click()
	GameState.save_game()
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _quit_to_desktop() -> void:
	_click()
	GameState.save_game()
	get_tree().paused = false
	get_tree().quit()


func _click() -> void:
	if click_player and click_player.stream:
		click_player.play()


# ---------------------------------------------------------------- settings UI


func _open_settings() -> void:
	_click()
	if _settings_root == null:
		_build_settings()
	panel.visible = false
	_settings_root.visible = true


func _close_settings() -> void:
	_click()
	_settings_root.visible = false
	panel.visible = true
	resume_button.grab_focus()


func _build_settings() -> void:
	_settings_root = Control.new()
	_settings_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_settings_root)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_root.add_child(center)

	_settings_panel = PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.035, 0.045, 0.97)
	panel_style.set_corner_radius_all(10)
	panel_style.set_content_margin_all(22)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 2
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.55, 0.13, 0.13, 0.45)
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	panel_style.shadow_size = 24
	_settings_panel.add_theme_stylebox_override("panel", panel_style)

	var vp_size := get_viewport().get_visible_rect().size
	_settings_panel.custom_minimum_size = Vector2(
		minf(700.0, vp_size.x * 0.92), minf(640.0, vp_size.y * 0.92)
	)
	center.add_child(_settings_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	_settings_panel.add_child(outer)

	var heading := Label.new()
	heading.text = "SETTINGS"
	heading.add_theme_font_size_override("font_size", 26)
	heading.add_theme_color_override("font_color", Color(0.88, 0.86, 0.84))
	outer.add_child(heading)

	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 1)
	rule.color = Color(0.55, 0.13, 0.13, 0.45)
	outer.add_child(rule)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)

	# ---- audio
	_add_section(box, "AUDIO")
	_add_slider(box, "Master volume", "master_volume", 0.0, 1.0, 0.01)
	_add_slider(box, "Music volume", "music_volume", 0.0, 1.0, 0.01)
	_add_slider(box, "Sound effects", "sfx_volume", 0.0, 1.0, 0.01)

	# ---- display
	_add_section(box, "DISPLAY")
	_add_check(box, "Fullscreen", "fullscreen")
	_add_check(box, "V-Sync", "vsync")
	_add_resolution(box)
	_add_graphics_quality(box)
	_add_msaa(box)

	# ---- camera
	_add_section(box, "CAMERA")
	_add_slider(box, "Mouse sensitivity", "mouse_sensitivity", 0.1, 3.0, 0.05)
	_add_check(box, "Invert Y axis", "invert_y")
	_add_slider(box, "Field of view", "fov", 60.0, 100.0, 1.0)

	# ---- controls
	_add_section(box, "CONTROLS")
	for entry in ACTIONS:
		_add_keybind_row(box, entry[0], entry[1])

	var reset_btn := Button.new()
	reset_btn.text = "Reset controls to defaults"
	reset_btn.custom_minimum_size = Vector2(0, 34)
	reset_btn.pressed.connect(_on_reset_controls)
	box.add_child(reset_btn)

	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(0, 42)
	back.add_theme_font_size_override("font_size", 18)
	back.pressed.connect(_close_settings)
	outer.add_child(back)


func _add_section(box: VBoxContainer, title_text: String) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	box.add_child(spacer)
	var lbl := Label.new()
	lbl.text = title_text
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.62, 0.34, 0.32))
	box.add_child(lbl)


func _value_text(value: float, is_float: bool) -> String:
	if is_float:
		return "%.1f" % value
	return "%d%%" % int(round(value * 100.0))


func _add_slider(
	box: VBoxContainer, title_text: String, key: String, min_v: float, max_v: float, step: float
) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var lbl := Label.new()
	lbl.text = title_text
	lbl.custom_minimum_size = Vector2(180, 0)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = float(GameState.get_setting(key))
	slider.custom_minimum_size = Vector2(320, 24)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)

	var val := Label.new()
	val.custom_minimum_size = Vector2(70, 0)
	val.text = _value_text(slider.value, key == "mouse_sensitivity" or key == "fov")
	row.add_child(val)

	slider.value_changed.connect(
		func(v: float) -> void:
			val.text = _value_text(v, key == "mouse_sensitivity" or key == "fov")
			GameState.set_setting(key, v)
	)
	box.add_child(row)


func _add_check(box: VBoxContainer, title_text: String, key: String) -> void:
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = title_text
	lbl.custom_minimum_size = Vector2(180, 0)
	row.add_child(lbl)
	var check := CheckButton.new()
	check.button_pressed = bool(GameState.get_setting(key))
	check.toggled.connect(func(on: bool) -> void: GameState.set_setting(key, on))
	row.add_child(check)
	box.add_child(row)


func _add_resolution(box: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = "Resolution"
	lbl.custom_minimum_size = Vector2(180, 0)
	row.add_child(lbl)

	var opt := OptionButton.new()
	var modes := [
		[1280, 720],
		[1600, 900],
		[1920, 1080],
		[2560, 1440],
		[3840, 2160],
	]
	var current := 0
	for i in modes.size():
		var m: Array = modes[i]
		opt.add_item("%d x %d" % [m[0], m[1]], i)
		if (
			int(GameState.get_setting("window_width")) == m[0]
			and int(GameState.get_setting("window_height")) == m[1]
		):
			current = i
	opt.select(current)
	opt.item_selected.connect(
		func(idx: int) -> void:
			var m: Array = modes[idx]
			GameState.set_setting("window_width", m[0])
			GameState.set_setting("window_height", m[1])
	)
	row.add_child(opt)
	box.add_child(row)


func _add_graphics_quality(box: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = "Graphics quality"
	lbl.custom_minimum_size = Vector2(180, 0)
	row.add_child(lbl)

	var opt := OptionButton.new()
	var current := 0
	for i in GameState.GRAPHICS_QUALITY_ORDER.size():
		var quality: String = GameState.GRAPHICS_QUALITY_ORDER[i]
		opt.add_item(str(GameState.GRAPHICS_QUALITY_LABELS[quality]), i)
		if quality == GameState.get_graphics_quality():
			current = i
	opt.select(current)
	opt.item_selected.connect(
		func(idx: int) -> void:
			GameState.set_graphics_quality(GameState.GRAPHICS_QUALITY_ORDER[idx])
			_sync_msaa_option()
	)
	row.add_child(opt)
	box.add_child(row)


func _add_msaa(box: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = "Anti-aliasing (MSAA)"
	lbl.custom_minimum_size = Vector2(180, 0)
	row.add_child(lbl)

	var opt := OptionButton.new()
	_msaa_option = opt
	opt.add_item("Off", 0)
	opt.add_item("2x", 1)
	opt.add_item("4x", 2)
	var msaa_level: int = int(GameState.get_setting("msaa"))
	opt.select(1 if msaa_level == 2 else (2 if msaa_level == 4 else 0))
	opt.item_selected.connect(
		func(idx: int) -> void:
			var level := 0
			if idx == 1:
				level = 2
			elif idx == 2:
				level = 4
			GameState.set_setting("msaa", level)
	)
	row.add_child(opt)
	box.add_child(row)


func _sync_msaa_option() -> void:
	if _msaa_option == null:
		return
	var level := int(GameState.get_setting("msaa"))
	_msaa_option.select(1 if level == 2 else (2 if level == 4 else 0))


func _add_keybind_row(box: VBoxContainer, action: String, title_text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var lbl := Label.new()
	lbl.text = title_text
	lbl.custom_minimum_size = Vector2(180, 0)
	row.add_child(lbl)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(220, 30)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	btn.text = _key_text(action)
	btn.pressed.connect(func() -> void: _start_rebind(action, btn))
	_rebind_buttons[action] = btn
	row.add_child(btn)
	box.add_child(row)


func _key_text(action: String) -> String:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return ev.as_text_physical_keycode()
	return "Unbound"


func _start_rebind(action: String, btn: Button) -> void:
	_click()
	_awaiting_action = action
	_awaiting_button = btn
	btn.text = "Press a key..."


func _on_reset_controls() -> void:
	_click()
	GameState.reset_keybinds()
	for action in _rebind_buttons.keys():
		(_rebind_buttons[action] as Button).text = _key_text(str(action))
