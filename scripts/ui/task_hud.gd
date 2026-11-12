extends Control
# Task HUD attached to the TaskLabel control in Player.tscn.
# Draws the objectives itself so the strike-through can use its own dark,
# fully opaque colour (RichTextLabel always draws [s] in the text colour,
# which is invisible over white glyphs).
#
#   OBJECTIVES
#   • Collect fuses (0/3)
#   • Restore electricity       <- appears once all 3 fuses are collected
#
# Completed tasks are struck through with STRIKE_COLOR.

const HEADER_SIZE := 12
const FONT_SIZE := 17
const LINE_SPACING := 5.0
const TEXT_COLOR := Color(1, 1, 1, 1)
const HEADER_COLOR := Color(0.64, 0.33, 0.31, 1)
const OUTLINE_COLOR := Color(0, 0, 0, 1)
const OUTLINE_SIZE := 4
# Very dark, completely opaque: clearly visible over the white letters.
const STRIKE_COLOR := Color(0.012, 0.012, 0.016, 1.0)
const STRIKE_WIDTH := 3.0
const PAD := Vector2(14.0, 10.0)

# Public snapshot of what is on screen (handy for debugging / tests).
var lines: Array[Dictionary] = []

var _panel_style := StyleBoxFlat.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_panel_style.bg_color = Color(0.018, 0.018, 0.026, 0.58)
	_panel_style.border_width_left = 2
	_panel_style.border_color = Color(0.58, 0.14, 0.14, 0.85)
	_panel_style.set_corner_radius_all(8)
	_panel_style.shadow_color = Color(0, 0, 0, 0.35)
	_panel_style.shadow_size = 10

	GameState.fuzes_changed.connect(_on_fuzes_changed)
	GameState.electricity_restored.connect(_refresh)
	_refresh()
	# Hidden by default; the basement Area3D reveals it.


func _on_fuzes_changed(_count: int) -> void:
	_refresh()


func _refresh() -> void:
	var fuzes: int = GameState.get_fuzes()
	var done_fuses: bool = fuzes >= GameState.MAX_FUZES

	lines = [{
		"text": "Collect fuses (%d/%d)" % [fuzes, GameState.MAX_FUZES],
		"done": done_fuses,
	}]
	if done_fuses:
		lines.append({
			"text": "Restore electricity",
			"done": GameState.electricity_on,
		})

	# Grow/shrink the panel to the number of visible objectives.
	var font: Font = get_theme_default_font()
	var head_h := font.get_ascent(HEADER_SIZE) + 7.0 + 10.0
	var item_h := font.get_height(FONT_SIZE) + LINE_SPACING
	var needed := PAD.y + head_h + font.get_ascent(FONT_SIZE) + (lines.size() - 1) * item_h
	needed += font.get_height(FONT_SIZE) + PAD.y
	size.y = maxf(needed, 60.0)

	queue_redraw()


func _draw() -> void:
	draw_style_box(_panel_style, Rect2(Vector2.ZERO, size))

	var font: Font = get_theme_default_font()

	# Header + hairline rule.
	var header_y: float = PAD.y + font.get_ascent(HEADER_SIZE)
	draw_string(
		font, Vector2(PAD.x, header_y), "OBJECTIVES",
		HORIZONTAL_ALIGNMENT_LEFT, -1, HEADER_SIZE, HEADER_COLOR
	)
	var rule_y: float = header_y + 7.0
	draw_line(
		Vector2(PAD.x, rule_y),
		Vector2(size.x - PAD.x, rule_y),
		Color(0.58, 0.14, 0.14, 0.32), 1.0, true
	)

	var ascent: float = font.get_ascent(FONT_SIZE)
	var line_h: float = font.get_height(FONT_SIZE) + LINE_SPACING
	var y: float = rule_y + 10.0 + ascent

	for line: Dictionary in lines:
		var bullet := "• "
		var full_text: String = bullet + str(line["text"])
		_draw_text(font, Vector2(PAD.x, y), full_text)

		if line["done"]:
			var bullet_w: float = font.get_string_size(
				bullet, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE
			).x
			var text_w: float = font.get_string_size(
				full_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE
			).x
			# Sit the line through the middle of the lower-case letters.
			var strike_y: float = y - ascent * 0.42
			draw_line(
				Vector2(PAD.x + bullet_w, strike_y),
				Vector2(PAD.x + text_w + 2.0, strike_y),
				STRIKE_COLOR,
				STRIKE_WIDTH,
				true
			)
		y += line_h


func _draw_text(font: Font, pos: Vector2, value: String) -> void:
	draw_string_outline(
		font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1,
		FONT_SIZE, OUTLINE_SIZE, OUTLINE_COLOR
	)
	draw_string(
		font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1,
		FONT_SIZE, TEXT_COLOR
	)
