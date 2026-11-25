extends Node2D
## Draws the snowy ground, the frozen shore and the sea along the bottom of the map.

var world_size := Vector2(2400, 1600)
var shore_y := 1380.0


func _ready() -> void:
	z_index = -10


func _draw() -> void:
	draw_rect(Rect2(Vector2(-200, -200), world_size + Vector2(400, 400)), Color(0.93, 0.95, 0.98))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 160:
		var p := Vector2(rng.randf_range(0, world_size.x), rng.randf_range(0, shore_y))
		var r := rng.randf_range(20, 90)
		draw_set_transform(p, 0, Vector2(1, 0.45))
		draw_circle(Vector2.ZERO, r, Color(0.82, 0.88, 0.96, 0.35))
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
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
	for i in 30:
		var p := Vector2(rng.randf_range(0, world_size.x), rng.randf_range(shore_y + 15, shore_y + 60))
		draw_line(p, p + Vector2(rng.randf_range(-20, 20), rng.randf_range(-6, 6)), Color(0.6, 0.75, 0.88), 1.0)
