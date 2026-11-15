extends Node
var preset_values = preload("res://main/libraries/preset_values.gd").new()
var player_script = preload("res://main/game/player/player.gd").new()
var save_script = preload("res://scripts/save_manager.gd").new()
var components_script = preload("res://main/game/components/components.gd").new()
@onready var day_counter: CanvasLayer = $DayCounter
@onready var day_transition: CanvasLayer = $DayTransition   # "You have survived!" screen (ui/day_transition.tscn)

var day_number: int = save_script.load_day()
var date

func setup() -> void:
	# Resetting Values
	player_script.health = preset_values.MAX_HEALTH
	components_script.Radiation = preset_values.RADIATION
	components_script.Power = preset_values.POWER
	components_script.Oxygen = preset_values.OXYGEN
	components_script.ToxicPerch = preset_values.TOXIC_PERCH
	components_script.SolarPanels = preset_values.SOLAR_PANELS
	
	components_script.AirFilteringUsing = false
	components_script.CoverSolarPanUsing = false
	components_script.RadiationShieldingUsing = false
	
	day_number += 1
	date = await DonkiService.fetch_random_day()
	
	# Enabling Day-Dependent Components
	update_day_by_day_components()
	
	# Events
	components_script.events_for_today = {}
	components_script.events_to_occur = {}
	components_script.events_occurring = {}
	components_script.SolarEventOccurring = false
	components_script.StormOccurring = components_script.STORMS.NONE
	components_script.decide_events(date)
	start_event_timers()
	
	# Other
	$Timers/DayTimer.start()
	$Timers/TickUpdateTimer.start()


# START OR NEXT DAY FUNCTIONS
func start() -> void:
	setup()
	day_counter.show_day(day_number)
func _on_day_end() -> void:
	$Timers/DayTimer.stop()
	$Timers/TickUpdateTimer.stop()
	# The day is over: freeze the game and show the transition screen. It does NOT start the next day by
	# itself any more, the player chooses with the two buttons (see the two functions below).
	# On the last day there is no next day, so the Continue button is hidden.
	get_tree().paused = true
	day_transition.show_transition(day_number < preset_values.MAX_DAYS)


# "Continue" on the transition screen: reset the day timer and start the next day.
func _on_transition_continue() -> void:
	$Timers/DayTimer.wait_time = preset_values.DAY_DURATION   # the day timer's original value again
	get_tree().paused = false
	start()   # setup() restarts DayTimer + TickUpdateTimer, and the day counter shows the new day number


# "Return to Main Menu" on the transition screen.
func _on_transition_main_menu() -> void:
	get_tree().paused = false   # undo the pause from _on_day_end() first
	get_tree().change_scene_to_file("res://main_menu.tscn")


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
	components_script.update_occurring_flags()
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
	components_script.update_occurring_flags()
	print("Event ended: ", event_dict)
	
	# Clean up the duration timer node
	end_timer.queue_free()
	
	
	


# COMPONENTS
func update_day_by_day_components() -> void:
	match day_number:
		1:
			components_script.PowerEnabled = true
			components_script.RadiationEnabled = true
			components_script.OxygenEnabled = false
			components_script.ToxicPerchEnabled = false
			components_script.SolarPanEnabled = false
			components_script.StormsEnabled = false
			components_script.SlowStormsEnabled = false
			components_script.FastStormsEnabled = false
			
			components_script.RadiationShieldingEnabled = true
			components_script.AirFilteringEnabled = false
			components_script.CoverSolarPanEnabled = false
		
		2:
			components_script.PowerEnabled = true
			components_script.RadiationEnabled = true
			components_script.OxygenEnabled = true
			components_script.ToxicPerchEnabled = true
			components_script.SolarPanEnabled = false
			components_script.StormsEnabled = false
			components_script.SlowStormsEnabled = false
			components_script.FastStormsEnabled = false
			
			components_script.RadiationShieldingEnabled = true
			components_script.AirFilteringEnabled = true
			components_script.CoverSolarPanEnabled = false
		
		3:
			components_script.PowerEnabled = true
			components_script.RadiationEnabled = true
			components_script.OxygenEnabled = true
			components_script.ToxicPerchEnabled = true
			components_script.SolarPanEnabled = true
			components_script.StormsEnabled = true
			components_script.SlowStormsEnabled = true
			components_script.FastStormsEnabled = true
			
			components_script.RadiationShieldingEnabled = true
			components_script.AirFilteringEnabled = true
			components_script.CoverSolarPanEnabled = true
		
		4:
			components_script.PowerEnabled = true
			components_script.RadiationEnabled = true
			components_script.OxygenEnabled = true
			components_script.ToxicPerchEnabled = true
			components_script.SolarPanEnabled = true
			components_script.StormsEnabled = true
			components_script.SlowStormsEnabled = true
			components_script.FastStormsEnabled = true
			
			components_script.RadiationShieldingEnabled = true
			components_script.AirFilteringEnabled = true
			components_script.CoverSolarPanEnabled = true
		
		5:
			components_script.PowerEnabled = true
			components_script.RadiationEnabled = true
			components_script.OxygenEnabled = true
			components_script.ToxicPerchEnabled = true
			components_script.SolarPanEnabled = true
			components_script.StormsEnabled = true
			components_script.SlowStormsEnabled = true
			components_script.FastStormsEnabled = true
			
			components_script.RadiationShieldingEnabled = true
			components_script.AirFilteringEnabled = true
			components_script.CoverSolarPanEnabled = true

func _updating_tick() -> void:
	components_script.tick_update()
