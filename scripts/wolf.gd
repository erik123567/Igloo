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
	"wolf": {"name": "wolf", "hp": 3.0, "dmg": 12.0, "speed": 150.0, "sense": 340.0, "scale": 1.0,
		"tint": Color(1, 1, 1), "loot": {"raw_meat": 2, "hide": 1, "bone": 1}, "xp": 25},
	"dire": {"name": "dire wolf", "hp": 7.0, "dmg": 18.0, "speed": 165.0, "sense": 380.0, "scale": 1.3,
		"tint": Color(0.55, 0.5, 0.48), "loot": {"raw_meat": 3, "hide": 2, "bone": 2}, "xp": 55},
	"frost": {"name": "frost wolf", "hp": 11.0, "dmg": 24.0, "speed": 180.0, "sense": 420.0, "scale": 1.4,
		"tint": Color(0.8, 0.92, 1.25), "loot": {"raw_meat": 3, "hide": 2, "bone": 2, "white_fur": 1}, "xp": 90},
	# Boss of the boreal forest. Calls its pack when hurt.
	"alpha": {"name": "Greymane, the pack alpha", "hp": 30.0, "dmg": 22.0, "speed": 165.0, "sense": 380.0, "scale": 1.9,
		"tint": Color(0.42, 0.42, 0.48), "loot": {"alpha_fang": 1, "raw_meat": 5, "hide": 4, "bone": 4, "iron": 3}, "xp": 250, "boss": true},
}
const WINDUP := 0.38          # seconds a wolf crouches before it lunges: your chance to dodge

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


func freeze(t: float) -> void:
	_freeze = t


func is_attacking() -> bool:
	return _windup > 0.0 or _recover > 0.0


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
	if _freeze > 0.0:
		_freeze -= delta
		queue_redraw()
		return
	if _recover > 0.0 and not leaving:
		_recover -= delta
		if _kb.length() > 5.0:
			position += _kb * delta
			_kb = _kb.move_toward(Vector2.ZERO, 1500.0 * delta)
		queue_redraw()
		return
	if _kb.length() > 5.0:
		position += _kb * delta
		_kb = _kb.move_toward(Vector2.ZERO, 1500.0 * delta)
	if _hurt > 0.0 and not leaving:
		queue_redraw()
		return   # stunned for a moment after a hit
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
		if _windup <= 0.0:
			position += dir_p * 14.0 * float(_v["scale"])
			if dist < 34.0 * float(_v["scale"]):
				if player.is_dodging():
					player.on_dodged()
				else:
					main.audio.play("bite", position)
					player.take_damage(float(_v["dmg"]), "a %s" % display_name, true, true)
					main.hud.show_toast("The %s bites you!" % display_name)
			_bite_cd = BITE_COOLDOWN
			_recover = 0.5
	elif _back_off > 0.0:
		vel = -dir_p * float(_v["speed"]) * 0.9
	elif is_boss() and position.distance_to(home) > 650.0:
		# a boss won't leave its lair for long
		vel = (home - position).normalized() * float(_v["speed"])
		hp = minf(hp + delta * 2.0, max_hp())
	elif dist < float(_v["sense"]) and not player.dead and not main.is_safe_spot(player.position):
		vel = dir_p * float(_v["speed"])
		# a pack takes turns: at most two wolves go for you at once, the rest circle
		if dist < 110.0 and not is_boss() and main.wolves_attacking(self) >= 2:
			vel = dir_p.orthogonal() * PROWL_SPEED * 1.6 + dir_p * (90.0 - dist)
		elif dist < 26.0 * float(_v["scale"]) and _bite_cd <= 0.0:
			_windup = WINDUP
			vel = Vector2.ZERO
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
	hp -= damage
	_flash = 0.07
	# poise: a wolf only flinches every few hits, and never mid-lunge
	_poise_hits += 1
	var poise := 2 if variant == "wolf" else 3
	if not is_boss() and _windup <= 0.0 and _poise_hits >= poise:
		_poise_hits = 0
		_hurt = 0.12
	main.float_text(position + Vector2(0, -20 * float(_v["scale"])), str(snappedf(damage, 0.1)), Color(1, 0.9, 0.5))
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
		player.add_xp("hunting", int(_v["xp"]))
		if is_boss():
			main.boss_defeated(variant, display_name)
		else:
			main.hud.show_message("You killed the %s." % display_name, 3.0)
		queue_free()
	else:
		main.hud.show_toast("You hit the %s!" % display_name)


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
	if hp < max_hp() and not is_boss():
		main.draw_bar(self, Vector2(0, -15 * sc), 22.0 * sc, hp / max_hp(), Color(0.9, 0.25, 0.25))
