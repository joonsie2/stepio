extends Control
## Game shell: top bar, five tabs (Walk in the middle) switched from the bottom
## bar or by swiping sideways, and a layer for popups.

const STEP_TEST_SCENE := "res://steps/step_test.tscn"
const WALK_TAB := 2
const SWIPE_MIN_DISTANCE := 90.0
const TABS := [
	["Shop", "Featured pals and costumes, pal slots and Stepcoin packs."],
	["Collection", "Your pals and party, friendship levels, and the wardrobe for you and your pals."],
	["Walk", ""],
	["Goals", "The monthly track, milestone rewards and badges."],
	["Friends", "Your friends, cheers, and Walk Together sessions."],
]

var _pages: Control
var _screens: Array[Control] = []
var _tab_buttons: Array[Button] = []
var _tab := WALK_TAB
var _page_position := float(WALK_TAB)
var _page_tween: Tween
var _popup_layer: Control
var _coin_label: Label
var _today_label: Label
var _multiplier_button: Button
var _press_position := Vector2.ZERO
var _pressing := false


func _ready() -> void:
	theme = Style.make_theme()
	var background := ColorRect.new()
	background.color = Style.CREAM
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(background)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 0)
	add_child(column)
	var safe := _safe_area_margins()
	column.add_child(_make_top_bar(safe.x))
	_pages = Control.new()
	_pages.clip_contents = true
	_pages.size_flags_vertical = SIZE_EXPAND_FILL
	_pages.resized.connect(_layout_pages)
	column.add_child(_pages)
	for i in TABS.size():
		var screen: Control
		if i == WALK_TAB:
			screen = preload("res://game/walk/walk_screen.gd").new()
		else:
			screen = preload("res://game/stub_screen.gd").new()
			screen.title = TABS[i][0]
			screen.summary = TABS[i][1]
		_pages.add_child(screen)
		_screens.append(screen)
	column.add_child(_make_nav_bar(safe.y))

	_popup_layer = Control.new()
	_popup_layer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_popup_layer.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_popup_layer)

	GameState.changed.connect(_refresh_top_bar)
	StepSync.today_changed.connect(func(_steps): _refresh_top_bar())
	StepSync.sync_now()
	_refresh_top_bar()
	_select_tab(WALK_TAB, false)


func _input(event: InputEvent) -> void:
	# Sideways swipes anywhere over the pages move between tabs.
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		_pressing = _popup_layer.get_child_count() == 0 \
				and _pages.get_global_rect().has_point(event.position)
		_press_position = event.position
	elif _pressing:
		_pressing = false
		var delta: Vector2 = event.position - _press_position
		if absf(delta.x) >= SWIPE_MIN_DISTANCE and absf(delta.x) > absf(delta.y) * 1.5:
			_select_tab(clampi(_tab + (1 if delta.x < 0 else -1), 0, TABS.size() - 1))


func _make_top_bar(safe_top: float) -> PanelContainer:
	var bar := PanelContainer.new()
	var style := Style.box(Style.BAR, 0, 14)
	style.content_margin_top = 14 + safe_top
	style.content_margin_left = 20
	style.content_margin_right = 20
	bar.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	bar.add_child(row)

	var profile := Style.button("Me", 24, Style.ACCENT)
	profile.custom_minimum_size = Vector2(72, 72)
	profile.pressed.connect(_show_profile)
	row.add_child(profile)

	var coin := preload("res://game/ui/coin_icon.gd").new()
	coin.custom_minimum_size = Vector2(34, 34)
	coin.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(coin)
	_coin_label = Style.label("0", 28, Style.BAR_TEXT)
	row.add_child(_coin_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(spacer)

	var today := VBoxContainer.new()
	today.add_theme_constant_override("separation", -4)
	today.add_child(Style.label("Today", 18, Color(Style.BAR_TEXT, 0.6)))
	_today_label = Style.label("...", 28, Style.BAR_TEXT)
	today.add_child(_today_label)
	row.add_child(today)

	_multiplier_button = Style.button("1.00x", 28, Style.GREEN)
	_multiplier_button.custom_minimum_size = Vector2(120, 72)
	_multiplier_button.pressed.connect(_show_multiplier)
	row.add_child(_multiplier_button)
	return bar


func _make_nav_bar(safe_bottom: float) -> PanelContainer:
	var bar := PanelContainer.new()
	var style := Style.box(Style.BAR, 0, 8)
	style.content_margin_bottom = 8 + safe_bottom
	bar.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	bar.add_child(row)
	for i in TABS.size():
		var button := Button.new()
		button.text = TABS[i][0]
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 96 if i == WALK_TAB else 84)
		button.size_flags_vertical = SIZE_SHRINK_END
		button.add_theme_font_size_override("font_size", 24 if i == WALK_TAB else 21)
		button.pressed.connect(_select_tab.bind(i))
		row.add_child(button)
		_tab_buttons.append(button)
	return bar


func _select_tab(index: int, animate: bool = true) -> void:
	_tab = index
	for i in _tab_buttons.size():
		var selected := i == index
		var color := Style.ACCENT if selected else Color(Style.BAR.lightened(0.12))
		for state in ["normal", "hover", "pressed"]:
			_tab_buttons[i].add_theme_stylebox_override(state, Style.box(color, 20, 6))
	if _page_tween:
		_page_tween.kill()
	if animate:
		_page_tween = create_tween()
		_page_tween.tween_method(_set_page_position, _page_position, float(index), 0.25) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_set_page_position(index)


func _set_page_position(value: float) -> void:
	_page_position = value
	_layout_pages()


func _layout_pages() -> void:
	for i in _screens.size():
		_screens[i].position = Vector2((i - _page_position) * _pages.size.x, 0)
		_screens[i].size = _pages.size
		_screens[i].visible = absf(i - _page_position) < 1.0


func _refresh_top_bar() -> void:
	_coin_label.text = Content.format_number(GameState.stepcoins)
	_today_label.text = "..." if StepSync.today_steps < 0 else Content.format_number(StepSync.today_steps)
	_multiplier_button.text = Content.format_multiplier(GameState.multiplier_cents())


func _show_multiplier() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	for part in GameState.multiplier_parts():
		column.add_child(_row(part.label, ("+" if part.label != "Base" else "") + "%.2f" % (part.cents / 100.0)))
	column.add_child(HSeparator.new())
	column.add_child(_row("Right now", Content.format_multiplier(GameState.multiplier_cents()), 30))
	var note := Style.label("New steps are multiplied by this when they sync. Pals and costumes add to it, up to %s." \
			% Content.format_multiplier(Content.MULTIPLIER_CAP_CENTS), 22, Style.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)
	_show_popup("Step multiplier", column)


func _show_profile() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.add_child(_row("Steps counted", Content.format_number(GameState.total_steps)))
	column.add_child(_row("Counting since", GameState.first_day))
	column.add_child(_row("Step source", StepReader.backend_name))
	column.add_child(_row("Status", StepReader.get_status()))
	if StepReader.is_native():
		var settings := Style.button("Open health settings", 24, Style.BAR)
		settings.pressed.connect(StepReader.open_settings)
		column.add_child(settings)
	var allow := Style.button("Ask for step access", 24, Style.BAR)
	allow.pressed.connect(StepSync.request_access)
	column.add_child(allow)
	var step_test := Style.button("Step reading test", 24, Style.BAR)
	step_test.pressed.connect(func(): get_tree().change_scene_to_file(STEP_TEST_SCENE))
	column.add_child(step_test)
	var reset := Style.button("Reset prototype save", 24, Color("c0504d"))
	reset.pressed.connect(func():
		GameState.clear_save()
		_close_popups()
		StepSync.sync_now())
	column.add_child(reset)
	_show_popup("Profile", column)


func _row(left: String, right: String, size: int = 24) -> HBoxContainer:
	var row := HBoxContainer.new()
	var name_label := Style.label(left, size)
	name_label.size_flags_horizontal = SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(name_label)
	row.add_child(Style.label(right, size))
	return row


func _show_popup(title: String, content: Control) -> void:
	_close_popups()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dim.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			_close_popups())
	_popup_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.mouse_filter = MOUSE_FILTER_IGNORE
	_popup_layer.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(600, 0)
	card.add_theme_stylebox_override("panel", Style.box(Style.PANEL, 28, 28))
	center.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	card.add_child(column)
	column.add_child(Style.label(title, 36))
	column.add_child(content)
	var close := Style.button("Close", 26)
	close.pressed.connect(_close_popups)
	column.add_child(close)


func _close_popups() -> void:
	for child in _popup_layer.get_children():
		_popup_layer.remove_child(child)
		child.queue_free()


## Top and bottom insets for notches and the home indicator, in viewport units.
func _safe_area_margins() -> Vector2:
	if not OS.has_feature("mobile"):
		return Vector2.ZERO
	var screen := DisplayServer.screen_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if screen.y <= 0:
		return Vector2.ZERO
	var scale := get_viewport_rect().size.y / screen.y
	return Vector2(safe.position.y * scale, maxf(0, screen.y - safe.end.y) * scale)
