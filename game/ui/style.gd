class_name Style
## Placeholder look for the prototype: colors, the shared theme and a few
## widget helpers, so screens can be built in code.

const CREAM := Color("f6efe3")
const INK := Color("3b3a4a")
const MUTED := Color("8a8496")
const ACCENT := Color("ff8a5b")
const ACCENT_DARK := Color("e0683a")
const GREEN := Color("5fae63")
const COIN := Color("f5c542")
const PANEL := Color("fffaf2")
const BAR := Color("2f3142")
const BAR_TEXT := Color("f6efe3")


static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 26
	theme.set_color("font_color", "Label", INK)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(state, "Button", Color.WHITE)
	theme.set_stylebox("normal", "Button", box(ACCENT, 22))
	theme.set_stylebox("hover", "Button", box(ACCENT, 22))
	theme.set_stylebox("pressed", "Button", box(ACCENT_DARK, 22))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_stylebox("panel", "PanelContainer", box(PANEL, 28))
	theme.set_stylebox("background", "ProgressBar", box(Color(INK, 0.12), 12))
	theme.set_stylebox("fill", "ProgressBar", box(GREEN, 12))
	return theme


static func box(color: Color, radius: int, padding: int = 16) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	return style


static func label(text: String, size: int = 26, color: Color = INK) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	return node


static func button(text: String, size: int = 28, color: Color = ACCENT) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(0, 80)
	node.add_theme_font_size_override("font_size", size)
	if color != ACCENT:
		node.add_theme_stylebox_override("normal", box(color, 22))
		node.add_theme_stylebox_override("hover", box(color, 22))
		node.add_theme_stylebox_override("pressed", box(color.darkened(0.15), 22))
	return node
