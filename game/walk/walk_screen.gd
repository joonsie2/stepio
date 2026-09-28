extends Control
## Walk tab (home): the avatar and party walking, this month's stepscore with
## the next milestone, and the count-up when new steps pour in.

const COUNT_UP_SECONDS := 1.6

var _view: Control
var _score_label: Label
var _milestone_label: Label
var _milestone_bar: ProgressBar
var _gain_label: Label
var _access_card: PanelContainer
var _shown_score := 0.0
var _score_tween: Tween


func _ready() -> void:
	clip_contents = true
	_view = preload("res://game/walk/walk_view.gd").new()
	_view.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_view.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_view)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	margin.mouse_filter = MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 18)
	margin.add_child(column)

	var score_card := PanelContainer.new()
	score_card.add_theme_stylebox_override("panel", Style.box(Color(Style.PANEL, 0.92), 28, 22))
	column.add_child(score_card)
	var score_column := VBoxContainer.new()
	score_column.add_theme_constant_override("separation", 6)
	score_card.add_child(score_column)
	score_column.add_child(Style.label("Stepscore this month", 24, Style.MUTED))
	_score_label = Style.label("0", 72)
	score_column.add_child(_score_label)
	_milestone_bar = ProgressBar.new()
	_milestone_bar.custom_minimum_size = Vector2(0, 26)
	_milestone_bar.show_percentage = false
	score_column.add_child(_milestone_bar)
	_milestone_label = Style.label("", 22, Style.MUTED)
	_milestone_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	score_column.add_child(_milestone_label)

	_gain_label = Style.label("", 30, Style.INK)
	_gain_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gain_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_gain_label.add_theme_stylebox_override("normal", Style.box(Color(Style.PANEL, 0.92), 24, 14))
	_gain_label.modulate.a = 0.0
	column.add_child(_gain_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = SIZE_EXPAND_FILL
	spacer.mouse_filter = MOUSE_FILTER_IGNORE
	column.add_child(spacer)

	_access_card = _make_access_card()
	column.add_child(_access_card)

	if not StepReader.is_native():
		var fake_button := Style.button("Walk 500 test steps", 24, Style.BAR)
		fake_button.size_flags_horizontal = SIZE_SHRINK_CENTER
		fake_button.custom_minimum_size = Vector2(320, 64)
		fake_button.pressed.connect(func():
			StepReader.add_fake_steps(500)
			StepSync.sync_now())
		column.add_child(fake_button)

	GameState.steps_scored.connect(_on_steps_scored)
	GameState.changed.connect(_refresh)
	StepSync.access_changed.connect(func(_granted): _refresh_access())
	_shown_score = GameState.stepscore
	_refresh()
	_refresh_access()


func _make_access_card() -> PanelContainer:
	var card := PanelContainer.new()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	card.add_child(column)
	var text := Style.label("step.io turns the steps your phone already counts into stepscore. Allow it to read your steps to start.", 24)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(text)
	var allow := Style.button("Allow step access")
	allow.pressed.connect(StepSync.request_access)
	column.add_child(allow)
	return card


func _refresh() -> void:
	_view.pal_ids = GameState.party
	if _score_tween == null or not _score_tween.is_running():
		_shown_score = GameState.stepscore
		_score_label.text = Content.format_number(GameState.stepscore)
	var index := GameState.next_milestone()
	if index == -1:
		_milestone_bar.value = 1.0
		_milestone_bar.max_value = 1.0
		_milestone_label.text = "Every milestone reached this month"
		return
	var previous: int = 0 if index == 0 else Content.MILESTONES[index - 1][0]
	var target: int = Content.MILESTONES[index][0]
	_milestone_bar.min_value = previous
	_milestone_bar.max_value = target
	_milestone_bar.value = GameState.stepscore
	_milestone_label.text = "Next milestone at %s: %s" % [
		Content.format_number(target), Content.MILESTONES[index][1]]


func _refresh_access() -> void:
	_access_card.visible = StepSync.access_checked and not StepSync.has_access


func _on_steps_scored(steps: int, multiplier_cents: int, gained: int) -> void:
	_view.boost(COUNT_UP_SECONDS + 0.5)
	_gain_label.text = "%s steps x %s = +%s stepscore" % [
		Content.format_number(steps), Content.format_multiplier(multiplier_cents).trim_suffix("x"),
		Content.format_number(gained)]
	if _score_tween:
		_score_tween.kill()
	_score_tween = create_tween()
	_score_tween.tween_method(_show_score, _shown_score, float(GameState.stepscore), COUNT_UP_SECONDS) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var fade := create_tween()
	fade.tween_property(_gain_label, "modulate:a", 1.0, 0.25)
	fade.tween_interval(COUNT_UP_SECONDS + 1.5)
	fade.tween_property(_gain_label, "modulate:a", 0.0, 0.6)


func _show_score(value: float) -> void:
	_shown_score = value
	_score_label.text = Content.format_number(int(value))
