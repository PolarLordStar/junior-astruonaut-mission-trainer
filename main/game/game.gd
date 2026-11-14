extends Node
var preset_values = preload("res://main/libraries/preset_values.gd")
var player_script = preload("res://main/game/player/player.gd")
var save_script = preload("res://scripts/save_manager.gd")
var components_script = preload("res://main/game/components/components.gd")

var day_number: int = save_script.new().load_day()
var date

func setup() -> void:
	# Resetting Values
	day_number += 1
	date = await DonkiService.fetch_random_day()
	
	# Resetting Components
	player_script.new().health = preset_values.new().MAX_HEALTH
	# ...
	
	# Enabling Day-Dependent Components
	# ...
	
	# Events
	components_script.new().events_for_today = []
	components_script.new().events_occurring = {}
	components_script.new().start()
	
	# Other
	$Timers/DayTimer.wait_time = preset_values.new().DAY_DURATION
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
