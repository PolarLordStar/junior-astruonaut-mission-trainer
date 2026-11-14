class_name StormGenerator
extends RefCounted
## Picks a random storm for the current day.
##
## Severity 1 = [Slow] storm, severity 2 = [Fast] storm.
##   Day 1-2 : no storms
##   Day 3   : slow storms only
##   Day 4+  : slow and fast storms
##
## Usage:   var storm := StormGenerator.generate(day_number)

const SLOW_STORMS_FROM_DAY := 3
const FAST_STORMS_FROM_DAY := 4

const STORMS := [
	{"name": "Electrostatic Dust Accumulation", "severity": 1},   # [Slow]
	{"name": "Regional Dust Front", "severity": 1},               # [Slow]
	{"name": "High-Velocity Dust Devil", "severity": 2},          # [Fast]
	{"name": "Global Regolith Blitz", "severity": 2},             # [Fast]
]


## Returns {"name": String, "severity": int}.
## Returns an empty Dictionary {} when no storm is allowed yet (day 1 and 2).
static func generate(day: int):
	var allowed: Array = []

	for storm in STORMS:
		if storm["severity"] == 1 and day >= SLOW_STORMS_FROM_DAY:
			allowed.append(storm)
		elif storm["severity"] == 2 and day >= FAST_STORMS_FROM_DAY:
			allowed.append(storm)

	if allowed.is_empty():
		return {}

	var chosen: Dictionary = allowed.pick_random()
	return {chosen["name"]: chosen["severity"]}
