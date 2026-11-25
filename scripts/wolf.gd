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

const TEX := [preload("res://art/wolf_0.png"), preload("res://art/wolf_1.png")]

var main
var hp := MAX_HP
var hit_radius := 12.0
var display_name := "wolf"
var leaving := false
var facing := Vector2.RIGHT

var _wander_dir := Vector2.RIGHT
var _wander_timer := 0.0
var _bite_cd := 0.0
var _back_off := 0.0
var _hurt := 0.0
var _anim := 0.0
var _moving := false
var _print_dist := 0.0
var _howl_timer := 0.0


func _ready() -> void:
	_howl_timer = randf_range(8.0, 25.0)
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
			main.audio.play("bite", position)
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
	var moved := new_pos.distance_to(position)
	_moving = moved > 0.1
	_print_dist += moved
	if _print_dist > 16.0:
		_print_dist = 0.0
		main.add_footprint(new_pos + Vector2(randf_range(-3, 3), 4), true)
	_howl_timer -= delta
	if _howl_timer <= 0.0:
		_howl_timer = randf_range(20.0, 40.0)
		if dist > 250.0 and not leaving:
			main.audio.play("howl", position, -6.0, 0.1)
	if _moving:
		facing = (new_pos - position).normalized()
		_anim += delta * 12.0
	position = new_pos
	queue_redraw()


func take_hit(player, damage: int = 1) -> void:
	hp -= damage
	_hurt = 0.2
	_back_off = 2.0
	position += (position - player.position).normalized() * 18.0
	main.audio.play("hit", position)
	main.puff(position + Vector2(0, -6), Color(0.6, 0.62, 0.7), 8, 60.0)
	main.shake(2.5)
	if hp <= 0:
		main.spawn_meat(position, 2)
		main.hud.show_message("You killed the wolf. It left meat behind.", 3.0)
		queue_free()
	else:
		main.hud.show_toast("You hit the wolf!")


func _draw() -> void:
	draw_set_transform(Vector2(0, 2), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 12, Color(0, 0, 0, 0.22))
	var flip := -1.0 if facing.x < 0.0 else 1.0
	draw_set_transform(Vector2.ZERO, 0, Vector2(flip, 1))
	var tint := Color(1, 0.5, 0.5) if _hurt > 0.0 else Color(1, 1, 1)
	var frame := (int(_anim) % 2) if _moving else 0
	draw_texture(TEX[frame], Vector2(-13, -11), tint)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
