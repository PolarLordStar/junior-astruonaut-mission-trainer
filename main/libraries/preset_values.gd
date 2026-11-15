extends Node

# PLAYER
const MAX_HEALTH: int = 100
const HEALTH: int = 100

# GAME SCRIPT
const MAX_DAYS: int = 5
const EVENT_DURATION: int = 60
const DAY_DURATION: int = 300 # seconds (5 minutes)

const MIN_EVENT_TIME: float = 0.0
const MAX_EVENT_TIME: float = 300.0
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

const POWER_1SP_INCREASE: int = 1


# COMPONENTS
