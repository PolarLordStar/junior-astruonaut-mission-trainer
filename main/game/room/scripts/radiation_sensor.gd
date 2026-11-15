# Some usage of AI occured in the script
class_name RadiationSensor
extends Sensor
## In the game its value is Components.Radiation (0 .. MAX_RADIATION), converted to this sensor's range.
## Radiation (Environment monitor). Rises when a solar flare approaches and spikes when it hits.
## FOR NASA DATA: change the numbers below, and/or fill the "Data" array in the Inspector.

# ===== EDIT THESE (placeholders, replace with real limits) =====
const ID := "radiation"
const LABEL := "RADIATION"
const UNIT := "mSv/h"
const DECIMALS := 2
const MIN := 0.0          # bar range
const MAX := 1.2
const WARN := 0.55        # amber above this
const DANGER := 0.70      # red above this
const NORMAL := 0.42      # resting value for the simulation
# ================================================================

var _storm: StormSystem
var _base := NORMAL
var _jit := 0.0
var _noise := 0.0
var _tick := 0.0


func _init() -> void:
	id = ID
	label = LABEL
	unit = UNIT
	decimals = DECIMALS
	min_value = MIN
	max_value = MAX
	warn_at = WARN
	danger_at = DANGER
	warn_title = "ELEVATED RADIATION"
	danger_title = "HIGH RADIATION"
	show_on_environment = true
	value = NORMAL


func _ready() -> void:
	_storm = get_tree().get_first_node_in_group("storm") as StormSystem


func _pull_from_components() -> void:
	set_value(_from_components(components.Radiation, PRESET.MAX_RADIATION))


func _simulate(delta: float) -> void:
	_tick += delta
	if _tick >= 0.25:
		_tick = 0.0
		_noise = randf_range(-0.04, 0.04)
	var target := NORMAL
	if _storm != null and _storm.kind == "SOLAR FLARE":
		if _storm.phase == 1:
			target = 0.52
		elif _storm.phase == 2:
			target = 0.62 + 0.18 * _storm.level
	_base = move_toward(_base, target, delta * 0.12)
	_jit = lerpf(_jit, _noise, 1.0 - exp(-delta * 6.0))
	value = clampf(_base + _jit, 0.2, 1.2)
