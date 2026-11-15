# Some usage of AI occured in the script
extends CanvasLayer
## Day counter + clock UI, kept in its own script so game.gd stays untouched.
##
## It only READS Game/Timers/DayTimer. It never starts, stops or sets that timer.
##
## 1) CLOCK: while the day timer is running, the whole day is mapped onto 00:00 -> 24:00 and the
##    time is shown on the middle monitor. While the timer is not running, the clock is not updated.
## 2) DAY COUNTER: show_day(n) renders "DAY n" at the top of the screen: it fades in, stays for
##    hold_time seconds, then slowly fades away. Whoever runs the day logic calls it, for example:
##        $DayCounter.show_day(day_number)
##
## The label (DayLabel) is a node in day_counter.tscn: move it or change its font, size and colours there.

## The clock moves in steps of this many game-minutes (5 = about once a second, 1 = smoother).
@export var clock_step_minutes := 5
@export var fade_in_time := 0.4    # seconds to fade in
@export var hold_time := 2.5       # seconds fully visible
@export var fade_out_time := 2.0   # seconds of the slow fade away

@onready var _label: Label = $DayLabel
@onready var _day_timer: Timer = get_node_or_null("../Timers/DayTimer")   # Game/Timers/DayTimer
var _clock: MissionClock   # the clock the monitors read (see mission_clock.gd)
var _tween: Tween


func _ready() -> void:
	_label.modulate.a = 0.0
	if _day_timer == null:
		push_warning("DayCounter: Game/Timers/DayTimer not found (this node must be a child of Game)")
	_clock = get_tree().get_first_node_in_group("clock") as MissionClock
	if _clock != null:
		_clock.simulate = false   # the clock follows the day timer instead of its own fake time


func _process(_delta: float) -> void:
	# CLOCK: only show the time while the day timer is running
	if _clock == null or _day_timer == null or _day_timer.is_stopped() or _day_timer.wait_time <= 0.0:
		return
	var progress := clampf(1.0 - _day_timer.time_left / _day_timer.wait_time, 0.0, 0.9999)
	var game_minutes := progress * 24.0 * 60.0
	var step := float(maxi(clock_step_minutes, 1))
	_clock.clock_s = floorf(game_minutes / step) * step * 60.0


## DAY COUNTER: renders "DAY n" at the top of the screen, then slowly fades it away.
func show_day(day: int) -> void:
	if not is_node_ready():
		await ready
	_label.text = "DAY %d" % day
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_label.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(_label, "modulate:a", 1.0, fade_in_time)
	_tween.tween_interval(hold_time)
	_tween.tween_property(_label, "modulate:a", 0.0, fade_out_time)
