extends CanvasLayer
## Transition screen between the end of a day and the start of the next one.
##
## It shows "You have survived!", then "Continue?" with two buttons:
##   Continue             -> emits continue_pressed. game.gd starts the next day with start().
##   Return to Main Menu  -> emits main_menu_pressed. game.gd changes to the main menu scene.
## This script only does the screen itself (fading, buttons). game.gd decides what the buttons do,
## the same way PauseMenu.gd and control_room.gd work together.
##
## HOW TO SHOW IT (game.gd does this in _on_day_end()):
##     $DayTransition.show_transition()         # with the Continue button
##     $DayTransition.show_transition(false)    # last day: only "Return to Main Menu"
##
## All the nodes are in main/game/ui/day_transition.tscn: change the texts, font sizes, colours and
## the darkness of the screen (Dim) there. The buttons use the shared McButton look.
##
## Node tree (day_transition.tscn):
##   DayTransition (CanvasLayer, keeps running while the game is paused)
##   └ Root
##     ├ Dim (ColorRect, the dark screen; it also blocks clicks on the room behind)
##     └ Center
##       └ Box (VBox): Title, GapTop, PromptLabel, ContinueButton, GapBottom, MainMenuButton

signal continue_pressed
signal main_menu_pressed

## Optional: drop a pixel font here and the texts use it (same file the pause menu looks for).
const FONT_PATH := "res://fonts/pixel.ttf"

@export var fade_in_time := 0.8     # seconds for the screen to fade in
@export var fade_out_time := 0.6    # seconds for it to fade away when you press Continue
@export var menu_fade_time := 0.4   # seconds to fade to black before the main menu loads

@onready var _root: Control = $Root
@onready var _dim: ColorRect = %Dim
@onready var _title: Label = %Title
@onready var _prompt: Label = %PromptLabel
@onready var _continue: Button = %ContinueButton
@onready var _menu: Button = %MainMenuButton

var _tween: Tween
var _dim_alpha := 0.94   # read from the scene in _ready()


func _ready() -> void:
	_dim_alpha = _dim.color.a
	if ResourceLoader.exists(FONT_PATH):
		var font := load(FONT_PATH) as Font
		_title.add_theme_font_override("font", font)
		_prompt.add_theme_font_override("font", font)


## Fades the screen in. can_continue = false hides "Continue?" and the Continue button (last day).
func show_transition(can_continue: bool = true) -> void:
	_kill_tween()
	_prompt.visible = can_continue
	_continue.visible = can_continue
	_set_buttons_disabled(true)   # no accidental click while it is still fading in
	_dim.color.a = _dim_alpha
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.modulate.a = 0.0
	visible = true
	_tween = create_tween()
	_tween.tween_property(_root, "modulate:a", 1.0, fade_in_time)
	_tween.tween_callback(_enable_buttons)


func _enable_buttons() -> void:
	_set_buttons_disabled(false)
	if _continue.visible:
		_continue.grab_focus()   # so Enter / Space also work
	else:
		_menu.grab_focus()


func _set_buttons_disabled(value: bool) -> void:
	_continue.disabled = value
	_menu.disabled = value


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()


# While this screen is up, Esc must not open the pause menu on top of it.
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()


# The buttons are wired to these in day_transition.tscn (Node tab > Signals).
func _on_continue_button_pressed() -> void:
	_set_buttons_disabled(true)
	continue_pressed.emit()   # game.gd starts the new day...
	_kill_tween()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE   # ...and the room can be clicked while this fades away
	_tween = create_tween()
	_tween.tween_property(_root, "modulate:a", 0.0, fade_out_time)
	_tween.tween_callback(func(): visible = false)


func _on_main_menu_button_pressed() -> void:
	_set_buttons_disabled(true)
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_dim, "color:a", 1.0, menu_fade_time)   # fade to black first
	_tween.tween_callback(main_menu_pressed.emit)
