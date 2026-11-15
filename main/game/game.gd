extends Node
var preset_values = preload("res://main/libraries/preset_values.gd").new()
var save_script = preload("res://scripts/save_manager.gd").new()
@onready var components_scene = get_node("Components")
@onready var health_scene = get_node("Health")
@onready var player_sounds = $PlayerSounds
@onready var day_counter: CanvasLayer = $DayCounter
@onready var day_transition: CanvasLayer = $DayTransition   # "You have survived!" screen (ui/day_transition.tscn)
@onready var _status_screen: ScreenUI = $ControlRoom/StatusViewport/StatusScreen
@onready var _env_screen: EnvironmentScreen = $ControlRoom/EnvironmentViewport/EnvironmentScreen
@onready var storm_system: StormSystem = $ControlRoom/StormSystem
@onready var _room = $ControlRoom

var day_number: int = save_script.load_day()
var date

func setup() -> void:
	# Resetting Values
	health_scene.Health = preset_values.MAX_HEALTH
	components_scene.Radiation = preset_values.RADIATION
	components_scene.Power = preset_values.POWER
	components_scene.Oxygen = preset_values.OXYGEN
	components_scene.ToxicPerch = preset_values.TOXIC_PERCH
	components_scene.SolarPanels = preset_values.SOLAR_PANELS
	
	components_scene.AirFilteringUsing = false
	components_scene.CoverSolarPanUsing = false
	components_scene.RadiationShieldingUsing = false
	
	# Control-room ambience (it is stopped when the player dies, so start it again for the new attempt)
	player_sounds.start_ambience()
	
	day_number += 1
	date = await DonkiService.fetch_random_day()
	
	# Enabling Day-Dependent Components
	update_day_by_day_components()
	
	# Events
	components_scene.events_for_today = {}
	components_scene.events_to_occur = {}
	components_scene.events_occurring = {}
	components_scene.SolarEventOccurring = false
	components_scene.StormOccurring = components_scene.STORMS.NONE
	storm_system.stop_storm()
	components_scene.decide_events(date)
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
	save_script.save_day(day_number)
	get_tree().paused = true
	day_transition.show_transition(day_number < preset_values.MAX_DAYS)

func _on_transition_continue() -> void:
	$Timers/DayTimer.wait_time = preset_values.DAY_DURATION
	get_tree().paused = false
	start()

func _on_transition_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://main_menu.tscn")

func _ready() -> void:
	day_transition.continue_pressed.connect(_on_transition_continue)
	day_transition.main_menu_pressed.connect(_on_transition_main_menu)
	_status_screen.show_power()
	_status_screen.hide_oxygen()
	_status_screen.hide_solar_panels()
	_env_screen.show_radiation()
	_env_screen.hide_perchlorate()
	_room.show_radiation_shielding_button()
	_room.hide_air_filtering_button()
	_room.hide_cover_solar_panels_button()
	
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
	components_scene.update_event_timers(delta)   # live countdowns shown on the 3rd monitor


func start_event_timers() -> void:
	# Clear any leftover event timers from the previous day
	for child in $Timers.get_children():
		if child.name != "DayTimer" && child.name != "TickUpdateTimer":
			child.queue_free()
	
	
	# Loop through each {event: severity} : delay_time pair
	for event_dict in components_scene.events_to_occur:
		var delay_time: float = components_scene.events_to_occur[event_dict]
		
		var event_timer = Timer.new()
		event_timer.wait_time = delay_time
		event_timer.one_shot = true
		$Timers.add_child(event_timer)
		
		# Connect timeout signal and pass the event data and presets
		event_timer.timeout.connect(_on_event_timer_timeout.bind(event_dict, preset_values.EVENT_DURATION, event_timer))
		event_timer.start()

func _on_event_timer_timeout(event_dict: Dictionary, duration: float, start_timer: Timer) -> void:
	# 1. Move the event from events_to_occur to events_occurring
	components_scene.events_to_occur.erase(event_dict)
	components_scene.events_occurring[event_dict] = duration
	update_event_visuals()
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
	components_scene.events_occurring.erase(event_dict)
	update_event_visuals()
	print("Event ended: ", event_dict)
	
	# Clean up the duration timer node
	end_timer.queue_free()
	
	


# COMPONENTS
func update_day_by_day_components() -> void:
	match day_number:
		1:
			components_scene.PowerEnabled = true
			components_scene.RadiationEnabled = true
			components_scene.OxygenEnabled = false
			components_scene.ToxicPerchEnabled = false
			components_scene.SolarPanEnabled = false
			
			_status_screen.show_power()
			_status_screen.hide_oxygen()
			_status_screen.hide_solar_panels()
			_env_screen.show_radiation()
			_env_screen.hide_perchlorate()
			
			components_scene.StormsEnabled = false
			components_scene.SlowStormsEnabled = false
			components_scene.FastStormsEnabled = false
			
			components_scene.RadiationShieldingEnabled = true
			components_scene.AirFilteringEnabled = false
			components_scene.CoverSolarPanEnabled = false
			_room.show_radiation_shielding_button()
			_room.hide_air_filtering_button()
			_room.hide_cover_solar_panels_button()
		
		2:
			components_scene.PowerEnabled = true
			components_scene.RadiationEnabled = true
			components_scene.OxygenEnabled = true
			components_scene.ToxicPerchEnabled = true
			components_scene.SolarPanEnabled = false
			
			_status_screen.show_power()
			_status_screen.show_oxygen()
			_status_screen.hide_solar_panels()
			_env_screen.show_radiation()
			_env_screen.show_perchlorate()
			
			components_scene.StormsEnabled = false
			components_scene.SlowStormsEnabled = false
			components_scene.FastStormsEnabled = false
			
			components_scene.RadiationShieldingEnabled = true
			components_scene.AirFilteringEnabled = true
			components_scene.CoverSolarPanEnabled = false
			_room.show_radiation_shielding_button()
			_room.show_air_filtering_button()
			_room.hide_cover_solar_panels_button()
		
		3:
			components_scene.PowerEnabled = true
			components_scene.RadiationEnabled = true
			components_scene.OxygenEnabled = true
			components_scene.ToxicPerchEnabled = true
			components_scene.SolarPanEnabled = true
			
			_status_screen.show_power()
			_status_screen.show_oxygen()
			_status_screen.show_solar_panels()
			_env_screen.show_radiation()
			_env_screen.show_perchlorate()
			
			components_scene.StormsEnabled = true
			components_scene.SlowStormsEnabled = true
			components_scene.FastStormsEnabled = true
			
			components_scene.RadiationShieldingEnabled = true
			components_scene.AirFilteringEnabled = true
			components_scene.CoverSolarPanEnabled = true
			_room.show_radiation_shielding_button()
			_room.show_air_filtering_button()
			_room.show_cover_solar_panels_button()
		
		4:
			components_scene.PowerEnabled = true
			components_scene.RadiationEnabled = true
			components_scene.OxygenEnabled = true
			components_scene.ToxicPerchEnabled = true
			components_scene.SolarPanEnabled = true
			
			_status_screen.show_power()
			_status_screen.show_oxygen()
			_status_screen.show_solar_panels()
			_env_screen.show_radiation()
			_env_screen.show_perchlorate()
			
			components_scene.StormsEnabled = true
			components_scene.SlowStormsEnabled = true
			components_scene.FastStormsEnabled = true
			
			components_scene.RadiationShieldingEnabled = true
			components_scene.AirFilteringEnabled = true
			components_scene.CoverSolarPanEnabled = true
			_room.show_radiation_shielding_button()
			_room.show_air_filtering_button()
			_room.show_cover_solar_panels_button()
		
		5:
			components_scene.PowerEnabled = true
			components_scene.RadiationEnabled = true
			components_scene.OxygenEnabled = true
			components_scene.ToxicPerchEnabled = true
			components_scene.SolarPanEnabled = true
			
			_status_screen.show_power()
			_status_screen.show_oxygen()
			_status_screen.show_solar_panels()
			_env_screen.show_radiation()
			_env_screen.show_perchlorate()
			
			components_scene.StormsEnabled = true
			components_scene.SlowStormsEnabled = true
			components_scene.FastStormsEnabled = true
			
			components_scene.RadiationShieldingEnabled = true
			components_scene.AirFilteringEnabled = true
			components_scene.CoverSolarPanEnabled = true
			_room.show_radiation_shielding_button()
			_room.show_air_filtering_button()
			_room.show_cover_solar_panels_button()

func _updating_tick() -> void:
	components_scene.tick_update()


func update_event_visuals() -> void:
	var solar_active := false
	var solar_level := 1
	var storm_active := false
	var storm_level := 1

	for event_dict in components_scene.events_occurring:
		var ev_name: String = str(event_dict.keys()[0])
		var severity: int = int(event_dict[ev_name])
		var clean_name := ev_name.trim_suffix("!")
		if clean_name in components_scene.SOLAR_EVENTS:
			solar_active = true
			solar_level = maxi(solar_level, severity)
		elif clean_name in components_scene.FAST_STORMS:
			storm_active = true
			storm_level = 3
		elif clean_name in components_scene.SLOW_STORMS:
			storm_active = true
			storm_level = maxi(storm_level, 1)

	if solar_active:
		_show_visual("SOLAR FLARE", solar_level)
	elif storm_active:
		_show_visual("DUST STORM", storm_level)
	else:
		storm_system.stop_storm()


func _show_visual(kind: String, level: int) -> void:
	level = clampi(level, 1, 3)
	if storm_system.phase == 2 and storm_system.kind == kind and storm_system.level == level:
		return   # already showing exactly this
	storm_system.start_storm(kind, level, 0.0, preset_values.EVENT_DURATION)
