class_name EnvironmentScreen
extends Control
## Middle monitor: environment stats. Built from real nodes so every part can be hidden or restyled.
##
## WHERE THE ROWS COME FROM: every Sensor node with show_on_environment = true (RadiationSensor,
## OxygenSensor, PerchlorateSensor ...) gets a row here, in scene-tree order. Labels, units and
## limits live in each sensor's own script. control_room.gd pushes the values every frame.
##
## HOW TO ADD A STAT: add a new Sensor node (see sensor.gd). Rows share the screen height, so about 4 fit.
##
## Node tree:
##   EnvironmentScreen (Control)
##   ├ Background (ColorRect)
##   ├ Margin
##   │ └ Layout (VBox)
##   │   ├ Header (HBox): TitleLabel, ClockLabel
##   │   └ Rows (VBox): Row_radiation, Row_oxygen, Row_perchlorate  (StatRow nodes)
##   └ Frame (Panel, the blue border)

const W := 640.0
const H := 400.0
const BG := Color("0f1b2b")
const FRAME := Color("2d2e55")
const CYAN := Color("5ee0f0")
const TEXT_DIM := Color("8c94c8")

var rows := {}   # id -> StatRow
var title_label: Label
var clock_label: Label
var _rows_box: VBoxContainer


func _ready() -> void:
	size = Vector2(W, H)
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.name = "Layout"
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	var header := HBoxContainer.new()
	header.name = "Header"
	layout.add_child(header)
	title_label = _make_label("TitleLabel", "ENVIRONMENT", 26, CYAN)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	clock_label = _make_label("ClockLabel", "SOL 000 · 00:00", 22, TEXT_DIM)
	header.add_child(clock_label)

	_rows_box = VBoxContainer.new()
	_rows_box.name = "Rows"
	_rows_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rows_box.add_theme_constant_override("separation", 8)
	layout.add_child(_rows_box)
	for n in get_tree().get_nodes_in_group("sensors"):
		if n.show_on_environment:
			add_row(n.row_cfg())

	var frame := Panel.new()
	frame.name = "Frame"
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = FRAME
	sb.set_border_width_all(8)
	frame.add_theme_stylebox_override("panel", sb)
	add_child(frame)


func _make_label(node_name: String, text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.name = node_name
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func add_row(cfg: Dictionary) -> StatRow:
	var r := StatRow.new()
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
