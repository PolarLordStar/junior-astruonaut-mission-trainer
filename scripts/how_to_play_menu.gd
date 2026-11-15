class_name HowToPlayMenu
extends CanvasLayer
## The "How to play" screen opened from the main menu.
## Close it with the Close button or the Esc key. Long text scrolls with the mouse wheel.
##
## The screen is built in code (see _build), so there is no scene to set up.


# =====================================================================================
#   WRITE YOUR INSTRUCTIONS HERE
#
#   Each { ... } block below is one section: a "title" (shown as a heading) and its "text".
#     - To add a section, copy a whole { ... }, block and paste it under the last one.
#     - To remove a section, delete its { ... }, block.
#     - Inside "text" you can press Enter for a new line (keep the text between the """ marks).
#     - Optional formatting inside the text:  [b]bold[/b]   [color=#ff8844]coloured[/color]
# =====================================================================================
const TITLE := "HOW TO PLAY"

const SECTIONS := [
	{
		"title": "Your mission",
		"text": """You must survive for a set number of days (Configureable in Options) by dealing with hazards while carefully maintaing resources.""",
	},
	{
		"title": "Controls",
		"text": """You may move your camera around with the mouse and use left click to interact with the buttons.""",
	},
	{
		"title": "The monitors",
		"text": """The left monitor displays your current resources, the central monitor shows hazards and the right monitor shows danger warnings and incoming events.""",
	},
	{
		"title": "Dangers and events",
		"text": """Danger and events are displayed on the right monitor along with the time until they active or if they are active then how much time it is left for them to pass. The severity is also shown which reflects how the hazards like radiation are effected.""",
	},
]

# ---- look (change these if you like) ----
const FONT_PATH := "res://fonts/pixel.ttf"   # optional pixel font, same as the other menus
const PANEL_SIZE := Vector2(960, 700)
const TEXT_AREA_HEIGHT := 440
const TITLE_COLOR := Color(1, 0.9176, 0.6275)   # same cream as the game title
const HEADING_COLOR := "#ffeaa0"
const BODY_COLOR := Color("e0e0e0")
const HEADING_SIZE := 32
const BODY_SIZE := 26

var _font: Font


func _ready() -> void:
	layer = 100
	add_to_group("how_to_play_menu")
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH) as Font
	_build()


# _input (not _unhandled_input) so Esc closes this screen BEFORE the Exit button can see it
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):   # Esc
		close_menu()
		get_viewport().set_input_as_handled()


func close_menu() -> void:
	queue_free()


# ---------- building the screen ----------
func _build() -> void:
	var root := Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Darkens the menu behind and blocks clicks on it
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.08, 0.7)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = PANEL_SIZE
	panel.add_theme_stylebox_override("panel", _box_style(Color("4a4a4a"), Color.BLACK, 4, 34))
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	panel.add_child(box)

	var title := Label.new()
	title.text = TITLE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(title, 44, TITLE_COLOR)
	box.add_child(title)

	# The instructions sit in a darker inset box that scrolls when the text is long
	var inset := PanelContainer.new()
	inset.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inset.add_theme_stylebox_override("panel", _box_style(Color("2f2f2f"), Color("1e1e1e"), 3, 22))
	box.add_child(inset)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, TEXT_AREA_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inset.add_child(scroll)

	var margin := MarginContainer.new()   # keeps the text clear of the scrollbar
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_right", 20)
	scroll.add_child(margin)

	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.selection_enabled = false
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("normal_font_size", BODY_SIZE)
	text.add_theme_font_size_override("bold_font_size", BODY_SIZE)
	text.add_theme_color_override("default_color", BODY_COLOR)
	if _font != null:
		text.add_theme_font_override("normal_font", _font)
		text.add_theme_font_override("bold_font", _font)
	text.text = _make_text()
	margin.add_child(text)

	# Close button (same look as the main-menu buttons)
	var close_button := McButton.new()
	close_button.text = "Close"
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(close_menu)
	box.add_child(close_button)
	close_button.grab_focus.call_deferred()


# Turns SECTIONS (at the top of this file) into one block of formatted text
func _make_text() -> String:
	var out := ""
	for section in SECTIONS:
		out += "[font_size=%d][color=%s][b]%s[/b][/color][/font_size]\n" % [HEADING_SIZE, HEADING_COLOR, section["title"]]
		out += str(section["text"]) + "\n\n"
	return out.strip_edges()


func _style_label(label: Label, font_size: int, color: Color) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("2b2b2b"))
	label.add_theme_constant_override("outline_size", 4)
	if _font != null:
		label.add_theme_font_override("font", _font)


func _box_style(fill: Color, border: Color, border_width: int, margin: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_content_margin_all(margin)
	return sb
