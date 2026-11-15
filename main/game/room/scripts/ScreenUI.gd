# Some usage of AI occured in the script
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
##   │   ├ Header (HBox): TitleLabel
##   │   ├ PowerMeter   (StatusMeter instance, room/status_meter.tscn)
##   │   ├ OxygenMeter  (StatusMeter instance)
##   │   ├ PanelsHeader (HBox): PanelsTitle
##   │   └ PanelsRow (HBox)
##   │     ├ GridBox (PanelContainer, the frame around the grid)
##   │     │ └ PanelCells (GridContainer, 3 columns x 2 rows): Panel1 ... Panel6 (SolarPanelCell instances,
##   │     │               room/solar_panel_cell.tscn; Panel1-3 are the top row, Panel4-6 the bottom row)
##   │     └ CountCircle (Panel drawn as a circle): CountLabel   <- the number of working panels, 0-6
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
var panels: Array[bool] = [true, true, true, true, true, true]   # true = that solar panel works

@onready var power_meter: StatusMeter = %PowerMeter
@onready var oxygen_meter: StatusMeter = %OxygenMeter
@onready var count_circle: Panel = %CountCircle
@onready var count_label: Label = %CountLabel
@onready var _cells: Array[Node] = %PanelCells.get_children()

# "Local to Scene" in the .tscn, so the circle has its own copy to recolour.
@onready var _circle_style := count_circle.get_theme_stylebox("panel") as StyleBoxFlat


## Green at 70 % and above, amber (yellowish) 50-69 %, red below 50 %. (Power and oxygen bars.)
static func level_color(v: float) -> Color:
	if v < 50.0:
		return RED
	if v < 70.0:
		return AMBER
	return GREEN


## Colour of the "number of working solar panels" circle: 0-2 red, 3-4 amber (yellowish), 5-6 green.
static func count_color(working: int) -> Color:
	if working <= 2:
		return RED
	if working <= 4:
		return AMBER
	return GREEN


func _process(_delta: float) -> void:
	power_meter.set_value(power)
	oxygen_meter.set_value(oxygen)
	var working := 0
	for i in _cells.size():
		var ok: bool = panels[i] if i < panels.size() else false
		(_cells[i] as SolarPanelCell).set_working(ok)
		if ok:
			working += 1
	count_label.text = str(working)
	_circle_style.bg_color = count_color(working)


# FOR DISABLING AND ENABLING COMPONENTS
func show_power() -> void:   power_meter.show()
func hide_power() -> void:   power_meter.hide()

func show_oxygen() -> void:  oxygen_meter.show()
func hide_oxygen() -> void:  oxygen_meter.hide()

func show_solar_panels() -> void:
	$Margin/Layout/PanelsHeader.show()
	$Margin/Layout/PanelsRow.show()
func hide_solar_panels() -> void:
	$Margin/Layout/PanelsHeader.hide()
	$Margin/Layout/PanelsRow.hide()

func _ready() -> void:
	power_meter.name_label.text = "POWER SUPPLY"
	oxygen_meter.name_label.text = "OXYGEN SUPPLY"
