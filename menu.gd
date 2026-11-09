extends Control
# Main menu: NEW GAME / LOAD SAVED GAME / SETTINGS / QUIT.
# Settings are built in code so adding options never breaks the scene file.

const WORLD_SCENE := "res://World.tscn"
const MENU_BG_SHADER := "res://menu_background.gdshader"

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

@onready var status: Label = $Status
@onready var click_player: AudioStreamPlayer = $ClickPlayer
@onready var menu_box: VBoxContainer = $Menu

# ---- settings window placement ---------------------------------------------
# Select "MainMenu" in menu.tscn and edit these in the Inspector, or change
# the defaults here.
@export_group("Settings Window")
## Size of the settings window in pixels.
@export var settings_panel_size := Vector2(700, 660)
## Offset from the centre of the screen: +X moves right, +Y moves down.
## (0, 0) = perfectly centred.
@export var settings_panel_offset := Vector2.ZERO


var settings_root: Control = null
var settings_panel: PanelContainer = null
var rebind_buttons: Dictionary = {}
var awaiting_action := ""
var awaiting_button: Button = null


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	status.text = ""
	_style_background()
	$Menu/NewGame.pressed.connect(_on_new_game)
	$Menu/LoadGame.pressed.connect(_on_load_game)
	$Menu/Settings.pressed.connect(_open_settings)
	$Menu/Quit.pressed.connect(_on_quit)


func _style_background() -> void:
	var bg := $Background as ColorRect
	if bg == null:
		return
	var shader := load(MENU_BG_SHADER) as Shader
	if shader == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = shader
	bg.material = mat


func _click() -> void:
	if click_player and click_player.stream:
		click_player.play()


# ------------------------------------------------------------------- actions

func _on_new_game() -> void:
	_click()
	GameState.start_new_game()
	_start_world()


func _on_load_game() -> void:
	_click()
	if not GameState.has_save():
		status.text = "No saved game found."
		return
	var data: Dictionary = GameState.read_save()
	if data.is_empty():
		status.text = "The save file could not be read."
		return
	GameState.start_loaded_game(data)
	_start_world()


func _start_world() -> void:
	var err := get_tree().change_scene_to_file(WORLD_SCENE)
	if err != OK:
		status.text = "Failed to load the world (error %d)." % err


func _on_quit() -> void:
	_click()
	get_tree().quit()


# ------------------------------------------------------------------ settings

func _open_settings() -> void:
	_click()
	if settings_root == null:
		_build_settings()
	settings_root.visible = true


func _build_settings() -> void:
	settings_root = Control.new()
	settings_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(settings_root)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_root.add_child(dim)

	settings_panel = PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.012, 0.018, 0.017, 0.985)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.22, 0.31, 0.28, 0.48)
	panel_style.set_corner_radius_all(4)
	panel_style.set_content_margin_all(20)
	settings_panel.add_theme_stylebox_override("panel", panel_style)
	# Clamp to the window so the window can never spill off-screen.
	var vp_size: Vector2 = get_viewport_rect().size
	settings_panel.custom_minimum_size = Vector2(
		minf(settings_panel_size.x, vp_size.x * 0.92),
		minf(settings_panel_size.y, vp_size.y * 0.92)
	)

	# A CenterContainer keeps the window centred at any resolution; the
	# exported offset above nudges it around the screen.
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_left = settings_panel_offset.x
	center.offset_right = settings_panel_offset.x
	center.offset_top = settings_panel_offset.y
	center.offset_bottom = settings_panel_offset.y
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	settings_root.add_child(center)
	center.add_child(settings_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	settings_panel.add_child(outer)

	var heading := Label.new()
	heading.text = "SETTINGS"
	heading.add_theme_font_size_override("font_size", 26)
	heading.add_theme_color_override("font_color", Color(0.78, 0.85, 0.81))
	outer.add_child(heading)

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
	back.pressed.connect(func() -> void:
		_click()
		settings_root.visible = false
	)
	outer.add_child(back)


func _add_section(box: VBoxContainer, title: String) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	box.add_child(spacer)
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.66, 0.19, 0.14))
	box.add_child(lbl)


func _value_text(value: float, is_float: bool) -> String:
	if is_float:
		return "%.1f" % value
	return "%d%%" % int(round(value * 100.0))


func _add_slider(box: VBoxContainer, title: String, key: String, min_v: float, max_v: float, step: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var lbl := Label.new()
	lbl.text = title
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

	slider.value_changed.connect(func(v: float) -> void:
		val.text = _value_text(v, key == "mouse_sensitivity" or key == "fov")
		GameState.set_setting(key, v)
	)
	box.add_child(row)


func _add_check(box: VBoxContainer, title: String, key: String) -> void:
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = title
	lbl.custom_minimum_size = Vector2(180, 0)
	row.add_child(lbl)
	var check := CheckButton.new()
	check.button_pressed = bool(GameState.get_setting(key))
	check.toggled.connect(func(on: bool) -> void:
		GameState.set_setting(key, on)
	)
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
		[1280, 720], [1600, 900], [1920, 1080], [2560, 1440], [3840, 2160],
	]
	var current := 0
	for i in modes.size():
		var m: Array = modes[i]
		opt.add_item("%d x %d" % [m[0], m[1]], i)
		if int(GameState.get_setting("window_width")) == m[0] and int(GameState.get_setting("window_height")) == m[1]:
			current = i
	opt.select(current)
	opt.item_selected.connect(func(idx: int) -> void:
		var m: Array = modes[idx]
		GameState.set_setting("window_width", m[0])
		GameState.set_setting("window_height", m[1])
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
	opt.add_item("Off", 0)
	opt.add_item("2x", 1)
	opt.add_item("4x", 2)
	var current: int = int(GameState.get_setting("msaa"))
	opt.select(current)
	opt.item_selected.connect(func(idx: int) -> void:
		var level := 0
		if idx == 1:
			level = 2
		elif idx == 2:
			level = 4
		GameState.set_setting("msaa", level)
	)
	row.add_child(opt)
	box.add_child(row)


func _add_keybind_row(box: VBoxContainer, action: String, title: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var lbl := Label.new()
	lbl.text = title
	lbl.custom_minimum_size = Vector2(180, 0)
	row.add_child(lbl)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(220, 30)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	btn.text = _key_text(action)
	btn.pressed.connect(func() -> void:
		_start_rebind(action, btn)
	)
	rebind_buttons[action] = btn
	row.add_child(btn)
	box.add_child(row)


func _key_text(action: String) -> String:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return ev.as_text_physical_keycode()
	return "Unbound"


func _start_rebind(action: String, btn: Button) -> void:
	awaiting_action = action
	awaiting_button = btn
	btn.text = "Press a key..."


func _unhandled_input(event: InputEvent) -> void:
	if awaiting_action == "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			awaiting_button.text = _key_text(awaiting_action)
		else:
			GameState.rebind_key(awaiting_action, event.physical_keycode)
			awaiting_button.text = _key_text(awaiting_action)
		awaiting_action = ""
		awaiting_button = null
		get_viewport().set_input_as_handled()


func _on_reset_controls() -> void:
	_click()
	GameState.reset_keybinds()
	for action in rebind_buttons.keys():
		(rebind_buttons[action] as Button).text = _key_text(str(action))
