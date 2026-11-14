extends Node
var preset_values = preload("res://main/libraries/preset_values.gd")
var game_script = preload("res://main/game/game.gd")

# Variables for bars and stuff
var Radiation = 0
var Power = 100 # Placeholder value
var Oxygen = 100 # Placeholder
var ToxicPerch = 0
var SolarPanels = 100 # Placeholder
var OccuringStorm = "None"
var events = {}

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


func _process(delta: float) -> void:
	if RadiationEnabled:
		# check events for current date through api
			# get date using game_script.date
			# if there is an event on this date
				events["EVENT_NAME"] = preset_values.EVEN
	
