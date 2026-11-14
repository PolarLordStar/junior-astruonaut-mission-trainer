class_name ScreenUI
extends Control
## Left monitor ("Life Support"): power supply, oxygen supply and the 6 solar panels.
## Every label, bar and panel is a real node in room/status_screen.tscn, so you can change the
## text, colours, sizes and positions in the editor. This script only pushes the numbers into them.
##
## control_room.gd writes the values below every frame. To show real data (for example from a NASA
## API) feed the Sensor nodes there (see Sensor.gd); this screen just displays what it is given.
##
## Node tree (room/status_screen.tscn):
##   StatusScreen (Control)
##   ├ Background (ColorRect)
##   ├ Margin
##   │ └ Layout (VBox)
##   │   ├ Header (HBox): TitleLabel, ClockLabel
##   │   ├ PowerMeter   (StatusMeter instance, room/status_meter.tscn)
##   │   ├ OxygenMeter  (StatusMeter instance)
##   │   ├ PanelsHeader (HBox): PanelsTitle, PanelsAvgLabel
##   │   └ PanelCells (HBox): Panel1 ... Panel6 (SolarPanelCell instances, room/solar_panel_cell.tscn)
##   └ Frame (Panel, the blue border)

# Shared colours and thresholds (also used by StatusMeter and SolarPanelCell).
const BG := Color("0f1b2b")
const CARD := Color("16273d")
const DIM := Color("3b3c66")
const TEXT_DIM := Color("8c94c8")
const WHITE := Color("eef0ff")
const GREEN := Color("4ade80")
const AMBER := Color("ffb02e")
const RED := Color("ff5a4a")

# Values pushed in by control_room.gd every frame.
var power := 100.0
var oxygen := 100.0
var panels: Array[float] = [100.0, 100.0, 100.0, 100.0, 100.0, 100.0]
var sol := 1
var clock_s := 0.0

@onready var clock_label: Label = %ClockLabel
@onready var power_meter: StatusMeter = %PowerMeter
@onready var oxygen_meter: StatusMeter = %OxygenMeter
@onready var panels_avg_label: Label = %PanelsAvgLabel
@onready var _cells: Array[Node] = %PanelCells.get_children()


## Green at 70 % and above, amber (yellowish) 50-69 %, red below 50 %.
static func level_color(v: float) -> Color:
	if v < 50.0:
		return RED
	if v < 70.0:
		return AMBER
	return GREEN


func _process(_delta: float) -> void:
	clock_label.text = "SOL %03d · %02d:%02d" % [sol, int(clock_s / 3600.0), int(fmod(clock_s, 3600.0) / 60.0)]
	power_meter.set_value(power)
	oxygen_meter.set_value(oxygen)
	var avg := 0.0
	for i in _cells.size():
		var v: float = panels[i] if i < panels.size() else 0.0
		(_cells[i] as SolarPanelCell).set_value(v)
	for p in panels:
		avg += p
	avg /= maxf(1.0, float(panels.size()))
	panels_avg_label.text = "AVG %d%%" % roundi(avg)
	panels_avg_label.add_theme_color_override("font_color", level_color(avg))
