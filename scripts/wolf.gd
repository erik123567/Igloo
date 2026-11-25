extends Node2D
## A wolf. Prowls at night, chases you when close, bites, and backs off when hit.
## Wolves will not step into firelight or a finished igloo. They leave at dawn.

# ---------- Tuning ----------
const PROWL_SPEED := 55.0
const CHASE_SPEED := 150.0    # walking is 130, sprinting is 210
const SENSE_RANGE := 340.0
const BITE_DAMAGE := 12.0
const BITE_COOLDOWN := 1.5
const MAX_HP := 3

var main
var hp := MAX_HP
var hit_radius := 12.0
var leaving := false
var facing := Vector2.RIGHT

var _wander_dir := Vector2.RIGHT
var _wander_timer := 0.0
var _bite_cd := 0.0
var _back_off := 0.0
var _hurt := 0.0
var _anim := 0.0
var _moving := false


func _ready() -> void:
	add_to_group("wolf")
	add_to_group("attackable")


func leave() -> void:
	leaving = true


func _process(delta: float) -> void:
	if main.game_over or main.sleeping:
		return
	_bite_cd -= delta
	_back_off -= delta
	_hurt = maxf(_hurt - delta, 0.0)
	var player = main.player
	var to_p: Vector2 = player.position - position
	var dist := to_p.length()
	var dir_p := to_p.normalized() if dist > 0.01 else Vector2.RIGHT
	var vel := Vector2.ZERO

	if leaving:
		vel = -dir_p * CHASE_SPEED * 0.8
		if dist > 900.0:
			queue_free()
			return
	elif _back_off > 0.0:
		vel = -dir_p * CHASE_SPEED * 0.9
	elif dist < SENSE_RANGE and not player.dead and not main.is_safe_spot(player.position):
		vel = dir_p * CHASE_SPEED
		if dist < 22.0 and _bite_cd <= 0.0:
			player.take_damage(BITE_DAMAGE, "a wolf attack")
			main.hud.show_toast("A wolf bites you!")
			_bite_cd = BITE_COOLDOWN
			_back_off = 0.7
	elif dist < SENSE_RANGE:
		# Player is safe by the fire: circle at the edge of the light, watching.
		vel = dir_p.orthogonal() * PROWL_SPEED
		if dist > 220.0:
			vel += dir_p * PROWL_SPEED
	else:
		_wander_timer -= delta
		if _wander_timer <= 0.0:
			_wander_timer = randf_range(1.5, 3.5)
			_wander_dir = Vector2.from_angle(randf() * TAU)
			# drift toward the player's area over time
			_wander_dir = (_wander_dir + dir_p * 0.6).normalized()
		vel = _wander_dir * PROWL_SPEED

	var new_pos := position + vel * delta
	var push: Vector2 = main.fear_push(new_pos)
	if push != Vector2.ZERO and not leaving:
		new_pos = position + push * PROWL_SPEED * delta
	new_pos.x = clampf(new_pos.x, 10.0, main.world_size.x - 10.0)
	new_pos.y = clampf(new_pos.y, 10.0, main.shore_y + 50.0)
	_moving = new_pos.distance_to(position) > 0.1
	if _moving:
		facing = (new_pos - position).normalized()
		_anim += delta * 12.0
	position = new_pos
	queue_redraw()


func take_hit(player) -> void:
	hp -= 1
	_hurt = 0.2
	_back_off = 2.0
	position += (position - player.position).normalized() * 18.0
	if hp <= 0:
		main.spawn_meat(position, 2)
		main.hud.show_message("You killed the wolf. It left meat behind.", 3.0)
		queue_free()
	else:
		main.hud.show_toast("You hit the wolf!")


func _draw() -> void:
	draw_set_transform(Vector2(0, 7), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 15, Color(0, 0, 0, 0.22))
	var flip := -1.0 if facing.x < 0.0 else 1.0
	draw_set_transform(Vector2.ZERO, 0, Vector2(flip, 1))
	var fur := Color(0.42, 0.43, 0.48)
	if _hurt > 0.0:
		fur = Color(0.9, 0.5, 0.5)
	var leg := sin(_anim) * 3.0 if _moving else 0.0
	# legs
	for x in [-9.0, -5.0, 6.0, 10.0]:
		var off: float = leg if (x < 0.0) else -leg
		draw_line(Vector2(x, 2), Vector2(x + off, 9), fur.darkened(0.3), 2.5)
	# tail
	draw_line(Vector2(-13, -1), Vector2(-20, -5), fur, 3.0)
	# body
	draw_set_transform(Vector2(0, 0), 0, Vector2(flip, 0.55))
	draw_circle(Vector2.ZERO, 13, fur)
	draw_set_transform(Vector2.ZERO, 0, Vector2(flip, 1))
	# head
	draw_circle(Vector2(12, -5), 6, fur.lightened(0.05))
	draw_colored_polygon(PackedVector2Array([Vector2(15, -5), Vector2(21, -2), Vector2(15, -1)]), fur.lightened(0.1))
	draw_colored_polygon(PackedVector2Array([Vector2(8, -9), Vector2(10, -15), Vector2(12, -9)]), fur.darkened(0.2))
	draw_colored_polygon(PackedVector2Array([Vector2(12, -9), Vector2(14, -15), Vector2(16, -9)]), fur.darkened(0.2))
	# glowing eyes
	draw_circle(Vector2(14.5, -6.5), 1.4, Color(1, 0.9, 0.2))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
