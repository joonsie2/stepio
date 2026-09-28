extends Control
## Placeholder art for the Walk screen, drawn with shapes: a parallax park, the
## avatar walking in place and the party pals following in a line behind.

const OUTLINE := Color("3b3a4a")
const OUTLINE_WIDTH := 5.0
const WALK_SPEED := 110.0  # Ground scroll, pixels per second.
const STRIDES_PER_SECOND := 1.7
const PAL_SPACING := 130.0

const SKY_TOP := Color("9fd3ec")
const SKY_BOTTOM := Color("fde9cf")
const FAR_HILLS := Color("b9d9a8")
const NEAR_HILLS := Color("93c483")
const GRASS := Color("7fb86f")
const PATH := Color("e8cf9f")
const TREE_TRUNK := Color("9b6b4a")
const TREE_CROWNS := [Color("e9914f"), Color("f2b84b"), Color("d9663f"), Color("8cbf5d")]
const SKIN := Color("f4c9a3")
const HAIR := Color("5a3d31")
const SHIRT := Color("ff8a5b")
const PANTS := Color("4d6fa8")

var pal_ids: Array = []

var _scroll := 0.0
var _stride := 0.0
var _boost := 0.0


## Walk faster for a moment, while new steps pour in.
func boost(seconds: float = 2.0) -> void:
	_boost = maxf(_boost, seconds)


func _process(delta: float) -> void:
	_boost = move_toward(_boost, 0.0, delta)
	var pace := 1.0 + minf(_boost, 1.0) * 1.5
	_scroll += WALK_SPEED * pace * delta
	_stride += TAU * STRIDES_PER_SECOND * pace * delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var ground_y := h * 0.74
	_draw_sky(w, ground_y)
	draw_circle(Vector2(w * 0.8, h * 0.2), 50, Color("ffe09a"))
	_draw_clouds(w, h)
	_draw_hills(w, ground_y + 10, ground_y - 150, 0.15, 520.0, FAR_HILLS)
	_draw_hills(w, ground_y + 10, ground_y - 80, 0.35, 330.0, NEAR_HILLS)
	_draw_trees(w, ground_y)
	draw_rect(Rect2(0, ground_y, w, h - ground_y), GRASS)
	var path_y := ground_y + 30
	draw_rect(Rect2(0, path_y, w, 70), PATH)
	_draw_path_stones(w, path_y)

	var feet_y := path_y + 50
	var avatar_x := w * 0.66
	for i in pal_ids.size():
		var pal: Dictionary = Content.PALS[pal_ids[i]]
		_draw_pal(Vector2(avatar_x - PAL_SPACING * (i + 1), feet_y), pal.color, i)
	_draw_avatar(Vector2(avatar_x, feet_y))


func _draw_sky(w: float, bottom: float) -> void:
	var bands := 48
	for i in bands:
		var t := float(i) / (bands - 1)
		draw_rect(Rect2(0, bottom * i / bands, w, bottom / bands + 1), SKY_TOP.lerp(SKY_BOTTOM, t))


func _draw_clouds(w: float, h: float) -> void:
	var spacing := 420.0
	var offset := fmod(_scroll * 0.05, spacing)
	for k in range(-1, int(w / spacing) + 2):
		var x := k * spacing - offset + 60
		var y := h * (0.1 + 0.08 * ((k + int(_scroll * 0.05 / spacing)) % 2))
		for puff in [[0, 0, 34], [36, -12, 40], [76, 0, 30]]:
			draw_circle(Vector2(x + puff[0], y + puff[1]), puff[2], Color(1, 1, 1, 0.85))


func _draw_hills(w: float, bottom: float, top: float, parallax: float, wavelength: float, color: Color) -> void:
	var points := PackedVector2Array()
	var steps := 40
	for i in steps + 1:
		var x := w * i / steps
		var wave := sin((x + _scroll * parallax) / wavelength * TAU) * 0.5 + 0.5
		points.append(Vector2(x, lerpf(bottom, top, 0.35 + 0.65 * wave)))
	points.append(Vector2(w, bottom))
	points.append(Vector2(0, bottom))
	draw_colored_polygon(points, color)


func _draw_trees(w: float, ground_y: float) -> void:
	var spacing := 250.0
	var travelled := _scroll * 0.7
	var first := int(floor(travelled / spacing))
	for k in range(-1, int(w / spacing) + 2):
		var index := first + k
		var x := index * spacing - travelled + 40.0 * _hash(index)
		var height := 110.0 + 50.0 * _hash(index + 7)
		var base := Vector2(x, ground_y + 6)
		var trunk := Rect2(base.x - 9, base.y - height, 18, height)
		draw_rect(trunk.grow(OUTLINE_WIDTH * 0.6), OUTLINE)
		draw_rect(trunk, TREE_TRUNK)
		var crown_color: Color = TREE_CROWNS[posmod(index, TREE_CROWNS.size())]
		var radius := 46.0 + 14.0 * _hash(index + 3)
		_outlined_circle(Vector2(base.x, base.y - height), radius, crown_color)


func _draw_path_stones(w: float, path_y: float) -> void:
	var spacing := 90.0
	var offset := fmod(_scroll, spacing)
	for k in range(0, int(w / spacing) + 2):
		var x := k * spacing - offset
		draw_rect(Rect2(x, path_y + 32, 36, 6), Color(PATH.darkened(0.12)))


func _draw_avatar(feet: Vector2) -> void:
	var swing := sin(_stride)
	var bob := absf(swing) * 6.0
	var hip := feet + Vector2(0, -70 - bob)

	# Legs and arms, back ones first.
	_limb(hip + Vector2(-6, 0), feet + Vector2(-swing * 22, 0), PANTS, 14)
	_limb(hip + Vector2(6, 0), feet + Vector2(swing * 22, 0), PANTS, 14)
	var shoulder := hip + Vector2(0, -62)
	_limb(shoulder, shoulder + Vector2(swing * 24, 50), SKIN, 11)

	var body := StyleBoxFlat.new()
	body.bg_color = SHIRT
	body.set_corner_radius_all(22)
	body.set_border_width_all(int(OUTLINE_WIDTH))
	body.border_color = OUTLINE
	draw_style_box(body, Rect2(hip.x - 30, hip.y - 76, 60, 84))

	_limb(shoulder, shoulder + Vector2(-swing * 24, 50), SKIN, 11)

	var head := hip + Vector2(0, -118)
	_outlined_circle(head, 42, SKIN)
	# Hair: the top half of the head, a little bigger.
	var hair := PackedVector2Array()
	for i in 17:
		var angle := PI + PI * i / 16.0
		hair.append(head + Vector2(cos(angle), sin(angle) * 0.9) * 44)
	draw_colored_polygon(hair, HAIR)
	draw_circle(head + Vector2(10, 4), 6, OUTLINE)
	draw_circle(head + Vector2(30, 4), 6, OUTLINE)
	draw_circle(head + Vector2(26, 18), 7, Color("f59a9a", 0.6))


func _draw_pal(feet: Vector2, color: Color, index: int) -> void:
	# Sprout: a round blob with a leaf, hopping a little out of step.
	var hop := absf(sin(_stride + 0.9 * (index + 1))) * 16.0
	var squash := 1.0 + 0.08 * cos(_stride * 2.0)
	var center := feet + Vector2(0, -38 - hop)
	draw_set_transform(center, 0, Vector2(squash, 1.0 / squash))
	draw_circle(Vector2.ZERO, 44 + OUTLINE_WIDTH, OUTLINE)
	draw_circle(Vector2.ZERO, 44, color)
	draw_set_transform(Vector2.ZERO)
	var stem_top := center + Vector2(4, -62)
	draw_line(center + Vector2(0, -42), stem_top, OUTLINE, 6)
	draw_set_transform(stem_top + Vector2(14, -2), -0.5, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 18 + OUTLINE_WIDTH, OUTLINE)
	draw_circle(Vector2.ZERO, 18, color.lightened(0.25))
	draw_set_transform(Vector2.ZERO)
	draw_circle(center + Vector2(8, -6), 5, OUTLINE)
	draw_circle(center + Vector2(26, -6), 5, OUTLINE)


func _limb(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	draw_line(from, to, OUTLINE, width + OUTLINE_WIDTH * 2)
	draw_circle(to, (width + OUTLINE_WIDTH * 2) / 2, OUTLINE)
	draw_line(from, to, color, width)
	draw_circle(to, width / 2, color)


func _outlined_circle(center: Vector2, radius: float, color: Color) -> void:
	draw_circle(center, radius + OUTLINE_WIDTH, OUTLINE)
	draw_circle(center, radius, color)


static func _hash(n: int) -> float:
	return fposmod(sin(n * 12.9898) * 43758.5453, 1.0)
