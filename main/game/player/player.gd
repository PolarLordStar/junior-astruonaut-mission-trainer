extends Node
var preset_values = preload("res://main/libraries/preset_values.gd")

## The player lost health but is still alive. game.gd plays the hurt sound for this.
signal hurt
## The player's health reached 0 (sent once). game.gd plays the death sound and stops the ambience.
signal died

# Whenever health is changed from anywhere (player_script.health -= 5), the setter below sends
# the signals above. Setting it back to full (a new day / a new attempt) sends nothing.
var health: int = preset_values.MAX_HEALTH:
	set(value):
		var old_health := health
		health = value
		if old_health <= 0:
			return   # already dead: nothing more to announce
		if health <= 0:
			died.emit()
		elif health < old_health:
			hurt.emit()
