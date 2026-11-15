extends Node
## Saves and loads the player's progress (for now: the current day number).
##
## SETUP: add this script as an AUTOLOAD named "SaveManager"
##   Project > Project Settings > Globals (Autoload) tab
##   Path: res://main/libraries/save_manager.gd    Node Name: SaveManager    then press Add.
## (Do NOT give this script a class_name. It would clash with the autoload name.)
##
## It never edits game.gd. Instead it watches the scene tree for the Game node (any node that has
## a "day_number" variable) and
##   1. before that node's _ready() runs, hands it the saved day, so the game resumes where you left off
##   2. every time day_number changes afterwards, writes it to the save file
##
## You can also call it yourself from any script:
##   SaveManager.has_save()      -> bool
##   SaveManager.load_day()      -> int  (DEFAULT_DAY = 1 if there is no save)
##   SaveManager.save_day(3)
##   SaveManager.delete_save()   # new game / reset progress
##
## The file is a small readable text file. In the editor: Project > Open User Data Folder > save.cfg

const SAVE_PATH := "user://save.cfg"
const SECTION := "progress"

## The day a brand-new game (no save file) starts on.
const DEFAULT_DAY := 1

## Turn off to only SAVE the day without ever loading it back into the game.
const RESTORE_ON_LOAD := true

## game.gd's setup() does "day_number += 1" when the game starts, so the value handed to it on load
## is (saved day - 1). That way "Continue" lands on the same day you quit on, not the next one.
## Set this to false if you ever remove that increment from game.gd.
const GAME_ADDS_ONE_ON_START := true

var _game: Node = null     # the Game node currently in the scene tree
var _last_saved := 0       # last day number written to (or read from) the file; 0 = nothing saved yet


func _ready() -> void:
	_last_saved = load_day() if has_save() else 0
	get_tree().node_added.connect(_on_node_added)


# ---------- public API ----------
func has_save() -> bool:
	var cfg := ConfigFile.new()
	return cfg.load(SAVE_PATH) == OK and cfg.has_section_key(SECTION, "day_number")


## Returns the saved day number, or DEFAULT_DAY (1) when there is no save file yet.
func load_day() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return DEFAULT_DAY
	return maxi(int(cfg.get_value(SECTION, "day_number", DEFAULT_DAY)), DEFAULT_DAY)


func save_day(day: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)   # keep anything else already in the file; a missing file is fine
	cfg.set_value(SECTION, "day_number", day)
	var err := cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("SaveManager: could not write %s (error %d)" % [SAVE_PATH, err])
		return
	_last_saved = day


## Deletes the save file, so the next game starts on day 1 (DEFAULT_DAY).
func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	_last_saved = 0


# ---------- watching the Game node ----------
## Runs for every node that enters the tree, BEFORE that node's _ready().
func _on_node_added(node: Node) -> void:
	if not ("day_number" in node):
		return
	_game = node
	if RESTORE_ON_LOAD:   # with no save file, load_day() gives DEFAULT_DAY, so a new game starts on day 1
		var start_value := load_day() - (1 if GAME_ADDS_ONE_ON_START else 0)
		node.set("day_number", maxi(start_value, 0))


func _process(_delta: float) -> void:
	if not is_instance_valid(_game):   # no game running (main menu), or the scene was changed
		_game = null
		return
	if not _game.is_node_ready():      # wait until the game has finished its own setup
		return
	var day: int = _game.get("day_number")
	if day > 0 and day != _last_saved:
		save_day(day)
