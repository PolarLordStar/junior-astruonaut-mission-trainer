class_name StatRow
extends PanelContainer
## One line on the Environment monitor: name, big value + unit, a bar and a little history graph.
## Everything is a real node (see the tree at the bottom of this comment), so you can hide() or
## restyle any part. Create rows with EnvironmentScreen.add_row({...}) and feed them with
## set_value(). Colours switch automatically: green = normal, amber = warn, red = danger.
##
## Node tree (all created in setup()):
##   Row_<id>  (StatRow, PanelContainer)
##   └ Margin
##     └ Layout (HBox)
##       ├ Left (VBox)
##       │  ├ NameLabel
##       │  ├ ValueLine (HBox): ValueLabel, UnitLabel
##       │  └ Bar (ProgressBar)
##       └ Sparkline

const CARD := Color("16273d")
const BG := Color("0f1b2b")
const GREEN := Color("4ade80")
const AMBER := Color("ffb02e")
const RED := Color("ff5a4a")
const TEXT_DIM := Color("8c94c8")

var id := ""
var title := ""
var unit := ""
var min_value := 0.0
var max_value := 100.0
var warn_at := INF       # high-is-bad: amber above this.  low-is-bad: amber below this
var danger_at := INF     # high-is-bad: red above this.    low-is-bad: red below this
var low_is_bad := false
var decimals := 0
var value := 0.0

var name_label: Label
var value_label: Label
var unit_label: Label
var bar: ProgressBar
var spark: Sparkline

var _card_style: StyleBoxFlat
var _fill: StyleBoxFlat
var _hist_t := 0.0
var _t := 0.0


## cfg keys: id, label, unit, min, max, warn, danger, low_is_bad, decimals
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
	_build()
	set_value(min_value)


func _build() -> void:
	custom_minimum_size = Vector2(0, 66)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_card_style = StyleBoxFlat.new()
	_card_style.bg_color = CARD
	_card_style.border_color = GREEN
	_card_style.border_width_left = 8
	add_theme_stylebox_override("panel", _card_style)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var layout := HBoxContainer.new()
	layout.name = "Layout"
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)

	var left := VBoxContainer.new()
	left.name = "Left"
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 2)
	layout.add_child(left)

	name_label = _make_label("NameLabel", title, 15, TEXT_DIM)
	left.add_child(name_label)

	var line := HBoxContainer.new()
	line.name = "ValueLine"
	line.add_theme_constant_override("separation", 8)
	left.add_child(line)
	value_label = _make_label("ValueLabel", "--", 30, GREEN)
	line.add_child(value_label)
	unit_label = _make_label("UnitLabel", unit, 16, TEXT_DIM)
	unit_label.size_flags_vertical = Control.SIZE_SHRINK_END
	line.add_child(unit_label)

	bar = ProgressBar.new()
	bar.name = "Bar"
	bar.show_percentage = false
	bar.min_value = min_value
	bar.max_value = max_value
	bar.custom_minimum_size = Vector2(0, 10)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = BG
	bar.add_theme_stylebox_override("background", bar_bg)
	_fill = StyleBoxFlat.new()
	_fill.bg_color = GREEN
	bar.add_theme_stylebox_override("fill", _fill)
	left.add_child(bar)

	spark = Sparkline.new()
	spark.name = "Sparkline"
	spark.custom_minimum_size = Vector2(170, 0)
	spark.min_v = min_value
	spark.max_v = max_value
	if is_finite(warn_at):
		spark.marks.append(warn_at)
	if is_finite(danger_at):
		spark.marks.append(danger_at)
	layout.add_child(spark)


func _make_label(node_name: String, text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.name = node_name
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


## 0 = normal, 1 = warn (amber), 2 = danger (red)
func level() -> int:
	if low_is_bad:
		if value < danger_at:
			return 2
		if value < warn_at:
			return 1
	else:
		if value > danger_at:
			return 2
		if value > warn_at:
			return 1
	return 0


func level_color() -> Color:
	match level():
		2:
			return RED
		1:
			return AMBER
	return GREEN


func set_value(v: float) -> void:
	value = v
	if value_label == null:
		return
	value_label.text = ("%." + str(decimals) + "f") % v
	bar.value = v
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
		spark.push(value)
	if _card_style != null:
		var flash := level() == 2 and sin(_t * 6.0) > -0.3
		_card_style.bg_color = CARD.lerp(RED, 0.14) if flash else CARD


## Tiny history graph. Lines mark the warn / danger levels.
class Sparkline extends Control:
	const MAX_POINTS := 60
	var values: Array[float] = []
	var marks: Array[float] = []
	var color := Color("4ade80")
	var min_v := 0.0
	var max_v := 1.0

	func push(v: float) -> void:
		values.append(v)
		if values.size() > MAX_POINTS:
			values.pop_front()
		queue_redraw()

	func _y(v: float) -> float:
		return lerpf(size.y - 3.0, 3.0, clampf(inverse_lerp(min_v, max_v, v), 0.0, 1.0))

	func _draw() -> void:
		for m in marks:
			var y := _y(m)
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(1.0, 0.35, 0.3, 0.45), 1.5)
		if values.size() > 1:
			var pts := PackedVector2Array()
			var step := size.x / float(MAX_POINTS - 1)
			for i in values.size():
				pts.append(Vector2(i * step, _y(values[i])))
			draw_polyline(pts, color, 2.5)
