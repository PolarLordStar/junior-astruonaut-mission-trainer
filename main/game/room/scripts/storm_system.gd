# Some usage of AI occured in the script
class_name StormSystem
extends Node
## Mars weather events (dust storm, solar flare, dust devil). Other sensors and the room visuals
## read from here.
##
## NOTHING STARTS BY ITSELF any more.
## EASIEST (works from any script, no arguments needed):
##     StormSystem.start_now()
##     StormSystem.stop_now()
## Or, if you already have the node:
##     var storm := get_tree().get_first_node_in_group("storm") as StormSystem
##     storm.trigger_storm()                                  # a dust storm, moderate, 25 s warning, lasts 20 s
##     storm.trigger_storm("SOLAR FLARE", 3, 60.0, 40.0)      # or choose kind, level (1-3), warning seconds, duration
##     storm.stop_storm()                                     # cancels it immediately
## The warning (red light, warnings monitor), the window dust and the room shake all follow from that.
## (Tick "Simulate" in the Inspector if you want the old automatic test storms back.)

const FIRST_STORM := 6.0   # calm seconds before the first storm warning
const STORM_WARN := 25.0   # seconds of warning before a storm hits
const STORM_CALM := 20.0   # calm seconds between storms
const STORMS := [          # storms arrive in this order, with a random severity (1 to 3)
	{"name": "DUST STORM", "last": 20.0},
	{"name": "SOLAR FLARE", "last": 14.0},
	{"name": "DUST DEVIL", "last": 12.0},
]

@export var simulate := false   # true = old behaviour: random storms start on their own

var phase := 0        # 0 = none, 1 = incoming, 2 = hitting
var kind := ""        # "DUST STORM", "SOLAR FLARE", "DUST DEVIL"
var level := 1        # 1 minor, 2 moderate, 3 severe
var eta := 0.0        # seconds until it hits (while incoming)
var left := 0.0       # seconds until it passes (while hitting)
var dust_amt := 0.0   # 0..1 smoothed dust in the air (window haze, solar power)

var _timer := FIRST_STORM
var _idx := 0


func _init() -> void:
	add_to_group("storm")


func _process(delta: float) -> void:
	if simulate:
		_cycle(delta)
	dust_amt = move_toward(dust_amt, _dust_target(), delta * 0.15)


## Call from ANY script with no arguments: StormSystem.start_now()
## Starts a default storm on the StormSystem in the scene. All arguments are optional.
static func start_now(storm_kind := "DUST STORM", storm_level := 2, warn_seconds := STORM_WARN, duration := 20.0) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var node := tree.get_first_node_in_group("storm") as StormSystem if tree != null else null
	if node == null:
		push_warning("StormSystem.start_now(): no StormSystem found in the scene.")
		return
	node.trigger_storm(storm_kind, storm_level, warn_seconds, duration)


## Call from ANY script: StormSystem.stop_now()
static func stop_now() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var node := tree.get_first_node_in_group("storm") as StormSystem if tree != null else null
	if node != null:
		node.stop_storm()


## Easy version: starts a storm with sensible defaults. kind is "DUST STORM", "SOLAR FLARE" or "DUST DEVIL".
func trigger_storm(storm_kind := "DUST STORM", storm_level := 2, warn_seconds := STORM_WARN, duration := 20.0) -> void:
	start_storm(storm_kind, storm_level, warn_seconds, duration)


## Ends any storm right now (warnings clear, dust settles).
func stop_storm() -> void:
	phase = 0
	kind = ""
	eta = 0.0
	left = 0.0
	_timer = STORM_CALM


## Start a storm yourself (for real data). eta = seconds of warning, duration = seconds it lasts.
func start_storm(storm_kind: String, storm_level: int, eta_seconds: float, duration: float) -> void:
	kind = storm_kind
	level = clampi(storm_level, 1, 3)
	eta = eta_seconds
	left = duration
	phase = 1 if eta_seconds > 0.0 else 2


func _dust_target() -> float:
	if phase == 2:
		if kind == "DUST STORM":
			return 0.3 * level
		if kind == "DUST DEVIL":
			return 0.18 * level
	return 0.0


func _cycle(delta: float) -> void:
	match phase:
		0:
			_timer -= delta
			if _timer <= 0.0:
				var s: Dictionary = STORMS[_idx % STORMS.size()]
				_idx += 1
				start_storm(s["name"], randi_range(1, 3), STORM_WARN, s["last"])
		1:
			eta -= delta
			if eta <= 0.0:
				eta = 0.0
				phase = 2
		2:
			left -= delta
			if left <= 0.0:
				left = 0.0
				kind = ""
				phase = 0
				_timer = STORM_CALM
