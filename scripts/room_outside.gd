class_name RoomOutside
extends RefCounted
## Everything outside the big window: sky, Martian ground, mesas, habitat dome, the sun
## (with its solar-flare spikes) and the drifting dust clouds.
## Built by ControlRoom._ready() with build(); update(delta) runs every frame.

var room: ControlRoom

var tile: float:
	get:
		return room.tile
var wall_h: float:
	get:
		return room.wall_h


var _sun_core: MeshInstance3D
var _sun_halo: MeshInstance3D
var _flare_root: Node3D
var _flare_amt := 0.0
var _clouds: Array[MeshInstance3D] = []


func _init(owner_room: ControlRoom) -> void:
	room = owner_room


func _dust() -> void:
	var d := ControlRoom.ROWS * tile
	for i in 4:
		var m := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = tile
		sm.height = tile * 1.2
		m.mesh = sm
		m.material_override = _glow_mat(Color(0.8, 0.5, 0.3, 0.3))
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.position = Vector3(-tile * 2.0 + i * tile * 1.4, wall_h * 0.5, -d - tile * (1.2 + (i % 2) * 0.6))
		m.scale = Vector3(1.6, 0.8, 1.0)
		m.set_meta("base_pos", m.position)
		room.add_child(m)
		_clouds.append(m)


func _glow_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _flat(pos: Vector3, flat_size: Vector3, color: Color) -> void:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = flat_size
	m.mesh = bm
	m.material_override = _glow_mat(color)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = pos
	room.add_child(m)


func _blob(pos: Vector3, scl: Vector3, color: Color) -> void:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	m.mesh = sm
	m.material_override = _glow_mat(color)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = pos
	m.scale = scl
	room.add_child(m)


func _cone(pos: Vector3, radius: float, h: float, color: Color) -> void:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = radius
	cm.height = h
	cm.radial_segments = 5
	m.mesh = cm
	m.material_override = _glow_mat(color)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = pos + Vector3(0, h / 2.0, 0)
	room.add_child(m)


func _orb(pos: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	m.mesh = sm
	m.material_override = _glow_mat(color)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = pos
	room.add_child(m)
	return m


func build() -> void:
	var d := ControlRoom.ROWS * tile
	var s := tile / 2.0
	var gy := 1.2 * s   # ground height
	# sky with a gradient: deep rust at the top, dusty peach at the horizon
	var sky := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(90, 40) * s
	sky.mesh = q
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded;
uniform vec3 top_col : source_color = vec3(0.36, 0.16, 0.10);
uniform vec3 low_col : source_color = vec3(0.95, 0.62, 0.38);
uniform float y0 = 0.5;
uniform float y1 = 6.0;
varying float wy;
void vertex() { wy = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y; }
void fragment() { ALBEDO = mix(low_col, top_col, smoothstep(y0, y1, wy)); }
"""
	var smat := ShaderMaterial.new()
	smat.shader = sh
	smat.set_shader_parameter("y0", gy)
	smat.set_shader_parameter("y1", wall_h * 1.6)
	sky.material_override = smat
	sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sky.position = Vector3(0, 14 * s, -d - 15 * s)
	room.add_child(sky)
	# ground, far mesas, dunes (far ones are paler, like dusty haze)
	_flat(Vector3(0, 0.6 * s, -d - 9 * s), Vector3(90, 1.2, 18) * s, Color("a35a2b"))
	_cone(Vector3(-9 * s, gy, -d - 13 * s), 5 * s, 3.2 * s, Color("c58b5e"))
	_cone(Vector3(2 * s, gy, -d - 14 * s), 6 * s, 2.4 * s, Color("c58b5e"))
	_cone(Vector3(11 * s, gy, -d - 13 * s), 5 * s, 3.6 * s, Color("bd8254"))
	_blob(Vector3(-4 * s, gy, -d - 6 * s), Vector3(6, 0.9, 3) * s, Color("b87140"))
	_blob(Vector3(6 * s, gy, -d - 7 * s), Vector3(7, 1.1, 3) * s, Color("ad6536"))
	_blob(Vector3(-1 * s, gy * 0.9, -d - 2.5 * s), Vector3(4, 0.5, 1.6) * s, Color("9a4f27"))
	_blob(Vector3(5 * s, gy * 0.9, -d - 3 * s), Vector3(3.5, 0.45, 1.4) * s, Color("9d532a"))
	# small habitat dome with a lit window and an antenna
	var dome := MeshInstance3D.new()
	var dm := SphereMesh.new()
	dm.radius = 0.8 * s
	dm.height = 0.8 * s
	dm.is_hemisphere = true
	dome.mesh = dm
	dome.material_override = _glow_mat(Color("d8d9f5"))
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dome.position = Vector3(-4 * s, gy + 0.85 * s, -d - 6 * s)
	room.add_child(dome)
	_flat(Vector3(-4 * s, gy + 1.1 * s, -d - 5.2 * s), Vector3(0.5, 0.25, 0.05) * s, Color("ffd36b"))
	_flat(Vector3(-3.1 * s, gy + 1.5 * s, -d - 6 * s), Vector3(0.06, 1.3, 0.06) * s, Color("d8d9f5"))
	_flat(Vector3(-3.1 * s, gy + 2.2 * s, -d - 6 * s), Vector3(0.16, 0.16, 0.16) * s, Color("ff5a4a"))
	# sun with a glow; during a solar flare it swells and shoots out orange spikes
	var sun_pos := Vector3(2.0 * s, wall_h * 0.6, -d - 12 * s)
	_sun_core = _orb(sun_pos, 2.2 * s, Color("fff0a8"))
	_sun_halo = _orb(sun_pos, 4.0 * s, Color(1.0, 0.85, 0.4, 0.25))
	_flare_root = Node3D.new()
	_flare_root.position = sun_pos + Vector3(0, 0, 0.2)
	room.add_child(_flare_root)
	for i in 12:
		var arm := Node3D.new()
		arm.rotation_degrees.z = i * 30.0 + (i % 3) * 7.0
		_flare_root.add_child(arm)
		var spike_len := (2.2 + float(i % 4) * 1.1) * s
		var sp := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.45 * s, spike_len, 0.02)
		sp.mesh = bm
		sp.material_override = _glow_mat(Color(1.0, 0.5, 0.12, 0.75))
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sp.position = Vector3(0, 2.0 * s + spike_len / 2.0, 0)
		arm.add_child(sp)
	_flare_root.visible = false
	_dust()


## Solar-flare sun, sun light colour and dust clouds rolling in. Called every frame by ControlRoom.
func update(delta: float) -> void:
	var target := 0.0
	if room.storm_type == "SOLAR FLARE":
		if room.storm_phase == 2:
			target = 1.0
		elif room.storm_phase == 1:
			target = 0.35
	_flare_amt = move_toward(_flare_amt, target, delta * 0.25)
	var t := Time.get_ticks_msec() / 1000.0
	if _flare_root != null:
		_flare_root.visible = _flare_amt > 0.02
		_flare_root.scale = Vector3.ONE * (0.4 + _flare_amt * (0.9 + 0.1 * sin(t * 6.0)))
		_flare_root.rotation_degrees.z = t * 6.0
	if _sun_core != null:
		(_sun_core.material_override as StandardMaterial3D).albedo_color = Color("fff0a8").lerp(Color("ff7a2a"), _flare_amt)
	if _sun_halo != null:
		(_sun_halo.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.8 - 0.3 * _flare_amt, 0.35 - 0.2 * _flare_amt, 0.25 + 0.3 * _flare_amt)
		_sun_halo.scale = Vector3.ONE * (1.0 + 0.9 * _flare_amt)
	if room._sun_light != null:
		room._sun_light.light_color = ControlRoom.SUN_COL.lerp(ControlRoom.FLARE_COL, _flare_amt)
		room._sun_light.light_energy = ControlRoom.SUN_ENERGY * (1.0 - 0.75 * room._dust_amt) * (1.0 + 0.5 * _flare_amt)
	for i in _clouds.size():
		var c := _clouds[i]
		var bp: Vector3 = c.get_meta("base_pos")
		c.position = bp + Vector3(sin(t * 0.15 + i) * 0.8, 0.0, room._dust_amt * tile * 1.4)
		c.scale = Vector3(1.6, 0.8, 1.0) * (1.0 + 0.5 * room._dust_amt)
		(c.material_override as StandardMaterial3D).albedo_color.a = 0.28 + 0.4 * room._dust_amt
