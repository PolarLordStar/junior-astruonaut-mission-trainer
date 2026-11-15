extends CanvasLayer
## Red screen warning while the player's health is low.
##
## It only READS the Health node (Game/Health, health.gd). It never changes the Health number:
##     Health BELOW low_health_threshold  ->  the whole screen fades to a red tint
##     Health back up to the threshold or more (a new day resets it to full)  ->  the red fades away
## When Health reaches 0 the death screen takes over (death_screen.gd).
##
## The red is the "Red" ColorRect in low_health_overlay.tscn: change its colour there.
## The numbers below show up in the Inspector when you select the LowHealthOverlay node in game.tscn.
## The overlay ignores the mouse, so clicking the desk buttons still works while the screen is red.

## The screen turns red while Health is BELOW this number (20 means red from 19 and lower).
@export var low_health_threshold: int = 20
## How strong the red is: 0 = invisible, 1 = solid red. Keep it low so the monitors stay readable.
@export_range(0.0, 1.0) var red_strength: float = 0.3
## Seconds the red takes to fade in and out.
@export var fade_time: float = 0.4

@onready var _red: ColorRect = $Red
@onready var _health = get_node_or_null("../Health")   # Game/Health (this node must be a child of Game)

var _is_low := false
var _tween: Tween


func _ready() -> void:
	_red.color.a = 0.0
	if _health == null:
		push_warning("LowHealthOverlay: Game/Health not found (this node must be a child of Game)")


func _process(_delta: float) -> void:
	if _health == null:
		return
	var low: bool = _health.Health < low_health_threshold
	if low == _is_low:
		return   # nothing changed
	_is_low = low
	_fade_to(red_strength if low else 0.0)


func _fade_to(alpha: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_red, "color:a", alpha, fade_time)
