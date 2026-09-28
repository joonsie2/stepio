extends Node
## Cached player state: party, stepscore, Stepcoins, which steps have already
## been counted. Saved to user://save.json. In the real game the server owns
## this (design doc §11.4) and the client only caches it.

signal changed
## Emitted after a sync that counted new steps.
signal steps_scored(steps: int, multiplier_cents: int, gained: int)

var save_path := "user://save.json"
const SAVE_VERSION := 1
## How far back a sync looks when the app was closed for a while.
const MAX_SYNC_DAYS := 7

var month := ""
var stepscore := 0  # This month's.
var stepcoins := 0
var owned_pals: Array = []
var party: Array = []  # Pal ids. The avatar is always in the party.
var pal_steps := {}  # Pal id -> steps walked while in the party.
var total_steps := 0  # Steps counted since install.
## Local date ("2026-09-28") -> steps already counted that day. A sync re-reads
## whole days and counts only what is new, so steps a watch uploads late still
## count.
var counted_by_day := {}
var first_day := ""  # Install day. Steps before it never count (§3.3).


func _ready() -> void:
	load_game()


func reset() -> void:
	month = current_month()
	stepscore = 0
	stepcoins = 0
	owned_pals = [Content.STARTER_PAL]
	party = [Content.STARTER_PAL]
	pal_steps = {Content.STARTER_PAL: 0}
	total_steps = 0
	counted_by_day = {}
	first_day = date_key(0)


## Multiplier parts, for the breakdown popup: [{"label", "cents"}].
func multiplier_parts() -> Array:
	var parts := [{"label": "Base", "cents": 100}]
	for pal_id in party:
		var pal: Dictionary = Content.PALS[pal_id]
		parts.append({
			"label": "%s (%s)" % [pal.name, pal.rarity.capitalize()],
			"cents": Content.RARITY_BONUS_CENTS[pal.rarity],
		})
		var level := pal_level(pal_id)
		parts.append({
			"label": "%s friendship level %d" % [pal.name, level],
			"cents": level * Content.FRIENDSHIP_BONUS_CENTS_PER_LEVEL,
		})
	return parts


func multiplier_cents() -> int:
	var total := 0
	for part in multiplier_parts():
		total += part.cents
	return mini(total, Content.MULTIPLIER_CAP_CENTS)


func pal_level(pal_id: String) -> int:
	return Content.friendship_level(pal_steps.get(pal_id, 0))


## Days a sync should read, as days-ago numbers (0 is today), oldest first.
func days_to_sync() -> Array:
	var days := []
	for days_ago in range(MAX_SYNC_DAYS - 1, -1, -1):
		var key := date_key(days_ago)
		if key >= first_day:
			days.append(days_ago)
	return days


## Takes each day's step total from the health platform, counts what was not
## counted before, and turns it into stepscore at the current multiplier.
## Returns the stepscore gained.
func apply_sync(steps_by_day: Dictionary) -> int:
	var new_steps := 0
	for key in steps_by_day:
		if key < first_day:
			continue
		var capped := mini(int(steps_by_day[key]), Content.DAILY_STEP_CAP)
		var before: int = counted_by_day.get(key, 0)
		if capped > before:
			new_steps += capped - before
			counted_by_day[key] = capped
	_roll_month()
	_forget_old_days()
	if new_steps == 0:
		save_game()
		return 0
	var cents := multiplier_cents()
	var gained := new_steps * cents / 100
	stepscore += gained
	total_steps += new_steps
	for pal_id in party:
		pal_steps[pal_id] = pal_steps.get(pal_id, 0) + new_steps
	save_game()
	steps_scored.emit(new_steps, cents, gained)
	changed.emit()
	return gained


## Index into Content.MILESTONES of the next milestone, or -1 when all are done.
func next_milestone() -> int:
	for i in Content.MILESTONES.size():
		if stepscore < Content.MILESTONES[i][0]:
			return i
	return -1


func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"month": month,
		"stepscore": stepscore,
		"stepcoins": stepcoins,
		"owned_pals": owned_pals,
		"party": party,
		"pal_steps": pal_steps,
		"total_steps": total_steps,
		"counted_by_day": counted_by_day,
		"first_day": first_day,
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
	else:
		push_error("Could not save: %s" % error_string(FileAccess.get_open_error()))


func load_game() -> void:
	reset()
	if FileAccess.file_exists(save_path):
		var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
		if data is Dictionary and int(data.get("version", 0)) == SAVE_VERSION:
			month = data.month
			stepscore = int(data.stepscore)
			stepcoins = int(data.stepcoins)
			owned_pals = data.owned_pals
			party = data.party
			pal_steps = {}
			for pal_id in data.pal_steps:
				pal_steps[pal_id] = int(data.pal_steps[pal_id])
			total_steps = int(data.total_steps)
			counted_by_day = {}
			for key in data.counted_by_day:
				counted_by_day[key] = int(data.counted_by_day[key])
			first_day = data.first_day
		else:
			push_warning("Save file unreadable or from another version, starting over")
	_roll_month()
	save_game()
	changed.emit()


func clear_save() -> void:
	reset()
	save_game()
	changed.emit()


func _roll_month() -> void:
	if month != current_month():
		month = current_month()
		stepscore = 0


func _forget_old_days() -> void:
	var oldest := date_key(MAX_SYNC_DAYS)
	for key in counted_by_day.keys():
		if key < oldest:
			counted_by_day.erase(key)


static func date_key(days_ago: int) -> String:
	return LocalDays.date_key(days_ago)


static func current_month() -> String:
	return date_key(0).substr(0, 7)
