extends Node
var preset_values = preload("res://main/libraries/preset_values.gd").new()
var player_script = preload("res://main/game/player/player.gd").new()
var save_script = preload("res://scripts/save_manager.gd").new()

var day_number: int = save_script.load_day()

func setup() -> void:
	# Resetting Values
	day_number += 1
	player_script.health = preset_values.MAX_HEALTH
	# ...
	
	# Enabling Day-Dependent Components
	# ...
	
	# Other
	$Timers/DayTimer.wait_time = preset_values.DAY_DURATION
	$Timers/DayTimer.start()





# START OR NEXT DAY FUNCTIONS
func start() -> void:
	# ...screen saying Day Number
	setup()
	# ...date randomises
func _on_day_end() -> void:
	# ...screen saying day number survived
	pass
func _ready() -> void:
	start()
