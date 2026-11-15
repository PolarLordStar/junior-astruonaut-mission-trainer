# Some usage of AI occured in the script
class_name McButton
extends Button
## Shared look for the four main-menu buttons (same blocky style as pause_menu.gd).
## Continue / Restart / Options / Exit each extend this and only add what happens on click.
## Override _on_pressed() in the child script. Call message.emit("text") to show the little
## message under the buttons (the MainMenu script displays it).

signal message(text: String)

const FONT_PATH := "res://fonts/pixel.ttf"   # optional pixel font, same as the pause menu
const PX := 3
const BTN_SIZE := Vector2(460, 56)

static var _sb_normal: StyleBoxTexture
static var _sb_hover: StyleBoxTexture


func _ready() -> void:
	custom_minimum_size = BTN_SIZE
	size = BTN_SIZE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if _sb_normal == null:
		_sb_normal = _mc_style(Color("6f6f6f"), Color("a6a6a6"), Color("3b3b3b"))
		_sb_hover = _mc_style(Color("6b76b8"), Color("a4abe0"), Color("373b70"))
	add_theme_stylebox_override("normal", _sb_normal)
	add_theme_stylebox_override("hover", _sb_hover)
	add_theme_stylebox_override("pressed", _sb_hover)
	add_theme_stylebox_override("focus", _sb_hover)   # keyboard focus looks like hover
	add_theme_color_override("font_color", Color("e0e0e0"))
	add_theme_color_override("font_hover_color", Color("ffffa0"))
	add_theme_color_override("font_focus_color", Color("ffffa0"))
	add_theme_color_override("font_pressed_color", Color("ffffa0"))
	add_theme_font_size_override("font_size", 26)
	add_theme_color_override("font_outline_color", Color("2b2b2b"))
	add_theme_constant_override("outline_size", 3)
	if ResourceLoader.exists(FONT_PATH):
		add_theme_font_override("font", load(FONT_PATH) as Font)
	pressed.connect(GameSounds.play_click)   # click sound for every menu button
	pressed.connect(_on_pressed)
	mouse_entered.connect(grab_focus)   # highlight follows the mouse


## Override in the child script.
func _on_pressed() -> void:
	pass


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
