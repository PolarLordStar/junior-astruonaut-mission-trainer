class_name HowToPlayButton
extends McButton
## "How to play": opens the instructions screen (how_to_play_menu.gd), which can be closed again.


func _on_pressed() -> void:
	if get_tree().get_first_node_in_group("how_to_play_menu") != null:
		return   # already open
	get_tree().current_scene.add_child(HowToPlayMenu.new())
