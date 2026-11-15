# Some usage of AI occured in the script
extends Node
## ALL the player + control-room ambience sounds live here, separate from game.gd and player.gd.
## Put this script on a Node called "PlayerSounds" that is a child of Game, next to "Player".
##
## It listens to the Player node's signals:
##   hurt -> GameSounds.play_hurt()
##   died -> GameSounds.play_death() and the control-room ambience stops
## game.gd only calls start_ambience() when a new day / attempt begins.

## The Player node (player.gd). Leave it empty and it is found automatically as Game/Player.
@export var player: Node


func _ready() -> void:
	if player == null:
		player = get_node_or_null("../Player")
	if player == null:
		push_warning("PlayerSounds: no Player node found, the hurt/death sounds will not play.")
		return
	player.hurt.connect(_on_player_hurt)
	player.died.connect(_on_player_died)


func start_ambience() -> void:
	var ambience := _get_ambience()
	if ambience != null:
		ambience.play_ambience()


func stop_ambience() -> void:
	var ambience := _get_ambience()
	if ambience != null:
		ambience.stop_ambience()


func _on_player_hurt() -> void:
	GameSounds.play_hurt()


func _on_player_died() -> void:
	GameSounds.play_death()
	stop_ambience()   # the control room goes quiet when the player dies


func _get_ambience() -> AmbiencePlayer:
	return get_tree().get_first_node_in_group("ambience") as AmbiencePlayer
