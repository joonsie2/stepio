class_name LocalDays
## Local calendar days as Unix times and date keys, for step queries.


## Unix time of local midnight, days_ago days before today.
static func midnight_unix(days_ago: int = 0) -> int:
	var today := Time.get_date_dict_from_system()
	var midnight_as_utc := Time.get_unix_time_from_datetime_dict({
		"year": today.year, "month": today.month, "day": today.day,
		"hour": 0, "minute": 0, "second": 0,
	})
	var bias_seconds: int = Time.get_time_zone_from_system().bias * 60
	return int(midnight_as_utc) - bias_seconds - days_ago * 86400


## Local date of the day days_ago days before today, as "YYYY-MM-DD".
static func date_key(days_ago: int = 0) -> String:
	# Noon of that local day, read as UTC, lands on the local date.
	var date := Time.get_date_dict_from_unix_time(midnight_unix(days_ago) + 43200)
	return "%04d-%02d-%02d" % [date.year, date.month, date.day]
