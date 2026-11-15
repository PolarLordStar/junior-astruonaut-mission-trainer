class_name EnvironmentScreen
extends Control
## Middle monitor: environment stats. All the nodes are in room/environment_screen.tscn,
## so every part (title, clock, frame ...) can be edited, hidden or restyled in the editor.
##
## WHERE THE ROWS COME FROM: every Sensor node with show_on_environment = true (RadiationSensor,
## OxygenSensor, PerchlorateSensor ...) gets a row here, in scene-tree order. Labels, units and
## limits live in each sensor's own script. control_room.gd pushes the values every frame.
## The rows are the only nodes made at run time (how many there are depends on the sensors).
## Each row is an instance of room/stat_row.tscn.
##
## HOW TO ADD A STAT: add a new Sensor node (see Sensor.gd). Rows share the screen height, so about 4 fit.
##
## Node tree (room/environment_screen.tscn):
##   EnvironmentScreen (Control)
##   ├ Background (ColorRect)
##   ├ Margin
##   │ └ Layout (VBox)
##   │   ├ Header (HBox): TitleLabel, ClockLabel
##   │   └ Rows (VBox): Row_radiation, Row_oxygen, Row_perchlorate  (StatRow instances)
##   └ Frame (Panel, the blue border)

const STAT_ROW := preload("res://main/game/room/stat_row.tscn")

var rows := {}   # id -> StatRow

@onready var title_label: Label = %TitleLabel
@onready var clock_label: Label = %ClockLabel
@onready var _rows_box: VBoxContainer = %Rows


func _ready() -> void:
	for n in get_tree().get_nodes_in_group("sensors"):
		if n.show_on_environment:
			add_row(n.row_cfg())


func add_row(cfg: Dictionary) -> StatRow:
	var r: StatRow = STAT_ROW.instantiate()
	_rows_box.add_child(r)
	r.setup(cfg)
	rows[r.id] = r
	return r


func set_value(id: String, v: float) -> void:
	var r: StatRow = rows.get(id)
	if r != null:
		r.set_value(v)


## Shows the time left on Game/Timers/DayTimer as M:SS (the value the timer has stored right now).
func set_day_time(seconds_left: float) -> void:
	if clock_label != null:
		var t := maxi(0, ceili(seconds_left))
		clock_label.text = "%d:%02d" % [int(t / 60.0), t % 60]


## (Old) Shows the time of day (HH:MM). The day itself runs on Game/Timers/DayTimer, see game.gd.
func set_time(clock_s: float) -> void:
	if clock_label != null:
		clock_label.text = "%02d:%02d" % [int(clock_s / 3600.0), int(fmod(clock_s, 3600.0) / 60.0)]


# ENABLING AND DISABLING COMPONENTS
func show_radiation() -> void:       rows["radiation"].show()
func hide_radiation() -> void:       rows["radiation"].hide()

func show_perchlorate() -> void:     rows["perchlorate"].show()
func hide_perchlorate() -> void:     rows["perchlorate"].hide()
