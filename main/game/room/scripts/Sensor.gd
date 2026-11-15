# Some usage of AI occured in the script
class_name Sensor
extends Node
## Base class for ONE stat on the control-room monitors (radiation, oxygen, power ...).
## You never add a plain "Sensor" node. Add one of its children instead:
## RadiationSensor, OxygenSensor, PerchlorateSensor, PowerSensor, SolarPanelsSensor (or your own).
##
## In the real game a sensor takes its number from the Components object that the Game node owns
## (the "Components" child node of Game, see main/game/components/components.gd): Radiation, Power, Oxygen,
## ToxicPerch and SolarPanels. That is the game state, so the monitors always show what Components
## holds. Components values run from 0 up to their MAX in main/libraries/preset_values.gd; each
## sensor converts that to its own range below. The sensor finds Components by itself (it looks
## through its parents for a node that has a child named "Components"), so nothing has to be wired up.
##
## Otherwise (no Game around, e.g. you run control_room.tscn on its own, or "Use Components" is off)
## there are three ways a sensor gets its number:
##   1. simulate = true (default): the sensor's own _simulate() invents believable numbers.
##   2. simulate = false and the "Data" array filled in the Inspector: it plays your list of real
##      values, one every "Seconds Per Sample"   <-- paste NASA numbers here.
##   3. simulate = false and your own code calling  sensor.set_value(12.3)  whenever a reading arrives.
##
## Label, unit, range and warning limits are constants at the top of each sensor's script.

# ---- filled in by each sensor script in _init() (do not edit here) ----
var id := ""
var label := ""
var unit := ""
var decimals := 1
var min_value := 0.0
var max_value := 100.0
var low_is_bad := false
var warn_at := INF
var danger_at := INF
var warn_title := ""
var danger_title := ""
var show_on_environment := false   # true = gets a row on the Environment monitor

# ---- editable in the Inspector ----
@export_group("Data source")
## ON = read the value from the game's Components object (when there is one). OFF = use the options below.
@export var use_components := true
## ON = built-in simulation. OFF = use the Data array below (or your own set_value() calls).
@export var simulate := true
## Real measurements, one number per sample (used when Simulate is off).
@export var data: PackedFloat32Array = PackedFloat32Array()
@export var seconds_per_sample := 2.0
@export var loop_data := true

## Used to turn a Components value (0 .. MAX_xxx) into this sensor's own range.
const PRESET := preload("res://main/libraries/preset_values.gd")

var value := 0.0
var _data_t := 0.0
var components   # the Components node (components.gd) that is a child of Game; null when there is no Game


## Registered here (not in _init) so it always happens, whatever the child scripts do in their own _init.
func _enter_tree() -> void:
	add_to_group("sensors")
	components = _find_components()
	if use_components and components != null:
		_pull_from_components()   # so the very first frame already shows the real value


func _process(delta: float) -> void:
	if use_components and components != null:
		_pull_from_components()
	elif simulate:
		_simulate(delta)
	elif data.size() > 0:
		_data_t += delta
		var i := int(_data_t / maxf(seconds_per_sample, 0.01))
		if loop_data:
			i = i % data.size()
		else:
			i = mini(i, data.size() - 1)
		set_value(data[i])


## Looks up through the parents for the node that has a child named "Components" (the Game node) and returns that Components node.
func _find_components():
	var n := get_parent()
	while n != null:
		if n.has_node("Components"):
			return n.get_node("Components")
		n = n.get_parent()
	return null


## Override in each sensor: read the matching variable from "components" and call set_value().
func _pull_from_components() -> void:
	pass


## Converts a Components value (0 .. components_max) into this sensor's own range (min_value .. max_value).
func _from_components(v, components_max: float) -> float:
	return remap(float(v), 0.0, components_max, min_value, max_value)


## Override in each sensor: update "value" here (used when there is no Components).
func _simulate(_delta: float) -> void:
	pass


## Feed a real reading from your own code.
func set_value(v: float) -> void:
	value = v


## 0 = normal, 1 = warn (amber), 2 = danger (red)
func level() -> int:
	if low_is_bad:
		return 2 if value < danger_at else (1 if value < warn_at else 0)
	return 2 if value > danger_at else (1 if value > warn_at else 0)


func format_value() -> String:
	return ("%." + str(decimals) + "f") % value


## Second line of the warning card. Override for custom text.
func detail() -> String:
	return "%s %s" % [format_value(), unit]


## The warning this sensor wants on monitor 3 right now, or {} for none.
func get_warning() -> Dictionary:
	var lv := level()
	if lv == 0:
		return {}
	return {
		"id": id,
		"title": danger_title if lv == 2 else warn_title,
		"detail": detail(),
		"badge": "CRITICAL" if lv == 2 else "CAUTION",
		"level": 3 if lv == 2 else 1,
	}


## What the Environment monitor needs to build this sensor's row.
func row_cfg() -> Dictionary:
	return {"id": id, "label": label, "unit": unit, "min": min_value, "max": max_value,
			"warn": warn_at, "danger": danger_at, "low_is_bad": low_is_bad, "decimals": decimals}


func find_sensor(sensor_id: String) -> Sensor:
	for n in get_tree().get_nodes_in_group("sensors"):
		var s := n as Sensor
		if s != null and s.id == sensor_id:
			return s
	return null
