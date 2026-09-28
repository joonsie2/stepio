extends Node
## Game-facing wrapper around the native step readers.
##
## On Android and iOS this talks to the "StepioHealth" engine singleton (Health
## Connect plugin or HealthKit GDExtension). Everywhere else it falls back to a
## fake source so the screens can be built and tested in the editor.

signal permission_changed(granted: bool, message: String)
signal steps_received(request_id: int, total: int, excluding_manual: int, error: String)

const SINGLETON_NAME := "StepioHealth"

var backend_name := "Fake steps (desktop)"
var _native: Object
var _next_request_id := 1


func _ready() -> void:
	if Engine.has_singleton(SINGLETON_NAME):
		_native = Engine.get_singleton(SINGLETON_NAME)
		backend_name = "HealthKit" if OS.get_name() == "iOS" else "Health Connect"
		_native.connect("permission_result", _on_native_permission_result)
		_native.connect("steps_result", _on_native_steps_result)
	elif OS.has_feature("mobile"):
		backend_name = "Missing native plugin"
		push_error("StepioHealth native plugin not found. See README for how to build it.")


func is_native() -> bool:
	return _native != null


## "available", "update_required" (Android: Health Connect needs installing or
## updating), "unsupported", or "fake".
func get_status() -> String:
	if _native:
		return _native.get_status()
	return "unsupported" if OS.has_feature("mobile") else "fake"


func check_permission() -> void:
	if _native:
		_native.check_permission()
	else:
		_emit_fake_permission.call_deferred()


func request_permission() -> void:
	if _native:
		_native.request_permission()
	else:
		_emit_fake_permission.call_deferred()


func open_settings() -> void:
	if _native:
		_native.open_settings()


## Asks for the steps between two Unix times (seconds, UTC). The answer arrives
## later through steps_received with the returned request id.
func query_steps(start_unix: int, end_unix: int) -> int:
	var request_id := _next_request_id
	_next_request_id += 1
	if _native:
		_native.query_steps(start_unix, end_unix, request_id)
	else:
		_emit_fake_steps.call_deferred(request_id, start_unix, end_unix)
	return request_id


## Unix time of local midnight, days_ago days before today.
static func local_midnight_unix(days_ago: int = 0) -> int:
	var today := Time.get_date_dict_from_system()
	var midnight_as_utc := Time.get_unix_time_from_datetime_dict({
		"year": today.year, "month": today.month, "day": today.day,
		"hour": 0, "minute": 0, "second": 0,
	})
	var bias_seconds: int = Time.get_time_zone_from_system().bias * 60
	return int(midnight_as_utc) - bias_seconds - days_ago * 86400


func _on_native_permission_result(granted: bool, message: String) -> void:
	permission_changed.emit(granted, message)


func _on_native_steps_result(request_id: int, total: int, excluding_manual: int, error: String) -> void:
	steps_received.emit(request_id, total, excluding_manual, error)


func _emit_fake_permission() -> void:
	permission_changed.emit(true, "Fake source, no permission needed")


func _emit_fake_steps(request_id: int, start_unix: int, end_unix: int) -> void:
	# Roughly 7,000 steps a day, spread evenly, stable between refreshes.
	var now := int(Time.get_unix_time_from_system())
	var seconds := maxi(0, mini(end_unix, now) - start_unix)
	var total := int(seconds * 7000.0 / 86400.0) + (start_unix / 86400) % 900
	steps_received.emit(request_id, total, total - total / 50, "")
