extends Control
# Main menu: NEW GAME / LOAD SAVED GAME / SETTINGS / QUIT.
# Settings are built in code so adding options never breaks the scene file.

const WORLD_SCENE := "res://scenes/world/World.tscn"
const MENU_BG_SHADER := "res://materials/shaders/menu_background.gdshader"
const WORLD_PRELOAD_DELAY := 0.35

const GRAPHICS_HELP := {
	"low":
	"Fastest mode. Fog, practicals and the film grade; expensive effects are thinned for high FPS.",
	"medium":
	"60 FPS target. Blood decals, glow and shadows return; volumetrics and SSAO stay off.",
	"high": "The horror mode. Volumetric fog, SSAO, particles and the full post grade.",
	"very_high": "Showpiece mode. SDFGI, SSR, full fog and the cleanest, most detailed image.",
}

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
@onready var portrait_viewport: SubViewport = $PortraitViewport

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
var background_material: ShaderMaterial = null
var graphics_help: Label = null
var msaa_option: OptionButton = null

# The world is a large scene. Load it on a background thread while the player
# reads the menu, and keep a loading overlay up if they start before it is
# ready. This prevents the "application is not responding" freeze on first
# launch, especially on Windows and on machines without the assets cached.
var _world_scene: PackedScene = null
var _world_loading := false
var _world_load_failed := false
var _world_transition_pending := false
var _loading_overlay: CanvasLayer = null
var _loading_bar: ProgressBar = null
var _loading_label: Label = null
var _loading_pulse := 0.0


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	status.text = ""
	_style_background()
	_sync_portrait_msaa()
	if not GameState.settings_changed.is_connected(_sync_portrait_msaa):
		GameState.settings_changed.connect(_sync_portrait_msaa)
	$Menu/NewGame.pressed.connect(_on_new_game)
	$Menu/LoadGame.pressed.connect(_on_load_game)
	$Menu/Settings.pressed.connect(_open_settings)
	$Menu/Quit.pressed.connect(_on_quit)
	_animate_intro()
	_wire_menu_buttons()
	if menu_box.get_child_count() > 0 and menu_box.get_child(0) is Button:
		(menu_box.get_child(0) as Button).grab_focus()
	call_deferred("_begin_world_preload")


func _process(delta: float) -> void:
	_loading_pulse += delta
	if _loading_overlay != null and _loading_overlay.visible and _loading_label != null:
		var dots := int(_loading_pulse * 3.0) % 4
		_loading_label.text = "ENTERING THE BASEMENT" + "...".substr(0, dots)
	if not _world_loading:
		return
	var progress: Array = []
	var state := ResourceLoader.load_threaded_get_status(WORLD_SCENE, progress)
	if state == ResourceLoader.THREAD_LOAD_LOADED:
		_world_scene = ResourceLoader.load_threaded_get(WORLD_SCENE) as PackedScene
		_world_loading = false
		if _loading_bar != null:
			_loading_bar.value = 100.0
		if _world_scene == null:
			_world_load_failed = true
			_show_load_error("The world loaded without a usable scene.")
		elif _world_transition_pending:
			_enter_world()
	elif state == ResourceLoader.THREAD_LOAD_FAILED:
		_world_loading = false
		_world_load_failed = true
		_show_load_error("The basement could not be loaded.")
	elif state == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_world_loading = false
		_world_load_failed = true
		_show_load_error("The basement scene is missing.")
	elif _loading_bar != null and progress.size() > 0:
		_loading_bar.value = clampf(float(progress[0]) * 100.0, 0.0, 100.0)


func _begin_world_preload() -> void:
	if _world_scene != null or _world_loading or _world_load_failed:
		return
	# Let the menu render its first frame before starting the disk/import work.
	await get_tree().create_timer(WORLD_PRELOAD_DELAY, false).timeout
	if not is_inside_tree() or _world_scene != null or _world_loading:
		return
	var err := ResourceLoader.load_threaded_request(WORLD_SCENE, "PackedScene", true)
	if err != OK:
		_world_load_failed = true
		status.text = "Failed to prepare the world (error %d)." % err
		return
	_world_loading = true


func _style_background() -> void:
	var bg := $Background as ColorRect
	if bg == null:
		return
	var shader := load(MENU_BG_SHADER) as Shader
	if shader == null:
		return
	background_material = ShaderMaterial.new()
	background_material.shader = shader
	if portrait_viewport != null:
		background_material.set_shader_parameter("portrait", portrait_viewport.get_texture())
		background_material.set_shader_parameter("image_size", Vector2(portrait_viewport.size))
	bg.material = background_material
	bg.color = Color.WHITE
	_update_background_size()
	get_viewport().size_changed.connect(_update_background_size)


func _update_background_size() -> void:
	if background_material == null:
		return
	var size := get_viewport_rect().size
	background_material.set_shader_parameter(
		"screen_size", Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0))
	)
	if portrait_viewport != null:
		background_material.set_shader_parameter("image_size", Vector2(portrait_viewport.size))


func _sync_portrait_msaa() -> void:
	if portrait_viewport == null:
		return
	# The menu portrait renders at 720p as a background; MSAA there only adds
	# cost without a visible benefit once the finished image is upscaled.
	portrait_viewport.msaa_3d = Viewport.MSAA_DISABLED


func _animate_intro() -> void:
	var title := $Title as Control
	var subtitle := $Subtitle as Control
	var status := $Status as Control
	var hint := get_node_or_null("Hint") as Control
	var elements: Array[Control] = [title, subtitle, menu_box, status, hint]
	for element in elements:
		if element != null:
			element.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	if title != null:
		tween.tween_property(title, "modulate:a", 1.0, 0.75).set_delay(0.08)
	if subtitle != null:
		tween.tween_property(subtitle, "modulate:a", 1.0, 0.75).set_delay(0.24)
	if menu_box != null:
		tween.tween_property(menu_box, "modulate:a", 1.0, 0.8).set_delay(0.42)
	if status != null:
		tween.tween_property(status, "modulate:a", 1.0, 0.8).set_delay(0.58)
	if hint != null:
		tween.tween_property(hint, "modulate:a", 1.0, 0.8).set_delay(0.70)
	for i in menu_box.get_child_count():
		var button := menu_box.get_child(i) as Button
		if button == null:
			continue
		button.modulate.a = 0.0
		var bt := create_tween()
		bt.tween_property(button, "modulate:a", 1.0, 0.6).set_delay(0.42 + float(i) * 0.10)


func _wire_menu_buttons() -> void:
	for child in menu_box.get_children():
		var button := child as Button
		if button == null:
			continue
		button.pivot_offset = button.size * 0.5
		button.mouse_entered.connect(_on_menu_button_hover.bind(button, true))
		button.mouse_exited.connect(_on_menu_button_hover.bind(button, false))


func _on_menu_button_hover(button: Button, entered: bool) -> void:
	if not is_instance_valid(button):
		return
	var tween := create_tween()
	(
		tween
		. tween_property(button, "scale", Vector2(1.018, 1.018) if entered else Vector2.ONE, 0.16)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)


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
	_world_transition_pending = true
	if _world_scene != null and not _world_load_failed:
		_enter_world()
		return
	_show_loading_overlay()
	if _world_load_failed:
		_show_load_error("The basement could not be loaded.")
		return
	if not _world_loading:
		_begin_world_preload()


func _enter_world() -> void:
	if _world_scene == null:
		return
	_world_transition_pending = false
	var err := get_tree().change_scene_to_packed(_world_scene)
	if err != OK:
		_show_load_error("Failed to enter the basement (error %d)." % err)


func _show_loading_overlay() -> void:
	if _loading_overlay != null:
		_loading_overlay.visible = true
		return
	_loading_overlay = CanvasLayer.new()
	_loading_overlay.name = "LoadingOverlay"
	_loading_overlay.layer = 100
	add_child(_loading_overlay)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.012, 0.014, 0.013, 0.985)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_loading_overlay.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading_overlay.add_child(center)

	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(620.0, 0.0)
	column.add_theme_constant_override("separation", 18)
	center.add_child(column)

	var title := Label.new()
	title.text = "THE BASEMENT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.66, 0.045, 0.025, 1.0))
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 4)
	column.add_child(title)
	_loading_label = Label.new()
	_loading_label.text = "ENTERING THE BASEMENT"
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.add_theme_font_size_override("font_size", 13)
	_loading_label.add_theme_color_override("font_color", Color(0.58, 0.62, 0.58, 1.0))
	column.add_child(_loading_label)

	_loading_bar = ProgressBar.new()
	_loading_bar.custom_minimum_size = Vector2(620.0, 12.0)
	_loading_bar.show_percentage = false
	_loading_bar.value = 0.0
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.025, 0.028, 0.026, 1.0)
	bar_bg.border_width_left = 1
	bar_bg.border_width_top = 1
	bar_bg.border_width_right = 1
	bar_bg.border_width_bottom = 1
	bar_bg.border_color = Color(0.20, 0.24, 0.21, 0.8)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.53, 0.018, 0.009, 1.0)
	_loading_bar.add_theme_stylebox_override("background", bar_bg)
	_loading_bar.add_theme_stylebox_override("fill", bar_fill)
	column.add_child(_loading_bar)

	var hint := Label.new()
	hint.text = "The dark is still settling. Please do not close the game."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.35, 0.39, 0.35, 1.0))
	column.add_child(hint)


func _show_load_error(message: String) -> void:
	status.text = message
	if _loading_overlay != null:
		_loading_overlay.visible = true
	if _loading_label != null:
		_loading_label.text = message
	if _loading_bar != null:
		_loading_bar.value = 0.0


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
		minf(settings_panel_size.x, vp_size.x * 0.92), minf(settings_panel_size.y, vp_size.y * 0.92)
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
	back.pressed.connect(
		func() -> void:
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


func _add_slider(
	box: VBoxContainer, title: String, key: String, min_v: float, max_v: float, step: float
) -> void:
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

	slider.value_changed.connect(
		func(v: float) -> void:
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
			var quality: String = GameState.GRAPHICS_QUALITY_ORDER[idx]
			GameState.set_graphics_quality(quality)
			if graphics_help != null:
				graphics_help.text = str(GRAPHICS_HELP.get(quality, ""))
			_sync_msaa_option()
	)
	row.add_child(opt)
	box.add_child(row)

	graphics_help = Label.new()
	graphics_help.text = str(GRAPHICS_HELP.get(GameState.get_graphics_quality(), ""))
	graphics_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	graphics_help.add_theme_font_size_override("font_size", 12)
	graphics_help.add_theme_color_override("font_color", Color(0.43, 0.53, 0.49))
	graphics_help.custom_minimum_size = Vector2(0, 34)
	box.add_child(graphics_help)


func _add_msaa(box: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = "Anti-aliasing (MSAA)"
	lbl.custom_minimum_size = Vector2(180, 0)
	row.add_child(lbl)

	var opt := OptionButton.new()
	msaa_option = opt
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
	if msaa_option == null:
		return
	var level := int(GameState.get_setting("msaa"))
	msaa_option.select(1 if level == 2 else (2 if level == 4 else 0))


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
	btn.pressed.connect(func() -> void: _start_rebind(action, btn))
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
