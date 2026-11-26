extends Node2D
## A polar bear. Roams the frozen north day and night. Slow to anger, deadly up close.
## You can outrun it by sprinting. It won't come into firelight or a finished shelter.

const TEX := [preload("res://art/bear_0.png"), preload("res://art/bear_1.png")]

const VARIANTS := {
	"polar": {"name": "polar bear", "hp": 12.0, "dmg": 28.0, "speed": 125.0, "scale": 2.0, "tint": Color(1, 1, 1),
		"loot": {"raw_meat": 5, "hide": 3, "bone": 2, "white_fur": 2}, "xp": 80},
	"great": {"name": "great white bear", "hp": 30.0, "dmg": 45.0, "speed": 140.0, "scale": 2.7, "tint": Color(0.92, 0.97, 1.1),
		"loot": {"raw_meat": 8, "hide": 4, "bone": 4, "white_fur": 4, "steel": 1}, "xp": 220},
	# Bosses: the tundra's old king and the ruler of the far north. Their swipes hit an area.
	"tusk": {"name": "Old Tusk", "hp": 70.0, "dmg": 40.0, "speed": 135.0, "scale": 3.2, "tint": Color(0.85, 0.78, 0.62),
		"loot": {"great_claw": 1, "raw_meat": 10, "hide": 5, "bone": 6, "white_fur": 4, "steel": 2}, "xp": 450, "boss": true},
	"king": {"name": "The White King", "hp": 160.0, "dmg": 55.0, "speed": 150.0, "scale": 4.0, "tint": Color(0.82, 0.92, 1.25),
		"loot": {"king_pelt": 1, "raw_meat": 12, "white_fur": 8, "steel": 5}, "xp": 1000, "boss": true},
}
const WINDUP := 0.7           # bears rear up before they swipe: dodge out of the red circle

# ---------- Tuning ----------
const ROAM_SPEED := 35.0
const CHASE_SPEED := 125.0       # walking is 130, sprinting 210
const SENSE_RANGE := 260.0
const ANGRY_RANGE := 480.0       # after you hit it, it notices you from much further
const SWIPE_DAMAGE := 28.0
const SWIPE_COOLDOWN := 2.0
const MAX_HP := 10

var main
var hp := float(MAX_HP)
var variant := "polar"
var _v: Dictionary = {}
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
var _windup := 0.0


func _ready() -> void:
	_v = VARIANTS.get(variant, VARIANTS["polar"])
	hp = _v["hp"]
	display_name = _v["name"]
	hit_radius = 11.0 * float(_v["scale"])
	add_to_group("bear")
	if is_boss():
		add_to_group("boss")
	add_to_group("attackable")
	if home == Vector2.ZERO:
		home = position


func is_boss() -> bool:
	return _v.get("boss", false)


func max_hp() -> float:
	return float(_v["hp"])


func reach() -> float:
	return 18.0 * float(_v["scale"])


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
	if is_boss():
		sense = 420.0
	if _windup > 0.0:
		_windup -= delta
		if _windup <= 0.0:
			main.audio.play("bite", position, 2.0, 0.0, 0.6)
			main.shake(9.0)
			main.puff(position, Color(0.95, 0.95, 1.0), 16, 120.0)
			if dist < reach() + 8.0 and not player.is_dodging():
				player.take_damage(float(_v["dmg"]), "a %s" % display_name, true, true)
			else:
				main.float_text(player.position + Vector2(0, -24), "dodged!", Color(0.7, 0.95, 1.0))
			_swipe_cd = SWIPE_COOLDOWN * (0.8 if is_boss() else 1.0)
			_back_off = 0.5
	elif _back_off > 0.0:
		vel = -dir_p * ROAM_SPEED * 1.5
	elif is_boss() and position.distance_to(home) > 600.0:
		vel = (home - position).normalized() * float(_v["speed"])
		hp = minf(hp + delta * 4.0, max_hp())
	elif dist < sense and not player.dead and not main.is_safe_spot(player.position):
		vel = dir_p * float(_v["speed"])
		if dist < reach() * 0.8 and _swipe_cd <= 0.0:
			_windup = WINDUP * (0.85 if variant == "king" else 1.0)
			vel = Vector2.ZERO
			main.audio.play("bite", position, -4.0, 0.0, 0.45)
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


func take_hit(player, damage: float = 1.0) -> void:
	hp -= damage
	_hurt = 0.2
	_angry = 20.0
	main.float_text(position + Vector2(0, -16 * float(_v["scale"])), str(snappedf(damage, 0.1)), Color(1, 0.9, 0.5))
	position += (position - player.position).normalized() * 6.0
	main.audio.play("hit", position)
	main.audio.play("bite", position, -2.0, 0.0, 0.55)
	main.puff(position + Vector2(0, -10), Color(0.95, 0.93, 0.85), 10, 60.0)
	main.shake(3.0)
	if hp <= 0:
		main.spawn_loot(position, _v["loot"].duplicate())
		main.stats["bears"] += 1
		player.add_xp("hunting", int(_v["xp"]))
		if is_boss():
			main.boss_defeated(variant, display_name)
		else:
			main.hud.show_message("You brought down a %s!" % display_name, 4.0)
		queue_free()
	else:
		main.hud.show_toast("You hit the %s! It's angry now." % display_name)


func _draw() -> void:
	var sc: float = _v.get("scale", 2.0)
	if _windup > 0.0:
		# danger zone telegraph
		draw_set_transform(Vector2(0, 2), 0, Vector2(1, 0.55))
		var a := 0.25 + 0.35 * (1.0 - _windup / WINDUP)
		draw_circle(Vector2.ZERO, reach() + 8.0, Color(1, 0.15, 0.1, a * 0.5))
		draw_arc(Vector2.ZERO, reach() + 8.0, 0, TAU, 32, Color(1, 0.2, 0.15, 0.9), 2.0)
	draw_set_transform(Vector2(0, 3), 0, Vector2(1, 0.3))
	draw_circle(Vector2.ZERO, 15 * sc, Color(0, 0, 0, 0.22))
	var flip := -1.0 if facing.x < 0.0 else 1.0
	draw_set_transform(Vector2.ZERO, 0, Vector2(sc * flip, sc))
	var tint: Color = Color(1, 0.55, 0.55) if _hurt > 0.0 else _v.get("tint", Color(1, 1, 1))
	var frame := (int(_anim) % 2) if _moving else 0
	var rear := Vector2(0, -3) if _windup > 0.0 else Vector2.ZERO
	draw_texture(TEX[frame], Vector2(-15, -15) + rear, tint)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if hp < max_hp() and not is_boss():
		main.draw_bar(self, Vector2(0, -17 * sc), 18.0 * sc, hp / max_hp(), Color(0.9, 0.25, 0.25))
