extends SceneTree
## Checks the scoring rules. Run with:
##   godot --headless -s res://tests/test_scoring.gd

var _failures := 0


func _initialize() -> void:
	var state = preload("res://game/game_state.gd").new()
	state.save_path = "user://test_save.json"
	state.reset()

	_check(state.multiplier_cents() == 106, "new player is 1.06x (base + Common pal + friendship 1)")

	var today: String = state.date_key(0)
	var gained: int = state.apply_sync({today: 1000})
	_check(gained == 1060, "1,000 steps at 1.06x give 1,060, got %d" % gained)
	gained = state.apply_sync({today: 1000})
	_check(gained == 0, "the same day total is not counted twice, got %d" % gained)
	gained = state.apply_sync({today: 1500})
	_check(gained == 530, "only the 500 new steps count, got %d" % gained)
	_check(state.stepscore == 1590, "stepscore adds up, got %d" % state.stepscore)

	gained = state.apply_sync({state.date_key(1): 5000})
	_check(gained == 0, "days before install never count, got %d" % gained)

	state.apply_sync({today: 60000})
	_check(state.counted_by_day[today] == Content.DAILY_STEP_CAP, "daily cap applies")

	state.pal_steps[Content.STARTER_PAL] = 150000
	_check(state.multiplier_cents() == 115, "friendship level 10 adds 0.10, got %d" % state.multiplier_cents())
	gained = state.apply_sync({})
	_check(gained == 0, "an empty sync gains nothing")

	state.party = ["sprout", "sprout", "sprout", "sprout", "sprout", "sprout", "sprout", "sprout", "sprout", "sprout", "sprout", "sprout", "sprout", "sprout"]
	_check(state.multiplier_cents() == Content.MULTIPLIER_CAP_CENTS, "multiplier caps at 3.00x")

	_check(Content.format_multiplier(106) == "1.06x", "format 1.06x")
	_check(Content.format_number(1234567) == "1,234,567", "format thousands")
	_check(Content.friendship_level(0) == 1 and Content.friendship_level(4999) == 2, "friendship levels")

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	state.free()
	print("FAILED: %d" % _failures if _failures else "All scoring checks passed")
	quit(1 if _failures else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		printerr("FAIL: " + what)
