extends CanvasLayer
## "YOU DIED" screen. It is a copy of the day transition screen ("You have survived!"), with
## Restart instead of Continue.
##
## It only READS the Health node (Game/Health, health.gd). It never changes the Health number.
## Every frame it checks that number, and the moment Health reaches 0:
##   1. the death sound plays: GameSounds.play_death()
##   2. the game pauses (day timer, events and damage all stop, and the room hum goes quiet)
##   3. the screen fades in: "YOU DIED", then the two buttons
##
##   Restart              -> same as the pause menu's Restart (control_room.gd _on_restart()):
##                           retry sound, delete the save, fade to black, load a new game (day 1).
##   Return to Main Menu  -> same as the day transition's (game.gd _on_transition_main_menu()):
##                           fade to black, un-pause, load the main menu.
## This script does everything itself, so game.gd does not need to know about it.
##
## All the nodes are in main/game/ui/death_screen.tscn: change the texts, font sizes, colours and
## the darkness of the screen (Dim) there. The buttons use the shared McButton look.
##
## Node tree (death_screen.tscn), the same as day_transition.tscn:
##   DeathScreen (CanvasLayer, keeps running while the game is paused)
##   └ Root
##     ├ Dim (ColorRect, the dark screen; it also blocks clicks on the room behind)
##     └ Center
##       └ Box (VBox): Title, GapTop, PromptLabel, RestartButton, GapBottom, MainMenuButton
##
## In game.tscn this node must be a child of Game, and it should stay LAST in the list (below
## DayTransition). That way it gets the keyboard first, so Esc cannot open the pause menu on top of it.

const GAME_SCENE := "res://main/game/game.tscn"
const MAIN_MENU_SCENE := "res://main_menu.tscn"

## Optional: drop a pixel font here and the texts use it (same file the other menus look for).
const FONT_PATH := "res://fonts/pixel.ttf"

@export var fade_in_time := 0.8    # seconds for the screen to fade in
@export var fade_out_time := 0.5   # seconds to fade to black before Restart / the main menu

@onready var _root: Control = $Root
@onready var _dim: ColorRect = %Dim
@onready var _title: Label = %Title
@onready var _prompt: Label = %PromptLabel
@onready var _restart: Button = %RestartButton
@onready var _menu: Button = %MainMenuButton
@onready var _health = get_node_or_null("../Health")   # Game/Health (this node must be a child of Game)

var _died := false      # true once the player has died (the screen only shows once)
var _leaving := false   # true once a button was pressed (no double clicks)
var _tween: Tween


func _ready() -> void:
	if _health == null:
		push_warning("DeathScreen: Game/Health not found (this node must be a child of Game)")
	if ResourceLoader.exists(FONT_PATH):
		var font := load(FONT_PATH) as Font
		_title.add_theme_font_override("font", font)
		_prompt.add_theme_font_override("font", font)


func _process(_delta: float) -> void:
	if _died or _health == null:
		return
	if _health.Health <= 0:
		_die()


func _die() -> void:
	_died = true
	GameSounds.play_death()
	get_tree().paused = true   # this node keeps running while paused (process mode: Always)
	_set_buttons_disabled(true)   # no accidental click while it is still fading in
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.modulate.a = 0.0
	visible = true
	_tween = create_tween()
	_tween.tween_property(_root, "modulate:a", 1.0, fade_in_time)
	_tween.tween_callback(_enable_buttons)


func _enable_buttons() -> void:
	_set_buttons_disabled(false)
	_restart.grab_focus()   # so Enter / Space also work


func _set_buttons_disabled(value: bool) -> void:
	_restart.disabled = value
	_menu.disabled = value


# While this screen is up, Esc must not open the pause menu on top of it.
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()


# The buttons are wired to these in death_screen.tscn (Node tab > Signals).
func _on_restart_button_pressed() -> void:
	if _leaving:
		return
	_leaving = true
	_set_buttons_disabled(true)
	GameSounds.play_retry()   # keeps playing after the scene change
	var save_script = preload("res://scripts/save_manager.gd").new()
	save_script.delete_save()   # a restart begins again from day 1
	save_script.free()
	_fade_to_black_then(_load_scene.bind(GAME_SCENE))


func _on_main_menu_button_pressed() -> void:
	if _leaving:
		return
	_leaving = true
	_set_buttons_disabled(true)
	_fade_to_black_then(_load_scene.bind(MAIN_MENU_SCENE))


func _fade_to_black_then(next: Callable) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_dim, "color:a", 1.0, fade_out_time)   # the dark screen turns fully black
	_tween.tween_callback(next)


func _load_scene(path: String) -> void:
	get_tree().paused = false   # we paused the game when the player died; undo it first
	get_tree().change_scene_to_file(path)
