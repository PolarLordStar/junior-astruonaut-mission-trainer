extends Control
## Main menu. The little message under the buttons is the MessageLabel node in main_menu.tscn.

@onready var _label: Label = $MessageLabel


func _ready() -> void:
	for b in find_children("*", "McButton", true, false):
		b.message.connect(_show_message)


func _show_message(text: String) -> void:
	_label.text = text
	_label.modulate.a = 1.0
	create_tween().tween_property(_label, "modulate:a", 0.0, 2.0).set_delay(1.5)
