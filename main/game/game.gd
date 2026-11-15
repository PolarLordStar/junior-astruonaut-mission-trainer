extends Node
var preset_values = preload("res://main/libraries/preset_values.gd").new()
var player_script = preload("res://main/game/player/player.gd").new()
var save_script = preload("res://scripts/save_manager.gd").new()
var components_script = preload("res://main/game/components/components.gd").new()
@onready var day_counter: CanvasLayer = $DayCounter

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
	
	# Control-room ambience (it is stopped when the player dies, so start it again for the new attempt)
	var ambience := _get_ambience()
	if ambience != null:
		ambience.play_ambience()
	
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
	if day_number < preset_values.MAX_DAYS:
		start()
	# ...screen saying day number survived
func _ready() -> void:
	player_script.hurt.connect(_on_player_hurt)
	player_script.died.connect(_on_player_died)
	start()


# PLAYER SOUNDS (scripts/game_sounds.gd, room/scripts/ambience_player.gd)
func _on_player_hurt() -> void:
	GameSounds.play_hurt()


func _on_player_died() -> void:
	GameSounds.play_death()
	var ambience := _get_ambience()
	if ambience != null:
		ambience.stop_ambience()   # the control room goes quiet when the player dies


func _get_ambience() -> AmbiencePlayer:
	return get_tree().get_first_node_in_group("ambience") as AmbiencePlayer


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
