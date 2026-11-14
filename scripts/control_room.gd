class_name ControlRoom
extends Node3D
## Mars control room built from the Kenney Space Station Kit (.glb files).
## Every model is measured when the scene starts, so no manual scaling is needed.
##
## Monitor 1 ("status"):      power supply, solar panel durability (6 panels), oxygen supply   (screen_ui.gd)
## Monitor 2 ("environment"): radiation, oxygen, toxic perchlorate                              (environment_screen.gd)
## Monitor 3 ("alerts"):      ONLY active warnings, black screen when there are none           (warnings_screen.gd)
## Esc opens the pause menu (see pause_menu.gd).
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
const LIGHT_BASE := 0.7    # normal brightness of the main lamp
# ---- Mars-mission "worn industrial" look (tweak these to taste) ----
const WALL_TINT := Color(0.6, 0.5, 0.45)    # multiplied onto the Kenney wall texture
const FLOOR_TINT := Color(0.4, 0.35, 0.34)
const CEIL_TINT := Color(0.72, 0.4, 0.34)   # reddish ceiling panels
const PROP_TINT := Color(0.55, 0.5, 0.48)
const DESK_TINT := Color(0.38, 0.38, 0.42)
const HULL := Color("23242b")
const AMBIENT_ENERGY := 0.55   # raise if the room feels too dark
const SUN_ENERGY := 1.0
const SUN_COL := Color("ff9d5c")
const FLARE_COL := Color("ff4d1f")
const SHOW_SUN_SHADOWS := true  # window light shafts; set false if it looks glitchy or runs slowly
const GREEN := Color("4ade80")
const RED := Color("ff5a4a")
const DARK := Color("2d2e55")
const LAV_DARK := Color("6b6ca4")
const CAM_PITCH := -9.0    # how far the camera looks down (degrees)
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
var cam: Camera3D
var _light: OmniLight3D
var _alert_light: OmniLight3D
var _haze_mat: ShaderMaterial
var _led_green: MeshInstance3D
var _led_red: MeshInstance3D
var _menu: PauseMenu
var outside: RoomOutside     # sky, ground, sun, dust clouds   (room_outside.gd)
var desk_rig: RoomDesk       # desk, monitors, consoles          (room_desk.gd)
var decor: RoomDecor         # racks, lockers, pipes, cables     (room_decor.gd)
var _flicker := 0.0
var _shake := 0.0
var _shake_off := Vector2.ZERO
var _sun_light: DirectionalLight3D
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
	_lighting()
	_shell(fs.y)
	_big_window()
	outside = RoomOutside.new(self)
	desk_rig = RoomDesk.new(self)
	decor = RoomDecor.new(self)
	outside.build()
	var desk := desk_rig.build()
	_camera(desk)
	_props(desk)
	decor.build()
	_vignette()
	_pause_menu()


func _process(delta: float) -> void:
	_warnings = _collect_warnings()
	_storm_visuals(delta)
	_update_warning_lights()
	_flicker_light(delta)
	decor.update(delta)
	outside.update(delta)
	_push_screens()
	desk_rig.update()
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
func _pause_menu() -> void:
	_menu = PauseMenu.new()
	add_child(_menu)
	_menu.restart_pressed.connect(_on_restart)
	_menu.options_pressed.connect(_on_options)
	_menu.main_menu_pressed.connect(_on_main_menu)
	_menu.quit_pressed.connect(_on_quit)
	if SHOW_MENU_ON_START:
		_menu.open()


func _on_restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_options() -> void:
	# TODO: options screen (to be decided).
	_menu.toast("Options are not set up yet")


func _on_main_menu() -> void:
	get_tree().paused = false   # must unpause first, or the main menu loads frozen
	get_tree().change_scene_to_file("res://main_menu.tscn")


func _on_quit() -> void:
	get_tree().quit()


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
	var st: ScreenUI = desk_rig.screens.get("status")
	if st != null:
		st.power = _val("power")
		st.oxygen = _val("oxygen")
		var sp := sensors.get("panels") as SolarPanelsSensor
		if sp != null:
			st.panels = sp.panels
		if clock != null:
			st.sol = clock.sol
			st.clock_s = clock.clock_s
	var env: EnvironmentScreen = desk_rig.screens.get("environment")
	if env != null:
		for id in env.rows.keys():
			env.set_value(id, _val(id))
		if clock != null:
			env.set_time(clock.sol, clock.clock_s)
	var al: WarningsScreen = desk_rig.screens.get("alerts")
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
	_light.light_energy = (LIGHT_BASE - _flicker) * (1.0 - 0.3 * _dust_amt)


# ---------- polish ----------
func _vignette() -> void:
	var layer := CanvasLayer.new()
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
void fragment() {
    float v = smoothstep(0.35, 0.85, length(UV - 0.5));
    COLOR = vec4(0.04, 0.03, 0.1, v * 0.55);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	rect.material = m
	layer.add_child(rect)
	add_child(layer)


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
	var holder := Node3D.new()
	holder.add_child(inst)
	holder.set_meta("size", bb.size)
	return holder


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


func _box(parent: Node3D, pos: Vector3, box_size: Vector3, color: Color, glow := false) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box_size
	m.mesh = mesh
	m.material_override = _mat(color, glow)
	m.position = pos
	parent.add_child(m)
	return m


# ---------- scene parts ----------
func _lighting() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("120d12")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a07f78")
	env.ambient_light_energy = AMBIENT_ENERGY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.fog_enabled = true
	env.fog_light_color = Color("b4724a")
	env.fog_density = 0.012
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# dim warm room lamp (this is the one that flickers)
	var light := OmniLight3D.new()
	light.position = Vector3(0, wall_h * 0.5, -tile * ROWS * 0.5)
	light.light_energy = LIGHT_BASE
	light.omni_range = tile * COLS * 1.6
	light.light_color = Color("ffd9b0")
	add_child(light)
	_light = light
	# red alarm light (pulses on warnings)
	_alert_light = OmniLight3D.new()
	_alert_light.position = Vector3(0, wall_h * 0.6, -tile * ROWS * 0.6)
	_alert_light.light_color = Color("ff3b2a")
	_alert_light.light_energy = 0.0
	_alert_light.omni_range = tile * COLS * 1.6
	add_child(_alert_light)
	# the Martian sun, shining in through the big window
	_sun_light = DirectionalLight3D.new()
	_sun_light.light_color = SUN_COL
	_sun_light.light_energy = SUN_ENERGY
	_sun_light.shadow_enabled = SHOW_SUN_SHADOWS
	_sun_light.shadow_bias = 0.1
	_sun_light.shadow_normal_bias = 2.0
	_sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_sun_light.directional_shadow_max_distance = tile * ROWS * 1.6
	add_child(_sun_light)
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
	cam = Camera3D.new()
	cam.position = Vector3(dpos.x, wall_h * 0.55, minf(dpos.z + 2.6 * u, -tile * 0.3))
	cam.rotation_degrees = Vector3(CAM_PITCH, 0, 0)
	cam.fov = 75
	add_child(cam)
	cam.current = true


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


func _no_shadow(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_no_shadow(c)
