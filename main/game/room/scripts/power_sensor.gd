# Some usage of AI occured in the script
class_name PowerSensor
extends Sensor
## In the game its value is Components.Power (0 .. MAX_POWER), converted to this sensor's range.
## Power supply (Life Support monitor). Follows the solar panels; dust in the air blocks sunlight.
## FOR NASA DATA: change the numbers below, and/or fill the "Data" array in the Inspector.

# ===== EDIT THESE =====
const ID := "power"
const LABEL := "POWER SUPPLY"
const UNIT := "%"
const POWER_LOW := 30.0   # below this the LOW POWER warning appears
const START := 90.0
# ======================

var _storm: StormSystem
var _panels: Sensor
var _base := START
var _jit := 0.0
var _noise := 0.0
var _tick := 0.0


func _init() -> void:
	id = ID
	label = LABEL
	unit = UNIT
	decimals = 0
	low_is_bad = true
	warn_at = POWER_LOW
	danger_at = POWER_LOW
	value = START


func _ready() -> void:
	_storm = get_tree().get_first_node_in_group("storm") as StormSystem
	_panels = find_sensor("panels")


func get_warning() -> Dictionary:
	if value >= POWER_LOW:
		return {}
	return {"id": id, "title": "LOW POWER", "detail": "%d%% available" % roundi(value),
			"badge": "WARNING", "level": 2}


func _pull_from_components() -> void:
	set_value(_from_components(components.Power, PRESET.MAX_POWER))


func _simulate(delta: float) -> void:
	_tick += delta
	if _tick >= 0.25:
		_tick = 0.0
		_noise = randf_range(-1.2, 1.2)
	# the panels report how many of the 6 work (0-6); turn that into 0-100 for the power maths
	var avg := (_panels.value / maxf(_panels.max_value, 0.01) * 100.0) if _panels != null else 90.0
	var dust := _storm.dust_amt if _storm != null else 0.0
	var sun := 1.0 - 0.55 * clampf(dust, 0.0, 1.0)
	_base = move_toward(_base, (avg * 0.9 + 10.0) * sun, delta * 4.0)
	_jit = lerpf(_jit, _noise, 1.0 - exp(-delta * 6.0))
	value = clampf(_base + _jit, 0.0, 100.0)
