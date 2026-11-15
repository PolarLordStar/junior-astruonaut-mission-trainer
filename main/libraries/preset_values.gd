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


# ====================================== DEFAULT COMPONENTS
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

# ====================================== CHANGING COMPONENTS
const POWER_1SP_INCREASE: float = 0.5 # power increase for 1 solar panel
const RADIATION_SHIELDING_POWER_DECREASE: int = 5
const AIR_FILTERING_POWER_DECREASE: int = 5

const SLOW_STORM_SP_DAMAGE_CHANCE: float = 0.025
const FAST_STORM_SP_DAMAGE_CHANCE: float = 0.05

const RADIATION_GCR_INCREASE: int = 1
const RADIATION_SOLAR_EVENT_INCREASES := {
	"Tiny Sun Flash": 2,
	"Small Sun Flash": 3,
	"Medium Sun Flash": 4,
	"Giant Sun Flash": 4,
	"Solar Cloud": 3,
	"Radiation Storm": 5,
}
const CRITICAL_RADIATION: int = 90 # decreases health above or equal
const RADIATION_DAMAGE_HEALTH: int = 5
const RADIATION_SHIELDING_RADIATION_DECREASE: int = 3

const OXYGEN_TP_DECREASE: int = 1 # decreases when toxic perch is above or equal medium
const CRITICAL_OXYGEN: int = 10 # decreases health below
const LOW_OXYGEN_DAMAGE_HEALTH: int = 5

const MEDIUM_TOXIC_PERCH: int = 50 # decreases above or equal
const TOXIC_PERCH_DUST_INCREASE: int = 1
const TOXIC_PERCH_STORM_INCREASE: int = 2
const CRITICAL_TOXIC_PERCH: int = 90 # decreases health above or equal
const TP_DAMAGE_HEALTH: int = 5
const AIR_FILTERING_TP_DECREASE: int = 3


# ====================================== HEALTH DAMAGE (lost every tick)
# Radiation and toxic perchlorates: damage while the bar is ABOVE the level
const DAMAGE_LEVEL_LOW: int = 35
const DAMAGE_LEVEL_MEDIUM: int = 65
const DAMAGE_LEVEL_HIGH: int = 90
const DAMAGE_LOW: int = 1
const DAMAGE_MEDIUM: int = 2
const DAMAGE_HIGH: int = 5

# Oxygen: damage while the bar is BELOW the level
const OXYGEN_DAMAGE_LEVEL_LOW: int = 66
const OXYGEN_DAMAGE_LEVEL_HIGH: int = 33
const OXYGEN_DAMAGE_LOW: int = 1
const OXYGEN_DAMAGE_HIGH: int = 2
