class_name LoadingScreen
extends CanvasLayer
## Full-screen "LOADING" overlay. Built entirely from code, so there is no scene file to set up.
## game.gd creates one in _ready() and uses it like this:
##     loading_screen.show_loading()        # when start() begins
##     await loading_screen.hide_loading()  # at the end of setup() (fades out, then it is gone)
## It sits above the day counter (layer 10) and the day transition screen (layer 20), blocks
## mouse clicks while it is showing, and keeps working even if the game is paused.

const FADE_TIME := 0.3
const BG_COLOR := Color("000000ff")
const TITLE_COLOR := Color("ffffffff")
const SUB_COLOR := Color("8c94c8")

var _root: Control
var _title: Label
var _tween: Tween
var _dots_timer := 0.0


func _init() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_STOP   # no clicks reach the game underneath
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = BG_COLOR
	_root.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	_root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	_title = Label.new()
	_title.text = "LOADING"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.custom_minimum_size = Vector2(460, 0)
	_title.add_theme_font_size_override("font_size", 56)
	_title.add_theme_color_override("font_color", TITLE_COLOR)
	box.add_child(_title)

	var sub := Label.new()
	sub.text = "Preparing the Day"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 24)
	sub.add_theme_color_override("font_color", SUB_COLOR)
	box.add_child(sub)

	visible = false
	set_process(false)


func _process(delta: float) -> void:
	# "LOADING", "LOADING.", "LOADING..", "LOADING..." (the label has a fixed width, so the box does not jump)
	_dots_timer += delta * 3.0
	_title.text = "LOADING" + ".".repeat(int(_dots_timer) % 4)

# While this screen is up, Esc must not open the pause menu. _input() runs before the pause
# menu's _unhandled_input(), so swallowing the key here means the menu never sees it.
func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()

## Shows the screen straight away (no fade in, so nothing is visible before it).
func show_loading() -> void:
	if _tween != null:
		_tween.kill()
	_root.modulate.a = 1.0
	_dots_timer = 0.0
	visible = true
	set_process(true)


## Fades the screen out and then hides it. Use "await" if you need to wait until it is gone.
func hide_loading() -> void:
	if not visible:
		return
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_root, "modulate:a", 0.0, FADE_TIME)
	await _tween.finished
	visible = false
	set_process(false)
