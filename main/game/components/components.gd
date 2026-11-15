extends Node
var preset_values = preload("res://main/libraries/preset_values.gd").new()

# Variables for bars and stuff
var Radiation: int = 0
var Power: int = 0
var Oxygen: int = 0
var ToxicPerch: int = 0
var SolarPanels: int = 0

# Events
var events_for_today = {} # {event : severity}
var events_to_occur = {} # {event : severity} : timer after which it occurs
var events_occurring = {} # {event : severity} : time until it ends

# User actions
var RadiationShieldingEnabled = false
var CoverSolarPanEnabled = false
var AirFilteringEnabled = false
var RadiationShieldingUsing = false
var CoverSolarPanUsing = false
var AirFilteringUsing = false

# Variables which check stuff
var PowerEnabled = false
var RadiationEnabled = false
var OxygenEnabled = false
var ToxicPerchEnabled = false
var SolarPanEnabled = false
var StormsEnabled = false
var SlowStormsEnabled = false
var FastStormsEnabled = false


func decide_events(date) -> void:
	# Deciding Events for Today
	if RadiationEnabled:
		for event in date["events"]:
			print(event["name"], " | severity ", event["severity"])
			events_for_today[event["name"]] = event["severity"]
	
	if StormsEnabled:	
		var storms = StormGenerator.generate(SlowStormsEnabled, FastStormsEnabled)
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
	# ================== INDIVIDUAL COMPONENTS
	
	
	# Radiation Increase AND High Damages Health
	if RadiationEnabled:
		Radiation += preset_values.RADIATION_GCR_INCREASE
		if Radiation >= preset_values.CRITICAL_RADIATION:
			# damage health
			pass
	
	# Low Oxygen Damages Health
	if OxygenEnabled:
		if Radiation < preset_values.CRITICAL_RADIATION:
			# damage health
			pass
	
	# Toxic Perchlorates Increase AND High Damages Health
	if ToxicPerchEnabled:
		ToxicPerch += preset_values.TOXIC_PERCH_DUST_INCREASE
		if ToxicPerch >= preset_values.CRITICAL_TOXIC_PERCH:
			# damage health
			pass
	
	
	# ================== LINKED COMPONENTS
	
	
	# Max Power generated when Solar Panels disabled
	if PowerEnabled and not SolarPanEnabled:
		Power += preset_values.POWER_1SP_INCREASE * preset_values.MAX_SOLAR_PANELS
	
	# Max Power generated when Solar Panels disabled
	if PowerEnabled and SolarPanEnabled:
		Power += preset_values.POWER_1SP_INCREASE * SolarPanels
	
	# Decreases Health if too many Toxic Perchlorates
	if OxygenEnabled and ToxicPerchEnabled:
		if ToxicPerch >= preset_values.MEDIUM_TOXIC_PERCH:
			# damage health
			pass
		
	
	
	
	
	
	
	
	
	
	
	
	
	
	# IGNORE THIS BUCK
	
	
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
	#print("Stats -> Rad: ", Radiation, " | Power: ", Power, " | O2: ", Oxygen)
