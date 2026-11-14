class_name RoomDecor
extends RefCounted
## Worn-industrial dressing: server racks, lockers, ceiling beams, pipes and cables.
## Built by ControlRoom._ready() with build(); update(delta) blinks the rack lights.

var room: ControlRoom

var tile: float:
	get:
		return room.tile
var wall_h: float:
	get:
		return room.wall_h


var _rack_leds: Array[MeshInstance3D] = []
var _rack_timer := 0.0


func _init(owner_room: ControlRoom) -> void:
	room = owner_room


## Worn-industrial dressing: server racks, lockers, ceiling beams, pipes and cables.
func build() -> void:
	var w := ControlRoom.COLS * tile
	var d := ControlRoom.ROWS * tile
	var rx := w / 2.0 - 0.42
	_rack(-rx, -d * 0.58, 90.0)
	_rack(-rx, -d * 0.58 - 0.95, 90.0)
	_locker(rx, -d * 0.58, -90.0)
	_locker(rx, -d * 0.58 - 0.95, -90.0)
	_ceiling()
	_wall_conduits()
	_cables()


func _rack(x: float, z: float, yaw: float) -> void:
	var r := Node3D.new()
	r.position = Vector3(x, 0, z)
	r.rotation_degrees.y = yaw
	room.add_child(r)
	var body := room._box(r, Vector3(0, 1.05, 0), Vector3(0.9, 2.1, 0.7), ControlRoom.HULL)
	body.material_override = room._grunge(Color("2a2b33"))
	room._box(r, Vector3(0, 2.1, 0), Vector3(0.96, 0.05, 0.76), ControlRoom.TRIM.darkened(0.3))
	var cols := [Color("4ade80"), Color("ffb02e"), Color("5ee0f0"), Color("ff5a4a")]
	for row in 8:
		var y := 0.35 + row * 0.22
		room._box(r, Vector3(0, y, 0.355), Vector3(0.8, 0.16, 0.03), Color("0e0f14"))
		for k in 4:
			var c: Color = cols[(row + k) % 4]
			var led := room._box(r, Vector3(-0.3 + k * 0.1, y, 0.375), Vector3(0.035, 0.035, 0.015), c, true)
			led.set_meta("base", c)
			_rack_leds.append(led)


func _locker(x: float, z: float, yaw: float) -> void:
	var r := Node3D.new()
	r.position = Vector3(x, 0, z)
	r.rotation_degrees.y = yaw
	room.add_child(r)
	var body := room._box(r, Vector3(0, 1.05, 0), Vector3(0.9, 2.1, 0.7), Color("5a5e66"))
	body.material_override = room._grunge(Color("5a5e66"))
	room._box(r, Vector3(0, 1.05, 0.355), Vector3(0.02, 2.0, 0.02), Color("20222a"))
	for sx in [-1.0, 1.0]:
		for i in 5:
			room._box(r, Vector3(sx * 0.22, 1.7 + i * 0.07, 0.36), Vector3(0.3, 0.025, 0.02), Color("1d1f26"))
		room._box(r, Vector3(sx * 0.07, 1.05, 0.37), Vector3(0.03, 0.25, 0.04), Color("8a8f99"))
		room._box(r, Vector3(sx * 0.22, 1.4, 0.36), Vector3(0.2, 0.06, 0.01), ControlRoom.TRIM)


func _ceiling() -> void:
	var w := ControlRoom.COLS * tile
	var d := ControlRoom.ROWS * tile
	var y := wall_h - 0.03
	for k in 4:
		room._box(room, Vector3(0, y - 0.07, -d * (0.15 + 0.25 * k)), Vector3(w, 0.14, 0.2), Color("2a2b32"))
	for sx in [-1.0, 1.0]:
		var p1 := room._cyl(room, Vector3(sx * 1.6, y - 0.18, -d / 2.0), 0.07, d, Color("4a3a36"))
		p1.rotation_degrees.x = 90.0
		var p2 := room._cyl(room, Vector3(sx * 2.2, y - 0.16, -d / 2.0), 0.04, d, ControlRoom.TRIM.darkened(0.35))
		p2.rotation_degrees.x = 90.0
		room._dim(room._box(room, Vector3(sx * 3.2, y, -d * 0.45), Vector3(0.9, 0.03, 0.5), Color("ff3b2a"), true), 0.7)
	room._dim(room._box(room, Vector3(0, y, -d * 0.5), Vector3(0.12, 0.03, d * 0.7), Color("ffb066"), true), 0.9)


func _wall_conduits() -> void:
	var w := ControlRoom.COLS * tile
	var d := ControlRoom.ROWS * tile
	for sx in [-1.0, 1.0]:
		for yy in [0.72, 0.5]:
			var p := room._cyl(room, Vector3(sx * (w / 2.0 - tile * 0.5), wall_h * yy, -d + 0.17), 0.05, tile * 0.9, Color("4a3a36"))
			p.rotation_degrees.z = 90.0


func _cables() -> void:
	var w := ControlRoom.COLS * tile
	var d := ControlRoom.ROWS * tile
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for sx in [-1.0, 1.0]:
		for k in 7:
			var h := rng.randf_range(0.5, 1.3)
			var cx: float = sx * (w / 2.0 - rng.randf_range(0.2, 0.6))
			var cz := -d * rng.randf_range(0.55, 0.9)
			var col := Color("15161b") if k % 3 != 0 else ControlRoom.TRIM.darkened(0.4)
			room._cyl(room, Vector3(cx, wall_h - h / 2.0, cz), 0.018, h, col)


## Randomly blinking server-rack lights. Called every frame by ControlRoom.
func update(delta: float) -> void:
	_rack_timer -= delta
	if _rack_timer <= 0.0 and not _rack_leds.is_empty():
		_rack_timer = 0.12
		for i in 4:
			var led: MeshInstance3D = _rack_leds[randi() % _rack_leds.size()]
			var m := led.material_override as StandardMaterial3D
			var base: Color = led.get_meta("base")
			var on := randf() > 0.35
			m.emission_energy_multiplier = 1.6 if on else 0.05
			m.albedo_color = base if on else base.darkened(0.7)
