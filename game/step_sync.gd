extends Node
## Reads steps from StepReader and hands them to GameState: when the app opens,
## when it comes back to the front, and every SYNC_SECONDS while it is open.

signal access_changed(has_access: bool)
signal today_changed(steps: int)
signal sync_failed(error: String)

const SYNC_SECONDS := 30.0
## Give up on a sync whose answers have not all arrived after this long.
const SYNC_TIMEOUT_MSEC := 20000

var has_access := false
var access_checked := false
var today_steps := -1  # Platform total for today, as the Health app shows it.

var _pending := {}  # Request id -> date key.
var _results := {}  # Date key -> steps without manual entries.
var _sync_started_msec := 0
var _sync_error := ""


func _ready() -> void:
	StepReader.permission_changed.connect(_on_permission_changed)
	StepReader.steps_received.connect(_on_steps_received)
	var timer := Timer.new()
	timer.wait_time = SYNC_SECONDS
	timer.autostart = true
	timer.timeout.connect(sync_now)
	add_child(timer)
	StepReader.check_permission()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED:
		StepReader.check_permission()


func request_access() -> void:
	StepReader.request_permission()


func is_syncing() -> bool:
	return not _pending.is_empty()


func sync_now() -> void:
	if not has_access:
		return
	if is_syncing():
		if Time.get_ticks_msec() - _sync_started_msec < SYNC_TIMEOUT_MSEC:
			return
		_pending.clear()
		sync_failed.emit("Step reading timed out")
	_results.clear()
	_sync_error = ""
	_sync_started_msec = Time.get_ticks_msec()
	var now := int(Time.get_unix_time_from_system())
	for days_ago in GameState.days_to_sync():
		var end_unix := now if days_ago == 0 else StepReader.local_midnight_unix(days_ago - 1)
		var id := StepReader.query_steps(StepReader.local_midnight_unix(days_ago), end_unix)
		_pending[id] = GameState.date_key(days_ago)


func _on_permission_changed(granted: bool, _message: String) -> void:
	var changed := granted != has_access or not access_checked
	has_access = granted
	access_checked = true
	if changed:
		access_changed.emit(has_access)
	sync_now()


func _on_steps_received(request_id: int, total: int, excluding_manual: int, error: String) -> void:
	if not _pending.has(request_id):
		return
	var key: String = _pending[request_id]
	_pending.erase(request_id)
	if not error.is_empty():
		_sync_error = error
	else:
		# Typed-in steps never count (design doc §3.3). On Android the second
		# number can exceed the total when two devices logged the same walk.
		_results[key] = mini(total, excluding_manual)
		if key == GameState.date_key(0):
			today_steps = total
			today_changed.emit(today_steps)
	if _pending.is_empty():
		# Days that did answer are safe to count; each day is only counted once.
		GameState.apply_sync(_results)
		if not _sync_error.is_empty():
			sync_failed.emit(_sync_error)
