class_name StatusMeter
extends VBoxContainer
## One big bar on the Life Support monitor: a name, the value in % and a bar that turns amber / red
## as it drops. All the nodes are in room/status_meter.tscn (the text of NameLabel is set on each
## instance inside room/status_screen.tscn). StatusScreen (ScreenUI.gd) feeds it with set_value().
##
## Node tree (room/status_meter.tscn):
##   StatusMeter (VBox)
##   ├ Line (HBox): NameLabel, ValueLabel
##   └ Bar (ProgressBar)

@onready var name_label: Label = %NameLabel
@onready var value_label: Label = %ValueLabel
@onready var bar: ProgressBar = %Bar

# "Local to Scene" in the .tscn, so every meter has its own copy to recolour.
@onready var _fill := bar.get_theme_stylebox("fill") as StyleBoxFlat


func set_value(v: float) -> void:
	var pct := clampf(v, 0.0, 100.0)
	var col := ScreenUI.level_color(pct)
	value_label.text = "%d%%" % roundi(pct)
	value_label.add_theme_color_override("font_color", col)
	bar.value = pct
	_fill.bg_color = col
