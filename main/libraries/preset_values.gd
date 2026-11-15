# Some usage of AI occured in the script
class_name PresetValues
extends Node

# PLAYER
const MAX_HEALTH: int = 100
const HEALTH: int = 100

# GAME SCRIPT
static var MAX_DAYS: int = 5
const EVENT_DURATION: int = 60
const DAY_DURATION: int = 300 # seconds (5 minutes)

const MIN_EVENT_TIME: float = 0.0 # what time event can start
const MAX_EVENT_TIME: float = 300.0 # what time event can start
const MIN_TIME_GAP: float = 8.0


# COMPONENTS
const MAX_RADIATION: int = 100
const RADIATION: int = 0
const MAX_POWER: int = 100
const POWER: int = 50
const MAX_OXYGEN: int = 100
const OXYGEN: int = 100
const MAX_TOXIC_PERCH: int = 100
const TOXIC_PERCH: int = 0
const MAX_SOLAR_PANELS: int = 6
const SOLAR_PANELS: int = 6

const RADIATION_GCR_INCREASE: int = 1
const CRITICAL_RADIATION: int = 90 # decreases health above or equal
const CRITICAL_OXYGEN: int = 10 # decreases health below
const TOXIC_PERCH_DUST_INCREASE: int = 1
const CRITICAL_TOXIC_PERCH: int = 90 # decreases health above or equal
const MEDIUM_TOXIC_PERCH: int = 50 # decreases above or equal
const OXYGEN_TP_DECREASE: int = 1 # decreases when toxic perch is above or equal medium
const POWER_1SP_INCREASE: int = 1
const SLOW_STORM_SP_DAMAGE_CHANCE: float = 0.025
const FAST_STORM_SP_DAMAGE_CHANCE: float = 0.05
const TOXIC_PERCH_STORM_INCREASE: int = 2
const RADIATION_SOLAR_EVENT_INCREASES := {
	"Tiny Sun Flash": 2,
	"Small Sun Flash": 3,
	"Medium Sun Flash": 4,
	"Giant Sun Flash": 5,
	"Solar Cloud Incoming": 3,
	"Radiation Storm": 6,
}
const RADIATION_SHIELDING_RADIATION_DECREASE: int = 3
const RADIATION_SHIELDING_POWER_DECREASE: int = 5
const AIR_FILTERING_TP_DECREASE: int = 3
const AIR_FILTERING_POWER_DECREASE: int = 5

const RADIATION_DAMAGE_HEALTH: int = 5
const LOW_OXYGEN_DAMAGE_HEALTH: int = 5
const TP_DAMAGE_HEALTH: int = 5

# COMPONENTS
