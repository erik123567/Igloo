extends Node2D
## A snowy pine tree (scenery).

const TEX := preload("res://art/pine.png")

var size := 1.0


func _draw() -> void:
	draw_set_transform(Vector2(0, 2), 0, Vector2(1, 0.3))
	draw_circle(Vector2.ZERO, 14.0 * size, Color(0, 0, 0, 0.18))
	draw_set_transform(Vector2.ZERO, 0, Vector2(size, size))
	draw_texture(TEX, Vector2(-16, -44))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
