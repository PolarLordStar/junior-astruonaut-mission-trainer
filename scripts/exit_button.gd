# Some usage of AI occured in the script
class_name ExitButton
extends McButton
## "Exit": closes the game, either by clicking the button or by pressing Esc.


func _on_pressed() -> void:
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):   # Esc
		get_tree().quit()
