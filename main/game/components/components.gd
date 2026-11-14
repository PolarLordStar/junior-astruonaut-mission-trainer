extends Node
var preset_values = preload("res://main/libraries/preset_values.gd").new()

# Variables for bars and stuff
var Radiation = 0
var Power = 100 # Placeholder value
var Oxygen = 100 # Placeholder
var ToxicPerch = 0
var SolarPanels = 100 # Placeholder
var OccuringStorm = "None"

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
	
