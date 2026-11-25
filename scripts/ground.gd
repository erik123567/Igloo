extends Node2D
## Draws the snowy ground, the frozen shore and the sea along the bottom of the map.

var world_size := Vector2(2400, 1600)
var shore_y := 1380.0


const TEX := preload("res://art/snow_tile.png")


func _ready() -> void:
	z_index = -10
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED


func _draw() -> void:
	draw_texture_rect(TEX, Rect2(Vector2(-256, -256), world_size + Vector2(512, 512)), true)
	# The further north (up), the bluer and colder the snow looks
	var bands := 40
	for i in bands:
		var y0 := shore_y * i / bands
		var north := 1.0 - float(i) / bands
		var tint := clampf((north - 0.35) * 1.4, 0.0, 1.0)
		draw_rect(Rect2(-256, y0 - 256 * int(i == 0), world_size.x + 512, shore_y / bands + 256 * int(i == 0)), Color(0.55, 0.7, 0.95, 0.22 * tint))
	# A big frozen lake out on the tundra
	draw_set_transform(Vector2(3000, 1150), 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 640, Color(0.6, 0.78, 0.92))
	draw_circle(Vector2(-60, -40), 560, Color(0.7, 0.85, 0.96))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# frozen shore (walkable ice)
	var ice := PackedVector2Array()
	var water := PackedVector2Array()
	var steps := 48
	for i in steps + 1:
		var x := world_size.x * i / steps
		ice.append(Vector2(x, shore_y + sin(i * 0.9) * 10.0))
	for i in range(steps, -1, -1):
		var x := world_size.x * i / steps
		water.append(Vector2(x, shore_y + 75.0 + sin(i * 1.3) * 8.0))
	var ice_poly := ice.duplicate()
	ice_poly.append(Vector2(world_size.x + 200, shore_y + 200))
	ice_poly.append(Vector2(-200, shore_y + 200))
	draw_colored_polygon(ice_poly, Color(0.74, 0.87, 0.95))
	var water_poly := PackedVector2Array()
	water_poly.append(Vector2(-200, world_size.y + 200))
	water_poly.append(Vector2(world_size.x + 200, world_size.y + 200))
	water_poly.append_array(water)
	draw_colored_polygon(water_poly, Color(0.16, 0.3, 0.45))
	# ice cracks
	for i in 60:
		var p := Vector2(rng.randf_range(0, world_size.x), rng.randf_range(shore_y + 15, shore_y + 60))
		draw_line(p, p + Vector2(rng.randf_range(-20, 20), rng.randf_range(-6, 6)), Color(0.6, 0.75, 0.88), 1.0)
