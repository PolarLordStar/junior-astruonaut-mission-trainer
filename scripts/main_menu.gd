extends Control

@onready var _label := Label.new()

func _ready() -> void:
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_label.position.y -= 80
	add_child(_label)

	for b in find_children("*", "McButton", true, false):
		b.message.connect(_show_message)

func _show_message(text: String) -> void:
	_label.text = text
	_label.modulate.a = 1.0
	create_tween().tween_property(_label, "modulate:a", 0.0, 2.0).set_delay(1.5)
