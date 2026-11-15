extends Node
var preset_values = preload("res://main/libraries/preset_values.gd").new()

# Variables for bars and stuff
var Radiation = 0
var Power = 0
var Oxygen = 0
var ToxicPerch = 0
var SolarPanels = 0

# Events
var events_for_today = {} # {event : severity}
var events_to_occur = {} # {event : severity} : timer after which it occurs
var events_occurring = {} # {event : severity} : time until it ends

# User actions
var RadiationShielding = false
var CoverSolarPan = false
var AirFiltering = false

# Variables which check stuff
var PowerEnabled = false
var RadiationEnabled = true
var OxygenEnabled = false
var ToxicPerchEnabled = false
var SolarPanEnabled = false
var StormsEnabled = true


func decide_events(date, day_number: int) -> void:
	# Deciding Events for Today
	if RadiationEnabled:
		for event in date["events"]:
			print(event["name"], " | severity ", event["severity"])
			events_for_today[event["name"]] = event["severity"]
	
	if StormsEnabled:	
		var storms = StormGenerator.generate(day_number)
		for storm in storms:
			events_for_today[storm] = storms[storm]
	
	# Deciding When Events Will Occur
	for event_name in events_for_today:
		var severity = events_for_today[event_name]
		var chosen_time: float = 0.0
		var valid_time: bool = false
		var attempts: int = 0
		
		# Keep rolling a random time until it is far enough from existing events
		while not valid_time and attempts < 100:
			attempts += 1
			chosen_time = snappedf(randf_range(preset_values.MIN_EVENT_TIME, preset_values.MAX_EVENT_TIME), 0.1)
			valid_time = true
			
			# Check against all scheduled times stored as values
			for existing_time in events_to_occur.values():
				if abs(chosen_time - existing_time) < preset_values.MIN_TIME_GAP:
					valid_time = false
					break
		
		if not valid_time:
			push_warning("Could not find ideal time gap for: " + str(event_name))
		
		# Use the single-pair dictionary as the key and the timestamp as the value
		var event_key: Dictionary = { event_name: severity }
		events_to_occur[event_key] = chosen_time
	
	print("Scheduled events: ", events_to_occur)

# Counts both event timers down (called every frame by game.gd, so they stop while the game is paused).
# The monitors read these numbers: events_to_occur = seconds until it occurs, events_occurring = seconds until it ends.
func update_event_timers(delta: float) -> void:
	for event in events_to_occur:
		events_to_occur[event] = maxf(0.0, events_to_occur[event] - delta)
	for event in events_occurring:
		events_occurring[event] = maxf(0.0, events_occurring[event] - delta)


func tick_update() -> void:
	pass
	## 1. Baseline changes that happen every tick (even without events)
	#Oxygen -= 0.5
	#Power += (SolarPanels / 100.0) * 1.0
	#
	## 2. Apply effects from any active events in events_occurring
	#for event_dict in events_occurring:
		#var event_name: String = event_dict.keys()[0]
		#var severity: int = event_dict[event_name]
		#
		#match event_name:
			#"Solar Cloud Incoming":
				#Radiation += 2.0 * severity
				#SolarPanels -= 1.0 * severity
			#"Toxic Storm":
				#ToxicPerch += 1.5 * severity
				#Oxygen -= 1.0 * severity
			## Add more event names here as needed
	#
	## 3. Keep values within valid bounds
	#Radiation = clampf(Radiation, 0.0, 100.0)
	#Power = clampf(Power, 0.0, 100.0)
	#Oxygen = clampf(Oxygen, 0.0, 100.0)
	#ToxicPerch = clampf(ToxicPerch, 0.0, 100.0)
	#SolarPanels = clampf(SolarPanels, 0.0, 100.0)
	#
	#print("Stats -> Rad: ", Radiation, " | Power: ", Power, " | O2: ", Oxygen)
