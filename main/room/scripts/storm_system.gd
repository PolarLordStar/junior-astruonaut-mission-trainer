class_name StormSystem
extends Node
## Mars weather events (dust storm, solar flare, dust devil). Other sensors and the room visuals
## read from here.
##
## REAL DATA: set Simulate = false and call start_storm("SOLAR FLARE", 3, 120.0, 40.0)
## when your data says a storm is coming. It then counts down and ends by itself.

const FIRST_STORM := 6.0   # calm seconds before the first storm warning
const STORM_WARN := 25.0   # seconds of warning before a storm hits
const STORM_CALM := 20.0   # calm seconds between storms
const STORMS := [          # storms arrive in this order, with a random severity (1 to 3)
	{"name": "DUST STORM", "last": 20.0},
	{"name": "SOLAR FLARE", "last": 14.0},
	{"name": "DUST DEVIL", "last": 12.0},
]

@export var simulate := true

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
