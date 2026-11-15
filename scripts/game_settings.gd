# Some usage of AI occured in the script
class_name GameSettings
extends RefCounted
## Settings the Options screen can change. Static variables keep their value while the game is
## running, so the main menu and the game see the same numbers. No autoload needed.
##
## Read or change them from any script:
##     GameSettings.common_sound = 50
##
## (The max number of days is not here: it is PresetValues.MAX_DAYS in preset_values.gd.)
## These are NOT saved to disk yet, so they go back to their defaults when the game is closed.

## "Common sound" (0 = silent, 100 = full). Nothing uses it yet: it is only stored here for later.
static var common_sound: int = 100
