class_name ScreenUI
extends Control
## One in-game monitor. mode: "status" (Monitor 1) or "warnings" (Monitor 2).
## control_room.gd writes the values below every frame. To show real data
## (for example from a NASA API), set `simulate = false` in control_room.gd
## and feed the values there.

@export_enum("status", "warnings") var mode: String = "status"

const W := 640.0
const H := 400.0
const MAX_POINTS := 60
const RAD_HIGH := 0.70   # mSv/h above this = HIGH RADIATION
const OXY_LOW := 30.0    # % below this = LOW OXYGEN SUPPLY

const BG := Color("0f1b2b")
const CARD := Color("16273d")
const FRAME := Color("2d2e55")
const CYAN := Color("5ee0f0")
const GREEN := Color("4ade80")
const AMBER := Color("ffb02e")
const RED := Color("ff5a4a")
const DIM := Color("3b3c66")
const TEXT_DIM := Color("8c94c8")
const WHITE := Color("eef0ff")

# --- data for the "status" monitor ---
var power := 100.0
var oxygen := 100.0       # also used by the warnings monitor
var panels: Array[float] = [100.0, 100.0, 100.0, 100.0, 100.0, 100.0]
var sol := 1
var clock_s := 0.0

# --- data for the "warnings" monitor ---
var radiation := 0.42
var storm_phase := 0      # 0 = none, 1 = incoming, 2 = hitting
var storm_type := ""
var storm_level := 1      # 1 minor, 2 moderate, 3 severe
var storm_eta := 0.0
var storm_left := 0.0

var history: Array[float] = []
var t := 0.0
var _tick := 0.0


func _ready() -> void:
	size = Vector2(W, H)


## How many warnings are active. Also used by control_room.gd for the alarm light.
static func warning_count(phase: int, rad: float, o2: float) -> int:
	var n := 0
	if phase != 0:
		n += 1
	if rad > RAD_HIGH:
		n += 1
	if o2 < OXY_LOW:
		n += 1
	return n


func _process(delta: float) -> void:
	t += delta
	_tick += delta
	if _tick >= 0.25:
		_tick = 0.0
		history.append(radiation)
		if history.size() > MAX_POINTS:
			history.pop_front()
	queue_redraw()


func _blink() -> bool:
	return sin(t * 6.0) > -0.3


func _text(pos: Vector2, s: String, font_size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	draw_string(ThemeDB.fallback_font, pos, s, align, width, font_size, color)


func _level_color(v: float) -> Color:
	if v < 25.0:
		return RED
	if v < 50.0:
		return AMBER
	return GREEN


func _mmss(seconds: float) -> String:
	var s := maxi(0, ceili(seconds))
	return "%d:%02d" % [int(s / 60.0), s % 60]


func _severity() -> String:
	match storm_level:
		1:
			return "MINOR"
		2:
			return "MODERATE"
	return "SEVERE"


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), BG)
	match mode:
		"status":
			_draw_status()
		"warnings":
			_draw_warnings()
	draw_rect(Rect2(0, 0, W, H), FRAME, false, 8.0)


# ---------- Monitor 1: status ----------
func _draw_status() -> void:
	_text(Vector2(24, 44), "LIFE SUPPORT", 26, CYAN)
	var clock := "SOL %03d · %02d:%02d" % [sol, int(clock_s / 3600.0), int(fmod(clock_s, 3600.0) / 60.0)]
	_text(Vector2(24, 44), clock, 22, TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT, W - 48.0)
	_meter(Vector2(24, 60), "POWER SUPPLY", power)
	_meter(Vector2(24, 128), "OXYGEN SUPPLY", oxygen)
	_draw_panels(Vector2(24, 196))


func _meter(origin: Vector2, label: String, value: float) -> void:
	var w := W - 48.0
	var v := clampf(value, 0.0, 100.0)
	var col := _level_color(v)
	_text(origin + Vector2(0, 26), label, 20, TEXT_DIM)
	_text(origin + Vector2(0, 26), "%d%%" % roundi(v), 30, col, HORIZONTAL_ALIGNMENT_RIGHT, w)
	var bar := Rect2(origin + Vector2(0, 38), Vector2(w, 20))
	draw_rect(bar, CARD)
	draw_rect(Rect2(bar.position, Vector2(w * v / 100.0, bar.size.y)), col)
	for i in range(1, 10):
		var x := bar.position.x + w * i / 10.0
		draw_line(Vector2(x, bar.position.y), Vector2(x, bar.end.y), BG, 2.0)
	draw_rect(bar, DIM, false, 2.0)


func _draw_panels(origin: Vector2) -> void:
	var w := W - 48.0
	var n := panels.size()
	var avg := 0.0
	for p in panels:
		avg += p
	avg /= maxf(1.0, float(n))
	_text(origin + Vector2(0, 26), "SOLAR PANEL DURABILITY", 20, TEXT_DIM)
	_text(origin + Vector2(0, 26), "AVG %d%%" % roundi(avg), 24, _level_color(avg), HORIZONTAL_ALIGNMENT_RIGHT, w)
	if n == 0:
		return
	var gap := 16.0
	var bw := (w - gap * (n - 1)) / n
	var top := origin.y + 40.0
	var bh := 108.0
	for i in n:
		var x := origin.x + i * (bw + gap)
		var d := clampf(panels[i], 0.0, 100.0)
		var col := _level_color(d)
		var frame := Rect2(x, top, bw, bh)
		draw_rect(frame, CARD)
		var fill_h := bh * d / 100.0
		draw_rect(Rect2(x, top + bh - fill_h, bw, fill_h), col)
		# solar-cell grid lines
		for k in range(1, 4):
			var y := top + bh * k / 4.0
			draw_line(Vector2(x, y), Vector2(x + bw, y), BG, 2.0)
		draw_line(Vector2(x + bw / 2.0, top), Vector2(x + bw / 2.0, top + bh), BG, 2.0)
		draw_rect(frame, DIM, false, 2.0)
		if d < 25.0 and _blink():
			draw_rect(frame, RED, false, 3.0)
		var txt_col := BG if d > 55.0 else WHITE
		_text(Vector2(x, top + bh / 2.0 + 8.0), "%d%%" % roundi(d), 22, txt_col, HORIZONTAL_ALIGNMENT_CENTER, bw)
		_text(Vector2(x, top + bh + 24.0), "P%d" % (i + 1), 18, TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, bw)


# ---------- Monitor 2: warnings ----------
func _draw_warnings() -> void:
	_text(Vector2(24, 44), "WARNINGS", 26, CYAN)
	var n := warning_count(storm_phase, radiation, oxygen)
	if n == 0:
		_text(Vector2(24, 44), "ALL CLEAR", 22, GREEN, HORIZONTAL_ALIGNMENT_RIGHT, W - 48.0)
	else:
		_text(Vector2(24, 44), "%d ACTIVE" % n, 22, RED, HORIZONTAL_ALIGNMENT_RIGHT, W - 48.0)
	_storm_card(Rect2(24, 62, W - 48.0, 94))
	_radiation_card(Rect2(24, 168, W - 48.0, 94))
	_oxygen_card(Rect2(24, 274, W - 48.0, 94))


func _card(r: Rect2, col: Color, caption: String, flash := false) -> void:
	draw_rect(r, CARD)
	if flash and _blink():
		draw_rect(r, Color(col, 0.16))
	draw_rect(Rect2(r.position, Vector2(8.0, r.size.y)), col)
	_text(r.position + Vector2(24, 30), caption, 18, TEXT_DIM)


func _storm_card(r: Rect2) -> void:
	var col := GREEN
	var headline := "NONE DETECTED"
	var side := ""
	if storm_phase == 1:
		col = AMBER
		headline = storm_type
		side = "ETA %s" % _mmss(storm_eta)
	elif storm_phase == 2:
		col = RED
		headline = storm_type
		side = "ACTIVE %s" % _mmss(storm_left)
	_card(r, col, "INCOMING STORMS", storm_phase == 2)
	_text(r.position + Vector2(24, 74), headline, 34, col)
	if storm_phase != 0:
		_text(r.position + Vector2(0, 30), "SEVERITY: %s" % _severity(), 18, TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 16.0)
		_text(r.position + Vector2(0, 74), side, 30, col, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 16.0)


func _spark_y(v: float, top: float, bot: float) -> float:
	return lerpf(bot, top, clampf((v - 0.2) / 1.0, 0.0, 1.0))


func _radiation_card(r: Rect2) -> void:
	var high := radiation > RAD_HIGH
	var col := RED if high else GREEN
	_card(r, col, "RADIATION", high)
	_text(r.position + Vector2(24, 74), "HIGH RADIATION" if high else "NORMAL", 30, col)
	_text(r.position + Vector2(0, 30), "%.2f mSv/h" % radiation, 22, WHITE, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 16.0)
	# little history graph with the warning level marked
	var sw := 230.0
	var sx := r.position.x + r.size.x - 16.0 - sw
	var top := r.position.y + 40.0
	var bot := r.position.y + 84.0
	var wy := _spark_y(RAD_HIGH, top, bot)
	draw_line(Vector2(sx, wy), Vector2(sx + sw, wy), Color(RED, 0.5), 1.5)
	if history.size() > 1:
		var pts := PackedVector2Array()
		for i in history.size():
			pts.append(Vector2(sx + i * (sw / MAX_POINTS), _spark_y(history[i], top, bot)))
		draw_polyline(pts, col, 2.5)


func _oxygen_card(r: Rect2) -> void:
	var low := oxygen < OXY_LOW
	var crit := oxygen < 15.0
	var col := GREEN
	if crit:
		col = RED
	elif low:
		col = AMBER
	_card(r, col, "OXYGEN SUPPLY", crit)
	_text(r.position + Vector2(24, 74), "LOW OXYGEN SUPPLY" if low else "NORMAL", 30, col)
	_text(r.position + Vector2(0, 46), "%d%%" % roundi(oxygen), 30, col, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 16.0)
	var bw := 200.0
	var bar := Rect2(r.position.x + r.size.x - 16.0 - bw, r.position.y + 58.0, bw, 14.0)
	draw_rect(bar, BG)
	draw_rect(Rect2(bar.position, Vector2(bw * clampf(oxygen, 0.0, 100.0) / 100.0, bar.size.y)), col)
	var mark := bar.position.x + bw * OXY_LOW / 100.0
	draw_line(Vector2(mark, bar.position.y - 3.0), Vector2(mark, bar.end.y + 3.0), WHITE, 2.0)
