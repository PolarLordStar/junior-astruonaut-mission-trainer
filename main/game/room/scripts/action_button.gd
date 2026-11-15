class_name ActionButton
extends Node3D
## A physical push-button on the control-room desk, built from code (no scene file needed).
## ControlRoom makes three of them: Radiation Shielding, Air Filtering, Covering Solar Panels.
##
## Left-click it: the button TOGGLES. First click: the cap sinks nearly flat and the orange bar on
## the plate in front of it lights up (= ON). Second click: the cap comes back up and the bar goes
## dark (= OFF). Every click emits "pressed"; "toggled(on)" says which state it is now in.
## What happens next is decided by the functions connected to those signals
## (see the three empty functions in control_room.gd).
##
## Clicks are found with a simple ray-vs-sphere test (ray_hits), so no collision shapes are needed.
## ControlRoom asks every button each frame whether the mouse is over it.

signal pressed
signal toggled(on: bool)

## The orange bar on the plate in front of the button (set by control_room.gd). Lit when ON.
var indicator: MeshInstance3D
var is_on := false

@export var label_text := "BUTTON"
@export var color := Color("ffb02e")

const BASE_R := 0.16
const CAP_R := 0.12
const BASE_H := 0.04
const CAP_H := 0.06
const REST_Y := BASE_H + CAP_H * 0.5   # height of the cap's centre when it is not pressed
const SINK := 0.04                     # how far the cap sinks when the button is ON (bigger = deeper)
const IND_OFF_COLOR := Color("3a2210") # the bar when OFF (dark, unlit)
const IND_ON_COLOR := Color("d9651f")  # the bar when ON (same orange as the trim)
const IND_ON_GLOW := 2.5
const HIT_R := 0.18                    # click / hover radius (a bit bigger than the cap, easier to hit)
const LABEL_Z := -0.25                 # the text lies this far BEHIND the button (away from the player, so it stays on screen)
const GLOW_IDLE := 0.5
const GLOW_HOVER := 1.4
const GLOW_FLASH := 3.0

var _cap: MeshInstance3D
var _cap_mat: StandardMaterial3D
var _hover := false
var _tween: Tween


func _ready() -> void:
	# dark base ring
	var base := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = BASE_R
	bm.bottom_radius = BASE_R
	bm.height = BASE_H
	bm.radial_segments = 20
	base.mesh = bm
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color("1b1c22")
	base_mat.roughness = 1.0
	base.material_override = base_mat
	base.position = Vector3(0.0, BASE_H * 0.5, 0.0)
	add_child(base)

	# the coloured cap that sinks when pressed
	_cap = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = CAP_R * 0.92
	cm.bottom_radius = CAP_R
	cm.height = CAP_H
	cm.radial_segments = 20
	_cap.mesh = cm
	_cap_mat = StandardMaterial3D.new()
	_cap_mat.albedo_color = color
	_cap_mat.roughness = 0.5
	_cap_mat.emission_enabled = true
	_cap_mat.emission = color
	_cap_mat.emission_energy_multiplier = GLOW_IDLE
	_cap.material_override = _cap_mat
	_cap.position = Vector3(0.0, REST_Y, 0.0)
	add_child(_cap)

	# the name, lying flat on the desk behind the button
	var label := Label3D.new()
	label.text = label_text
	label.font_size = 34
	label.pixel_size = 0.0017
	label.modulate = Color("e8ecff")
	label.outline_size = 6
	label.outline_modulate = Color("0e0f14")
	label.shaded = false
	label.rotation_degrees.x = -90.0
	label.position = Vector3(0.0, 0.006, LABEL_Z)
	add_child(label)


## True if the ray (from the camera through the mouse) passes over this button.
func ray_hits(origin: Vector3, dir: Vector3) -> bool:
	if not is_visible_in_tree():
		return false
	var centre := to_global(Vector3(0.0, REST_Y, 0.0))
	var radius := HIT_R * global_transform.basis.get_scale().x   # the desk rig is scaled down
	var t := (centre - origin).dot(dir)
	if t < 0.0:
		return false
	return (origin + dir * t).distance_to(centre) <= radius


func set_hover(on: bool) -> void:
	_hover = on
	if _cap_mat != null and (_tween == null or not _tween.is_running()):
		_cap_mat.emission_energy_multiplier = GLOW_HOVER if _hover else GLOW_IDLE


## Toggles ON / OFF with an animation and emits "pressed" and "toggled" straight away.
## Plays the button-press sound on every click. The sound is here and not in set_on(), so
## switching a button from code stays silent.
func press() -> void:
	GameSounds.play_button_press()
	set_on(not is_on)
	pressed.emit()


## Turns the button ON (cap down, bar lit) or OFF (cap up, bar dark). Call it from code if you
## ever need to switch a button without a click.
func set_on(on: bool) -> void:
	is_on = on
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_cap, "position:y", REST_Y - SINK if on else REST_Y, 0.12)
	_tween.tween_property(_cap_mat, "emission_energy_multiplier", GLOW_FLASH, 0.05)
	if indicator != null:
		var mat := indicator.material_override as StandardMaterial3D
		if mat != null:
			_tween.tween_property(mat, "albedo_color", IND_ON_COLOR if on else IND_OFF_COLOR, 0.12)
			_tween.tween_property(mat, "emission_energy_multiplier", IND_ON_GLOW if on else 0.0, 0.12)
	_tween.chain().tween_property(_cap_mat, "emission_energy_multiplier", GLOW_HOVER if _hover else GLOW_IDLE, 0.12)
	toggled.emit(on)


## Gives the bar its own material so it can light up (called once by control_room.gd).
func setup_indicator(bar: MeshInstance3D) -> void:
	indicator = bar
	var mat := StandardMaterial3D.new()
	mat.albedo_color = IND_OFF_COLOR
	mat.roughness = 0.6
	mat.emission_enabled = true
	mat.emission = IND_ON_COLOR
	mat.emission_energy_multiplier = 0.0
	bar.material_override = mat
