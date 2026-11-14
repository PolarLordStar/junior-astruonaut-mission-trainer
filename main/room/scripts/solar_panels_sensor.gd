class_name SolarPanelsSensor
extends Sensor
## The 6 solar panels (Life Support monitor). "value" is the average durability.
## Dust storms wear the panels down; some panels get hit harder than others.
## FOR NASA DATA: call set_panels([96, 91, 88, 94, 79, 85]) with real numbers (Simulate off).
## (A "Data" array here sets ALL panels to the same number.)

# ===== EDIT THESE =====
const ID := "panels"
const LABEL := "SOLAR PANEL DURABILITY"
const UNIT := "%"
const PANEL_EXPOSURE := [1.2, 0.8, 1.0, 1.5, 0.6, 1.0]   # per-panel dust wear multiplier
# ======================

var panels: Array[float] = [96.0, 91.0, 88.0, 94.0, 79.0, 85.0]   # 0-100 %
var _storm: StormSystem


func _init() -> void:
	id = ID
	label = LABEL
	unit = UNIT
	decimals = 0
	low_is_bad = true
	warn_at = 50.0
	danger_at = 25.0


func _ready() -> void:
	_storm = get_tree().get_first_node_in_group("storm") as StormSystem
	_recalc()


## No warning card for panels (add one here if you want).
func get_warning() -> Dictionary:
	return {}


func set_panels(list: Array) -> void:
	for i in mini(list.size(), panels.size()):
		panels[i] = float(list[i])
	_recalc()


func set_value(v: float) -> void:
	panels.fill(v)
	_recalc()


func _recalc() -> void:
	var avg := 0.0
	for p in panels:
		avg += p
	value = avg / panels.size()


func _simulate(delta: float) -> void:
	if _storm != null and _storm.phase == 2 and _storm.kind.begins_with("DUST"):
		var wear := (0.12 if _storm.kind == "DUST STORM" else 0.06) * _storm.level * delta
		for i in panels.size():
			panels[i] = maxf(5.0, panels[i] - wear * PANEL_EXPOSURE[i % PANEL_EXPOSURE.size()])
	_recalc()
