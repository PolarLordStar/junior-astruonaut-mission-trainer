extends Node
var preset_values = preload("res://main/libraries/preset_values.gd")
var player_script = preload("res://main/game/player/player.gd").new()
var save_script = preload("res://scripts/save_manager.gd")
var components_script = preload("res://main/game/components/components.gd").new()

var day_number: int = save_script.new().load_day()
var date

func setup() -> void:
	# Resetting Values
	day_number += 1
	date = await DonkiService.fetch_random_day()
	
	# Resetting Components
	player_script.health = preset_values.new().MAX_HEALTH
	# ...
	
	# Enabling Day-Dependent Components
	# ...
	
	# Events
	components_script.events_for_today = {}
	components_script.events_to_occur = {}
	components_script.events_occurring = {}
	components_script.decide_events(date, day_number)
	start_event_timers()
	
	# Other
	$Timers/DayTimer.wait_time = preset_values.new().DAY_DURATION
	$Timers/DayTimer.start()
	$Timers/TickUpdateTimer.start()


# START OR NEXT DAY FUNCTIONS
func start() -> void:
	# ...screen saying Day Number
	setup()
func _on_day_end() -> void:
	$Timers/DayTimer.stop()
	$Timers/TickUpdateTimer.stop()
	# ...screen saying day number survived
func _ready() -> void:
	start()


# EVENTS
func _process(delta: float) -> void:
	components_script.update_event_timers(delta)   # live countdowns shown on the 3rd monitor


func start_event_timers() -> void:
	# Clear any leftover event timers from the previous day
	for child in $Timers.get_children():
		if child.name != "DayTimer" && child.name != "TickUpdateTimer":
			child.queue_free()
	
	
	# Loop through each {event: severity} : delay_time pair
	for event_dict in components_script.events_to_occur:
		var delay_time: float = components_script.events_to_occur[event_dict]
		
		var event_timer = Timer.new()
		event_timer.wait_time = delay_time
		event_timer.one_shot = true
		$Timers.add_child(event_timer)
		
		# Connect timeout signal and pass the event data and presets
		event_timer.timeout.connect(_on_event_timer_timeout.bind(event_dict, preset_values.EVENT_DURATION, event_timer))
		event_timer.start()

func _on_event_timer_timeout(event_dict: Dictionary, duration: float, start_timer: Timer) -> void:
	# 1. Move the event from events_to_occur to events_occurring
	components_script.events_to_occur.erase(event_dict)
	components_script.events_occurring[event_dict] = duration
	print("Event started: ", event_dict, " | Ends in: ", duration, "s")
	
	# 2. Clean up the start delay timer
	start_timer.queue_free()
	
	# 3. Create a new timer for when this occurring event should end
	var end_timer = Timer.new()
	end_timer.wait_time = duration
	end_timer.one_shot = true
	$Timers.add_child(end_timer)
	
	end_timer.timeout.connect(_on_event_duration_timeout.bind(event_dict, end_timer))
	end_timer.start()

func _on_event_duration_timeout(event_dict: Dictionary, end_timer: Timer) -> void:
	# Remove the expired event from events_occurring
	components_script.events_occurring.erase(event_dict)
	print("Event ended: ", event_dict)
	
	# Clean up the duration timer node
	end_timer.queue_free()


# COMPONENTS
func _updating_tick() -> void:
	components_script.tick_update()
