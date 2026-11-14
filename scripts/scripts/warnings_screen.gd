class_name WarningsScreen
extends Control
## Right monitor: shows ONLY active warnings. With no warnings the whole screen is black.
##
## HOW TO FEED IT: call set_warnings() with the full list of warnings that are active right now
## (call it every frame or whenever something changes). Anything not in the list disappears.
##     warnings_screen.set_warnings([
##         {"id": "storm", "title": "DUST STORM INCOMING", "detail": "Arrives in 0:24", "badge": "SEVERE", "level": 3},
##         {"id": "radiation", "title": "HIGH RADIATION", "detail": "0.82 mSv/h", "badge": "CRITICAL", "level": 3},
##     ])
## Keys: id (unique, same id = same card), title, detail (optional), badge (optional), level 1..3
## (1 amber, 2 orange, 3 red and flashing). Worst warnings are listed first, at most MAX_VISIBLE shown.
## control_room.gd builds this list in _collect_warnings(); edit that to change what counts as a warning.
##
## Node tree:
##   WarningsScreen (Control)
##   ├ Background (ColorRect, black)
##   └ Content   <- hidden when there are no warnings = black screen
##     ├ Margin
##     │ └ Layout (VBox)
##     │   ├ Header (HBox): TitleLabel, CountLabel
##     │   └ Cards (VBox): Warning_<id> ...  (WarningCard nodes)
##     └ Frame (Panel, the blue border)

const W := 640.0
const H := 400.0
const FRAME := Color("2d2e55")
const CYAN := Color("5ee0f0")
const RED := Color("ff5a4a")
const MAX_VISIBLE := 4

var title_label: Label
var count_label: Label
var content: Control

var _cards := {}   # id -> WarningCard
var _cards_box: VBoxContainer


func _ready() -> void:
	size = Vector2(W, H)
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	content = Control.new()
	content.name = "Content"
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.visible = false
	add_child(content)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 18)
	content.add_child(margin)

	var layout := VBoxContainer.new()
	layout.name = "Layout"
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	var header := HBoxContainer.new()
	header.name = "Header"
	layout.add_child(header)
	title_label = _make_label("TitleLabel", "WARNINGS", 26, CYAN)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	count_label = _make_label("CountLabel", "", 22, RED)
	header.add_child(count_label)

	_cards_box = VBoxContainer.new()
	_cards_box.name = "Cards"
	_cards_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cards_box.add_theme_constant_override("separation", 10)
	layout.add_child(_cards_box)

	var frame := Panel.new()
	frame.name = "Frame"
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = FRAME
	sb.set_border_width_all(8)
	frame.add_theme_stylebox_override("panel", sb)
	content.add_child(frame)


func _make_label(node_name: String, text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.name = node_name
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func set_warnings(list: Array) -> void:
	if _cards_box == null:
		return
	var sorted := list.duplicate()
	sorted.sort_custom(func(a, b): return int(a["level"]) > int(b["level"]))
	var seen := {}
	var order := 0
	for w in sorted:
		var wid: String = w["id"]
		seen[wid] = true
		var card: WarningCard = _cards.get(wid)
		if card == null:
			card = WarningCard.new()
			card.name = "Warning_" + wid
			_cards[wid] = card
			_cards_box.add_child(card)
		card.update_from(w)
		card.visible = order < MAX_VISIBLE
		_cards_box.move_child(card, order)
		order += 1
	for wid in _cards.keys():
		if not seen.has(wid):
			(_cards[wid] as Node).queue_free()
			_cards.erase(wid)
	content.visible = not _cards.is_empty()
	var extra := _cards.size() - MAX_VISIBLE
	var txt := "%d ACTIVE" % _cards.size()
	if extra > 0:
		txt += "  (+%d more)" % extra
	count_label.text = txt


## One warning: coloured side stripe, title, detail line and a severity badge.
class WarningCard extends PanelContainer:
	const CARD := Color("16273d")
	const TEXT_DIM := Color("8c94c8")
	const AMBER := Color("ffb02e")
	const ORANGE := Color("ff8a3d")
	const RED := Color("ff5a4a")

	var level := 1
	var title_label: Label
	var detail_label: Label
	var badge_label: Label
	var _style := StyleBoxFlat.new()
	var _t := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(0, 64)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		_style.bg_color = CARD
		_style.border_color = AMBER
		_style.border_width_left = 8
		add_theme_stylebox_override("panel", _style)
		var margin := MarginContainer.new()
		margin.name = "Margin"
		margin.add_theme_constant_override("margin_left", 16)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_top", 6)
		margin.add_theme_constant_override("margin_bottom", 6)
		add_child(margin)
		var row := HBoxContainer.new()
		row.name = "Layout"
		margin.add_child(row)
		var left := VBoxContainer.new()
		left.name = "Left"
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(left)
		title_label = _make_label("TitleLabel", "", 26)
		left.add_child(title_label)
		detail_label = _make_label("DetailLabel", "", 16)
		detail_label.add_theme_color_override("font_color", TEXT_DIM)
		left.add_child(detail_label)
		badge_label = _make_label("BadgeLabel", "", 18)
		badge_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(badge_label)

	func _make_label(node_name: String, text: String, font_size: int) -> Label:
		var l := Label.new()
		l.name = node_name
		l.text = text
		l.add_theme_font_size_override("font_size", font_size)
		return l

	func color() -> Color:
		if level >= 3:
			return RED
		if level == 2:
			return ORANGE
		return AMBER

	func update_from(w: Dictionary) -> void:
		level = int(w.get("level", 1))
		var col := color()
		_style.border_color = col
		title_label.add_theme_color_override("font_color", col)
		badge_label.add_theme_color_override("font_color", col)
		_set_text(title_label, str(w.get("title", "")))
		_set_text(detail_label, str(w.get("detail", "")))
		_set_text(badge_label, str(w.get("badge", "")))

	func _set_text(l: Label, s: String) -> void:
		if l.text != s:
			l.text = s

	func _process(delta: float) -> void:
		_t += delta
		var flash := level >= 3 and sin(_t * 6.0) > -0.3
		_style.bg_color = CARD.lerp(color(), 0.16) if flash else CARD
