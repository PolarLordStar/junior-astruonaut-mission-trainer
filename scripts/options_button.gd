class_name OptionsButton
extends McButton
## "Options": opens the options screen (options_menu.gd), which can be closed again.


func _on_pressed() -> void:
	if get_tree().get_first_node_in_group("options_menu") != null:
		return   # already open
	get_tree().current_scene.add_child(OptionsMenu.new())
