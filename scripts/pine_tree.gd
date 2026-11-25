extends Node2D
## A snowy pine tree (scenery).

var size := 1.0


func _draw() -> void:
	var s := size
	draw_set_transform(Vector2(0, 2), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 16.0 * s, Color(0, 0, 0, 0.18))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	draw_rect(Rect2(-3 * s, -8 * s, 6 * s, 10 * s), Color(0.35, 0.22, 0.12))
	var green := Color(0.13, 0.32, 0.22)
	for i in 3:
		var w := (16.0 - i * 4.0) * s
		var base_y := (-6.0 - i * 12.0) * s
		var top := base_y - 18.0 * s
		draw_colored_polygon(PackedVector2Array([Vector2(-w, base_y), Vector2(0, top), Vector2(w, base_y)]), green.lightened(i * 0.05))
		var cap_y := top + 9.0 * s
		draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.5, cap_y), Vector2(0, top), Vector2(w * 0.5, cap_y)]), Color(0.95, 0.97, 1.0))
