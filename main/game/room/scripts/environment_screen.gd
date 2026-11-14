class_name EnvironmentScreen
extends Control
## Middle monitor: environment stats. All the nodes are in scenes/environment_screen.tscn,
## so every part (title, clock, frame ...) can be edited, hidden or restyled in the editor.
##
## WHERE THE ROWS COME FROM: every Sensor node with show_on_environment = true (RadiationSensor,
## OxygenSensor, PerchlorateSensor ...) gets a row here, in scene-tree order. Labels, units and
## limits live in each sensor's own script. control_room.gd pushes the values every frame.
## The rows are the only nodes made at run time (how many there are depends on the sensors).
## Each row is an instance of scenes/stat_row.tscn.
##
## HOW TO ADD A STAT: add a new Sensor node (see Sensor.gd). Rows share the screen height, so about 4 fit.
##
## Node tree (scenes/environment_screen.tscn):
##   EnvironmentScreen (Control)
##   ├ Background (ColorRect)
##   ├ Margin
##   │ └ Layout (VBox)
##   │   ├ Header (HBox): TitleLabel, ClockLabel
##   │   └ Rows (VBox): Row_radiation, Row_oxygen, Row_perchlorate  (StatRow instances)
##   └ Frame (Panel, the blue border)

const STAT_ROW := preload("res://scenes/stat_row.tscn")

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


func set_time(sol: int, clock_s: float) -> void:
	if clock_label != null:
		clock_label.text = "SOL %03d · %02d:%02d" % [sol, int(clock_s / 3600.0), int(fmod(clock_s, 3600.0) / 60.0)]
