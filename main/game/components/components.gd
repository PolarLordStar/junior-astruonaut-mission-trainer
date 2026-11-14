extends Node
var preset_values = preload("res://main/libraries/preset_values.gd").new()
var game_script = preload("res://main/game/game.gd").new()

# Variables for bars and stuff
var Radiation = 0
var Power = 100 # Placeholder value
var Oxygen = 100 # Placeholder
var ToxicPerch = 0
var SolarPanels = 100 # Placeholder
var OccuringStorm = "None"

# Events
var events_for_today = []
var events_to_occur = {} # event_name_severity : timer after which it occurs
var events_occurring = {} # event_name_severity : time until it ends

# User actions
var RadiationShielding = false
var CoverSolarPan = false
var AirFiltering = false

# Variables which check stuff
var PowerEnabled = false
var RadiationEnabled = false
var OxygenEnabled = false
var ToxicPerchEnabled = false
var SolarPanEnabled = false
var StormsEnabled = false


func start() -> void:
	# Deciding Events for Today
	if RadiationEnabled:
		for event in game_script.date["events"]:
			print(event["name"], " | severity ", event["severity"])
			events_for_today.append(event["name"] + "_" + event["severity"])
	
	if StormsEnabled:
		# ...
		pass
	
	
	# Deciding When Events Will Occur
	
	
