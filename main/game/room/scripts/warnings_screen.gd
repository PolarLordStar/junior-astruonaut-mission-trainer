class_name WarningsScreen
extends Control
## Right monitor: shows ONLY active warnings. With no warnings the whole screen is black.
## All the fixed nodes are in room/warnings_screen.tscn; each warning card is an instance of
## room/warning_card.tscn, made when a warning appears and removed when it goes away.
##
## HOW TO FEED IT: call set_warnings() with the full list of warnings that are active right now
## (call it every frame or whenever something changes). Anything not in the list disappears.
##     warnings_screen.set_warnings([
##         {"id": "storm", "title": "DUST STORM INCOMING", "detail": "Arrives in 0:24", "badge": "SEVERE", "level": 3},
##         {"id": "radiation", "title": "HIGH RADIATION", "detail": "0.82 mSv/h", "badge": "CRITICAL", "level": 3},
##     ])
## Keys: id (unique, same id = same card), title, detail (optional), badge (optional), level 1..3
## (1 amber, 2 orange, 3 red and flashing). Worst warnings are listed first. Every warning is listed:
## when they do not all fit on the monitor the list scrolls (see SCROLLING below).
## control_room.gd builds this list in _collect_warnings(); edit that to change what counts as a warning.
##
## Node tree (room/warnings_screen.tscn):
##   WarningsScreen (Control)
##   ├ Background (ColorRect, black)
##   └ Content   <- hidden when there are no warnings = black screen
##     ├ Margin
##     │ └ Layout (VBox)
##     │   ├ Header (HBox): TitleLabel, CountLabel
##     │   └ CardsClip (Control, cuts off whatever sticks out)
##     │     ├ Cards (VBox): Warning_<id> ...  (WarningCard instances), moved up / down to scroll
##     │     └ ScrollThumb (Panel): the slim scrollbar, only shown when the list is longer than the screen
##     └ Frame (Panel, the blue border)
##
## SCROLLING: the monitor is a picture on a 3D screen, so the mouse wheel never reaches it by itself.
## control_room.gd checks whether the mouse is over this monitor and then calls scroll_by() /
## set_hovered(). The list eases to its new position, and the slim scrollbar on the right is faint
## while nothing happens and bright while scrolling or while the mouse is over the monitor.

const WARNING_CARD := preload("res://main/game/room/warning_card.tscn")

# ---- scrolling (tweak these to taste) ----
const GUTTER := 14.0            # room kept free on the right for the scrollbar while the list scrolls
const THUMB_W := 6.0            # how wide the scrollbar is
const MIN_THUMB := 30.0         # the scrollbar never gets shorter than this
const SCROLL_SMOOTH := 16.0     # how fast the list eases to its new place (bigger = snappier)
const BAR_IDLE_ALPHA := 0.35    # scrollbar when nothing is happening (faint, so players see there is more)
const BAR_ACTIVE_ALPHA := 0.95  # scrollbar while scrolling or while the mouse is over the monitor
const BAR_ACTIVE_TIME := 1.2    # seconds the scrollbar stays bright after the last scroll

@onready var title_label: Label = %TitleLabel
@onready var count_label: Label = %CountLabel
@onready var content: Control = %Content
@onready var _clip: Control = %CardsClip
@onready var _cards_box: VBoxContainer = %Cards
@onready var _thumb: Panel = %ScrollThumb

var _cards := {}   # id -> WarningCard
var _target := 0.0       # where the list is heading, in pixels scrolled down from the top
var _current := 0.0      # where the list is right now (eases towards _target)
var _max_scroll := 0.0   # 0 = everything fits, nothing to scroll
var _idle := 99.0        # seconds since the last scroll
var _hovered := false    # mouse is over this monitor (set by control_room.gd)
var _bar_alpha := 0.0


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
		_cards_box.move_child(card, order)
		order += 1
	for wid in _cards.keys():
		if not seen.has(wid):
			(_cards[wid] as Node).queue_free()
			_cards.erase(wid)
	content.visible = not _cards.is_empty()
	count_label.text = "%d ACTIVE" % _cards.size()


## Scrolls the list by this many pixels (positive = down, negative = up). control_room.gd calls
## this when the mouse wheel is turned while the mouse is over this monitor.
func scroll_by(pixels: float) -> void:
	_target = clampf(_target + pixels, 0.0, _max_scroll)
	_idle = 0.0


## control_room.gd tells the screen whether the mouse is over the monitor (makes the scrollbar bright).
func set_hovered(on: bool) -> void:
	_hovered = on


func _process(delta: float) -> void:
	if _clip == null or not content.visible:
		_target = 0.0
		_current = 0.0
		return
	var view := _clip.size
	if view.x < 1.0 or view.y < 1.0:
		return   # the layout has not run yet
	# The Cards box is at least as tall as the screen, so with only a few warnings the cards still
	# stretch to fill it (as before). With more warnings it is taller and the extra part scrolls.
	var content_h := _cards_box.get_combined_minimum_size().y
	_max_scroll = maxf(0.0, content_h - view.y)
	var scrolls := _max_scroll > 0.5
	_cards_box.size = Vector2(view.x - (GUTTER if scrolls else 0.0), maxf(content_h, view.y))
	_target = clampf(_target, 0.0, _max_scroll)
	_current = lerpf(_current, _target, 1.0 - exp(-SCROLL_SMOOTH * delta))
	if absf(_current - _target) < 0.5:
		_current = _target
	_cards_box.position = Vector2(0.0, -roundf(_current))
	_idle += delta
	_update_bar(view, content_h, scrolls, delta)


## The slim scrollbar: its length shows how much of the list is on screen, its place shows where you are.
func _update_bar(view: Vector2, content_h: float, scrolls: bool, delta: float) -> void:
	var want := 0.0
	if scrolls:
		want = BAR_ACTIVE_ALPHA if (_hovered or _idle < BAR_ACTIVE_TIME) else BAR_IDLE_ALPHA
	_bar_alpha = lerpf(_bar_alpha, want, 1.0 - exp(-10.0 * delta))
	_thumb.visible = _bar_alpha > 0.01
	if not _thumb.visible:
		return
	var thumb_h := clampf(view.y * view.y / maxf(content_h, 1.0), MIN_THUMB, view.y)
	var frac := _current / _max_scroll if _max_scroll > 0.0 else 0.0
	_thumb.size = Vector2(THUMB_W, thumb_h)
	_thumb.position = Vector2(view.x - THUMB_W - 2.0, (view.y - thumb_h) * clampf(frac, 0.0, 1.0))
	_thumb.modulate.a = _bar_alpha
