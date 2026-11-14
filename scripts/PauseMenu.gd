class_name PauseMenu
extends CanvasLayer
## Minecraft-style pause menu. Esc opens and closes it and pauses the game.
## Continue closes it. Restart, Options and Return to Main Menu only send a signal,
## so control_room.gd decides what each one does.

signal restart_pressed
signal options_pressed
signal main_menu_pressed

## Optional: drop a pixel font (a Minecraft-like .ttf) here and the menu uses it.
const FONT_PATH := "res://fonts/pixel.ttf"
const PX := 3                          # screen pixels per "block pixel" in the button art
const BTN_SIZE := Vector2(460, 56)

var _font: Font
var _sb_normal: StyleBoxTexture
var _sb_hover: StyleBoxTexture
var _first: Button
var _toast: Label
var _toast_tween: Tween


func _init() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS   # keeps working while the game is paused
	visible = false


func _ready() -> void:
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH) as Font
	_sb_normal = _mc_style(Color("6f6f6f"), Color("a6a6a6"), Color("3b3b3b"))
	_sb_hover = _mc_style(Color("6b76b8"), Color("a4abe0"), Color("373b70"))

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(root)

	var dim := ColorRect.new()                 # darkens the game and blocks clicks behind the menu
	dim.color = Color(0.02, 0.02, 0.08, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	var title := Label.new()
	title.text = "Game Menu"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_text(title, 38)
	box.add_child(title)
	_gap(box, 16)

	_first = _button(box, "Continue", close)
	_button(box, "Restart", func(): restart_pressed.emit())
	_button(box, "Options", func(): options_pressed.emit())
	_gap(box, 12)
	_button(box, "Return to Main Menu", func(): main_menu_pressed.emit())

	_toast = Label.new()
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.custom_minimum_size = Vector2(0, 34)
	_toast.modulate.a = 0.0
	_style_text(_toast, 20)
	_toast.add_theme_color_override("font_color", Color("ffffa0"))
	box.add_child(_toast)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):   # Esc
		toggle()
		get_viewport().set_input_as_handled()


func open() -> void:
	if visible:
		return
	visible = true
	get_tree().paused = true
	_first.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false


func toggle() -> void:
	if visible:
		close()
	else:
		open()


## Short message under the buttons that fades out by itself.
func toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.4)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)


# ---------- building blocks ----------
func _gap(parent: Control, h: float) -> void:
	var g := Control.new()
	g.custom_minimum_size = Vector2(0, h)
	parent.add_child(g)


func _style_text(c: Control, size: int) -> void:
	c.add_theme_font_size_override("font_size", size)
	c.add_theme_color_override("font_outline_color", Color("2b2b2b"))
	c.add_theme_constant_override("outline_size", 3)
	if _font != null:
		c.add_theme_font_override("font", _font)


func _button(parent: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = BTN_SIZE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal", _sb_normal)
	b.add_theme_stylebox_override("hover", _sb_hover)
	b.add_theme_stylebox_override("pressed", _sb_hover)
	b.add_theme_stylebox_override("focus", _sb_hover)   # keyboard focus looks like hover
	b.add_theme_color_override("font_color", Color("e0e0e0"))
	b.add_theme_color_override("font_hover_color", Color("ffffa0"))
	b.add_theme_color_override("font_focus_color", Color("ffffa0"))
	b.add_theme_color_override("font_pressed_color", Color("ffffa0"))
	_style_text(b, 26)
	b.pressed.connect(action)
	b.mouse_entered.connect(b.grab_focus)               # highlight follows the mouse
	parent.add_child(b)
	return b


## Builds the chunky button art in code: black outline, light top-left edge,
## dark bottom-right edge. Used as a 9-patch so it stretches to any button size.
func _mc_style(base: Color, light: Color, dark: Color) -> StyleBoxTexture:
	const N := 10
	var img := Image.create_empty(N * PX, N * PX, false, Image.FORMAT_RGBA8)
	for y in N:
		for x in N:
			var c := base
			if x == 0 or y == 0 or x == N - 1 or y == N - 1:
				c = Color.BLACK
			elif y >= N - 3 or x == N - 2:
				c = dark
			elif x == 1 or y == 1:
				c = light
			img.fill_rect(Rect2i(x * PX, y * PX, PX, PX), c)
	var sb := StyleBoxTexture.new()
	sb.texture = ImageTexture.create_from_image(img)
	sb.texture_margin_left = 2 * PX
	sb.texture_margin_right = 2 * PX
	sb.texture_margin_top = 2 * PX
	sb.texture_margin_bottom = 3 * PX
	return sb
