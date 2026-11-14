class_name SolarPanelCell
extends ColorRect
## One solar panel on the Life Support monitor: a plain rectangle, green when the panel works
## and red when it does not. Nothing else (no name, no number, no grid).
## StatusScreen (ScreenUI.gd) feeds it with set_working(). The node is in room/solar_panel_cell.tscn.

var working := true


func set_working(on: bool) -> void:
	working = on
	var col := ScreenUI.GREEN if on else ScreenUI.RED
	if color != col:
		color = col
