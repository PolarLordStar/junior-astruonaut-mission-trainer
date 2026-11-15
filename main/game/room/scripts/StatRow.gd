# Some usage of AI occured in the script
class_name StatRow
extends PanelContainer
## One line on the Environment monitor: name, a big percentage, a bar and a little history graph.
## The number, bar and graph show the reading as a share of its range (Components value 100 = 100 %,
## 0 = 0 %). The COLOUR still says how good it is: green = fine, amber = warning, red = danger.
## All the nodes are in room/stat_row.tscn, so you can restyle, move or hide any part in the editor.
## EnvironmentScreen makes one instance of that scene per sensor (EnvironmentScreen.add_row({...}))
## and feeds it with set_value(). Colours switch automatically: green = normal, amber = warn, red = danger.
##
## Node tree (room/stat_row.tscn):
##   StatRow (PanelContainer)          <- renamed to Row_<id> when it is set up
##   └ Margin
##     └ Layout (HBox)
##       ├ Left (VBox)
##       │  ├ NameLabel
##       │  ├ ValueLine (HBox): ValueLabel, UnitLabel (hidden)
##       │  └ Bar (ProgressBar)
##       └ Sparkline

const CARD := Color("16273d")
const GREEN := Color("4ade80")
const AMBER := Color("ffb02e")
const RED := Color("ff5a4a")

var id := ""
var title := ""
var unit := ""
var min_value := 0.0
var max_value := 100.0
var warn_at := INF       # high-is-bad: amber above this.  low-is-bad: amber below this
var danger_at := INF     # high-is-bad: red above this.    low-is-bad: red below this
var low_is_bad := false
var decimals := 0
var value := 0.0         # raw reading
var percent := 100.0     # "how good is it" (100 = perfect), only used for the colours
var shown := 0.0         # the reading as a share of its range (0 .. 100): what the label, bar and graph display

@onready var name_label: Label = %NameLabel
@onready var value_label: Label = %ValueLabel
@onready var unit_label: Label = %UnitLabel
@onready var bar: ProgressBar = %Bar
@onready var spark: Sparkline = %Sparkline

# The two styles are "Local to Scene" in the .tscn, so every row has its own copy to recolour.
@onready var _card_style := get_theme_stylebox("panel") as StyleBoxFlat
@onready var _fill := bar.get_theme_stylebox("fill") as StyleBoxFlat

var _hist_t := 0.0
var _t := 0.0


## cfg keys: id, label, unit, min, max, warn, danger, low_is_bad, decimals
## Call this AFTER adding the row to the tree (EnvironmentScreen.add_row does).
func setup(cfg: Dictionary) -> void:
	id = cfg.get("id", "")
	title = cfg.get("label", id.to_upper())
	unit = cfg.get("unit", "")
	min_value = cfg.get("min", 0.0)
	max_value = cfg.get("max", 100.0)
	low_is_bad = cfg.get("low_is_bad", false)
	warn_at = cfg.get("warn", -INF if low_is_bad else INF)
	danger_at = cfg.get("danger", -INF if low_is_bad else INF)
	decimals = cfg.get("decimals", 0)
	name = "Row_" + id

	name_label.text = title
	unit_label.visible = false      # percentages only, no units
	bar.min_value = 0.0
	bar.max_value = 100.0
	spark.min_v = 0.0
	spark.max_v = 100.0
	spark.marks.clear()
	if is_finite(warn_at):
		spark.marks.append(to_shown(warn_at))
	if is_finite(danger_at):
		spark.marks.append(to_shown(danger_at))
	set_value(max_value if low_is_bad else min_value)


## The raw reading turned into a "how good is it" percentage (100 = perfect, 0 = worst).
## A sensor whose unit already is % (oxygen) is shown as is. For the others the warn limit sits at
## 70 % and the danger limit at 50 %, so the colour changes exactly when the sensor's warning does.
func to_percent(v: float) -> float:
	if unit.strip_edges() == "%":
		return clampf(v, 0.0, 100.0)
	var span := max_value - min_value
	if span <= 0.0:
		return 100.0
	var pct: float
	if low_is_bad:
		if v >= warn_at:
			pct = remap(v, warn_at, max_value, 70.0, 100.0)
		elif v >= danger_at:
			pct = remap(v, danger_at, warn_at, 50.0, 70.0)
		else:
			pct = remap(v, min_value, danger_at, 0.0, 50.0)
	else:
		if v <= warn_at:
			pct = remap(v, min_value, warn_at, 100.0, 70.0)
		elif v <= danger_at:
			pct = remap(v, warn_at, danger_at, 70.0, 50.0)
		else:
			pct = remap(v, danger_at, max_value, 50.0, 0.0)
	return clampf(pct, 0.0, 100.0)


## The raw reading as a straight share of the sensor's range: min_value = 0 %, max_value = 100 %.
func to_shown(v: float) -> float:
	var span := max_value - min_value
	if span <= 0.0:
		return 0.0
	return clampf((v - min_value) / span * 100.0, 0.0, 100.0)


## 0 = normal (green), 1 = warn (amber), 2 = danger (red)
func level() -> int:
	if percent < 50.0:
		return 2
	if percent < 70.0:
		return 1
	return 0


func level_color() -> Color:
	return ScreenUI.level_color(percent)


func set_value(v: float) -> void:
	value = v
	percent = to_percent(v)
	shown = to_shown(v)
	if value_label == null:
		return
	value_label.text = "%d%%" % roundi(shown)
	bar.value = shown
	var col := level_color()
	_fill.bg_color = col
	_card_style.border_color = col
	value_label.add_theme_color_override("font_color", col)
	spark.color = col


func _process(delta: float) -> void:
	_t += delta
	_hist_t += delta
	if _hist_t >= 0.5 and spark != null:
		_hist_t = 0.0
		spark.push(shown)
	if _card_style != null:
		var flash := level() == 2 and sin(_t * 6.0) > -0.3
		_card_style.bg_color = CARD.lerp(RED, 0.14) if flash else CARD
