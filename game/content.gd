class_name Content
## Placeholder content for the prototype. The real game loads pal and costume
## definitions from ContentDB resources and the monthly track from the server
## (design doc §11.4 and §11.5).

## Multipliers are kept in hundredths (105 means 1.05x) so sums stay exact.
const MULTIPLIER_CAP_CENTS := 300
## Steps counted per day at most (design doc §3.3).
const DAILY_STEP_CAP := 40000

const RARITY_BONUS_CENTS := {"common": 5, "uncommon": 8, "rare": 12, "epic": 20}
const FRIENDSHIP_BONUS_CENTS_PER_LEVEL := 1
## Steps walked in the party needed for each friendship level, 1 to 10.
## Placeholder numbers; the design doc does not set them yet.
const FRIENDSHIP_STEPS := [0, 2000, 5000, 10000, 20000, 35000, 55000, 80000, 110000, 150000]

const STARTER_PAL := "sprout"
const PALS := {
	"sprout": {"name": "Sprout", "rarity": "common", "color": Color("7cc47f")},
}

## Monthly reward track (design doc §6.3): [stepscore, reward].
const MILESTONES := [
	[10000, "20 Stepcoins"],
	[25000, "Common costume piece (Head)"],
	[45000, "Common pal"],
	[70000, "30 Stepcoins"],
	[100000, "Avatar set piece 1 of 3"],
	[135000, "Uncommon pal"],
	[175000, "40 Stepcoins"],
	[220000, "Avatar set piece 2 of 3"],
	[270000, "Rare costume piece (Accessory)"],
	[325000, "Rare pal"],
	[380000, "50 Stepcoins"],
	[440000, "Avatar set piece 3 of 3"],
	[500000, "Epic costume piece (Head)"],
	[560000, "Monthly featured Epic pal"],
	[620000, "75 Stepcoins"],
	[700000, "Monthly exclusive Epic costume piece + 100 Stepcoins"],
]


static func friendship_level(steps_walked: int) -> int:
	var level := 1
	for i in FRIENDSHIP_STEPS.size():
		if steps_walked >= FRIENDSHIP_STEPS[i]:
			level = i + 1
	return level


static func format_multiplier(cents: int) -> String:
	return "%d.%02dx" % [cents / 100, cents % 100]


static func format_number(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += ","
		out += digits[i]
	return ("-" if value < 0 else "") + out
