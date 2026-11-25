extends Node2D
## A snowshoe hare. Wanders by day and bolts when you get close. Sprint to catch it, Space to hunt.

const WANDER_SPEED := 35.0
const FLEE_SPEED := 150.0    # sprinting is 210, so you can run it down
const FLEE_STAMINA := 2.0    # seconds it can bolt before stopping to rest
const REST_TIME := 1.2
const SCARE_RANGE := 130.0

const TEX := [preload("res://art/hare_0.png"), preload("res://art/hare_1.png")]

var main
var hit_radius := 8.0
var display_name := "hare"
var _flee_left := FLEE_STAMINA
var _rest := 0.0
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
	_rest = maxf(_rest - delta, 0.0)
	if _rest > 0.0:
		vel = Vector2.ZERO  # out of breath: your chance to strike
	elif to_p.length() < SCARE_RANGE:
		vel = -to_p.normalized() * FLEE_SPEED
		_flee_left -= delta
		if _flee_left <= 0.0:
			_rest = REST_TIME
			_flee_left = FLEE_STAMINA
	else:
		_flee_left = minf(_flee_left + delta * 0.5, FLEE_STAMINA)
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


func take_hit(player, _damage: float = 1.0) -> void:
	main.audio.play("squeak", position)
	main.audio.play("hit", position, -4.0)
	main.puff(position, Color(0.8, 0.74, 0.66), 10, 60.0)
	main.spawn_loot(position, {"raw_meat": 1, "hide": 1} if randf() < 0.5 else {"raw_meat": 1})
	main.stats["hares"] += 1
	player.add_xp("hunting", 8)
	main.hud.show_toast("Caught a hare! Pick up the meat (E).")
	queue_free()


func _draw() -> void:
	draw_set_transform(Vector2(0, 2), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 6, Color(0, 0, 0, 0.2))
	var flip := -1.0 if facing.x < 0.0 else 1.0
	var hop := -2.0 if (_moving and int(_anim) % 2 == 1) else 0.0
	draw_set_transform(Vector2(0, hop), 0, Vector2(flip, 1))
	var frame := (int(_anim) % 2) if _moving else 0
	draw_texture(TEX[frame], Vector2(-6, -10))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
