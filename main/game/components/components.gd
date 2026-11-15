extends Node
var preset_values = preload("res://main/libraries/preset_values.gd").new()

const SOLAR_EVENTS = ["Tiny Sun Flash", "Small Sun Flash", "Medium Sun Flash",
	"Giant Sun Flash", "Solar Cloud Incoming", "Radiation Storm"]
const SLOW_STORMS = ["Electrostatic Dust Accumulation", "Regional Dust Front"]
const FAST_STORMS = ["High-Velocity Dust Devil", "Global Regolith Blitz"]

# Variables for bars and stuff
@export var Radiation: int = 0
@export var Power: int = 0
@export var Oxygen: int = 0
@export var ToxicPerch: int = 0
@export var SolarPanels: int = 0

# Events
@export var events_for_today = {} # {event : severity}
@export var events_to_occur = {} # {event : severity} : timer after which it occurs
@export var events_occurring = {} # {event : severity} : time until it ends

@export var SolarEventOccurring = false
enum STORMS {NONE, SLOW, FAST}
@export var StormOccurring = STORMS.NONE

# User actions
@export var RadiationShieldingEnabled = false
@export var CoverSolarPanEnabled = false
@export var AirFilteringEnabled = false
@export var RadiationShieldingUsing = false
@export var CoverSolarPanUsing = false
@export var AirFilteringUsing = false

# Variables which check stuff
@export var PowerEnabled = false
@export var RadiationEnabled = false
@export var OxygenEnabled = false
@export var ToxicPerchEnabled = false
@export var SolarPanEnabled = false
@export var StormsEnabled = false
@export var SlowStormsEnabled = false
@export var FastStormsEnabled = false


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
		if Radiation > 100:
			Radiation = 100
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
		if ToxicPerch > 100:
			ToxicPerch = 100
		if ToxicPerch >= preset_values.CRITICAL_TOXIC_PERCH:
			# damage health
			pass
	
	
	# ================== LINKED COMPONENTS
	
	
	# Max Power generated when Solar Panels disabled
	if PowerEnabled and not SolarPanEnabled:
		Power += preset_values.POWER_1SP_INCREASE * preset_values.MAX_SOLAR_PANELS
		if Power > 100:
			Power = 100
	
	# Max Power generated when Solar Panels enabled UNLESS Solar Panels Covered
	if PowerEnabled and SolarPanEnabled and not CoverSolarPanUsing:
		Power += preset_values.POWER_1SP_INCREASE * SolarPanels
		if Power > 100:
			Power = 100
	
	# Decreases Oxygen if Medium Toxic Perchlorates
	if OxygenEnabled and ToxicPerchEnabled:
		if ToxicPerch >= preset_values.MEDIUM_TOXIC_PERCH:
			# decreases oxygen
			Oxygen -= preset_values.OXYGEN_TP_DECREASE
			if Oxygen < 0:
				Oxygen = 0
	
	
	# ================== EVENT COMPONENTS
	
	
	# Damage Solar Panel Chance
	if StormsEnabled and SolarPanEnabled:
		if StormOccurring == STORMS.SLOW:
			if randf() >= preset_values.SLOW_STORM_SP_DAMAGE_CHANCE:
				SolarPanels -= 1
		if StormOccurring == STORMS.FAST:
			if randf() >= preset_values.FAST_STORM_SP_DAMAGE_CHANCE:
				SolarPanels -= 1
		if SolarPanels < 0:
			SolarPanels = 0
	
	# Increases Toxic Perchlorates MASSIVELY if Storm
	if ToxicPerchEnabled and StormsEnabled and StormOccurring != STORMS.NONE:
		ToxicPerch += preset_values.TOXIC_PERCH_STORM_INCREASE
		if ToxicPerch > 100:
			ToxicPerch = 100
	
	# Increase Radiation MASSIVELY if Solar Event
	if RadiationEnabled and SolarEventOccurring:
		Radiation += preset_values.RADIATION_SOLAR_EVENT_INCREASE
		if Radiation > 100:
			Radiation = 100
	
	# ================== EVENT COMPONENTS
	
	
	# Decrease Radiation if Radiation Shielding
	if RadiationEnabled and RadiationShieldingEnabled and RadiationShieldingUsing:
		Radiation -= preset_values.RADIATION_SHIELDING_RADIATION_DECREASE
		Power -= preset_values.RADIATION_SHIELDING_POWER_DECREASE
		if Radiation < 0:
			Radiation = 0
		# stops button if insufficient power
		if Power < preset_values.RADIATION_SHIELDING_RADIATION_DECREASE:
			RadiationShieldingUsing = false
	
	# Decreases Toxic Perchlorates if Air Filtering
	if ToxicPerchEnabled and OxygenEnabled and AirFilteringEnabled and AirFilteringUsing:
		ToxicPerch -= preset_values.AIR_FILTERING_TP_DECREASE
		Power -= preset_values.AIR_FILTERING_POWER_DECREASE
		if ToxicPerch < 0:
			Radiation = 0
		# stops button if insufficient power
		if Power < preset_values.AIR_FILTERING_POWER_DECREASE:
			AirFilteringUsing = false
	
	
	
	
	
	print("Storm Occurring: " + str(StormOccurring) + " | Solar Event Occurring: " + str(SolarEventOccurring))
	print("Rad: " + str(Radiation) + " | Power: " + str(Power) + " | O2: " + str(Oxygen) + " | SP: " + str(SolarPanels) + " | TP: " + str(ToxicPerch))


func update_occurring_flags() -> void:
	StormOccurring = STORMS.NONE
	SolarEventOccurring = false

	for event_dict in events_occurring:
		var event_name: String = event_dict.keys()[0].trim_suffix("!")
		if event_name in FAST_STORMS:
			StormOccurring = STORMS.FAST
		elif event_name in SLOW_STORMS and StormOccurring != STORMS.FAST:
			StormOccurring = STORMS.SLOW
		elif event_name in SOLAR_EVENTS:
			SolarEventOccurring = true
