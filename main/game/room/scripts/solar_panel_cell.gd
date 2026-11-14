class_name SolarPanelCell
extends VBoxContainer
## One solar panel on the Life Support monitor: a box that fills from the bottom, the % inside it
## and the panel name (P1, P2 ...) under it. The border blinks red when the panel is below 25 %.
## All the nodes are in room/solar_panel_cell.tscn; StatusScreen (ScreenUI.gd) feeds it with set_value().
##
## Node tree (room/solar_panel_cell.tscn):
##   SolarPanelCell (VBox)
##   ├ Cell (Control)
##   │ ├ Bar (ProgressBar, fills bottom to top)
##   │ ├ Grid (the solar-cell lines: Line1 .. Line3, LineV)
##   │ ├ PercentLabel
##   │ └ Frame (Panel, the border)
##   └ NameLabel

var value := 100.0

@onready var percent_label: Label = %PercentLabel
@onready var bar: ProgressBar = %Bar
@onready var frame: Panel = %Frame

# Both are "Local to Scene" in the .tscn, so every panel has its own copy to recolour.
@onready var _fill := bar.get_theme_stylebox("fill") as StyleBoxFlat
@onready var _frame_style := frame.get_theme_stylebox("panel") as StyleBoxFlat

var _t := 0.0


func set_value(v: float) -> void:
	value = clampf(v, 0.0, 100.0)
	bar.value = value
	_fill.bg_color = ScreenUI.level_color(value)
	percent_label.text = "%d%%" % roundi(value)
	var text_col: Color = ScreenUI.BG if value > 55.0 else ScreenUI.WHITE
	percent_label.add_theme_color_override("font_color", text_col)


func _process(delta: float) -> void:
	_t += delta
	var alarm := value < 25.0 and sin(_t * 6.0) > -0.3
	_frame_style.border_color = ScreenUI.RED if alarm else ScreenUI.DIM
