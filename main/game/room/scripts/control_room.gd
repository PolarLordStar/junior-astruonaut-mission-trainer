extends Node3D
## Mars control room built from the Kenney Space Station Kit (.glb files).
## Every model is measured when the scene starts, so no manual scaling is needed.
##
## Monitor 1 ("status"):      power supply, solar panel durability (6 panels), oxygen supply   (ScreenUI.gd, status_screen.tscn)
## Monitor 2 ("environment"): radiation, oxygen, toxic perchlorate                              (environment_screen.gd)
## Monitor 3 ("alerts"):      ONLY active warnings, black screen when there are none           (warnings_screen.gd)
## Esc opens the pause menu (see PauseMenu.gd).
##
## SCENE NODES: the lights (RoomLamp, AlertLight, Sun), the WorldEnvironment, the Camera3D, the
## Vignette, the PauseMenu and the three monitor screens (StatusScreen, EnvironmentScreen,
## AlertsScreen, each inside its own SubViewport) are real nodes in control_room.tscn: select them
## in the editor to change colours, energy, shadows, fov, text and so on. This script only PLACES
## them, because positions depend on the room size measured from the Kenney models. The walls,
## floor, desk, window, scenery and set dressing are still built from code (they are loops over
## the measured kit models, not single nodes).
##
## DATA: every stat is its own child node of ControlRoom (RadiationSensor, OxygenSensor,
## PerchlorateSensor, PowerSensor, SolarPanelsSensor, StormSystem, MissionClock).
## Each one simulates by default; turn "Simulate" off in the Inspector and feed it NASA data instead
## (Data array, or sensor.set_value(x) from code). This script only displays what they report.

const KIT := "res://Assets/kenney_space-station-kit/Models/GLB format/"
const COLS := 5            # room width in floor tiles
const ROWS := 4            # room depth in floor tiles (was 5, smaller room)
const DESK_AT := 0.44      # desk position as a fraction of the room depth (was 0.42). Bigger = window closer
const MID_COL := 2         # which tile gets the window (0-based)
const MID_ROW := 1         # which tile gets a door on each side wall
const WALL_YAW_FIX := 0.0  # if wall details face OUTWARD, set this to 180.0

const WIN_FROM := 1        # big window starts at this back-wall tile (0-based)
const WIN_TO := 3          # ...and ends at this tile (inclusive)
const HEIGHT_SCALE := 1.4  # taller room (1.0 = original kit height)
const WALL_COL := Color("3a3c45")   # window frame / trims: dark gunmetal
const TRIM := Color("d9651f")       # rusty orange accent
# ---- Mars-mission "worn industrial" look (tweak these to taste) ----
const WALL_TINT := Color(0.6, 0.5, 0.45)    # multiplied onto the Kenney wall texture
const FLOOR_TINT := Color(0.4, 0.35, 0.34)
const CEIL_TINT := Color(0.72, 0.4, 0.34)   # reddish ceiling panels
const PROP_TINT := Color(0.55, 0.5, 0.48)
const DESK_TINT := Color(0.38, 0.38, 0.42)
const HULL := Color("23242b")
# Lamp / sun / ambient light settings now live on the RoomLamp, Sun and WorldEnvironment nodes
# (Inspector). Their starting energy and colour are read from there when the scene starts.
const FLARE_COL := Color("ff4d1f")
const GREEN := Color("4ade80")
const RED := Color("ff5a4a")
const DARK := Color("2d2e55")
const LAV_DARK := Color("6b6ca4")
const CAM_PITCH := -11.0   # how far the camera looks down (degrees)
const CAM_HEIGHT := 0.62   # camera height as a fraction of the room height (a bit higher = monitors sit lower, so the window stays visible)
const MONITOR_SCALE := 1.4 # 1.0 = original monitor size. Bigger = easier to read, but covers more of the window
const SHOW_MENU_ON_START := false

# ---- data nodes: CHILD nodes of ControlRoom, found automatically by group (names/order do not matter) ----
var storm: StormSystem
var clock: MissionClock
var sensors := {}            # sensor id -> Sensor ("power", "oxygen", "panels", "radiation", "perchlorate" ...)

# read-only shortcuts so the visual code below keeps working with the old names
var storm_phase: int:
	get:
		return storm.phase if storm != null else 0
var storm_type: String:
	get:
		return storm.kind if storm != null else ""
var storm_level: int:
	get:
		return storm.level if storm != null else 1
var storm_eta: float:
	get:
		return storm.eta if storm != null else 0.0
var storm_left: float:
	get:
		return storm.left if storm != null else 0.0
var _dust_amt: float:
	get:
		return storm.dust_amt if storm != null else 0.0

var tile := 2.0
var wall_h := 2.0
@onready var cam: Camera3D = %Camera3D
var _steam: Array[MeshInstance3D] = []
@onready var _light: OmniLight3D = %RoomLamp          # the warm lamp that flickers
@onready var _alert_light: OmniLight3D = %AlertLight   # red, pulses on warnings
@onready var _sun_light: DirectionalLight3D = %Sun
var _light_base := 1.0        # starting values, read from the nodes above in _ready()
var _sun_base_energy := 1.0
var _sun_base_color := Color.WHITE
var _haze_mat: ShaderMaterial
var _led_green: MeshInstance3D
var _led_red: MeshInstance3D
# The monitors are optional: delete a viewport (and its screen) from control_room.tscn to remove one.
@onready var _status_viewport := get_node_or_null("%StatusViewport") as SubViewport
@onready var _env_viewport := get_node_or_null("%EnvironmentViewport") as SubViewport
@onready var _alerts_viewport := get_node_or_null("%AlertsViewport") as SubViewport
@onready var _status_screen := get_node_or_null("%StatusScreen") as ScreenUI
@onready var _env_screen := get_node_or_null("%EnvironmentScreen") as EnvironmentScreen
@onready var _alerts_screen := get_node_or_null("%AlertsScreen") as WarningsScreen
@onready var _menu: PauseMenu = %PauseMenu
var _flicker := 0.0
var _shake := 0.0
var _shake_off := Vector2.ZERO
var _sun_core: MeshInstance3D
var _sun_halo: MeshInstance3D
var _flare_root: Node3D
var _flare_amt := 0.0
var _clouds: Array[MeshInstance3D] = []
var _rack_leds: Array[MeshInstance3D] = []
var _rack_timer := 0.0
var _grunge_cache := {}
var _warnings: Array = []     # active warnings, rebuilt every frame (shown on monitor 3)
var window_bars: Array[MeshInstance3D] = []   # the 2 bars between the window panes: window_bars[0].hide() removes one
var _bars_root: Node3D


func _ready() -> void:
	_find_nodes()
	var fs := _size("floor")
	if fs == Vector3.ZERO:
		push_error("Kenney kit not found in %s. Copy the .glb files and the Textures folder there." % KIT)
	else:
		tile = maxf(fs.x, fs.z)
	var ws := _size("wall")
	if ws != Vector3.ZERO:
		wall_h = ws.y * HEIGHT_SCALE
	_light_base = _light.light_energy
	_sun_base_energy = _sun_light.light_energy
	_sun_base_color = _sun_light.light_color
	_lighting()
	_shell(fs.y)
	_big_window()
	_outside()
	var desk := _desk()
	_camera(desk)
	_props(desk)
	_decor()
	if SHOW_MENU_ON_START:
		_menu.open()


func _process(delta: float) -> void:
	_warnings = _collect_warnings()
	_storm_visuals(delta)
	_update_warning_lights()
	_flicker_light(delta)
	_extras(delta)
	_push_screens()
	for st in _steam:
		var ph := fmod(Time.get_ticks_msec() / 1000.0 * 0.4 + float(st.get_meta("phase")), 1.0)
		st.position = Vector3(sin(ph * 6.0) * 0.03, 0.24 + ph * 0.35, 0.0)
		st.scale = Vector3.ONE * (0.8 + ph)
		(st.material_override as StandardMaterial3D).albedo_color.a = (1.0 - ph) * 0.5
	# FNAF-style look-around: move the mouse left/right to turn the view.
	var vp := get_viewport()
	var m := vp.get_mouse_position() / vp.get_visible_rect().size
	cam.rotation_degrees.y = lerpf(cam.rotation_degrees.y, -(m.x - 0.5) * 50.0, 0.1)
	cam.rotation_degrees.x = CAM_PITCH + _shake_off.x
	cam.rotation_degrees.z = _shake_off.y


# ---------- data nodes ----------
func _find_nodes() -> void:
	storm = get_tree().get_first_node_in_group("storm") as StormSystem
	clock = get_tree().get_first_node_in_group("clock") as MissionClock
	for n in get_tree().get_nodes_in_group("sensors"):
		var sen := n as Sensor
		if sen != null:
			sensors[sen.id] = sen
	if storm == null:
		push_warning("No StormSystem node found. Add one as a child of ControlRoom.")
	if sensors.is_empty():
		push_warning("No Sensor nodes found. Add RadiationSensor, OxygenSensor, ... as children of ControlRoom.")


func _val(id: String) -> float:
	var sen: Sensor = sensors.get(id)
	return sen.value if sen != null else 0.0


# ---------- pause menu ----------
# The PauseMenu node is in control_room.tscn; its three signals are connected to these there.
func _on_restart() -> void:
	# TODO: restart behaviour (to be decided).
	_menu.toast("Restart is not set up yet")


func _on_options() -> void:
	# TODO: options screen (to be decided).
	_menu.toast("Options are not set up yet")


func _on_main_menu() -> void:
	get_tree().paused = false   # the pause menu paused the tree; undo it first
	get_tree().change_scene_to_file("res://main_menu.tscn")


# ---------- storm visuals ----------
## Dust haze on the window, room shake and dimmer light while a storm is hitting.
func _storm_visuals(delta: float) -> void:
	var shake := 0.0
	if storm_phase == 2:
		match storm_type:
			"DUST STORM":
				shake = 0.2 * storm_level
			"DUST DEVIL":
				shake = 0.12 * storm_level
	_shake = move_toward(_shake, shake, delta * 0.2)
	if _haze_mat != null:
		_haze_mat.set_shader_parameter("amount", _dust_amt)
	var jitter := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
	_shake_off = _shake_off.lerp(jitter, 0.35)


## Red alarm light pulses while there are warnings (the desk lamp box was removed, so the LEDs are skipped).
func _update_warning_lights() -> void:
	var n := _warnings.size()
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 5.0)
	if _alert_light != null:
		var target := 0.0
		if n > 0:
			target = pulse * (1.4 if storm_phase == 2 else 0.8)
		_alert_light.light_energy = lerpf(_alert_light.light_energy, target, 0.15)
	_set_led(_led_green, n == 0)
	_set_led(_led_red, n > 0 and (storm_phase != 2 or pulse > 0.4))


func _set_led(led: MeshInstance3D, on: bool) -> void:
	if led == null:
		return
	var m := led.material_override as StandardMaterial3D
	var base: Color = led.get_meta("base")
	m.emission_energy_multiplier = 1.6 if on else 0.0
	m.albedo_color = base if on else base.darkened(0.7)


func _push_screens() -> void:
	var st := _status_screen
	if st != null:
		st.power = _val("power")
		st.oxygen = _val("oxygen")
		var sp := sensors.get("panels") as SolarPanelsSensor
		if sp != null:
			st.panels = sp.panels
		if clock != null:
			st.sol = clock.sol
			st.clock_s = clock.clock_s
	var env := _env_screen
	if env != null:
		for id in env.rows.keys():
			env.set_value(id, _val(id))
		if clock != null:
			env.set_time(clock.sol, clock.clock_s)
	var al := _alerts_screen
	if al != null:
		al.set_warnings(_warnings)


## Everything that should show on monitor 3 right now: the storm, plus whatever each sensor
## reports through its own get_warning() (edit the warning text in that sensor's script).
func _collect_warnings() -> Array:
	var out: Array = []
	if storm_phase == 1:
		out.append({"id": "storm", "title": "%s INCOMING" % storm_type, "detail": "Arrives in %s" % _mmss(storm_eta), "badge": _storm_badge(), "level": storm_level})
	elif storm_phase == 2:
		out.append({"id": "storm", "title": "%s ACTIVE" % storm_type, "detail": "Passes in %s" % _mmss(storm_left), "badge": _storm_badge(), "level": storm_level})
	for sen in sensors.values():
		var w: Dictionary = sen.get_warning()
		if not w.is_empty():
			out.append(w)
	return out


func _storm_badge() -> String:
	match storm_level:
		1:
			return "MINOR"
		2:
			return "MODERATE"
	return "SEVERE"


func _level_badge(lv: int) -> String:
	return "CRITICAL" if lv == 2 else "CAUTION"


func _mmss(seconds: float) -> String:
	var t := maxi(0, ceili(seconds))
	return "%d:%02d" % [int(t / 60.0), t % 60]


func _flicker_light(delta: float) -> void:
	if _light == null:
		return
	_flicker = move_toward(_flicker, 0.0, delta * 3.0)
	var chance := 0.004 + (0.012 * storm_level if storm_phase == 2 else 0.0)
	if randf() < chance:
		_flicker = 0.25
	_light.light_energy = (_light_base - _flicker) * (1.0 - 0.3 * _dust_amt)


# ---------- polish ----------
func _pipe(x: float, z: float) -> void:
	var ps := _size("pipe")
	var p := _place("pipe", Vector3(x, 0, z), 0.0, false, PROP_TINT)
	if p != null and ps.y > 0.01:
		p.scale.y = wall_h / ps.y
	for k in 3:
		_place("pipe-ring-colored", Vector3(x, wall_h * (0.2 + 0.3 * k), z), 0.0, false, Color(0.85, 0.45, 0.3))


# ---------- kit helpers ----------
func _bounds(n: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var have := false
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out = xf * (n as MeshInstance3D).get_aabb()
		have = true
	for c in n.get_children():
		if c is Node3D:
			var b := _bounds(c, xf * (c as Node3D).transform)
			if b.has_surface():
				out = out.merge(b) if have else b
				have = true
	return out


## Loads a kit model and wraps it so its origin is bottom-centre.
func _kit(model: String) -> Node3D:
	var path := KIT + model + ".glb"
	if not ResourceLoader.exists(path):
		push_warning("Missing model: " + path)
		return null
	var inst := (load(path) as PackedScene).instantiate() as Node3D
	var bb := _bounds(inst, Transform3D.IDENTITY)
	var c := bb.get_center()
	inst.position = Vector3(-c.x, -bb.position.y, -c.z)
	var wrap := Node3D.new()
	wrap.add_child(inst)
	wrap.set_meta("size", bb.size)
	return wrap


func _size(model: String) -> Vector3:
	var n := _kit(model)
	if n == null:
		return Vector3.ZERO
	var s: Vector3 = n.get_meta("size")
	n.free()
	return s


func _place(model: String, pos: Vector3, yaw := 0.0, align_x := false, tint := Color.WHITE) -> Node3D:
	var n := _kit(model)
	if n == null:
		return null
	var s: Vector3 = n.get_meta("size")
	if align_x and s.z > s.x * 1.01:
		yaw += 90.0
	n.position = pos
	n.rotation_degrees.y = yaw
	if model.begins_with("wall"):
		n.scale.y = HEIGHT_SCALE
	if tint != Color.WHITE:
		_tint(n, tint)
	add_child(n)
	return n


func _mat(color: Color, glow := false) -> StandardMaterial3D:
	var s := StandardMaterial3D.new()
	s.albedo_color = color
	s.roughness = 1.0
	if glow:
		s.emission_enabled = true
		s.emission = color
		s.emission_energy_multiplier = 1.5
	return s


func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, glow := false) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	m.mesh = mesh
	m.material_override = _mat(color, glow)
	m.position = pos
	parent.add_child(m)
	return m


# ---------- scene parts ----------
## The environment and the three lights are nodes in control_room.tscn (WorldEnvironment, RoomLamp,
## AlertLight, Sun). Colours, energy and shadows are edited there. This only places them and sets
## the ranges, because those depend on the room size measured from the kit models.
func _lighting() -> void:
	var light_range := tile * COLS * 1.6
	_light.position = Vector3(0, wall_h * 0.5, -tile * ROWS * 0.5)
	_light.omni_range = light_range
	_alert_light.position = Vector3(0, wall_h * 0.6, -tile * ROWS * 0.6)
	_alert_light.omni_range = light_range
	_sun_light.directional_shadow_max_distance = tile * ROWS * 1.6
	_sun_light.look_at_from_position(Vector3(1.5, wall_h * 1.3, -tile * ROWS - tile * 4.0), Vector3(0, 0, -tile * ROWS * 0.45))


func _shell(floor_thick: float) -> void:
	var w := COLS * tile
	var d := ROWS * tile
	# floor + ceiling (the ceiling is the floor tile flipped upside down)
	for i in COLS:
		for j in ROWS:
			var p := Vector3(-w / 2.0 + (i + 0.5) * tile, 0, -(j + 0.5) * tile)
			_place("floor", p, 0.0, false, FLOOR_TINT)
			var c := _place("floor", p, 0.0, false, CEIL_TINT)
			if c != null:
				c.rotation_degrees.x = 180.0
				c.position.y = wall_h + floor_thick
	# back and front walls
	for i in COLS:
		var x := -w / 2.0 + (i + 0.5) * tile
		if i < WIN_FROM or i > WIN_TO:
			_place("wall", Vector3(x, 0, -d), WALL_YAW_FIX, true, WALL_TINT)
		_place("wall", Vector3(x, 0, 0), 180.0 + WALL_YAW_FIX, true, WALL_TINT)
	# side walls, each with a door
	for j in ROWS:
		var z := -(j + 0.5) * tile
		var piece := "wall-door" if j == MID_ROW else "wall"
		_place(piece, Vector3(-w / 2.0, 0, z), 90.0 + WALL_YAW_FIX, true, WALL_TINT)
		_place(piece, Vector3(w / 2.0, 0, z), -90.0 + WALL_YAW_FIX, true, WALL_TINT)


func _big_window() -> void:
	var w := COLS * tile
	var d := ROWS * tile
	var x0 := -w / 2.0 + WIN_FROM * tile
	var x1 := -w / 2.0 + (WIN_TO + 1) * tile
	var width := x1 - x0
	var cx := (x0 + x1) / 2.0
	var thick := tile * 0.25
	var sill_h := wall_h * 0.22
	var lintel_h := wall_h * 0.16
	var z := -d
	var open_h := wall_h - lintel_h - sill_h
	var sill := _box(self, Vector3(cx, sill_h / 2.0, z), Vector3(width, sill_h, thick), WALL_COL)
	sill.material_override = _grunge(WALL_COL)
	var lintel := _box(self, Vector3(cx, wall_h - lintel_h / 2.0, z), Vector3(width, lintel_h, thick), WALL_COL)
	lintel.material_override = _grunge(WALL_COL)
	_box(self, Vector3(cx, sill_h, z), Vector3(width, tile * 0.06, thick * 1.3), TRIM)
	_box(self, Vector3(cx, wall_h - lintel_h, z), Vector3(width, tile * 0.06, thick * 1.3), TRIM)
	# only the 2 inner bars (the outer ones merged with the walls). Each bar is its own node
	# inside "WindowBars", so bar.hide() / bar.queue_free() removes just that bar.
	_bars_root = Node3D.new()
	_bars_root.name = "WindowBars"
	add_child(_bars_root)
	for k in range(1, 3):
		var px := x0 + width * k / 3.0
		var bar := _box(_bars_root, Vector3(px, sill_h + open_h / 2.0, z), Vector3(tile * 0.1, open_h, thick * 0.7), WALL_COL)
		bar.name = "WindowBar%d" % k
		bar.material_override = _grunge(WALL_COL)
		window_bars.append(bar)
	# mission patch above the window
	_patch(Vector3(cx, wall_h - lintel_h / 2.0, z + thick / 2.0 + 0.005), lintel_h * 0.45)
	# dust haze just outside the glass: invisible until a dust storm hits
	var haze := MeshInstance3D.new()
	var hq := QuadMesh.new()
	hq.size = Vector2(width, open_h)
	haze.mesh = hq
	var hs := Shader.new()
	hs.code = """shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled;
uniform float amount = 0.0;
uniform vec3 dust_col : source_color = vec3(0.80, 0.46, 0.22);
void fragment() {
	float n = 0.5 + 0.25 * sin(UV.x * 9.0 + TIME * 1.7) + 0.25 * sin(UV.y * 7.0 - TIME * 1.1 + UV.x * 4.0);
	ALBEDO = dust_col;
	ALPHA = clamp(amount * (0.55 + 0.6 * n), 0.0, 0.95);
}
"""
	_haze_mat = ShaderMaterial.new()
	_haze_mat.shader = hs
	_haze_mat.set_shader_parameter("amount", 0.0)
	haze.material_override = _haze_mat
	haze.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	haze.position = Vector3(cx, sill_h + open_h / 2.0, z - 0.05)
	add_child(haze)


func _dust() -> void:
	var d := ROWS * tile
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
		add_child(m)
		_clouds.append(m)


func _glow_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _flat(pos: Vector3, size: Vector3, color: Color) -> void:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.material_override = _glow_mat(color)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = pos
	add_child(m)


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
	add_child(m)


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
	add_child(m)


func _orb(pos: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	m.mesh = sm
	m.material_override = _glow_mat(color)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = pos
	add_child(m)
	return m


func _outside() -> void:
	var d := ROWS * tile
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
	add_child(sky)
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
	add_child(dome)
	_flat(Vector3(-4 * s, gy + 1.1 * s, -d - 5.2 * s), Vector3(0.5, 0.25, 0.05) * s, Color("ffd36b"))
	_flat(Vector3(-3.1 * s, gy + 1.5 * s, -d - 6 * s), Vector3(0.06, 1.3, 0.06) * s, Color("d8d9f5"))
	_flat(Vector3(-3.1 * s, gy + 2.2 * s, -d - 6 * s), Vector3(0.16, 0.16, 0.16) * s, Color("ff5a4a"))
	# sun with a glow; during a solar flare it swells and shoots out orange spikes
	var sun_pos := Vector3(2.0 * s, wall_h * 0.6, -d - 12 * s)
	_sun_core = _orb(sun_pos, 2.2 * s, Color("fff0a8"))
	_sun_halo = _orb(sun_pos, 4.0 * s, Color(1.0, 0.85, 0.4, 0.25))
	_flare_root = Node3D.new()
	_flare_root.position = sun_pos + Vector3(0, 0, 0.2)
	add_child(_flare_root)
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
		var m := _mat(Color(1, 1, 1, 0.5))
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		st.material_override = m
		st.set_meta("phase", i * 0.33)
		cup.add_child(st)
		_steam.append(st)


func _cup_part(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _desk() -> Dictionary:
	var model := "table-large"
	var s := _size(model)
	if s == Vector3.ZERO:
		model = "table"
		s = _size(model)
	var pos := Vector3(0, 0, -ROWS * tile * DESK_AT)
	var n := _place(model, pos, 0.0, true, DESK_TINT)
	var width := maxf(s.x, s.z) if n != null else tile * 2.0
	var depth := minf(s.x, s.z) if n != null else tile
	var top := s.y if n != null else 0.8
	# monitor rig: built at a "5 wide desk" scale, then scaled to fit the real desk
	var u := (width / 5.0) * 0.9
	var rig := Node3D.new()
	rig.position = Vector3(pos.x, top, pos.z)
	rig.scale = Vector3.ONE * u
	add_child(rig)
	# three monitors, the outer two angled towards the player
	# MONITOR_SCALE makes them bigger; the side ones move outward so they never overlap the middle one,
	# and all three keep the same gap above the desk (their bottom edge stays put, they grow upward).
	var mon_y := 0.145 + 0.475 * MONITOR_SCALE
	var mon_side := 0.76 * MONITOR_SCALE * (1.0 + cos(deg_to_rad(16.0))) + 0.12
	_monitor(rig, _status_viewport, Vector3(-mon_side, mon_y, -0.2), 16.0)    # left: life support
	_monitor(rig, _env_viewport, Vector3(0.0, mon_y, -0.42), 0.0)             # middle: radiation / oxygen / perchlorate
	_monitor(rig, _alerts_viewport, Vector3(mon_side, mon_y, -0.2), -16.0)    # right: warnings only
	_box(rig, Vector3(0, 0.02, 0.45), Vector3(1.1, 0.04, 0.35), DARK)              # keyboard
	_box(rig, Vector3(1.05, 0.008, 0.5), Vector3(0.5, 0.016, 0.4), Color("17181d"))  # mouse pad
	_box(rig, Vector3(1.05, 0.035, 0.5), Vector3(0.1, 0.04, 0.16), Color("2b2d36"))  # mouse
	_box(rig, Vector3(0, -0.01, depth * 0.5 / u), Vector3(width / u, 0.05, 0.05), TRIM)   # orange front edge
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
	var tablet := _box(lw, Vector3(-0.1, 0.045, 0.12), Vector3(0.42, 0.02, 0.3), Color("14151a"))
	tablet.rotation_degrees.y = 14.0
	_dim(_box(tablet, Vector3(0, 0.0105, 0), Vector3(0.38, 0.003, 0.26), Color("8fb4d6"), true), 0.9)
	var paper := _box(lw, Vector3(0.35, 0.042, -0.05), Vector3(0.3, 0.012, 0.22), Color("cfc6b0"))
	paper.rotation_degrees.y = -12.0
	_headphones(lw, Vector3(-0.42, 0.04, 0.05))
	var rw := _wing(1.0, pos, width, depth, top)
	_console(rw)
	_no_shadow(lw)
	_no_shadow(rw)
	return {"pos": pos, "top": top, "width": width}


## One desk monitor: bezel, stand and a quad that shows the SubViewport's picture. The screen
## itself (the SubViewport and the UI inside it) is a node in control_room.tscn.
func _monitor(parent: Node3D, vp: SubViewport, pos: Vector3, yaw: float) -> void:
	if vp == null:
		return
	var bezel := _box(parent, pos, Vector3(1.52 * MONITOR_SCALE, 0.95 * MONITOR_SCALE, 0.07), DARK)
	bezel.rotation_degrees.y = yaw
	var stand_h := pos.y - 0.475 * MONITOR_SCALE + 0.04
	_box(parent, Vector3(pos.x, stand_h / 2.0, pos.z), Vector3(0.14, stand_h, 0.14), LAV_DARK)
	var quad := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.4, 0.875) * MONITOR_SCALE
	quad.mesh = q
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = vp.get_texture()
	quad.material_override = mat
	quad.position = Vector3(0, 0, 0.04)
	bezel.add_child(quad)


func _props(desk: Dictionary) -> void:
	var w := COLS * tile
	var d := ROWS * tile
	var dpos: Vector3 = desk["pos"]
	var dw: float = desk["width"]
	_place("computer-system", Vector3(-w / 2.0 + tile * 0.5, 0, -d * 0.3), 90.0, false, PROP_TINT)
	_place("chair", Vector3(dpos.x + dw * 0.75, 0, dpos.z + tile * 0.6), 165.0, false, PROP_TINT)


func _camera(desk: Dictionary) -> void:
	var u: float = float(desk["width"]) / 5.0
	var dpos: Vector3 = desk["pos"]
	cam.position = Vector3(dpos.x, wall_h * CAM_HEIGHT, minf(dpos.z + 2.6 * u, -tile * 0.3))
	cam.rotation_degrees = Vector3(CAM_PITCH, 0, 0)   # fov and "current" are set on the Camera3D node


## Multiplies a colour onto every material of a kit model (used to darken the pastel Kenney look).
func _tint(n: Node, col: Color) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null:
			for i in mi.mesh.get_surface_count():
				var src := mi.get_active_material(i)
				if src is StandardMaterial3D:
					var dup := src.duplicate() as StandardMaterial3D
					dup.albedo_color = dup.albedo_color * col
					mi.set_surface_override_material(i, dup)
	for c in n.get_children():
		_tint(c, col)


## Cloudy, scratched metal made from procedural noise (no image files needed).
func _grunge(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if _grunge_cache.has(key):
		return _grunge_cache[key]
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.02
	noise.fractal_octaves = 4
	var ramp := Gradient.new()
	ramp.set_color(0, color.darkened(0.45))
	ramp.set_color(1, color.lightened(0.08))
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.noise = noise
	tex.color_ramp = ramp
	tex.seamless = true
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = 0.9
	_grunge_cache[key] = m
	return m


func _cyl(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, glow := false) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 12
	m.mesh = cm
	m.material_override = _mat(color, glow)
	m.position = pos
	parent.add_child(m)
	return m


func _dim(mi: MeshInstance3D, energy: float) -> void:
	var m := mi.material_override as StandardMaterial3D
	if m != null:
		m.emission_energy_multiplier = energy


## Round mission badge: navy disc, orange ring, little rocket.
func _patch(pos: Vector3, r: float) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var ring := _cyl(root, Vector3.ZERO, r, 0.04, TRIM.darkened(0.15))
	ring.rotation_degrees.x = 90.0
	var face := _cyl(root, Vector3(0, 0, 0.012), r * 0.84, 0.04, Color("101a33"))
	face.rotation_degrees.x = 90.0
	_box(root, Vector3(0, r * 0.05, 0.04), Vector3(r * 0.2, r * 0.8, 0.012), Color("e8ecff"))
	_box(root, Vector3(0, r * 0.52, 0.04), Vector3(r * 0.1, r * 0.2, 0.012), Color("e8ecff"))
	_box(root, Vector3(-r * 0.2, -r * 0.25, 0.04), Vector3(r * 0.1, r * 0.3, 0.012), TRIM)
	_box(root, Vector3(r * 0.2, -r * 0.25, 0.04), Vector3(r * 0.1, r * 0.3, 0.012), TRIM)
	var flame := _box(root, Vector3(0, -r * 0.55, 0.045), Vector3(r * 0.5, r * 0.08, 0.012), Color("ff7a2a"), true)
	_dim(flame, 0.8)


func _wing(side: float, pos: Vector3, width: float, depth: float, top: float) -> Node3D:
	var length := 1.3
	var wing := Node3D.new()
	wing.position = Vector3(pos.x + side * (width / 2.0 + 0.46), top - 0.05, pos.z + depth * 0.1 + 0.33)
	wing.rotation_degrees.y = -side * 30.0
	add_child(wing)
	var slab := _box(wing, Vector3.ZERO, Vector3(length, 0.07, depth * 0.9), Color("3b3d45"))
	slab.material_override = _grunge(Color("3b3d45"))
	_box(wing, Vector3(0, 0, depth * 0.45), Vector3(length, 0.08, 0.05), TRIM)   # orange edge trim
	var base_h := top - 0.07
	_box(wing, Vector3(0, -0.045 - base_h / 2.0, 0), Vector3(length * 0.88, base_h, depth * 0.78), HULL)
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
	band.material_override = _mat(Color("16171c"))
	band.scale = Vector3(1.0, 1.0, 0.8)
	root.add_child(band)
	for sx in [-1.0, 1.0]:
		var cup := _cyl(root, Vector3(sx * 0.11, 0.0, 0.0), 0.075, 0.07, Color("0f1014"))
		cup.rotation_degrees.z = 90.0


func _console(wing: Node3D) -> void:
	var con := Node3D.new()
	con.position = Vector3(0, 0.035, -0.1)
	wing.add_child(con)
	_box(con, Vector3(0, 0.12, 0), Vector3(0.9, 0.24, 0.5), Color("55453e"))
	var tilt := Node3D.new()
	tilt.position = Vector3(0, 0.26, 0.0)
	tilt.rotation_degrees.x = -22.0
	con.add_child(tilt)
	_box(tilt, Vector3.ZERO, Vector3(0.9, 0.03, 0.46), Color("2b2c33"))
	_dial(tilt, Vector3(-0.22, 0.02, -0.1), 0.12)
	_dial(tilt, Vector3(0.22, 0.02, -0.1), 0.12)
	var bcols := [Color("ff3b2a"), Color("ffb02e"), Color("6b6f7a"), Color("ff3b2a"), Color("4ade80")]
	for row in 2:
		for k in 5:
			var bc: Color = bcols[(k + row) % 5]
			_box(tilt, Vector3(-0.32 + k * 0.16, 0.025, 0.08 + row * 0.1), Vector3(0.07, 0.03, 0.06), bc, (k + row) % 3 == 0)


func _dial(parent: Node3D, pos: Vector3, r: float) -> void:
	_cyl(parent, pos, r, 0.02, Color("101114"))
	var face := _cyl(parent, pos + Vector3(0, 0.008, 0), r * 0.82, 0.02, Color("ffb02e"), true)
	_dim(face, 0.8)
	var needle := _box(parent, pos + Vector3(0, 0.02, 0), Vector3(r * 0.08, 0.006, r * 0.7), Color("1b1b1f"))
	needle.rotation_degrees.y = randf_range(-50.0, 50.0)


## Worn-industrial dressing: server racks, lockers, ceiling beams, pipes and cables.
func _decor() -> void:
	var w := COLS * tile
	var d := ROWS * tile
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
	add_child(r)
	var body := _box(r, Vector3(0, 1.05, 0), Vector3(0.9, 2.1, 0.7), HULL)
	body.material_override = _grunge(Color("2a2b33"))
	_box(r, Vector3(0, 2.1, 0), Vector3(0.96, 0.05, 0.76), TRIM.darkened(0.3))
	var cols := [Color("4ade80"), Color("ffb02e"), Color("5ee0f0"), Color("ff5a4a")]
	for row in 8:
		var y := 0.35 + row * 0.22
		_box(r, Vector3(0, y, 0.355), Vector3(0.8, 0.16, 0.03), Color("0e0f14"))
		for k in 4:
			var c: Color = cols[(row + k) % 4]
			var led := _box(r, Vector3(-0.3 + k * 0.1, y, 0.375), Vector3(0.035, 0.035, 0.015), c, true)
			led.set_meta("base", c)
			_rack_leds.append(led)


func _locker(x: float, z: float, yaw: float) -> void:
	var r := Node3D.new()
	r.position = Vector3(x, 0, z)
	r.rotation_degrees.y = yaw
	add_child(r)
	var body := _box(r, Vector3(0, 1.05, 0), Vector3(0.9, 2.1, 0.7), Color("5a5e66"))
	body.material_override = _grunge(Color("5a5e66"))
	_box(r, Vector3(0, 1.05, 0.355), Vector3(0.02, 2.0, 0.02), Color("20222a"))
	for sx in [-1.0, 1.0]:
		for i in 5:
			_box(r, Vector3(sx * 0.22, 1.7 + i * 0.07, 0.36), Vector3(0.3, 0.025, 0.02), Color("1d1f26"))
		_box(r, Vector3(sx * 0.07, 1.05, 0.37), Vector3(0.03, 0.25, 0.04), Color("8a8f99"))
		_box(r, Vector3(sx * 0.22, 1.4, 0.36), Vector3(0.2, 0.06, 0.01), TRIM)


func _ceiling() -> void:
	var w := COLS * tile
	var d := ROWS * tile
	var y := wall_h - 0.03
	for k in 4:
		_box(self, Vector3(0, y - 0.07, -d * (0.15 + 0.25 * k)), Vector3(w, 0.14, 0.2), Color("2a2b32"))
	for sx in [-1.0, 1.0]:
		var p1 := _cyl(self, Vector3(sx * 1.6, y - 0.18, -d / 2.0), 0.07, d, Color("4a3a36"))
		p1.rotation_degrees.x = 90.0
		var p2 := _cyl(self, Vector3(sx * 2.2, y - 0.16, -d / 2.0), 0.04, d, TRIM.darkened(0.35))
		p2.rotation_degrees.x = 90.0
		_dim(_box(self, Vector3(sx * 3.2, y, -d * 0.45), Vector3(0.9, 0.03, 0.5), Color("ff3b2a"), true), 0.7)
	_dim(_box(self, Vector3(0, y, -d * 0.5), Vector3(0.12, 0.03, d * 0.7), Color("ffb066"), true), 0.9)


func _wall_conduits() -> void:
	var w := COLS * tile
	var d := ROWS * tile
	for sx in [-1.0, 1.0]:
		for yy in [0.72, 0.5]:
			var p := _cyl(self, Vector3(sx * (w / 2.0 - tile * 0.5), wall_h * yy, -d + 0.17), 0.05, tile * 0.9, Color("4a3a36"))
			p.rotation_degrees.z = 90.0


func _cables() -> void:
	var w := COLS * tile
	var d := ROWS * tile
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for sx in [-1.0, 1.0]:
		for k in 7:
			var h := rng.randf_range(0.5, 1.3)
			var cx: float = sx * (w / 2.0 - rng.randf_range(0.2, 0.6))
			var cz := -d * rng.randf_range(0.55, 0.9)
			var col := Color("15161b") if k % 3 != 0 else TRIM.darkened(0.4)
			_cyl(self, Vector3(cx, wall_h - h / 2.0, cz), 0.018, h, col)


## Blinking rack lights, solar-flare sun, and dust clouds rolling in.
func _extras(delta: float) -> void:
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
	var target := 0.0
	if storm_type == "SOLAR FLARE":
		if storm_phase == 2:
			target = 1.0
		elif storm_phase == 1:
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
	if _sun_light != null:
		_sun_light.light_color = _sun_base_color.lerp(FLARE_COL, _flare_amt)
		_sun_light.light_energy = _sun_base_energy * (1.0 - 0.75 * _dust_amt) * (1.0 + 0.5 * _flare_amt)
	for i in _clouds.size():
		var c := _clouds[i]
		var bp: Vector3 = c.get_meta("base_pos")
		c.position = bp + Vector3(sin(t * 0.15 + i) * 0.8, 0.0, _dust_amt * tile * 1.4)
		c.scale = Vector3(1.6, 0.8, 1.0) * (1.0 + 0.5 * _dust_amt)
		(c.material_override as StandardMaterial3D).albedo_color.a = 0.28 + 0.4 * _dust_amt


func _no_shadow(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_no_shadow(c)
