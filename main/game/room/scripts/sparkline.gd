class_name Sparkline
extends Control
## Tiny history graph used by StatRow (scenes/stat_row.tscn). Lines mark the warn / danger levels.

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
