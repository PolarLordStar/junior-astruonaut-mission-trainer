class_name OptionsMenu
extends CanvasLayer
## The Options screen opened by the main-menu Options button.
## Close it with the Close button or the Esc key.
##
## It changes the variables in game_settings.gd:
##     Max days      -> PresetValues.MAX_DAYS (in preset_values.gd)
##     Common sound  -> GameSettings.common_sound
##
## Everything is built in code (see _build), so there is no scene to set up.

const FONT_PATH := "res://fonts/pixel.ttf"   # optional pixel font, same as the other menus
const MIN_DAYS := 1
const MAX_DAYS_LIMIT := 30

var _font: Font
var _sound_value: Label


func _ready() -> void:
	layer = 100
	add_to_group("options_menu")
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH) as Font
	_build()


func _unhandled_input(event: InputEvent) -> void:
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
	dim.color = Color(0.02, 0.02, 0.08, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 0)
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	panel.add_child(box)

	var title := _label("OPTIONS", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	# Max days
	var days_row := _row("Max days")
	var spin := SpinBox.new()
	spin.min_value = MIN_DAYS
	spin.max_value = MAX_DAYS_LIMIT
	spin.step = 1
	spin.value = PresetValues.MAX_DAYS
	spin.custom_minimum_size = Vector2(170, 40)
	spin.value_changed.connect(_on_max_days_changed)
	days_row.add_child(spin)
	box.add_child(days_row)

	# Common sound
	var sound_row := _row("Common sound")
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = GameSettings.common_sound
	slider.custom_minimum_size = Vector2(220, 40)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(_on_sound_changed)
	sound_row.add_child(slider)
	_sound_value = _label(str(GameSettings.common_sound))
	_sound_value.custom_minimum_size = Vector2(56, 0)
	_sound_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sound_row.add_child(_sound_value)
	box.add_child(sound_row)

	# Close button (same look as the main-menu buttons)
	var close_button := McButton.new()
	close_button.text = "Close"
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(close_menu)
	box.add_child(close_button)
	close_button.grab_focus.call_deferred()


func _row(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var label := _label(text)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return row


func _label(text: String, font_size: int = 26) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("e0e0e0"))
	label.add_theme_color_override("font_outline_color", Color("2b2b2b"))
	label.add_theme_constant_override("outline_size", 3)
	if _font != null:
		label.add_theme_font_override("font", _font)
	return label


func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("4a4a4a")
	sb.border_color = Color.BLACK
	sb.set_border_width_all(4)
	sb.set_content_margin_all(34)
	return sb


# ---------- changing the settings ----------
func _on_max_days_changed(value: float) -> void:
	PresetValues.MAX_DAYS = int(value)
	print("MAX_DAYS is now ", PresetValues.MAX_DAYS)


func _on_sound_changed(value: float) -> void:
	GameSettings.common_sound = int(value)
	_sound_value.text = str(int(value))
