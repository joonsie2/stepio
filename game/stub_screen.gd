extends Control
## Placeholder for the tabs the prototype does not build yet.

var title := ""
var summary := ""


func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(520, 0)
	center.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	card.add_child(column)
	column.add_child(Style.label(title, 40))
	var text := Style.label(summary, 24, Style.MUTED)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(text)
	column.add_child(Style.label("Coming after the prototype", 22, Style.ACCENT_DARK))
