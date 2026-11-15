# Some usage of AI occured in the script
class_name AmbiencePlayer
extends AudioStreamPlayer
## The control-room background hum. It is the AmbiencePlayer node in control_room.tscn.
##
##   - Starts when the control room starts and loops for as long as the game is running.
##   - Goes quiet while the game is paused (Esc menu) and carries on from the same spot afterwards.
##   - game.gd calls stop_ambience() when the player dies and play_ambience() when a new attempt
##     starts. (play_ambience() does nothing if the hum is already playing, so it never restarts.)
##   - The volume follows GameSettings.common_sound (0 = silent, 100 = full). It is checked every
##     frame, so changing the setting changes the hum straight away.
##
## To use a different sound, drop another file in the Stream slot in the Inspector.
## Otherwise it plays DEFAULT_STREAM_PATH.

## How loud the hum is compared to the other sounds, in dB (0 = as recorded).
## The recording is about as loud as the hurt and death sounds, so it is turned down to stay in
## the background. Raise it (for example -8) for a louder hum.
const GAIN_DB := -12.0

const DEFAULT_STREAM_PATH := "res://Assets/sounds/control_room/ControlRoomAmbience.mp3"

var _wanted := false   # true while the hum should be playing (false after stop_ambience())


func _ready() -> void:
	add_to_group("ambience")
	if stream == null:
		stream = load(DEFAULT_STREAM_PATH) as AudioStream
	if stream == null:
		push_warning("AmbiencePlayer: no sound to play (%s not found)" % DEFAULT_STREAM_PATH)
		return
	# MP3 and Ogg streams have a "loop" switch: turn it on so the hum repeats without a gap.
	if "loop" in stream:
		stream.set("loop", true)
	# Safety net for streams that cannot loop by themselves: start again when the end is reached.
	finished.connect(_on_finished)
	play_ambience()


func _process(_delta: float) -> void:
	_apply_volume()


## Start the hum (nothing happens if it is already playing).
func play_ambience() -> void:
	if stream == null:
		return
	_wanted = true
	if not playing:
		_apply_volume()
		play()


## Stop the hum (used when the player dies).
func stop_ambience() -> void:
	_wanted = false
	stop()


func _apply_volume() -> void:
	var db := GameSounds.common_volume_db(GAIN_DB)
	if not is_equal_approx(volume_db, db):
		volume_db = db


func _on_finished() -> void:
	if _wanted:
		play()


func _notification(what: int) -> void:
	# Godot already pauses an audio player together with the game; this only makes sure of it.
	if what == NOTIFICATION_PAUSED:
		stream_paused = true
	elif what == NOTIFICATION_UNPAUSED:
		stream_paused = false
