class_name PauseMenu
extends CanvasLayer
## Minecraft-style pause menu. Esc opens and closes it and pauses the game.
## Continue closes it. Restart, Options and Return to Main Menu only send a signal,
## so control_room.gd decides what each one does.
##
## All the nodes are in room/pause_menu.tscn (the buttons use the shared McButton look).
##
## Node tree (room/pause_menu.tscn):
##   PauseMenu (CanvasLayer)
##   └ Root
##     ├ Dim (ColorRect, darkens the game and blocks clicks behind the menu)
##     └ Center
##       └ Box (VBox): Title, GapTop, ContinueButton, RestartButton, OptionsButton,
##                     GapBottom, MainMenuButton, Toast

signal restart_pressed
signal options_pressed
signal main_menu_pressed

## Optional: drop a pixel font (a Minecraft-like .ttf) here and the menu uses it.
const FONT_PATH := "res://fonts/pixel.ttf"

@onready var _first: Button = %ContinueButton
@onready var _toast: Label = %Toast
@onready var _title: Label = %Title

var _toast_tween: Tween


func _ready() -> void:
	if ResourceLoader.exists(FONT_PATH):
		var font := load(FONT_PATH) as Font
		_title.add_theme_font_override("font", font)
		_toast.add_theme_font_override("font", font)


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


# The buttons are wired to these in pause_menu.tscn (Node tab > Signals).
func _on_restart_button_pressed() -> void:
	restart_pressed.emit()


func _on_options_button_pressed() -> void:
	options_pressed.emit()


func _on_main_menu_button_pressed() -> void:
	main_menu_pressed.emit()
