extends Node

signal event_triggered(event: Dictionary)

const BASE := "https://ccmc.gsfc.nasa.gov/DONKI-API/get"
const EVENT_TYPES := ["FLR", "CME", "SEP"]
const FALLBACK_PATH := "res://data/donki_fallback.json"
const REQUEST_TIMEOUT := 15.0
const MAX_RANGE_DAYS := 365
const EARLIEST_RANDOM_DATE := "2011-01-01"

var events: Array = []
var loaded := false
var source := ""
var start_date := ""
var end_date := ""

var _loading := false
var _network_failed := false
var _request_failed := false
var _replay_index := 0
var _replay_timer: Timer


# --- Date validation ---------------------------------------------------------

# Returns "" if the dates are fine, otherwise a message to show the player.
func validate_dates(from_date: String, to_date: String) -> String:
	if not _is_valid_date(from_date):
		return "Start date must be a real date like 2026-10-01."
	if not _is_valid_date(to_date):
		return "End date must be a real date like 2026-11-13."
	if from_date > to_date:
		return "The start date must be on or before the end date."
	if to_date > Time.get_date_string_from_system(true):
		return "The end date can't be in the future."

	var days: int = int((_to_unix(to_date) - _to_unix(from_date)) / 86400.0)
	if days > MAX_RANGE_DAYS:
		return "Please choose a period of %d days or less." % MAX_RANGE_DAYS
	return ""

# Returns a random, valid calendar date (YYYY-MM-DD) from EARLIEST_RANDOM_DATE up to yesterday (UTC).
func random_date() -> String:
	var first := _to_unix(EARLIEST_RANDOM_DATE)
	var last := _to_unix(Time.get_date_string_from_system(true)) - 86400
	var days := int((last - first) / 86400)
	return Time.get_date_string_from_unix_time(first + randi_range(0, days) * 86400)


# Loads the CME, FLR and SEP events for ONE date. Await it.
# Returns the events as a list (they are also stored in DonkiService.events).
func load_events_for_date(date: String) -> Array:
	if _loading:
		return []
	var problem := validate_dates(date, date)
	if problem != "":
		print("DONKI: invalid date '%s': %s" % [date, problem])
		return []
	await load_events(date, date)
	return events


# Picks a RANDOM valid date, loads that day's CME, FLR and SEP events, prints them to
# Godot's Output panel, and returns them. Call it from any script:
#
#     var day = await DonkiService.fetch_random_day()
#     print(day["date"], " -> ", day["count"], " events")
#     for e in day["events"]:
#         print(e["name"], e["details"])
#
# Returns a Dictionary:
#   "date"          the random date, e.g. "2024-05-10"
#   "events"        Array of game-ready events (name, kind, severity, time, action, details)
#   "count"         number of events
#   "source"        "live", "cache" or "fallback"
#   "reached_nasa"  true if NASA answered; false means the result may be incomplete
#   "message"       one-line summary you can show on screen
func fetch_random_day(print_report: bool = true) -> Dictionary:
	# If another load is still running, wait for it to finish first
	while _loading:
		await get_tree().process_frame

	var date := random_date()
	await load_events(date, date)

	var result := {
		"date": date,
		"events": events,
		"count": events.size(),
		"source": source,
		"reached_nasa": source == "live",
		"message": _day_message(date),
	}
	if print_report:
		_print_day(result)
	return result


func _day_message(date: String) -> String:
	if not events.is_empty():
		return "%d event(s) on %s" % [events.size(), date]
	if source == "live":
		return "NASA recorded no CME, flare or SEP events on %s." % date
	return "Couldn't reach NASA and no saved data covers %s." % date


func _print_day(result: Dictionary) -> void:
	print("=== DONKI events on %s (source: %s) ===" % [result["date"], result["source"]])
	if result["events"].is_empty():
		print(result["message"])
		return
	for e in result["events"]:
		print("%s  [%s, severity %d of 3]" % [e["name"], e["kind"], e["severity"]])
		print("  What to do: %s" % e["action"])
		for key in e["details"]:
			if e["details"][key] != "":
				print("  %s: %s" % [key, e["details"][key]])


func _is_valid_date(s: String) -> bool:
	var rx := RegEx.new()
	rx.compile("^\\d{4}-\\d{2}-\\d{2}$")
	if rx.search(s) == null:
		return false
	var parts := s.split("-")
	var m := int(parts[1])
	var d := int(parts[2])
	if m < 1 or m > 12 or d < 1 or d > 31:
		return false
	# Round trip catches impossible dates like 2026-02-30
	return Time.get_date_string_from_unix_time(_to_unix(s)) == s


func _to_unix(date: String) -> int:
	var parts := date.split("-")
	return Time.get_unix_time_from_datetime_dict({
		"year": int(parts[0]), "month": int(parts[1]), "day": int(parts[2]),
		"hour": 0, "minute": 0, "second": 0,
	})


# --- Loading -----------------------------------------------------------------

# Call this with the dates the player typed. Await it to know when it's done.
func load_events(start: String, end: String) -> void:
	if _loading:
		return
	_loading = true
	loaded = false
	_network_failed = false
	_request_failed = false
	start_date = start
	end_date = end

	var raw := {}
	for type in EVENT_TYPES:
		raw[type] = await _fetch(type, start, end)

	var cache_path := "user://donki_cache_%s_%s.json" % [start, end]

	if not _is_empty(raw):
		source = "live"
		_save_json(cache_path, raw)
		events = _convert(raw)
	elif not _request_failed:
		# NASA answered every request successfully: nothing was recorded in this period.
		source = "live"
		events = []
	else:
		raw = _load_json(cache_path)
		if not _is_empty(raw):
			source = "cache"
			events = _convert(raw)
		else:
			source = "fallback"
			events = _filter_range(_convert(_load_json(FALLBACK_PATH)), start, end)

	print("DONKI: %d events for %s to %s (source: %s)" % [events.size(), start, end, source])

	loaded = true
	_loading = false


# --- Fetching ----------------------------------------------------------------

func _fetch(type: String, start: String, end: String) -> Array:
	if _network_failed:
		_request_failed = true
		return []

	var http := HTTPRequest.new()
	add_child(http)
	http.timeout = REQUEST_TIMEOUT

	var url := "%s/%s?startDate=%s&endDate=%s" % [BASE, type, start, end]
	var err := http.request(url, ["Accept: application/json"])
	if err != OK:
		print("DONKI: %s request could not start (error %d)" % [type, err])
		_network_failed = true
		_request_failed = true
		http.queue_free()
		return []

	# result = [result_code, response_code, headers, body]
	var result: Array = await http.request_completed
	http.queue_free()

	print("DONKI: %s -> result %d, HTTP code %d" % [type, result[0], result[1]])

	if result[0] != HTTPRequest.RESULT_SUCCESS:
		_network_failed = true
		_request_failed = true
		return []
	if result[1] != 200:
		_request_failed = true
		return []

	var text: String = result[3].get_string_from_utf8().strip_edges()
	if text.is_empty():
		return []   # successful, but no events

	var parsed = JSON.parse_string(text)
	return parsed if parsed is Array else []


# --- Converting NASA data to game events -------------------------------------

func _convert(raw: Dictionary) -> Array:
	var out: Array = []

	var flare_names := ["Tiny Sun Flash", "Small Sun Flash", "Medium Sun Flash", "Giant Sun Flash!"]
	var severity_by_class := {"A": 0, "B": 0, "C": 1, "M": 2, "X": 3}

	for f in raw.get("FLR", []):
		var class_full := _s(f.get("classType", ""))
		var severity: int = severity_by_class.get(class_full.substr(0, 1), 1)
		out.append({
			"id": _s(f.get("flrID", "")),
			"kind": "flare",
			"name": flare_names[severity],
			"severity": severity,
			"time": _s(f.get("peakTime", f.get("beginTime", ""))),
			"action": "Move to the shelter" if severity >= 2 else "Check the solar panels",
			"details": {
				"NASA class": class_full,
				"Began": _s(f.get("beginTime", "")),
			},
		})

	for c in raw.get("CME", []):
		out.append({
			"id": _s(c.get("activityID", "")),
			"kind": "cme",
			"name": "Solar Cloud Incoming",
			"severity": 2,
			"time": _s(c.get("startTime", "")),
			"action": "Prepare the outpost",
			"details": {
				"Started": _s(c.get("startTime", "")),
			},
		})

	for s in raw.get("SEP", []):
		out.append({
			"id": _s(s.get("sepID", "")),
			"kind": "sep",
			"name": "Radiation Storm!",
			"severity": 3,
			"time": _s(s.get("eventTime", "")),
			"action": "Shelter in place now",
			"details": {
				"Event time": _s(s.get("eventTime", "")),
			},
		})

	out.sort_custom(func(a, b): return a["time"] < b["time"])
	return out


# Converts any value to text, treating null as empty.
func _s(value) -> String:
	return "" if value == null else str(value)


func _instrument_names(list) -> String:
	var names: Array = []
	if list is Array:
		for i in list:
			if i is Dictionary and i.has("displayName"):
				names.append(str(i["displayName"]))
	return ", ".join(names)


func _cme_speed(c: Dictionary) -> String:
	var analyses = c.get("cmeAnalyses", [])
	if analyses is Array and analyses.size() > 0:
		var best = analyses[0]
		for a in analyses:
			if a is Dictionary and a.get("isMostAccurate", false):
				best = a
		var speed = best.get("speed")
		if speed != null:
			return "%s km/s" % str(speed)
	return ""


func _filter_range(list: Array, start: String, end: String) -> Array:
	return list.filter(func(e):
		var day: String = e["time"].substr(0, 10)
		return day >= start and day <= end)


# --- Replay: trigger events during gameplay ----------------------------------

func start_replay(seconds_between_events: float = 45.0) -> void:
	_replay_index = 0

	if _replay_timer == null:
		_replay_timer = Timer.new()
		_replay_timer.timeout.connect(_on_replay_tick)
		add_child(_replay_timer)

	_replay_timer.wait_time = seconds_between_events
	_replay_timer.start()


func stop_replay() -> void:
	if _replay_timer:
		_replay_timer.stop()


func _on_replay_tick() -> void:
	if events.is_empty():
		return
	event_triggered.emit(events[_replay_index % events.size()])
	_replay_index += 1


# --- Helpers -----------------------------------------------------------------

func _is_empty(raw: Dictionary) -> bool:
	for key in raw:
		if raw[key] is Array and raw[key].size() > 0:
			return false
	return true


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


func _save_json(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data))
