class_name PerchlorateSensor
extends Sensor
## Toxic perchlorate in the cabin air (Environment monitor). Rises during dust storms.
## FOR NASA DATA: change the numbers below, and/or fill the "Data" array in the Inspector.

# ===== EDIT THESE (placeholders, replace with real limits) =====
const ID := "perchlorate"
const LABEL := "TOXIC PERCHLORATE"
const UNIT := "mg/m³"
const DECIMALS := 2
const MIN := 0.0
const MAX := 1.0
const WARN := 0.4
const DANGER := 0.7
const NORMAL := 0.06
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
	warn_title = "PERCHLORATE RISING"
	danger_title = "TOXIC PERCHLORATE"
	show_on_environment = true
	value = NORMAL


func _ready() -> void:
	_storm = get_tree().get_first_node_in_group("storm") as StormSystem


func _simulate(delta: float) -> void:
	_tick += delta
	if _tick >= 0.25:
		_tick = 0.0
		_noise = randf_range(-0.008, 0.008)
	var target := NORMAL
	if _storm != null and _storm.kind.begins_with("DUST"):
		if _storm.phase == 1:
			target = 0.12
		elif _storm.phase == 2:
			target = 0.2 + 0.18 * _storm.level
	_base = move_toward(_base, target, delta * 0.05)
	_jit = lerpf(_jit, _noise, 1.0 - exp(-delta * 6.0))
	value = clampf(_base + _jit, 0.0, 1.0)
