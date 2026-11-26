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

## Wolf types, from the coast to the far north: hp, bite damage, chase speed, sense range, size, colour, loot, XP.
const VARIANTS := {
	"wolf": {"name": "wolf", "hp": 110.0, "dmg": [8, 11], "cd": 1.4, "armor": 0.0, "speed": 155.0, "sense": 340.0, "scale": 1.0,
		"tint": Color(1, 1, 1), "loot": {"raw_meat": 2, "hide": 1, "bone": 1}, "xp": 20},
	"dire": {"name": "dire wolf", "hp": 220.0, "dmg": [14, 18], "cd": 1.4, "armor": 2.0, "speed": 165.0, "sense": 380.0, "scale": 1.3,
		"tint": Color(0.55, 0.5, 0.48), "loot": {"raw_meat": 3, "hide": 2, "bone": 2}, "xp": 45},
	"frost": {"name": "frost wolf", "hp": 340.0, "dmg": [18, 24], "cd": 1.4, "armor": 3.0, "speed": 175.0, "sense": 420.0, "scale": 1.4,
		"tint": Color(0.8, 0.92, 1.25), "loot": {"raw_meat": 3, "hide": 2, "bone": 2, "white_fur": 1}, "xp": 80},
	# Boss of the boreal forest. Calls its pack when hurt.
	"alpha": {"name": "Greymane, the pack alpha", "hp": 1400.0, "dmg": [24, 30], "cd": 1.2, "armor": 5.0, "speed": 165.0, "sense": 380.0, "scale": 1.9,
		"tint": Color(0.42, 0.42, 0.48), "loot": {"alpha_fang": 1, "raw_meat": 5, "hide": 4, "bone": 4, "iron": 3}, "xp": 600, "boss": true},
}
const WINDUP := 0.35          # the damage point: how long after starting a bite it lands

var main
var hp := float(MAX_HP)
var variant := "wolf"
var _v: Dictionary = {}
var hit_radius := 12.0
var display_name := "wolf"
var leaving := false
var resident := false     # forest pack wolves stay out in the daytime too
var home := Vector2.ZERO
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
var _windup := 0.0
var _kb := Vector2.ZERO
var _recover := 0.0      # standing still after an attack: free hits for you
var _freeze := 0.0       # hitstop
var _flash := 0.0        # white flash when hit
var _poise_hits := 0
var _summons := 2             # the alpha calls for help twice


func _ready() -> void:
	_v = VARIANTS.get(variant, VARIANTS["wolf"])
	hp = _v["hp"]
	display_name = _v["name"]
	hit_radius = 12.0 * float(_v["scale"])
	_howl_timer = randf_range(8.0, 25.0)
	add_to_group("wolf")
	if is_boss():
		add_to_group("boss")
		resident = true
	add_to_group("attackable")


func is_boss() -> bool:
	return _v.get("boss", false)


func max_hp() -> float:
	return float(_v["hp"])


## Wolves of this pack within reach of each other (counting this one).
func _pack_size() -> int:
	var n := 0
	for w in get_tree().get_nodes_in_group("wolf"):
		if w.position.distance_to(position) < 220.0:
			n += 1
	return n


func freeze(t: float) -> void:
	_freeze = t


func is_attacking() -> bool:
	return _windup > 0.0


func knock(v: Vector2) -> void:
	_kb = v * (0.3 if is_boss() else 1.0 / float(_v["scale"]))


func leave() -> void:
	if not resident:
		leaving = true


func _process(delta: float) -> void:
	if main.game_over or main.sleeping:
		return
	_bite_cd -= delta
	_back_off -= delta
	_hurt = maxf(_hurt - delta, 0.0)
	_flash = maxf(_flash - delta, 0.0)
	var player = main.player
	var to_p: Vector2 = player.position - position
	var dist := to_p.length()
	var dir_p := to_p.normalized() if dist > 0.01 else Vector2.RIGHT
	var vel := Vector2.ZERO

	if leaving:
		vel = -dir_p * float(_v["speed"]) * 0.8
		if dist > 900.0:
			queue_free()
			return
	elif _windup > 0.0:
		# crouched, about to lunge
		_windup -= delta
		facing = dir_p
		if _windup <= 0.0 and dist < 26.0 * float(_v["scale"]) + 22.0 and not player.dead:
			var d: Array = _v["dmg"]
			main.audio.play("bite", position)
			player.take_damage(float(randi_range(d[0], d[1])), "a %s" % display_name, true, true)
			if variant == "frost":
				player.temp = maxf(player.temp - 4.0, 0.0)   # frost bites chill you
	elif _back_off > 0.0:
		vel = -dir_p * float(_v["speed"]) * 0.9
	elif is_boss() and position.distance_to(home) > 650.0:
		# a boss won't leave its lair for long
		vel = (home - position).normalized() * float(_v["speed"])
		hp = minf(hp + delta * 2.0, max_hp())
	elif dist < float(_v["sense"]) and not player.dead and not main.is_safe_spot(player.position):
		var reach := 26.0 * float(_v["scale"])
		vel = dir_p * float(_v["speed"]) if dist > reach * 0.8 else Vector2.ZERO
		if hp < max_hp() * 0.2 and not is_boss() and _pack_size() < 3:
			vel = -dir_p * float(_v["speed"])   # badly hurt and alone: it runs
		elif dist < reach and _bite_cd <= 0.0:
			_windup = WINDUP
			_bite_cd = float(_v["cd"])
			main.audio.play("swing", position, -10.0, 0.0, 0.6)
	elif dist < float(_v["sense"]):
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
			if resident:
				if position.distance_to(home) > 300.0:
					_wander_dir = (home - position).normalized()
			else:
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


func take_hit(player, damage: float = 1.0) -> void:
	damage = maxf(damage * (1.0 - player.armor_reduction(float(_v["armor"]))), 1.0)
	hp -= damage
	_flash = 0.07
	_hurt = 0.15
	main.puff(position + Vector2(0, -6), Color(0.85, 0.2, 0.2), 5, 50.0)
	main.float_text(position + Vector2(0, -20 * float(_v["scale"])), str(int(round(damage))), Color(1, 0.9, 0.5))
	if is_boss() and _summons > 0 and hp < max_hp() * (0.33 * _summons) and hp > 0:
		_summons -= 1
		main.audio.play("howl", position, 0.0, 0.0)
		main.hud.show_message("%s howls for its pack!" % display_name, 3.0)
		for i in 2:
			var w = get_script().new()
			w.main = main
			w.variant = "wolf"
			w.resident = true
			w.home = home
			w.position = position + Vector2.from_angle(randf() * TAU) * 160.0
			get_parent().add_child(w)
	main.audio.play("hit", position)
	main.puff(position + Vector2(0, -6), Color(0.6, 0.62, 0.7), 8, 60.0)
	if hp <= 0:
		main.spawn_loot(position, _v["loot"].duplicate())
		main.stats["wolves"] += 1
		player.gain_xp(int(_v["xp"]))
		if is_boss():
			main.boss_defeated(variant, display_name)
		else:
			main.hud.show_message("You killed the %s." % display_name, 3.0)
		queue_free()
	else:
		pass


func _draw() -> void:
	var sc: float = _v.get("scale", 1.0)
	draw_set_transform(Vector2(0, 2), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 12 * sc, Color(0, 0, 0, 0.22))
	var flip := -1.0 if facing.x < 0.0 else 1.0
	draw_set_transform(Vector2.ZERO, 0, Vector2(flip * sc, sc))
	var tint: Color = Color(1, 0.5, 0.5) if _hurt > 0.0 else _v.get("tint", Color(1, 1, 1))
	if _flash > 0.0:
		tint = Color(3, 3, 3)
	if _windup > 0.0:
		tint = tint.lerp(Color(1, 0.3, 0.3), 0.5)
		draw_set_transform(Vector2(0, 2), 0, Vector2(flip * sc * 1.1, sc * 0.85))
	var frame := (int(_anim) % 2) if _moving else 0
	draw_texture(TEX[frame], Vector2(-13, -11), tint)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if _windup > 0.0:
		draw_string(ThemeDB.fallback_font, Vector2(-3, -16 * sc - 4), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.25, 0.2))
	if main.player.order_target == self:
		draw_set_transform(Vector2(0, 2), 0, Vector2(1, 0.5))
		draw_arc(Vector2.ZERO, hit_radius + 6.0, 0, TAU, 24, Color(1, 0.2, 0.15, 0.9), 1.5)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if hp < max_hp() and not is_boss():
		main.draw_bar(self, Vector2(0, -15 * sc), 22.0 * sc, hp / max_hp(), Color(0.9, 0.25, 0.25))
