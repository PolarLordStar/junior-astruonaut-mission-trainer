class_name RoomDesk
extends RefCounted
## The control desk: table, 3 monitors (status / environment / alerts), keyboard,
## tea cup and the two angled side consoles.
## Built by ControlRoom._ready() with build(); update() animates the tea steam every frame.

var room: ControlRoom

var tile: float:
	get:
		return room.tile
var wall_h: float:
	get:
		return room.wall_h


var screens := {}    # "status" / "environment" / "alerts" -> the Control shown on that monitor
var steam: Array[MeshInstance3D] = []


func _init(owner_room: ControlRoom) -> void:
	room = owner_room


## Rising steam above the tea cup.
func update() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for st in steam:
		var ph := fmod(t * 0.4 + float(st.get_meta("phase")), 1.0)
		st.position = Vector3(sin(ph * 6.0) * 0.03, 0.24 + ph * 0.35, 0.0)
		st.scale = Vector3.ONE * (0.8 + ph)
		(st.material_override as StandardMaterial3D).albedo_color.a = (1.0 - ph) * 0.5


func _tea_cup(parent: Node3D, pos: Vector3) -> void:
	var cup := Node3D.new()
	cup.position = pos
	cup.scale = Vector3.ONE * 1.4
	parent.add_child(cup)
	var white := Color("f4f4ff")
	var sc := CylinderMesh.new()
	sc.top_radius = 0.26
	sc.bottom_radius = 0.2
	sc.height = 0.025
	_cup_part(cup, sc, white, Vector3(0, 0.0125, 0))
	var cm := CylinderMesh.new()
	cm.top_radius = 0.17
	cm.bottom_radius = 0.11
	cm.height = 0.18
	_cup_part(cup, cm, white, Vector3(0, 0.115, 0))
	var tm := CylinderMesh.new()
	tm.top_radius = 0.155
	tm.bottom_radius = 0.155
	tm.height = 0.01
	_cup_part(cup, tm, Color("9a4a1e"), Vector3(0, 0.195, 0))
	var hm := TorusMesh.new()
	hm.inner_radius = 0.03
	hm.outer_radius = 0.075
	var handle := _cup_part(cup, hm, white, Vector3(0.2, 0.125, 0))
	handle.rotation_degrees.x = 90.0
	for i in 3:
		var st := MeshInstance3D.new()
		var ss := SphereMesh.new()
		ss.radius = 0.035
		ss.height = 0.07
		st.mesh = ss
		var m := room._mat(Color(1, 1, 1, 0.5))
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		st.material_override = m
		st.set_meta("phase", i * 0.33)
		cup.add_child(st)
		steam.append(st)


func _cup_part(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = room._mat(color)
	mi.position = pos
	parent.add_child(mi)
	return mi


## Builds the desk, the 3 monitors and the side consoles. Returns {pos, top, width} for the camera and props.
func build() -> Dictionary:
	var model := "table-large"
	var s := room._size(model)
	if s == Vector3.ZERO:
		model = "table"
		s = room._size(model)
	var pos := Vector3(0, 0, -ControlRoom.ROWS * tile * ControlRoom.DESK_AT)
	var n := room._place(model, pos, 0.0, true, ControlRoom.DESK_TINT)
	var width := maxf(s.x, s.z) if n != null else tile * 2.0
	var depth := minf(s.x, s.z) if n != null else tile
	var top := s.y if n != null else 0.8
	# monitor rig: built at a "5 wide desk" scale, then scaled to fit the real desk
	var u := (width / 5.0) * 0.9
	var rig := Node3D.new()
	rig.position = Vector3(pos.x, top, pos.z)
	rig.scale = Vector3.ONE * u
	room.add_child(rig)
	# three monitors, the outer two angled towards the player
	_monitor(rig, "status", Vector3(-1.7, 0.62, -0.2), 16.0)          # left: life support (unchanged)
	_monitor(rig, "environment", Vector3(0.0, 0.62, -0.42), 0.0)      # middle: radiation / oxygen / perchlorate
	_monitor(rig, "alerts", Vector3(1.7, 0.62, -0.2), -16.0)          # right: warnings only
	room._box(rig, Vector3(0, 0.02, 0.45), Vector3(1.1, 0.04, 0.35), ControlRoom.DARK)              # keyboard
	room._box(rig, Vector3(1.05, 0.008, 0.5), Vector3(0.5, 0.016, 0.4), Color("17181d"))  # mouse pad
	room._box(rig, Vector3(1.05, 0.035, 0.5), Vector3(0.1, 0.04, 0.16), Color("2b2d36"))  # mouse
	room._box(rig, Vector3(0, -0.01, depth * 0.5 / u), Vector3(width / u, 0.05, 0.05), ControlRoom.TRIM)   # orange front edge
	_tea_cup(rig, Vector3(-1.9, 0.0, 0.55))
	# cool glow from the screens onto the desk
	var glow := OmniLight3D.new()
	glow.light_color = Color("7fd8ff")
	glow.light_energy = 0.5
	glow.omni_range = 3.5
	glow.position = Vector3(0, 0.9, 0.8)
	rig.add_child(glow)
	# angled side consoles, like the wrap-around desk in the reference
	var lw := _wing(-1.0, pos, width, depth, top)
	var tablet := room._box(lw, Vector3(-0.1, 0.045, 0.12), Vector3(0.42, 0.02, 0.3), Color("14151a"))
	tablet.rotation_degrees.y = 14.0
	room._dim(room._box(tablet, Vector3(0, 0.0105, 0), Vector3(0.38, 0.003, 0.26), Color("8fb4d6"), true), 0.9)
	var paper := room._box(lw, Vector3(0.35, 0.042, -0.05), Vector3(0.3, 0.012, 0.22), Color("cfc6b0"))
	paper.rotation_degrees.y = -12.0
	_headphones(lw, Vector3(-0.42, 0.04, 0.05))
	var rw := _wing(1.0, pos, width, depth, top)
	_console(rw)
	room._no_shadow(lw)
	room._no_shadow(rw)
	return {"pos": pos, "top": top, "width": width}


func _monitor(parent: Node3D, kind: String, pos: Vector3, yaw: float) -> void:
	var bezel := room._box(parent, pos, Vector3(1.52, 0.95, 0.07), ControlRoom.DARK)
	bezel.rotation_degrees.y = yaw
	var stand_h := pos.y - 0.475 + 0.04
	room._box(parent, Vector3(pos.x, stand_h / 2.0, pos.z), Vector3(0.14, stand_h, 0.14), ControlRoom.LAV_DARK)
	var vp := SubViewport.new()
	vp.size = Vector2i(int(ScreenUI.W), int(ScreenUI.H))
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	room.add_child(vp)
	var ui: Control
	match kind:
		"environment":
			ui = EnvironmentScreen.new()
		"alerts":
			ui = WarningsScreen.new()
		_:
			var status_ui := ScreenUI.new()
			status_ui.mode = kind
			ui = status_ui
	ui.name = "Screen_" + kind
	vp.add_child(ui)
	screens[kind] = ui
	var quad := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.4, 0.875)
	quad.mesh = q
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = vp.get_texture()
	quad.material_override = mat
	quad.position = Vector3(0, 0, 0.04)
	bezel.add_child(quad)


func _wing(side: float, pos: Vector3, width: float, depth: float, top: float) -> Node3D:
	var length := 1.3
	var wing := Node3D.new()
	wing.position = Vector3(pos.x + side * (width / 2.0 + 0.46), top - 0.05, pos.z + depth * 0.1 + 0.33)
	wing.rotation_degrees.y = -side * 30.0
	room.add_child(wing)
	var slab := room._box(wing, Vector3.ZERO, Vector3(length, 0.07, depth * 0.9), Color("3b3d45"))
	slab.material_override = room._grunge(Color("3b3d45"))
	room._box(wing, Vector3(0, 0, depth * 0.45), Vector3(length, 0.08, 0.05), ControlRoom.TRIM)   # orange edge trim
	var base_h := top - 0.07
	room._box(wing, Vector3(0, -0.045 - base_h / 2.0, 0), Vector3(length * 0.88, base_h, depth * 0.78), ControlRoom.HULL)
	return wing


func _headphones(parent: Node3D, pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = 25.0
	parent.add_child(root)
	var band := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.09
	tm.outer_radius = 0.13
	band.mesh = tm
	band.material_override = room._mat(Color("16171c"))
	band.scale = Vector3(1.0, 1.0, 0.8)
	root.add_child(band)
	for sx in [-1.0, 1.0]:
		var cup := room._cyl(root, Vector3(sx * 0.11, 0.0, 0.0), 0.075, 0.07, Color("0f1014"))
		cup.rotation_degrees.z = 90.0


func _console(wing: Node3D) -> void:
	var con := Node3D.new()
	con.position = Vector3(0, 0.035, -0.1)
	wing.add_child(con)
	room._box(con, Vector3(0, 0.12, 0), Vector3(0.9, 0.24, 0.5), Color("55453e"))
	var tilt := Node3D.new()
	tilt.position = Vector3(0, 0.26, 0.0)
	tilt.rotation_degrees.x = -22.0
	con.add_child(tilt)
	room._box(tilt, Vector3.ZERO, Vector3(0.9, 0.03, 0.46), Color("2b2c33"))
	_dial(tilt, Vector3(-0.22, 0.02, -0.1), 0.12)
	_dial(tilt, Vector3(0.22, 0.02, -0.1), 0.12)
	var bcols := [Color("ff3b2a"), Color("ffb02e"), Color("6b6f7a"), Color("ff3b2a"), Color("4ade80")]
	for row in 2:
		for k in 5:
			var bc: Color = bcols[(k + row) % 5]
			room._box(tilt, Vector3(-0.32 + k * 0.16, 0.025, 0.08 + row * 0.1), Vector3(0.07, 0.03, 0.06), bc, (k + row) % 3 == 0)


func _dial(parent: Node3D, pos: Vector3, r: float) -> void:
	room._cyl(parent, pos, r, 0.02, Color("101114"))
	var face := room._cyl(parent, pos + Vector3(0, 0.008, 0), r * 0.82, 0.02, Color("ffb02e"), true)
	room._dim(face, 0.8)
	var needle := room._box(parent, pos + Vector3(0, 0.02, 0), Vector3(r * 0.08, 0.006, r * 0.7), Color("1b1b1f"))
	needle.rotation_degrees.y = randf_range(-50.0, 50.0)
