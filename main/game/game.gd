extends Node
var preset_values = preload("res://main/libraries/preset_values.gd")
var player_script = preload("res://main/game/player/player.gd")

var day_number: int = 0
var time

@onready var _day_timer: Timer = $Timers/DayTimer   # one in-game day = preset_values.DAY_DURATION seconds
@onready var _day_label: Label = $DayBanner/DayLabel   # the "DAY n" text at the top of the screen
var _banner_tween: Tween
const BANNER_FADE_IN := 0.4    # seconds to fade in
const BANNER_HOLD := 2.5       # seconds fully visible
const BANNER_FADE_OUT := 2.0   # seconds of the slow fade away
var _clock: MissionClock                            # the clock shown on the monitors (see mission_clock.gd)

func setup() -> void:
	# Resetting Values
	day_number += 1
	#player_script.health = preset_values.MAX_HEALTH
	# ...
	
	# Enabling Day-Dependent Components
	# ...
	
	# Other
	$Timers/DayTimer.wait_time = preset_values.DAY_DURATION
	$Timers/DayTimer.start()





# START OR NEXT DAY FUNCTIONS
func start() -> void:
	setup()
	_show_day_banner()   # "DAY n" shows for a few seconds, then slowly fades away
	# ...date randomises
func _on_day_end() -> void:
	# ...screen saying day number survived
	if day_number < preset_values.MAX_DAYS:
		start()   # next day: the timer restarts, the clock goes back to 00:00 and the banner shows again
func _ready() -> void:
	_clock = get_tree().get_first_node_in_group("clock") as MissionClock
	if _clock != null:
		_clock.simulate = false   # the clock now follows the day timer instead of its own fake time
	start()


# DAY BANNER
func _show_day_banner() -> void:
	_day_label.text = "DAY %d" % day_number
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_day_label.modulate.a = 0.0
	_banner_tween = create_tween()
	_banner_tween.tween_property(_day_label, "modulate:a", 1.0, BANNER_FADE_IN)
	_banner_tween.tween_interval(BANNER_HOLD)
	_banner_tween.tween_property(_day_label, "modulate:a", 0.0, BANNER_FADE_OUT)


# CLOCK
# The whole day (DayTimer, 300 s) is mapped onto 00:00 -> 24:00, so the clock moves at an even speed.
# It moves in steps of preset_values.CLOCK_STEP_MINUTES game-minutes (not every frame).
func _process(_delta: float) -> void:
	if _clock == null or _day_timer.is_stopped():
		return
	var progress := clampf(1.0 - _day_timer.time_left / _day_timer.wait_time, 0.0, 0.9999)
	var game_minutes := progress * 24.0 * 60.0
	var step := float(preset_values.CLOCK_STEP_MINUTES)
	_clock.clock_s = floorf(game_minutes / step) * step * 60.0
