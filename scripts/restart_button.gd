# Some usage of AI occured in the script
class_name RestartButton
extends McButton
## "Restart": not set up yet.
var save_script = preload("res://scripts/save_manager.gd")
const GAME_SCENE := "res://main/game/game.tscn"

var _starting := false


func _on_pressed() -> void:
	if _starting:
		return
	if not ResourceLoader.exists(GAME_SCENE):
		message.emit("Game scene not found: " + GAME_SCENE)
		return
	_starting = true
	GameSounds.play_retry()   # keeps playing after the scene change (it lives on the scene root)
	save_script.new().delete_save()
	var layer := CanvasLayer.new()
	layer.layer = 100
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(fade)
	add_child(layer)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.5)
	tw.tween_callback(func(): get_tree().change_scene_to_file(GAME_SCENE))
