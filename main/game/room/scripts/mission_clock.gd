# Some usage of AI occured in the script
class_name MissionClock
extends Node
## Mission day (sol) and time of day shown at the top of the monitors.
## REAL DATA: set Simulate = false and call set_time(sol, seconds_since_midnight).

const CLOCK_SPEED := 60.0   # 1 real second = 1 minute of mission time

@export var simulate := true
@export var sol := 47
@export_range(0.0, 24.0) var start_hour := 8.0

var clock_s := 8.0 * 3600.0


func _init() -> void:
	add_to_group("clock")


func _ready() -> void:
	clock_s = start_hour * 3600.0


func _process(delta: float) -> void:
	if not simulate:
		return
	clock_s += delta * CLOCK_SPEED
	if clock_s >= 86400.0:
		clock_s -= 86400.0
		sol += 1


func set_time(new_sol: int, seconds_since_midnight: float) -> void:
	sol = new_sol
	clock_s = seconds_since_midnight
