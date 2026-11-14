class_name ActionButton
extends Node3D
## A physical push-button on the control-room desk, built from code (no scene file needed).
## ControlRoom makes three of them: Radiation Shielding, Air Filtering, Covering Solar Panels.
##
## Left-click it: the cap sinks, flashes, and the "pressed" signal is emitted. That is ALL the
## button does. What happens next is decided by the function connected to "pressed"
## (see the three empty functions in control_room.gd).
##
## Clicks are found with a simple ray-vs-sphere test (ray_hits), so no collision shapes are needed.
## ControlRoom asks every button each frame whether the mouse is over it.

signal pressed

@export var label_text := "BUTTON"
@export var color := Color("ffb02e")

const BASE_R := 0.16
const CAP_R := 0.12
const BASE_H := 0.04
const CAP_H := 0.06
const REST_Y := BASE_H + CAP_H * 0.5   # height of the cap's centre when it is not pressed
const TRAVEL := 0.03                   # how far the cap sinks when pressed
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


## Plays the press animation and emits "pressed" straight away.
func press() -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_cap, "position:y", REST_Y - TRAVEL, 0.05)
	_tween.parallel().tween_property(_cap_mat, "emission_energy_multiplier", GLOW_FLASH, 0.05)
	_tween.tween_property(_cap, "position:y", REST_Y, 0.12)
	_tween.parallel().tween_property(_cap_mat, "emission_energy_multiplier", GLOW_HOVER if _hover else GLOW_IDLE, 0.12)
	pressed.emit()
