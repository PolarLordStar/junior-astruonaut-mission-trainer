class_name WarningsScreen
extends Control
## Right monitor: shows ONLY active warnings. With no warnings the whole screen is black.
## All the fixed nodes are in scenes/warnings_screen.tscn; each warning card is an instance of
## scenes/warning_card.tscn, made when a warning appears and removed when it goes away.
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
## Node tree (scenes/warnings_screen.tscn):
##   WarningsScreen (Control)
##   ├ Background (ColorRect, black)
##   └ Content   <- hidden when there are no warnings = black screen
##     ├ Margin
##     │ └ Layout (VBox)
##     │   ├ Header (HBox): TitleLabel, CountLabel
##     │   └ Cards (VBox): Warning_<id> ...  (WarningCard instances)
##     └ Frame (Panel, the blue border)

const MAX_VISIBLE := 3
const WARNING_CARD := preload("res://scenes/warning_card.tscn")

@onready var title_label: Label = %TitleLabel
@onready var count_label: Label = %CountLabel
@onready var content: Control = %Content
@onready var _cards_box: VBoxContainer = %Cards

var _cards := {}   # id -> WarningCard


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
			card = WARNING_CARD.instantiate()
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
