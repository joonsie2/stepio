extends Control
## Step reading test screen: asks for step access, shows today's steps and the
## last 7 days, and logs how long each read takes.

const AUTO_REFRESH_SECONDS := 30.0
const DAYS_SHOWN := 7

@onready var _status_label: Label = %StatusLabel
@onready var _today_label: Label = %TodayLabel
@onready var _today_detail_label: Label = %TodayDetailLabel
@onready var _days_label: Label = %DaysLabel
@onready var _log_label: RichTextLabel = %LogLabel
@onready var _permission_button: Button = %PermissionButton
@onready var _refresh_button: Button = %RefreshButton
@onready var _settings_button: Button = %SettingsButton

# request id -> {"label": String, "sent_msec": int, "day": int (-1 for today)}
var _pending := {}
var _day_results := {}
var _slowest_day_msec := 0
var _requested_permission := false


func _ready() -> void:
	StepReader.permission_changed.connect(_on_permission_changed)
	StepReader.steps_received.connect(_on_steps_received)
	_permission_button.pressed.connect(_on_permission_pressed)
	_refresh_button.pressed.connect(refresh)
	_settings_button.pressed.connect(StepReader.open_settings)
	_settings_button.visible = StepReader.is_native()

	var timer := Timer.new()
	timer.wait_time = AUTO_REFRESH_SECONDS
	timer.autostart = true
	timer.timeout.connect(_refresh_today)
	add_child(timer)

	_log("Source: %s, status: %s" % [StepReader.backend_name, StepReader.get_status()])
	_update_status()
	StepReader.check_permission()
	refresh()


func _notification(what: int) -> void:
	# Coming back to the app is the moment the real game syncs steps.
	if what == NOTIFICATION_APPLICATION_RESUMED and is_node_ready():
		_log("App resumed")
		_update_status()
		refresh()


func refresh() -> void:
	_refresh_today()
	_day_results.clear()
	_slowest_day_msec = 0
	for id in _pending.keys():
		if _pending[id].day > 0:
			_pending.erase(id)  # Ignore answers from an older refresh.
	for day in range(1, DAYS_SHOWN + 1):
		var id := StepReader.query_steps(
			StepReader.local_midnight_unix(day), StepReader.local_midnight_unix(day - 1)
		)
		_pending[id] = {"label": _day_name(day), "sent_msec": Time.get_ticks_msec(), "day": day}


func _refresh_today() -> void:
	var id := StepReader.query_steps(
		StepReader.local_midnight_unix(0), int(Time.get_unix_time_from_system())
	)
	_pending[id] = {"label": "Today", "sent_msec": Time.get_ticks_msec(), "day": 0}


func _on_permission_pressed() -> void:
	_log("Requesting step access")
	_requested_permission = true
	StepReader.request_permission()


func _on_permission_changed(granted: bool, message: String) -> void:
	_log("Permission: %s (%s)" % ["yes" if granted else "no", message])
	_permission_button.text = "Ask for step access again" if granted else "Allow step access"
	if granted and _requested_permission:
		_requested_permission = false
		refresh()


func _on_steps_received(request_id: int, total: int, excluding_manual: int, error: String) -> void:
	if not _pending.has(request_id):
		return
	var request: Dictionary = _pending[request_id]
	_pending.erase(request_id)
	var elapsed: int = Time.get_ticks_msec() - request.sent_msec

	if not error.is_empty():
		_log("[color=#ff8080]%s failed after %d ms: %s[/color]" % [request.label, elapsed, error])
		if request.day == 0:
			_today_label.text = "?"
			_today_detail_label.text = error
		return

	if request.day == 0:
		_log("Today: %d steps (%d without manual entries), %d ms" % [total, excluding_manual, elapsed])
		_today_label.text = _format_steps(total)
		_today_detail_label.text = "%s without manual entries" % _format_steps(excluding_manual)
	else:
		_day_results[request.day] = [total, excluding_manual]
		_slowest_day_msec = maxi(_slowest_day_msec, elapsed)
		if _day_results.size() == DAYS_SHOWN:
			_log("Last %d days loaded, slowest %d ms" % [DAYS_SHOWN, _slowest_day_msec])
		_update_days()


func _update_status() -> void:
	var status := StepReader.get_status()
	var hint := ""
	match status:
		"update_required":
			hint = "\nInstall or update Health Connect, then come back."
		"unsupported":
			hint = "\nThis device cannot provide step data."
	_status_label.text = "%s: %s%s" % [StepReader.backend_name, status, hint]
	_settings_button.text = "Get Health Connect" if status == "update_required" else "Open health settings"


func _update_days() -> void:
	var lines := PackedStringArray()
	for day in range(1, DAYS_SHOWN + 1):
		if _day_results.has(day):
			var result: Array = _day_results[day]
			var manual_note := ""
			if result[1] != result[0]:
				manual_note = "  (%s w/o manual)" % _format_steps(result[1])
			lines.append("%s   %s%s" % [_day_name(day), _format_steps(result[0]), manual_note])
		else:
			lines.append("%s   ..." % _day_name(day))
	_days_label.text = "\n".join(lines)


func _log(line: String) -> void:
	var time := Time.get_time_string_from_system()
	_log_label.append_text("[color=#9aa0a6]%s[/color] %s\n" % [time, line])
	print(line)


static func _day_name(days_ago: int) -> String:
	if days_ago == 1:
		return "Yesterday"
	var date := Time.get_date_dict_from_unix_time(StepReader.local_midnight_unix(days_ago) + 43200)
	var weekdays := ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
	return "%s %d/%d" % [weekdays[date.weekday], date.month, date.day]


static func _format_steps(steps: int) -> String:
	if steps < 0:
		return "?"
	var digits := str(steps)
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += ","
		out += digits[i]
	return out
