class_name OxygenSensor
extends Sensor
## In the game its value is Components.Oxygen (0 .. MAX_OXYGEN), converted to this sensor's range.
## Oxygen level. Feeds the Life Support monitor ("oxygen supply" bar) and the low-oxygen warnings.
## It has NO row on the Environment monitor any more (set show_on_environment = true to bring it back). Drains faster when power is low; a reserve tank
## refills it when it runs out.
## FOR NASA DATA: change the numbers below, and/or fill the "Data" array in the Inspector.

# ===== EDIT THESE (placeholders, replace with real limits) =====
const ID := "oxygen"
const LABEL := "OXYGEN LEVEL"
const UNIT := "%"
const DECIMALS := 0
const MIN := 0.0
const MAX := 100.0
const WARN := 70.0        # amber BELOW this (low is bad)
const DANGER := 50.0      # red BELOW this
const START := 90.0
const O2_DRAIN := 0.4     # % used per second (simulation)
# ================================================================

var _power: Sensor
var _refill := false


func _init() -> void:
	id = ID
	label = LABEL
	unit = UNIT
	decimals = DECIMALS
	min_value = MIN
	max_value = MAX
	low_is_bad = true
	warn_at = WARN
	danger_at = DANGER
	warn_title = "OXYGEN DROPPING"
	danger_title = "LOW OXYGEN SUPPLY"
	show_on_environment = false   # no row on the Environment monitor (the Life Support bar still uses this sensor)
	value = START


func _ready() -> void:
	_power = find_sensor("power")


func detail() -> String:
	return "%d%% remaining" % roundi(value)


func _pull_from_components() -> void:
	set_value(_from_components(components.Oxygen, PRESET.MAX_OXYGEN))


func _simulate(delta: float) -> void:
	var power := _power.value if _power != null else 90.0
	var drain := O2_DRAIN
	if power < 40.0:
		drain += (40.0 - power) / 40.0 * 0.4
	if _refill:
		value = minf(100.0, value + 6.0 * delta)
		if value >= 95.0:
			_refill = false
	else:
		value = maxf(0.0, value - drain * delta)
		if value <= 12.0:
			_refill = true
