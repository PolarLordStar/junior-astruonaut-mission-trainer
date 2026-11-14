class_name MarsBackground
extends Control
## Animated Mars backdrop for the main menu: pulsing sun, hazy mesas, slowly scrolling dunes
## and a rover that drives across the screen every so often. All drawn in code, no image files.

const PERIOD := 26.0         # seconds per rover pass (it drives ~80% of that, then a short pause)
const ROVER_SIZE := 500.0    # the rover is (screen height / this) times its drawn size: smaller = bigger rover
const SKY_TOP := Color(0.36, 0.16, 0.10)
const SKY_LOW := Color(0.95, 0.62, 0.38)

var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_t = PERIOD * 0.08   # so the rover is already entering the screen at launch


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var horizon := h * 0.58
	var s := h / ROVER_SIZE

	# sky
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, horizon + 2), Vector2(0, horizon + 2)]),
			PackedColorArray([SKY_TOP, SKY_TOP, SKY_LOW, SKY_LOW]))

	# sun with a soft glow
	var sun := Vector2(w * 0.72, horizon - h * 0.2)
	var r := minf(w, h) * 0.085
	var pulse := 1.0 + 0.02 * sin(_t * 0.8)
	draw_circle(sun, r * 3.2 * pulse, Color(1.0, 0.75, 0.4, 0.10))
	draw_circle(sun, r * 2.2 * pulse, Color(1.0, 0.78, 0.42, 0.16))
	draw_circle(sun, r * 1.5, Color(1.0, 0.85, 0.5, 0.28))
	draw_circle(sun, r, Color("fff0a8"))

	# far mesas + dusty haze at the horizon
	_mesa(w * 0.12, w * 0.22, h * 0.10, horizon, Color(0.77, 0.55, 0.37))
	_mesa(w * 0.40, w * 0.18, h * 0.06, horizon, Color(0.79, 0.57, 0.39))
	_mesa(w * 0.86, w * 0.26, h * 0.12, horizon, Color(0.75, 0.53, 0.35))
	var haze := Color(0.95, 0.62, 0.38, 0.5)
	var clear := Color(0.95, 0.62, 0.38, 0.0)
	draw_polygon(PackedVector2Array([Vector2(0, horizon - h * 0.12), Vector2(w, horizon - h * 0.12), Vector2(w, horizon + 2), Vector2(0, horizon + 2)]),
			PackedColorArray([clear, clear, haze, haze]))

	# dunes (farther = slower), then the ground
	_layer(horizon + h * 0.03, h * 0.02, 0.004, 6.0, 0.0, Color(0.72, 0.44, 0.25))
	_layer(horizon + h * 0.09, h * 0.03, 0.006, 14.0, 2.0, Color(0.64, 0.37, 0.20))
	_layer(h * 0.79, h * 0.008, 0.01, 30.0, 4.0, Color(0.55, 0.30, 0.16))
	var road_y := h * 0.86
	draw_rect(Rect2(0, road_y - h * 0.012, w, h * 0.06), Color(0.47, 0.25, 0.13))
	for i in 9:
		var rx := fmod(i * 0.137 + 0.05, 1.0) * w
		var ry := h * (0.93 + 0.02 * (i % 3))
		var rr := (10.0 + (i % 4) * 6.0) * s
		draw_colored_polygon(PackedVector2Array([Vector2(rx - rr, ry), Vector2(rx - rr * 0.5, ry - rr * 0.7),
				Vector2(rx + rr * 0.6, ry - rr * 0.6), Vector2(rx + rr, ry)]), Color(0.38, 0.20, 0.11))

	# the rover drives left to right, then pauses off-screen before the next pass
	var u := fmod(_t, PERIOD) / PERIOD
	if u < 0.8:
		var x := lerpf(-w * 0.15, w * 1.15, u / 0.8)
		_rover(x, road_y + h * 0.012, s)


func _mesa(cx: float, width: float, height: float, base_y: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(cx - width * 0.5, base_y + 2), Vector2(cx - width * 0.35, base_y - height),
			Vector2(cx + width * 0.35, base_y - height), Vector2(cx + width * 0.5, base_y + 2)]), color)


## A wavy silhouette filled down to the bottom of the screen. "speed" scrolls it sideways.
func _layer(base: float, amp: float, freq: float, speed: float, phase: float, color: Color) -> void:
	var step := 16.0
	var pts := PackedVector2Array()
	for i in int(size.x / step) + 2:
		var x := i * step
		var q := (x + _t * speed) * freq + phase
		pts.append(Vector2(x, base + amp * sin(q) + amp * 0.5 * sin(q * 2.3 + phase)))
	var last_x := pts[pts.size() - 1].x
	pts.append(Vector2(last_x, size.y))
	pts.append(Vector2(0, size.y))
	draw_colored_polygon(pts, color)


func _ellipse(c: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, color)


## Side view of the rover facing right. Local coordinates: origin on the ground, y points down.
func _rover(x: float, ground_y: float, s: float) -> void:
	var bob := sin(x * 0.07) * 1.2
	draw_set_transform(Vector2(x, ground_y), 0.0, Vector2(s, s))
	_ellipse(Vector2(0, 1), 88.0, 7.0, Color(0, 0, 0, 0.25))
	# dust behind it
	for i in 6:
		var f := float(i) / 6.0
		var p := Vector2(-70.0 - i * 22.0, -6.0 - i * 4.0 + sin(_t * 3.0 + i) * 2.0)
		draw_circle(p, 7.0 + i * 3.5, Color(0.86, 0.6, 0.4, 0.32 * (1.0 - f)))
	# suspension arms
	var grey := Color(0.55, 0.55, 0.6)
	draw_line(Vector2(-30, -40 + bob), Vector2(-52, -16), grey, 4.0)
	draw_line(Vector2(0, -40 + bob), Vector2(0, -16), grey, 4.0)
	draw_line(Vector2(30, -40 + bob), Vector2(52, -16), grey, 4.0)
	# wheels (spin with the distance travelled)
	var ang := x / (16.0 * s)
	for wx in [-52.0, 0.0, 52.0]:
		var c := Vector2(wx, -16.0)
		draw_circle(c, 16.0, Color(0.1, 0.1, 0.12))
		draw_circle(c, 9.0, Color(0.42, 0.42, 0.48))
		for k in 3:
			var a := ang + k * TAU / 3.0
			draw_line(c, c + Vector2(cos(a), sin(a)) * 12.0, Color(0.62, 0.62, 0.68), 3.0)
		draw_circle(c, 3.0, Color(0.85, 0.85, 0.9))
	# body
	draw_rect(Rect2(-62, -76 + bob, 124, 36), Color(0.85, 0.82, 0.78))
	draw_rect(Rect2(-62, -48 + bob, 124, 8), Color(0.62, 0.6, 0.58))
	draw_rect(Rect2(-62, -64 + bob, 124, 5), Color("d9651f"))
	draw_rect(Rect2(-40, -88 + bob, 60, 12), Color(0.74, 0.72, 0.7))
	draw_rect(Rect2(-8, -96 + bob, 18, 8), Color(0.3, 0.3, 0.34))
	# antenna dish (back) and camera mast (front)
	draw_line(Vector2(-45, -76 + bob), Vector2(-45, -100 + bob), grey, 3.0)
	draw_circle(Vector2(-45, -104 + bob), 9.0, Color(0.9, 0.9, 0.94))
	draw_line(Vector2(38, -76 + bob), Vector2(38, -120 + bob), grey, 4.0)
	draw_rect(Rect2(30, -132 + bob, 24, 14), Color(0.16, 0.17, 0.2))
	draw_circle(Vector2(51, -125 + bob), 4.0, Color("5ee0f0"))
	# little robot arm
	draw_line(Vector2(62, -58 + bob), Vector2(84, -46 + bob), grey, 4.0)
	draw_line(Vector2(84, -46 + bob), Vector2(92, -34 + bob), grey, 4.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
