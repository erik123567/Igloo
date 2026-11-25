extends Node2D
## A polar bear. Roams the frozen north day and night. Slow to anger, deadly up close.
## You can outrun it by sprinting. It won't come into firelight or a finished shelter.

const TEX := [preload("res://art/bear_0.png"), preload("res://art/bear_1.png")]

# ---------- Tuning ----------
const ROAM_SPEED := 35.0
const CHASE_SPEED := 125.0       # walking is 130, sprinting 210
const SENSE_RANGE := 260.0
const ANGRY_RANGE := 480.0       # after you hit it, it notices you from much further
const SWIPE_DAMAGE := 28.0
const SWIPE_COOLDOWN := 2.0
const MAX_HP := 10

var main
var hp := MAX_HP
var hit_radius := 22.0
var display_name := "polar bear"
var home := Vector2.ZERO
var facing := Vector2.RIGHT

var _angry := 0.0
var _wander := Vector2.ZERO
var _wander_t := 0.0
var _swipe_cd := 0.0
var _back_off := 0.0
var _hurt := 0.0
var _anim := 0.0
var _moving := false
var _print_dist := 0.0


func _ready() -> void:
	add_to_group("bear")
	add_to_group("attackable")
	if home == Vector2.ZERO:
		home = position


func _process(delta: float) -> void:
	if main.game_over or main.sleeping:
		return
	_swipe_cd -= delta
	_back_off -= delta
	_angry = maxf(_angry - delta, 0.0)
	_hurt = maxf(_hurt - delta, 0.0)
	var player = main.player
	var to_p: Vector2 = player.position - position
	var dist := to_p.length()
	var dir_p := to_p.normalized() if dist > 0.01 else Vector2.RIGHT
	var sense := ANGRY_RANGE if _angry > 0.0 else SENSE_RANGE
	var vel := Vector2.ZERO
	if _back_off > 0.0:
		vel = -dir_p * ROAM_SPEED * 1.5
	elif dist < sense and not player.dead and not main.is_safe_spot(player.position):
		vel = dir_p * CHASE_SPEED
		if dist < 30.0 and _swipe_cd <= 0.0:
			main.audio.play("bite", position, 2.0, 0.0, 0.6)
			player.take_damage(SWIPE_DAMAGE, "a polar bear")
			main.shake(9.0)
			_swipe_cd = SWIPE_COOLDOWN
			_back_off = 0.5
	else:
		_wander_t -= delta
		if _wander_t <= 0.0:
			_wander_t = randf_range(2.0, 5.0)
			_wander = Vector2.ZERO if randf() < 0.35 else Vector2.from_angle(randf() * TAU)
			if position.distance_to(home) > 450.0:
				_wander = (home - position).normalized()
		vel = _wander * ROAM_SPEED

	var new_pos := position + vel * delta
	var push: Vector2 = main.fear_push(new_pos)
	if push != Vector2.ZERO:
		new_pos = position + push * ROAM_SPEED * 2.0 * delta
	new_pos.x = clampf(new_pos.x, 20.0, main.world_size.x - 20.0)
	new_pos.y = clampf(new_pos.y, 20.0, main.shore_y)
	var moved := new_pos.distance_to(position)
	_moving = moved > 0.1
	_print_dist += moved
	if _print_dist > 22.0:
		_print_dist = 0.0
		main.add_footprint(new_pos + Vector2(randf_range(-6, 6), 4), true)
	if _moving:
		facing = (new_pos - position).normalized()
		_anim += delta * 7.0
	position = new_pos
	queue_redraw()


func take_hit(player, damage: int = 1) -> void:
	hp -= damage
	_hurt = 0.2
	_angry = 20.0
	position += (position - player.position).normalized() * 6.0
	main.audio.play("hit", position)
	main.audio.play("bite", position, -2.0, 0.0, 0.55)
	main.puff(position + Vector2(0, -10), Color(0.95, 0.93, 0.85), 10, 60.0)
	main.shake(3.0)
	if hp <= 0:
		main.spawn_loot(position, {"raw_meat": 5, "hide": 3, "bone": 2})
		main.stats["bears"] += 1
		main.hud.show_message("You brought down a polar bear! It left meat, hides and bones.", 4.0)
		queue_free()
	else:
		main.hud.show_toast("You hit the polar bear! It's angry now.")


func _draw() -> void:
	draw_set_transform(Vector2(0, 3), 0, Vector2(1, 0.3))
	draw_circle(Vector2.ZERO, 30, Color(0, 0, 0, 0.22))
	var flip := -1.0 if facing.x < 0.0 else 1.0
	draw_set_transform(Vector2.ZERO, 0, Vector2(2.0 * flip, 2.0))
	var tint := Color(1, 0.55, 0.55) if _hurt > 0.0 else Color(1, 1, 1)
	var frame := (int(_anim) % 2) if _moving else 0
	draw_texture(TEX[frame], Vector2(-15, -15), tint)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
