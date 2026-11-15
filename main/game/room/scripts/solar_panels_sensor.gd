# Some usage of AI occured in the script
class_name SolarPanelsSensor
extends Sensor
## In the game its value is Components.SolarPanels (0 .. MAX_SOLAR_PANELS), converted to this sensor's range.
## The 6 solar panels (Life Support monitor). Each panel is simply working or not working.
## "value" is the number of working panels, 0-6 (shown in the number box on the monitor);
## PowerSensor uses it too.
## Dust storms break panels one at a time; some panels get hit harder than others.
## A broken panel stays broken (nothing repairs it yet).
## FOR NASA DATA (Simulate off): call set_panels([true, true, false, true, true, true]) (1 / 0 work too),
## or set_value(4) to say "4 panels work" (the first 4 are shown as working).
## (A "Data" array here is a list of working-panel counts.)

# ===== EDIT THESE =====
const ID := "panels"
const LABEL := "NUMBER OF SOLAR PANELS"
const UNIT := ""
const PANEL_TOTAL := 6                                   # how many panels there are = the highest count
const PANEL_EXPOSURE := [1.2, 0.8, 1.0, 1.5, 0.6, 1.0]  # per-panel dust wear multiplier
# Wear per second of storm (times the storm level and the panel's exposure). A panel breaks
# when its wear reaches 1.0. Raise these to make panels break faster.
const WEAR_DUST_STORM := 0.0072
const WEAR_DUST_DEVIL := 0.0036
# ======================

var panels: Array[bool] = [true, true, true, true, false, true]   # true = working
var _wear: Array[float] = []   # damage building up on each panel; at 1.0 the panel breaks
var _storm: StormSystem


func _init() -> void:
	id = ID
	label = LABEL
	unit = UNIT
	decimals = 0
	min_value = 0.0
	max_value = float(PANEL_TOTAL)
	low_is_bad = true
	warn_at = 5.0     # yellow below 5 (3-4 working)
	danger_at = 3.0   # red below 3    (0-2 working)


func _ready() -> void:
	_storm = get_tree().get_first_node_in_group("storm") as StormSystem
	_wear.resize(panels.size())
	_wear.fill(0.0)
	_recalc()


## No warning card for panels (add one here if you want).
func get_warning() -> Dictionary:
	return {}


func set_panels(list: Array) -> void:
	for i in mini(list.size(), panels.size()):
		panels[i] = bool(list[i])
	_recalc()


## "v panels work": the first v are working, the rest are not.
func set_value(v: float) -> void:
	var n := clampi(roundi(v), 0, panels.size())
	for i in panels.size():
		panels[i] = i < n
	_recalc()


func _recalc() -> void:
	var working := 0
	for p in panels:
		if p:
			working += 1
	value = float(working)


func _pull_from_components() -> void:
	set_value(_from_components(components.SolarPanels, PRESET.MAX_SOLAR_PANELS))


func _simulate(delta: float) -> void:
	if _storm != null and _storm.phase == 2 and _storm.kind.begins_with("DUST"):
		var pace := WEAR_DUST_STORM if _storm.kind == "DUST STORM" else WEAR_DUST_DEVIL
		var wear := pace * _storm.level * delta
		for i in panels.size():
			if not panels[i]:
				continue
			_wear[i] += wear * PANEL_EXPOSURE[i % PANEL_EXPOSURE.size()]
			if _wear[i] >= 1.0:
				_wear[i] = 0.0
				panels[i] = false
	_recalc()
