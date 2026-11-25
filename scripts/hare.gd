extends Node2D
## A snowshoe hare. Wanders by day and bolts when you get close. Sprint to catch it, Space to hunt.

const WANDER_SPEED := 35.0
const FLEE_SPEED := 165.0
const SCARE_RANGE := 130.0

var main
var hit_radius := 8.0
var facing := Vector2.RIGHT
var _dir := Vector2.RIGHT
var _timer := 0.0
var _anim := 0.0
var _moving := false


func _ready() -> void:
	add_to_group("hare")
	add_to_group("attackable")


func _process(delta: float) -> void:
	if main.game_over or main.sleeping:
		return
	var to_p: Vector2 = main.player.position - position
	var vel := Vector2.ZERO
	if to_p.length() < SCARE_RANGE:
		vel = -to_p.normalized() * FLEE_SPEED
	else:
		_timer -= delta
		if _timer <= 0.0:
			_timer = randf_range(0.8, 2.5)
			_dir = Vector2.ZERO if randf() < 0.4 else Vector2.from_angle(randf() * TAU)
		vel = _dir * WANDER_SPEED
	var new_pos := position + vel * delta
	new_pos.x = clampf(new_pos.x, 20.0, main.world_size.x - 20.0)
	new_pos.y = clampf(new_pos.y, 20.0, main.shore_y)
	_moving = new_pos.distance_to(position) > 0.05
	if _moving:
		facing = (new_pos - position).normalized()
		_anim += delta * 14.0
	position = new_pos
	queue_redraw()


func take_hit(_player) -> void:
	main.spawn_meat(position, 1)
	main.hud.show_toast("Caught a hare! Pick up the meat (E).")
	queue_free()


func _draw() -> void:
	var hop := absf(sin(_anim)) * 3.0 if _moving else 0.0
	draw_set_transform(Vector2(0, 5), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 7, Color(0, 0, 0, 0.2))
	var flip := -1.0 if facing.x < 0.0 else 1.0
	var fur := Color(0.78, 0.72, 0.64)
	draw_set_transform(Vector2(0, -hop), 0, Vector2(flip, 0.75))
	draw_circle(Vector2.ZERO, 6.5, fur)
	draw_set_transform(Vector2(0, -hop), 0, Vector2(flip, 1))
	draw_circle(Vector2(5, -4), 3.8, fur)
	draw_line(Vector2(4, -7), Vector2(2, -14), fur.darkened(0.15), 2.2)
	draw_line(Vector2(6, -7), Vector2(6, -14), fur.darkened(0.15), 2.2)
	draw_circle(Vector2(-6, -1), 2.2, Color(0.97, 0.97, 1))
	draw_circle(Vector2(6.5, -4.5), 0.9, Color(0.1, 0.1, 0.1))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
