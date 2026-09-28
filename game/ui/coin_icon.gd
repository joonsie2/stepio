extends Control
## Placeholder Stepcoin icon.


func _draw() -> void:
	var radius := minf(size.x, size.y) / 2
	var center := size / 2
	draw_circle(center, radius, Style.COIN.darkened(0.25))
	draw_circle(center, radius * 0.8, Style.COIN)
	draw_circle(center, radius * 0.35, Style.COIN.darkened(0.15))
