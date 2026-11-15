# Some usage of AI occured in the script
extends Control
## Main menu. The little message under the buttons is the MessageLabel node in main_menu.tscn.
##
## Background music: plays MUSIC_PATH in a loop while the main menu is on screen. It follows the
## "Common sound" setting (GameSettings.common_sound), checked every frame, so changing it in
## Options changes the music straight away. It stops by itself when the game scene loads.

const MUSIC_PATH := "res://Assets/sounds/main_menu/DryHands.mp3"

## How loud the music is compared to the other sounds, in dB (0 = as recorded, -6 = about half).
const MUSIC_GAIN_DB := -6.0

@onready var _label: Label = $MessageLabel

var _music: AudioStreamPlayer


func _ready() -> void:
	for b in find_children("*", "McButton", true, false):
		b.message.connect(_show_message)
	_start_music()


func _process(_delta: float) -> void:
	if _music != null:
		_music.volume_db = GameSounds.common_volume_db(MUSIC_GAIN_DB)


func _start_music() -> void:
	var stream := load(MUSIC_PATH) as AudioStream
	if stream == null:
		push_warning("MainMenu: music not found (%s)" % MUSIC_PATH)
		return
	if "loop" in stream:
		stream.set("loop", true)   # repeat without a gap
	_music = AudioStreamPlayer.new()
	_music.stream = stream
	_music.volume_db = GameSounds.common_volume_db(MUSIC_GAIN_DB)
	_music.finished.connect(_music.play)   # safety net if the stream cannot loop by itself
	add_child(_music)
	_music.play()


func _show_message(text: String) -> void:
	_label.text = text
	_label.modulate.a = 1.0
	create_tween().tween_property(_label, "modulate:a", 0.0, 2.0).set_delay(1.5)
