extends Node2D
## Anything you can gather with E: sticks, stones, flint rocks, snow drifts, berry bushes, meat.

var main
var kind := "sticks"
var amount := 1           # used by meat drops
var uses := 1             # -1 means it never runs out
var max_uses := 1
var interact_radius := 6.0
var _look := 0            # small random variation in how it's drawn


func _ready() -> void:
	add_to_group("interactable")
	_look = int(absf(position.x * 7.0 + position.y * 13.0)) % 1000
	match kind:
		"flint_rock":
			uses = 4
			interact_radius = 18.0
		"snow_drift":
			uses = -1
			interact_radius = 14.0
		"berry_bush":
			uses = 3
			max_uses = 3
			interact_radius = 12.0
			add_to_group("daily")
		"stone":
			interact_radius = 5.0


func get_prompt(_player) -> String:
	match kind:
		"sticks":
			return "[E] Pick up sticks"
		"stone":
			return "[E] Pick up stone"
		"flint_rock":
			return "[E] Chip flint from the rock" if uses > 0 else "This rock is picked clean"
		"snow_drift":
			return "[E] Cut a snow block (hold E)"
		"berry_bush":
			return "[E] Pick berries (%d left)" % uses if uses > 0 else "No berries left today"
		"meat":
			return "[E] Take raw meat"
	return ""


func can_interact(_player) -> bool:
	return uses != 0


func interact(player) -> void:
	match kind:
		"sticks":
			if player.spend_energy(1.0):
				player.add_item("sticks", 2)
				queue_free()
		"stone":
			if player.spend_energy(1.0):
				player.add_item("stone", 1)
				queue_free()
		"flint_rock":
			if player.spend_energy(3.0):
				uses -= 1
				player.add_item("flint", 1)
				if randf() < 0.3:
					player.add_item("stone", 1)
		"snow_drift":
			if player.spend_energy(2.0):
				player.add_item("snow_block", 1)
		"berry_bush":
			if player.spend_energy(0.5):
				uses -= 1
				player.add_item("berries", 1)
		"meat":
			player.add_item("raw_meat", amount)
			queue_free()
	queue_redraw()


func new_day() -> void:
	if kind == "berry_bush":
		uses = max_uses
		queue_redraw()


# ---------- Drawing (placeholder art) ----------

func _shadow(r: float, y: float = 3.0) -> void:
	draw_set_transform(Vector2(0, y), 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, r, Color(0, 0, 0, 0.15))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func _draw() -> void:
	match kind:
		"sticks":
			var brown := Color(0.45, 0.3, 0.15)
			draw_line(Vector2(-8, 2), Vector2(8, -2), brown, 2.5)
			draw_line(Vector2(-6, -3), Vector2(7, 4), brown.darkened(0.2), 2.0)
			draw_line(Vector2(-3, 4), Vector2(5, -5), brown.lightened(0.1), 2.0)
		"stone":
			_shadow(6.0)
			draw_circle(Vector2.ZERO, 5.5, Color(0.5, 0.5, 0.55))
			draw_circle(Vector2(-1.5, -1.5), 2.2, Color(0.68, 0.68, 0.72))
		"flint_rock":
			_shadow(22.0, 6.0)
			var pts := PackedVector2Array([
				Vector2(-22, 6), Vector2(-18, -10), Vector2(-6, -18), Vector2(10, -16),
				Vector2(21, -4), Vector2(18, 8), Vector2(0, 11)])
			draw_colored_polygon(pts, Color(0.42, 0.42, 0.47))
			draw_colored_polygon(PackedVector2Array([Vector2(-14, -11), Vector2(-6, -18), Vector2(10, -16), Vector2(4, -11)]), Color(0.95, 0.97, 1))
			for i in maxi(uses, 0):
				var p := Vector2(-12 + i * 8, -2 + (i % 2) * 5)
				draw_colored_polygon(PackedVector2Array([p + Vector2(-3, 0), p + Vector2(0, -4), p + Vector2(3, 0), p + Vector2(0, 3)]), Color(0.15, 0.15, 0.2))
		"snow_drift":
			_shadow(16.0, 4.0)
			draw_set_transform(Vector2(0, 0), 0, Vector2(1.0, 0.6))
			draw_circle(Vector2.ZERO, 17, Color(0.78, 0.86, 0.97))
			draw_circle(Vector2(-3, -4), 13, Color(0.97, 0.99, 1))
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			draw_line(Vector2(-6, -2), Vector2(6, -2), Color(0.7, 0.8, 0.93), 1.0)
		"berry_bush":
			_shadow(13.0, 5.0)
			var green := Color(0.16, 0.36, 0.2)
			draw_circle(Vector2(-6, 0), 8, green)
			draw_circle(Vector2(6, 0), 8, green)
			draw_circle(Vector2(0, -6), 9, green.lightened(0.1))
			draw_circle(Vector2(-2, -12), 4, Color(0.95, 0.97, 1))
			var spots := [Vector2(-7, -2), Vector2(5, -4), Vector2(1, 3)]
			for i in uses:
				draw_circle(spots[i % 3], 2.6, Color(0.85, 0.1, 0.2))
		"meat":
			_shadow(8.0)
			draw_set_transform(Vector2.ZERO, 0.3, Vector2(1, 0.65))
			draw_circle(Vector2.ZERO, 8, Color(0.75, 0.25, 0.3))
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			draw_line(Vector2(5, 2), Vector2(11, 5), Color(0.95, 0.92, 0.85), 2.5)
