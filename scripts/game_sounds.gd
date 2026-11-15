# Some usage of AI occured in the script
class_name GameSounds
extends RefCounted
## The player's sounds (hurt, death, retry) plus the one rule that turns the "Common sound"
## setting into a real volume. Static functions, so (like game_settings.gd) there is no autoload
## and no scene to set up. Call them from any script:
##
##     GameSounds.play_hurt()
##     GameSounds.play_death()
##     GameSounds.play_retry()
##     GameSounds.play_click()
##     GameSounds.play_button_press()
##
## Who calls what right now:
##     play_hurt / play_death   game.gd, when player.gd says the player was hurt / died
##     play_retry               scripts/restart_button.gd (main menu "Restart")
##     play_click               scripts/mc_button.gd (every McButton: main menu, pause menu, options)
##     play_button_press        main/game/room/scripts/action_button.gd (the 3 push-buttons on the control-room desk)
## (the control-room hum is not here: it is the AmbiencePlayer node in control_room.tscn)
##
## VOLUME: every sound follows GameSettings.common_sound (0 = silent, 100 = full), read at the
## moment the sound starts. The *_GAIN_DB numbers below only set how loud one sound is compared
## to the others (0 = as recorded, -6 = about half as loud, +6 = about twice as loud). They do
## not replace the setting.
##
## Each sound is played by a short-lived AudioStreamPlayer that is added to the scene root and
## deletes itself when the sound ends. That way a sound keeps playing when the scene changes
## (the retry sound starts on the main menu and carries on into the game) and also while the
## game is paused.

const HURT_PATH := "res://Assets/sounds/player/HurtPlayer.wav"
const DEATH_PATH := "res://Assets/sounds/player/DeathPlayer.wav"
const RETRY_PATH := "res://Assets/sounds/player/RetryGame.wav"
const CLICK_PATH := "res://Assets/sounds/ui/MinecraftClick.wav"
const BUTTON_PRESS_PATH := "res://Assets/sounds/ui/ButtonPress.wav"

const HURT_GAIN_DB := 0.0
const DEATH_GAIN_DB := 0.0
const RETRY_GAIN_DB := 0.0
const CLICK_GAIN_DB := 0.0
const BUTTON_PRESS_GAIN_DB := -6.0   # recorded louder than the other sounds, so it is turned down a bit

## Godot's quietest volume. Used when Common sound is 0.
const SILENT_DB := -80.0

# The hurt sound that is playing right now (null / freed when none is).
static var _hurt_player: AudioStreamPlayer


## Player lost health but is still alive. If the last hurt sound has not finished yet it is
## left alone, so damage that comes every second does not restart it again and again.
static func play_hurt() -> void:
	if is_instance_valid(_hurt_player):
		return
	_hurt_player = _play(HURT_PATH, HURT_GAIN_DB)


## Player's health reached 0.
static func play_death() -> void:
	_play(DEATH_PATH, DEATH_GAIN_DB)


## Player starts again (a new attempt).
static func play_retry() -> void:
	_play(RETRY_PATH, RETRY_GAIN_DB)


## A menu button was clicked.
static func play_click() -> void:
	_play(CLICK_PATH, CLICK_GAIN_DB)


## One of the push-buttons on the control-room desk was pressed.
static func play_button_press() -> void:
	_play(BUTTON_PRESS_PATH, BUTTON_PRESS_GAIN_DB)


## The volume (in dB) for GameSettings.common_sound, plus an optional gain for one sound.
## AmbiencePlayer uses this too, so every sound in the game follows the setting the same way.
static func common_volume_db(gain_db: float = 0.0) -> float:
	var level := clampf(GameSettings.common_sound / 100.0, 0.0, 1.0)
	if level <= 0.0:
		return SILENT_DB
	return maxf(linear_to_db(level) + gain_db, SILENT_DB)


static func _play(path: String, gain_db: float) -> AudioStreamPlayer:
	if GameSettings.common_sound <= 0:
		return null   # silent: nothing to play
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var stream := load(path) as AudioStream
	if stream == null:
		push_warning("GameSounds: could not load " + path)
		return null
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = common_volume_db(gain_db)
	player.process_mode = Node.PROCESS_MODE_ALWAYS   # keeps playing while the game is paused
	player.autoplay = true                           # starts as soon as it is in the tree
	player.finished.connect(player.queue_free)
	# deferred: adding a child to the root straight away can fail while a scene is still starting up
	tree.root.add_child.call_deferred(player)
	return player
