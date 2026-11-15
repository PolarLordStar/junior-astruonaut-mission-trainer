# Some usage of AI occured in the script
class_name WarningCard
extends PanelContainer
## One warning on the Warnings monitor: coloured side stripe, title, detail line and a severity badge.
## The nodes are in room/warning_card.tscn. WarningsScreen makes one instance per active warning.
##
## Node tree (room/warning_card.tscn):
##   WarningCard (PanelContainer)
##   └ Margin
##     └ Layout (HBox)
##       ├ Left (VBox): TitleLabel, DetailLabel
##       └ BadgeLabel

const CARD := Color("16273d")
const AMBER := Color("ffb02e")
const ORANGE := Color("ff8a3d")
const RED := Color("ff5a4a")

var level := 1

@onready var title_label: Label = %TitleLabel
@onready var detail_label: Label = %DetailLabel
@onready var badge_label: Label = %BadgeLabel

# "Local to Scene" in the .tscn, so every card has its own copy to recolour.
@onready var _style := get_theme_stylebox("panel") as StyleBoxFlat
var _t := 0.0


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
