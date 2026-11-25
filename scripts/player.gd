extends Node2D
## The player: movement, the four survival stats, gathering, eating, cooking and fighting.

# ---------- Tuning (change these numbers to balance the game) ----------
const WALK_SPEED := 130.0
const SPRINT_SPEED := 210.0
const COLD_SLOW := 0.7             # speed multiplier when body temp is low
const INTERACT_RANGE := 26.0
const ATTACK_RANGE := 36.0

const TEMP_DRAIN_DAY := 0.45       # body temp lost per second outside in daylight
const TEMP_DRAIN_NIGHT := 1.3      # ... at night
const IGLOO_INSULATION := 0.3      # inside a finished igloo you only feel this share of the cold
const FIRE_WARMTH := 3.5           # warmth per second right next to a fire
const HUNGER_DRAIN := 0.2          # hunger lost per second
const HUNGER_SPRINT_EXTRA := 0.3
const ENERGY_SPRINT_COST := 9.0    # energy per second while sprinting
const ENERGY_REST_REGEN := 3.0     # energy per second while standing still
const ENERGY_FIRE_BONUS := 3.0     # extra energy per second resting by a fire
const FREEZE_DAMAGE := 2.5         # health per second when body temp is 0
const STARVE_DAMAGE := 1.2         # health per second when hunger is 0
const HEAL_RATE := 0.6             # health per second when warm and fed

const TEX := {
	"down": [preload("res://art/player_down_0.png"), preload("res://art/player_down_1.png"), preload("res://art/player_down_2.png")],
	"up": [preload("res://art/player_up_0.png"), preload("res://art/player_up_1.png"), preload("res://art/player_up_2.png")],
	"side": [preload("res://art/player_side_0.png"), preload("res://art/player_side_1.png")],
}

var main

var temp := 85.0      # body temperature, 0 = freezing
var hunger := 90.0    # 100 = full, 0 = starving
var energy := 100.0
var health := 100.0

var inventory := {
	"sticks": 0, "flint": 0, "stone": 0, "snow_block": 0,
	"berries": 0, "raw_meat": 0, "cooked_meat": 0,
	"logs": 0, "arrows": 0, "torch": 0, "hide": 0, "bone": 0, "iron": 0,
}
var tools := {"axe": 0, "spear": 0, "bow": 0}   # 0 = don't have it, 1 stone, 2 bone, 3 iron
var gear := {"mittens": false, "boots": false, "coat": false}
var weapon := "hands"        # "hands", "spear" or "bow"
var torch_time := 0.0        # seconds left on the torch you're holding
const TORCH_BURN := 90.0

var facing := Vector2.DOWN
var is_moving := false
var is_sprinting := false
var target = null           # nearest thing you can use with E
var prey = null             # nearest animal you could hit with Space
var warmth_source := ""     # "fire", "igloo" or ""
var dead := false

var _action_cd := 0.0
var _attack_cd := 0.0
var _swing := 0.0
var _hurt := 0.0
var _walk := 0.0
var _light: PointLight2D
var _step_dist := 0.0
var _step_left := false
var _breath := 0.0
var _hail_tick := 0.0


func _ready() -> void:
	_light = PointLight2D.new()
	_light.texture = main.make_light_texture()
	_light.texture_scale = 1.4
	_light.color = Color(0.75, 0.82, 1.0)
	add_child(_light)

	# Gentle snowfall that follows the player
	var snow := CPUParticles2D.new()
	snow.amount = 120
	snow.lifetime = 5.0
	snow.preprocess = 5.0
	snow.local_coords = false
	snow.position = Vector2(0, -120)
	snow.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	snow.emission_rect_extents = Vector2(420, 200)
	snow.direction = Vector2(0.3, 1)
	snow.spread = 15.0
	snow.gravity = Vector2(0, 6)
	snow.initial_velocity_min = 18.0
	snow.initial_velocity_max = 35.0
	snow.scale_amount_min = 1.0
	snow.scale_amount_max = 2.2
	snow.color = Color(1, 1, 1, 0.85)
	snow.z_index = 50
	add_child(snow)


func _process(delta: float) -> void:
	if dead or main.game_over or main.sleeping:
		return
	_action_cd = maxf(_action_cd - delta, 0.0)
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_swing = maxf(_swing - delta, 0.0)
	_hurt = maxf(_hurt - delta, 0.0)
	_move(delta)
	_update_stats(delta)
	_find_target()
	prey = _nearest_attackable(ATTACK_RANGE + 30.0)
	_handle_actions()
	if torch_time > 0.0:
		_light.energy = 0.5 + 0.8 * main.get_night_factor() + sin(Time.get_ticks_msec() / 90.0) * 0.06
		_light.texture_scale = 2.4
		_light.color = Color(1.0, 0.72, 0.42)
	else:
		_light.energy = 0.55 * main.get_night_factor()
		_light.texture_scale = 1.4
		_light.color = Color(0.75, 0.82, 1.0)
	# frosty breath when it's cold
	_breath -= delta
	if _breath <= 0.0:
		_breath = 1.4
		if temp < 50.0 or main.get_night_factor() > 0.5:
			main.puff(position + Vector2(0, -9) + facing * 6.0, Color(1, 1, 1, 0.6), 4, 14.0)
	queue_redraw()


func _move(delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if main.hud.craft_open:
		dir = Vector2.ZERO  # the arrow keys scroll the crafting menu instead
	is_moving = dir.length() > 0.1
	is_sprinting = is_moving and Input.is_action_pressed("sprint") and energy > 1.0
	var speed := SPRINT_SPEED if is_sprinting else WALK_SPEED
	if temp < 25.0:
		speed *= COLD_SLOW
	if energy < 10.0 and not is_sprinting:
		speed *= 0.85
	speed *= main.weather.speed_multiplier()
	if gear["boots"]:
		speed *= 1.08
	if is_moving:
		facing = dir.normalized()
		position += dir * speed * delta
		position.x = clampf(position.x, 16.0, main.world_size.x - 16.0)
		position.y = clampf(position.y, 16.0, main.shore_y + 60.0)
		_walk += delta * speed * 0.055
		_step_dist += speed * delta
		if _step_dist > 20.0:
			_step_dist = 0.0
			_step_left = not _step_left
			var side := facing.orthogonal() * (3.0 if _step_left else -3.0)
			main.add_footprint(position + Vector2(0, 3) + side)
			main.audio.play("step_%d" % (randi() % 3), null, -10.0 if not is_sprinting else -7.0, 0.12)


func _update_stats(delta: float) -> void:
	var nf: float = main.get_night_factor()
	var rate := -lerpf(TEMP_DRAIN_DAY, TEMP_DRAIN_NIGHT, nf)
	warmth_source = ""
	var shelter = main.get_shelter_at(position)
	var sheltered: bool = shelter != null and shelter.storm_proof()
	if shelter != null:
		rate *= shelter.insulation()
		if not sheltered:
			rate *= main.weather.cold_multiplier()
		rate += shelter.heat()
		warmth_source = shelter.shelter_name()
	else:
		rate *= main.weather.cold_multiplier() * main.zone_cold(position)
	rate *= gear_cold_factor()
	if torch_time > 0.0:
		torch_time = maxf(torch_time - delta * (1.0 + main.weather.blizzard), 0.0)
		rate += 0.4
		if torch_time <= 0.0:
			say("Your torch has burned out.")
	# hail hurts out in the open; a tree's branches help a bit
	var hail_dmg: float = main.weather.hail_damage()
	if hail_dmg > 0.0 and not sheltered:
		if main.under_tree(position):
			hail_dmg *= 0.4
		take_damage(hail_dmg * delta, "hail", false)
		_hail_tick -= delta
		if _hail_tick <= 0.0:
			_hail_tick = 1.0
			_hurt = 0.15
			main.hud.flash_damage()
	var heat: float = main.get_fire_heat(position)
	if heat > 0.0:
		rate += 0.8 + FIRE_WARMTH * heat
		warmth_source = "fire"
	temp = clampf(temp + rate * delta, 0.0, 100.0)

	var hunger_rate := HUNGER_DRAIN + (HUNGER_SPRINT_EXTRA if is_sprinting else 0.0)
	hunger = clampf(hunger - hunger_rate * delta, 0.0, 100.0)

	var regen := 0.0
	if is_sprinting:
		regen = -ENERGY_SPRINT_COST
	elif is_moving:
		regen = 0.8
	else:
		regen = ENERGY_REST_REGEN + (ENERGY_FIRE_BONUS if heat > 0.0 else 0.0)
	if regen > 0.0 and hunger < 20.0:
		regen *= 0.5
	energy = clampf(energy + regen * delta, 0.0, 100.0)

	if temp <= 0.0:
		take_damage(FREEZE_DAMAGE * delta, "the cold", false)
	if hunger <= 0.0:
		take_damage(STARVE_DAMAGE * delta, "hunger", false)
	var pelted := hail_dmg > 0.0 and not sheltered
	if temp > 45.0 and hunger > 40.0 and health < 100.0 and not pelted:
		health = minf(health + HEAL_RATE * delta, 100.0)


func _find_target() -> void:
	target = null
	var best := INF
	for n in get_tree().get_nodes_in_group("interactable"):
		if not is_instance_valid(n) or n.is_queued_for_deletion():
			continue
		var d: float = position.distance_to(n.position) - n.interact_radius
		if d < INTERACT_RANGE and d < best and n.get_prompt(self) != "":
			best = d
			target = n


## How much of the cold gets through your clothes (1.0 = no fur gear).
func gear_cold_factor() -> float:
	var f := 1.0
	if gear["mittens"]:
		f *= 0.9
	if gear["boots"]:
		f *= 0.9
	if gear["coat"]:
		f *= 0.75
	return f


func _handle_actions() -> void:
	if main.hud.craft_open:
		main.hud.handle_craft_keys()
		return
	if target != null and _action_cd <= 0.0:
		if Input.is_action_just_pressed("interact"):
			_use_target()
		elif Input.is_action_pressed("interact") and target.can_interact(self):
			_use_target()  # holding E repeats, handy for snow blocks
	if Input.is_action_just_pressed("attack") and _attack_cd <= 0.0:
		_attack()
	if Input.is_action_just_pressed("eat"):
		_eat()
	if Input.is_action_just_pressed("cook"):
		_cook()
	if Input.is_action_just_pressed("sleep"):
		main.try_sleep()
	if Input.is_action_just_pressed("cycle_weapon"):
		_cycle_weapon()
	if Input.is_action_just_pressed("torch"):
		_light_torch()


func _use_target() -> void:
	_action_cd = 0.35
	if target.can_interact(self):
		target.interact(self)
	else:
		say(target.get_prompt(self))


func _attack() -> void:
	if weapon == "bow":
		_attack_cd = 0.7
		if inventory["arrows"] <= 0:
			say("You're out of arrows. Craft more (Tab).")
			return
		inventory["arrows"] -= 1
		var dir := facing
		# gentle auto-aim toward the nearest animal roughly in front of you
		var best_d := 320.0
		for n in get_tree().get_nodes_in_group("attackable"):
			var to: Vector2 = n.position - position
			if to.length() < best_d and absf(facing.angle_to(to)) < 0.5:
				best_d = to.length()
				dir = to.normalized()
		facing = dir
		main.audio.play("bow", null, -3.0)
		main.shoot_arrow(position + Vector2(0, -6) + dir * 8.0, dir)
		return
	_attack_cd = 0.45 if weapon == "hands" else 0.55
	_swing = 0.18
	energy = maxf(energy - 3.0, 0.0)
	main.audio.play("swing", null, -4.0)
	var reach := ATTACK_RANGE + (16.0 if weapon == "spear" else 0.0)
	var best = _nearest_attackable(reach)
	if best != null:
		facing = (best.position - position).normalized()
		best.take_hit(self, (1 + int(tools["spear"])) if weapon == "spear" else 1)


func _cycle_weapon() -> void:
	var options := ["hands"]
	for w in ["spear", "bow"]:
		if tools[w]:
			options.append(w)
	if options.size() == 1:
		say("You only have your hands. Craft a spear or bow (Tab).")
		return
	weapon = options[(options.find(weapon) + 1) % options.size()]
	main.hud.show_toast("Holding: %s" % weapon.capitalize())


func _light_torch() -> void:
	if torch_time > 0.0:
		say("Your torch is already burning (%ds left)." % int(torch_time))
		return
	if inventory["torch"] <= 0:
		say("You have no torches. Craft one (Tab): 3 sticks.")
		return
	inventory["torch"] -= 1
	torch_time = TORCH_BURN
	main.audio.play("ignite", null, -6.0)


func _nearest_attackable(reach: float):
	var best = null
	var bd := INF
	for n in get_tree().get_nodes_in_group("attackable"):
		if n.is_queued_for_deletion():
			continue
		var d: float = position.distance_to(n.position)
		if d < reach + n.hit_radius and d < bd:
			bd = d
			best = n
	return best


func _eat() -> void:
	if inventory["cooked_meat"] > 0:
		inventory["cooked_meat"] -= 1
		hunger = minf(hunger + 35.0, 100.0)
		temp = minf(temp + 6.0, 100.0)
		energy = minf(energy + 10.0, 100.0)
		say("You eat cooked meat. Warm and filling.")
		main.audio.play("eat")
	elif inventory["berries"] > 0:
		inventory["berries"] -= 1
		hunger = minf(hunger + 7.0, 100.0)
		say("You eat a handful of berries.")
		main.audio.play("eat")
	elif inventory["raw_meat"] > 0:
		inventory["raw_meat"] -= 1
		hunger = minf(hunger + 15.0, 100.0)
		main.audio.play("eat")
		take_damage(6.0, "food poisoning")
		say("You eat raw meat... your stomach churns. Cook it next time (C at a fire).")
	else:
		say("You have nothing to eat. Pick berries or hunt hares (Space).")


func _cook() -> void:
	if inventory["raw_meat"] <= 0:
		say("You have no raw meat. Hunt hares with Space.")
		return
	if main.get_nearby_fire(position, 60.0) == null:
		say("Stand next to a burning fire to cook.")
		return
	inventory["raw_meat"] -= 1
	inventory["cooked_meat"] += 1
	main.hud.show_toast("Cooked 1 meat")
	main.audio.play("ignite", null, -8.0)


# ---------- Called by other scripts ----------

func add_item(item: String, n: int) -> void:
	inventory[item] += n
	main.hud.show_toast("+%d %s" % [n, main.hud.item_name(item)])
	main.audio.play("pickup", null, -6.0, 0.05)


func spend_energy(amount: float) -> bool:
	if energy < amount:
		say("You're too exhausted. Stand still, rest by a fire, or sleep.")
		return false
	energy -= amount
	return true


func say(text: String) -> void:
	main.hud.show_message(text, 3.5)


func take_damage(amount: float, cause: String, flash: bool = true) -> void:
	if dead:
		return
	health -= amount
	if flash:
		_hurt = 0.3
		main.audio.play("hurt", null, -2.0)
		main.shake(5.0)
		main.hud.flash_damage()
	if health <= 0.0:
		health = 0.0
		dead = true
		queue_redraw()
		main.on_player_died(cause)


## Applies a night's sleep. Returns a line describing how it went.
func apply_sleep(had_fire: bool) -> String:
	energy = 100.0
	hunger = maxf(hunger - 25.0, 0.0)
	health = minf(health + 15.0, 100.0)
	if had_fire:
		temp = maxf(temp, 75.0)
		return "You slept warm beside the fire."
	temp -= 30.0
	if temp < 0.0:
		take_damage(-temp, "the cold")
		temp = 0.0
	return "You woke up shivering. A fire inside the igloo would help."


# ---------- Drawing ----------

func _draw() -> void:
	draw_set_transform(Vector2(0, 3), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 8, Color(0, 0, 0, 0.22))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	var tint := Color(1, 1, 1)
	if _hurt > 0.0:
		tint = Color(1, 0.45, 0.45)
	if dead:
		draw_set_transform(Vector2(0, -2), PI / 2, Vector2.ONE)
		draw_texture(TEX["down"][0], Vector2(-8, -9), Color(0.8, 0.8, 0.9))
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		return
	var view := "down"
	var flip := 1.0
	if absf(facing.x) > absf(facing.y):
		view = "side"
		flip = -1.0 if facing.x < 0.0 else 1.0
	elif facing.y < 0.0:
		view = "up"
	var frame := 0
	if is_moving:
		if view == "side":
			frame = [1, 0][int(_walk) % 2]
		else:
			frame = [1, 0, 2, 0][int(_walk) % 4]
	draw_set_transform(Vector2.ZERO, 0, Vector2(flip, 1))
	var behind := view == "up"
	if behind:
		_draw_held()
	draw_texture(TEX[view][frame], Vector2(-8, -15), tint)
	if not behind:
		_draw_held()
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if _swing > 0.0:
		var a := facing.angle()
		draw_arc(facing * 10.0 + Vector2(0, -5), 12, a - 1.0, a + 1.0, 10, Color(1, 1, 1, 0.9), 2.0)


## Draws the weapon and torch in your hands (in the sprite's own flipped space).
func _draw_held() -> void:
	var hand := Vector2(7, -5)
	if weapon == "spear":
		draw_line(hand + Vector2(0, 6), hand + Vector2(0, -16), Color(0.5, 0.34, 0.18), 1.5)
		draw_colored_polygon(PackedVector2Array([hand + Vector2(-2, -16), hand + Vector2(0, -21), hand + Vector2(2, -16)]), Color(0.25, 0.25, 0.32))
	elif weapon == "bow":
		draw_arc(hand + Vector2(-2, -3), 8, -1.3, 1.3, 8, Color(0.5, 0.34, 0.18), 1.5)
		draw_line(hand + Vector2(-2, -3) + Vector2.from_angle(-1.3) * 8, hand + Vector2(-2, -3) + Vector2.from_angle(1.3) * 8, Color(0.9, 0.9, 0.85), 0.8)
	if torch_time > 0.0:
		var t := Vector2(-7, -4)
		draw_line(t + Vector2(0, 5), t + Vector2(0, -5), Color(0.45, 0.3, 0.15), 2.0)
		var f := sin(Time.get_ticks_msec() / 70.0) * 0.8
		draw_colored_polygon(PackedVector2Array([t + Vector2(-2.5, -5), t + Vector2(f, -12), t + Vector2(2.5, -5)]), Color(1, 0.5, 0.12))
		draw_colored_polygon(PackedVector2Array([t + Vector2(-1.2, -5), t + Vector2(-f * 0.5, -9), t + Vector2(1.2, -5)]), Color(1, 0.88, 0.4))
