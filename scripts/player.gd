extends Node2D
## The player: movement, the four survival stats, gathering, eating, cooking and fighting.

# ---------- Tuning (change these numbers to balance the game) ----------
const WALK_SPEED := 150.0
const SPRINT_SPEED := 235.0
const ACCEL := 1400.0              # how fast you reach full speed (px/s per second)
const FRICTION := 1800.0           # how fast you stop when you let go
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
const FREEZE_DAMAGE := 5.0         # health per second when body temp is 0
const STARVE_DAMAGE := 2.4         # health per second when hunger is 0
const HEAL_RATE := 1.2             # health per second when warm and fed

const TEX := {
	"down": [preload("res://art/player_down_0.png"), preload("res://art/player_down_1.png"), preload("res://art/player_down_2.png")],
	"up": [preload("res://art/player_up_0.png"), preload("res://art/player_up_1.png"), preload("res://art/player_up_2.png")],
	"side": [preload("res://art/player_side_0.png"), preload("res://art/player_side_1.png")],
}

var main

var temp := 85.0      # body temperature, 0 = freezing
var hunger := 90.0    # 100 = full, 0 = starving
var energy := 100.0
var health := 200.0
var max_health := 200.0
var armor := 0               # armor piece worn: 0 none, 1 bone, 2 iron, 3 frost king

## Character level (1 to 30) from XP, mostly from kills. Each level: +14 HP, +1 damage,
## +0.3 armor, +2% attack speed.
var level := 1
var xp := 0
const MAX_LEVEL := 30

## Skills level up with XP as you play (1 to 10).
var skills := {
	"survival": {"level": 1, "xp": 0},    # time spent out in the cold: lose less body heat
	"gathering": {"level": 1, "xp": 0},   # chopping and gathering: use less energy
}
const MAX_SKILL := 10
var _cold_xp := 0.0

var inventory := {
	"sticks": 0, "flint": 0, "stone": 0, "snow_block": 0,
	"berries": 0, "raw_meat": 0, "cooked_meat": 0,
	"logs": 0, "arrows": 0, "torch": 0, "hide": 0, "bone": 0, "iron": 0,
	"raw_fish": 0, "cooked_fish": 0, "jerky": 0, "radio_part": 0, "white_fur": 0, "steel": 0,
	"alpha_fang": 0, "great_claw": 0, "king_pelt": 0,
}
var tools := {"axe": 0, "spear": 0, "bow": 0, "rod": 0}   # 0 = don't have it, 1 stone, 2 bone, 3 iron
var gear := {"mittens": false, "boots": false, "coat": false, "polar_coat": false}
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
var _swing := 0.0
const SWING_TIME := 0.16
var velocity := Vector2.ZERO
var _aim_lock := 0.0        # after an attack you keep facing the way you struck
var _swing_dir := Vector2.RIGHT
var order_target = null     # the animal you've been told to attack
var move_target = null      # a spot you clicked to walk to
var _atk_cd := 0.0          # time until you can start another attack
var _swing_t := -1.0        # time into the current swing, -1 when not swinging
var _swing_target = null
var _hurt := 0.0
var _walk := 0.0
var _light: PointLight2D
var _step_dist := 0.0
var _step_left := false
var _breath := 0.0
var _hail_tick := 0.0
## Weapons: damage range by tier (index 0 = fists), seconds between attacks,
## the damage point (when in the swing the blow lands) and reach.
const WEAPONS := {
	"hands": {"dmg": [[4, 6]], "cooldown": 1.7, "point": 0.35, "range": 34.0},
	"axe": {"dmg": [[4, 6], [9, 12], [13, 16], [18, 23], [27, 33]], "cooldown": 1.6, "point": 0.35, "range": 36.0},
	"spear": {"dmg": [[4, 6], [10, 13], [12, 15], [19, 24], [27, 33]], "cooldown": 1.8, "point": 0.4, "range": 58.0},
	"bow": {"dmg": [[10, 14]], "cooldown": 2.0, "point": 0.45, "range": 260.0},
}
## Armor points: worn armor piece, plus coats.
const ARMOR_POINTS := [0.0, 4.0, 7.0, 10.0]


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
	main.update_camera(delta)
	if dead or main.game_over or main.sleeping:
		return
	_action_cd = maxf(_action_cd - delta, 0.0)
	_swing = maxf(_swing - delta, 0.0)
	_aim_lock = maxf(_aim_lock - delta, 0.0)
	_hurt = maxf(_hurt - delta, 0.0)
	_move(delta)
	_update_combat(delta)
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
	if dir.length() > 0.1:
		order_target = null   # steering yourself cancels any order
		move_target = null
		_cancel_swing()
	elif order_target != null:
		if not is_instance_valid(order_target) or order_target.is_queued_for_deletion():
			order_target = null
		else:
			var to_t: Vector2 = order_target.position - position
			if to_t.length() > attack_range() + order_target.hit_radius - 4.0:
				dir = to_t.normalized()
	elif move_target != null:
		var to_m: Vector2 = move_target - position
		if to_m.length() < 6.0:
			move_target = null
		else:
			dir = to_m.normalized()
	if _swing_t >= 0.0:
		dir = Vector2.ZERO    # you stand still while swinging
	var wants_move := dir.length() > 0.1
	is_sprinting = wants_move and Input.is_action_pressed("sprint") and energy > 1.0
	var speed := SPRINT_SPEED if is_sprinting else WALK_SPEED
	if temp < 25.0:
		speed *= COLD_SLOW
	if energy < 10.0 and not is_sprinting:
		speed *= 0.85
	speed *= main.weather.speed_multiplier()
	if gear["boots"]:
		speed *= 1.08
	if armor >= 2:
		speed *= 0.95
	var want := dir.limit_length(1.0) * speed
	# snappy: accelerate hard toward where you want to go, brake hard when you stop
	var rate := ACCEL if wants_move else FRICTION
	if wants_move and velocity.dot(want) < 0.0:
		rate = FRICTION * 1.5   # turning around is instant-ish
	velocity = velocity.move_toward(want, rate * delta)
	if wants_move and _aim_lock <= 0.0:
		facing = dir.normalized()
	position += velocity * delta
	position.x = clampf(position.x, 16.0, main.world_size.x - 16.0)
	position.y = clampf(position.y, 16.0, main.shore_y + 60.0)
	var spd := velocity.length()
	is_moving = spd > 20.0
	if is_moving:
		_walk += delta * spd * 0.055
		_step_dist += spd * delta
		if _step_dist > 22.0:
			_step_dist = 0.0
			_step_left = not _step_left
			var side := velocity.normalized().orthogonal() * (3.0 if _step_left else -3.0)
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
	if rate < 0.0:
		rate *= 1.0 - 0.04 * (skill("survival") - 1)
		# braving the cold trains Survival, faster in harsher places
		_cold_xp += delta * main.zone_cold(position) * (1.0 + main.get_night_factor())
		if _cold_xp >= 6.0:
			_cold_xp = 0.0
			add_xp("survival", 1)
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
		take_damage(hail_dmg * 2.0 * delta, "hail", false)
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
	if temp > 45.0 and hunger > 40.0 and health < max_health and not pelted:
		health = minf(health + HEAL_RATE * delta, max_health)


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
	if gear["polar_coat"]:
		f *= 0.6
	elif gear["coat"]:
		f *= 0.75
	return f


func _handle_actions() -> void:
	if main.hud.craft_open:
		main.hud.handle_craft_keys()
		return
	_update_fishing(get_process_delta_time())
	if target == null and Input.is_action_just_pressed("interact") and (fishing or can_fish()):
		_fish_action()
	elif target != null and _action_cd <= 0.0:
		if Input.is_action_just_pressed("interact"):
			_use_target()
		elif Input.is_action_pressed("interact") and target.can_interact(self):
			_use_target()  # holding E repeats, handy for snow blocks
	if Input.is_action_just_pressed("attack"):
		var near = _nearest_attackable(220.0)
		if near != null:
			attack_order(near)
		else:
			say("Nothing to attack nearby.")
	if not main.hud.mouse_over_ui():
		var m := get_global_mouse_position()
		if Input.is_action_just_pressed("attack_mouse"):
			var a = animal_at(m)
			if a != null:
				attack_order(a)
		elif Input.is_action_just_pressed("order"):
			var a = animal_at(m)
			if a != null:
				attack_order(a)
			else:
				order_target = null
				_cancel_swing()
				move_target = m
				main.click_marker(m)
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


## Attack. With a direction (mouse click) you swing or shoot exactly that way;
## without one (Space) you aim at the nearest animal in front of you.
# ---------- Combat (Warcraft 3 style: orders, auto-attack, damage point) ----------

func attack_order(n) -> void:
	order_target = n
	move_target = null


## The animal under (or right next to) a world point, if any.
func animal_at(m: Vector2):
	var best = null
	var bd := INF
	for n in get_tree().get_nodes_in_group("attackable"):
		if n.is_queued_for_deletion():
			continue
		var d: float = (n.position + Vector2(0, -6)).distance_to(m)
		if d < n.hit_radius + 14.0 and d < bd:
			bd = d
			best = n
	return best


func weapon_stats() -> Dictionary:
	return WEAPONS.get(weapon, WEAPONS["hands"])


func attack_range() -> float:
	return float(weapon_stats()["range"])


func damage_range() -> Array:
	var w := weapon_stats()
	var tiers: Array = w["dmg"]
	var tier := 0
	if weapon == "axe" or weapon == "spear":
		tier = clampi(int(tools[weapon]), 0, tiers.size() - 1)
	var r: Array = tiers[tier]
	return [int(r[0]) + level - 1, int(r[1]) + level - 1]


func attack_cooldown() -> float:
	return float(weapon_stats()["cooldown"]) / (1.0 + 0.02 * (level - 1))


func armor_value() -> float:
	var a: float = ARMOR_POINTS[armor] + 0.3 * (level - 1)
	if gear["polar_coat"]:
		a += 3.0
	elif gear["coat"]:
		a += 2.0
	return a


## Warcraft 3's armor formula: share of damage blocked.
static func armor_reduction(a: float) -> float:
	return 0.06 * a / (1.0 + 0.06 * a)


func _cancel_swing() -> void:
	_swing_t = -1.0
	_swing_target = null


func _update_combat(delta: float) -> void:
	_atk_cd = maxf(_atk_cd - delta, 0.0)
	if _swing_t >= 0.0:
		_swing_t += delta
		if _swing_t >= float(weapon_stats()["point"]):
			_land_blow()
			_swing_t = -1.0
		return
	if order_target == null or not is_instance_valid(order_target) or order_target.is_queued_for_deletion():
		order_target = null
		return
	var to_t: Vector2 = order_target.position - position
	if to_t.length() <= attack_range() + order_target.hit_radius and _atk_cd <= 0.0:
		if weapon == "bow" and inventory["arrows"] <= 0:
			say("You're out of arrows. Craft more (Tab) or switch weapons (F).")
			order_target = null
			return
		# start a swing; the blow lands at the damage point unless you move first
		_swing_t = 0.0
		_swing_target = order_target
		_atk_cd = attack_cooldown()
		facing = to_t.normalized()
		_swing_dir = facing
		_aim_lock = attack_cooldown()
		if weapon != "bow":
			main.audio.play("swing", null, -8.0, 0.1, 0.9)


func _land_blow() -> void:
	var t = _swing_target
	if t == null or not is_instance_valid(t) or t.is_queued_for_deletion():
		return
	var dr := damage_range()
	var dmg := float(randi_range(dr[0], dr[1]))
	var to_t: Vector2 = t.position - position
	if weapon == "bow":
		inventory["arrows"] -= 1
		main.audio.play("bow", null, -3.0)
		main.shoot_arrow(position + Vector2(0, -6) + to_t.normalized() * 8.0, to_t.normalized(), dmg)
		return
	if to_t.length() > attack_range() + t.hit_radius + 16.0:
		return   # it got away before the blow landed
	_swing = SWING_TIME
	main.audio.play("hit", null, -2.0, 0.1)
	t.take_hit(self, dmg)


func is_dodging() -> bool:
	return false


func _cycle_weapon() -> void:
	var options := ["hands"]
	for w in ["axe", "spear", "bow"]:
		if tools[w]:
			options.append(w)
	if options.size() == 1:
		say("You only have your fists. Craft an axe, spear or bow (Tab).")
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


## Food you can eat: item, hunger, warmth, energy, health, message. Best first.
const FOODS := [
	["cooked_meat", 35.0, 6.0, 10.0, 0.0, "You eat cooked meat. Warm and filling."],
	["cooked_fish", 30.0, 4.0, 8.0, 0.0, "You eat grilled fish. Delicious."],
	["jerky", 22.0, 0.0, 6.0, 0.0, "You chew on some jerky."],
	["berries", 7.0, 0.0, 0.0, 0.0, "You eat a handful of berries."],
	["raw_fish", 10.0, 0.0, 0.0, -4.0, "You eat raw fish... not great. Cook it next time (C at a fire)."],
	["raw_meat", 15.0, 0.0, 0.0, -6.0, "You eat raw meat... your stomach churns. Cook it next time (C at a fire)."],
]


func _eat() -> void:
	for f in FOODS:
		if inventory[f[0]] > 0:
			inventory[f[0]] -= 1
			hunger = minf(hunger + f[1], 100.0)
			temp = minf(temp + f[2], 100.0)
			energy = minf(energy + f[3], 100.0)
			main.audio.play("eat")
			if f[4] < 0.0:
				take_damage(-f[4], "food poisoning")
			say(f[5])
			return
	say("You have nothing to eat. Pick berries, hunt hares (Space) or fish through the ice.")


func _cook() -> void:
	var raw := ""
	for item in ["raw_meat", "raw_fish"]:
		if inventory[item] > 0:
			raw = item
			break
	if raw == "":
		say("You have nothing raw to cook. Hunt hares with Space, or fish.")
		return
	if main.get_nearby_fire(position, 60.0) == null:
		say("Stand next to a burning fire to cook.")
		return
	inventory[raw] -= 1
	var cooked := "cooked_meat" if raw == "raw_meat" else "cooked_fish"
	inventory[cooked] += 1
	main.hud.show_toast("Cooked 1 %s" % ("meat" if raw == "raw_meat" else "fish"))
	main.audio.play("ignite", null, -8.0)


# ---------- Fishing ----------

var fishing := false
var _fish_wait := 0.0
var _bite := 0.0


func can_fish() -> bool:
	return int(tools["rod"]) > 0 and main.on_ice(position)


func fishing_prompt() -> String:
	if fishing:
		return "BITE! Press E!" if _bite > 0.0 else "Fishing... wait for a bite (move to stop)"
	if can_fish():
		return "[E] Fish through the ice"
	return ""


func _update_fishing(delta: float) -> void:
	if not fishing:
		return
	if is_moving or not can_fish():
		fishing = false
		return
	if _bite > 0.0:
		_bite -= delta
		if _bite <= 0.0:
			say("It got away...")
			_fish_wait = randf_range(4.0, 9.0)
	else:
		_fish_wait -= delta
		if _fish_wait <= 0.0:
			_bite = 1.3
			main.audio.play("squeak", null, -8.0, 0.0, 0.5)
			main.puff(position + facing * 16.0, Color(0.7, 0.85, 1.0), 6, 30.0)


func _fish_action() -> void:
	if not fishing:
		fishing = true
		_bite = 0.0
		_fish_wait = randf_range(4.0, 9.0)
		main.audio.play("gather", null, -6.0)
		say("You cut a hole in the ice and drop your line.")
	elif _bite > 0.0:
		_bite = 0.0
		_fish_wait = randf_range(4.0, 9.0)
		add_item("raw_fish", 2 if randf() < 0.25 else 1)
		main.puff(position + facing * 16.0, Color(0.8, 0.9, 1.0), 10, 50.0)


# ---------- Called by other scripts ----------

func add_item(item: String, n: int) -> void:
	inventory[item] += n
	main.hud.show_toast("+%d %s" % [n, main.hud.item_name(item)])
	main.audio.play("pickup", null, -6.0, 0.05)


func spend_energy(amount: float) -> bool:
	amount *= 1.0 - 0.06 * (skill("gathering") - 1)
	add_xp("gathering", 2)
	if energy < amount:
		say("You're too exhausted. Stand still, rest by a fire, or sleep.")
		return false
	energy -= amount
	return true


func say(text: String) -> void:
	main.hud.show_message(text, 3.5)


## Called when an animal's attack connects.
func take_damage(amount: float, cause: String, flash: bool = true, is_attack: bool = false) -> void:
	if dead:
		return
	if is_attack:
		amount *= 1.0 - armor_reduction(armor_value())
		main.float_text(position + Vector2(0, -26), str(int(round(amount))), Color(1, 0.35, 0.3))
	health -= amount
	if flash:
		_hurt = 0.3
		main.audio.play("hurt", null, -2.0)
		main.shake(3.0)
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
	health = minf(health + 40.0, max_health)
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
	var wind := Vector2.ZERO
	if _swing_t >= 0.0:
		# lean back while winding up the blow
		wind = Vector2(-2.0 * minf(_swing_t / float(weapon_stats()["point"]), 1.0), 0) if view == "side" else Vector2.ZERO
	draw_texture(TEX[view][frame], Vector2(-8, -15) + wind, tint)
	if not behind:
		_draw_held()
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if fishing:
		var bob := facing * 18.0 + Vector2(0, 2)
		draw_set_transform(bob, 0, Vector2(1, 0.45))
		draw_circle(Vector2.ZERO, 6, Color(0.1, 0.2, 0.3, 0.8))
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		var dip := 2.0 if _bite > 0.0 else 0.0
		draw_line(Vector2(6, -8), bob + Vector2(0, -1 + dip), Color(0.9, 0.9, 0.9, 0.8), 0.6)
		draw_circle(bob + Vector2(0, -1 + dip), 1.6, Color(1, 0.3, 0.2))
	if _swing > 0.0:
		# a bold crescent that sweeps across in the swing direction
		var k := 1.0 - _swing / SWING_TIME
		var a := _swing_dir.angle()
		var r := 26.0 if weapon == "spear" else 20.0
		var c := Vector2(0, -6)
		var from := a - 1.1 + 2.2 * maxf(k - 0.35, 0.0)
		var to := a - 1.1 + 2.2 * minf(k + 0.45, 1.0)
		var col := Color(1, 1, 1, 0.95 * (1.0 - k * 0.6))
		draw_arc(c, r, from, to, 14, col, 5.0)
		draw_arc(c, r - 6.0, from + 0.15, to - 0.1, 12, Color(0.8, 0.9, 1.0, 0.5 * (1.0 - k)), 3.0)


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



# ---------- Skills ----------

func skill(name: String) -> int:
	return int(skills[name]["level"])


func xp_needed(level: int) -> int:
	return int(40.0 * pow(level, 1.5))


func xp_to_next() -> int:
	return 80 * level


## Character XP, mostly from kills.
func gain_xp(amount: int) -> void:
	if level >= MAX_LEVEL or amount <= 0:
		return
	xp += amount
	main.float_text(position + Vector2(0, -34), "+%d xp" % amount, Color(0.75, 0.6, 1.0))
	while level < MAX_LEVEL and xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		max_health = 200.0 + 14.0 * (level - 1)
		health = minf(health + 40.0, max_health)
		main.audio.play("chime", null, -4.0, 0.0)
		main.puff(position + Vector2(0, -10), Color(1, 0.9, 0.4), 20, 80.0)
		main.hud.show_message("Level %d! Max health %d, damage +%d, armor +%.1f." % [level, int(max_health), level - 1, 0.3 * (level - 1)], 5.0)


func add_xp(name: String, amount: int) -> void:
	if not skills.has(name):
		return
	if amount <= 0 or skill(name) >= MAX_SKILL:
		return
	var sk: Dictionary = skills[name]
	sk["xp"] = int(sk["xp"]) + amount
	while int(sk["level"]) < MAX_SKILL and int(sk["xp"]) >= xp_needed(int(sk["level"])):
		sk["xp"] = int(sk["xp"]) - xp_needed(int(sk["level"]))
		sk["level"] = int(sk["level"]) + 1
		_on_level_up(name, int(sk["level"]))


func _on_level_up(name: String, level: int) -> void:
	var what := ""
	match name:
		"survival":
			what = "you lose %d%% less body heat" % (4 * (level - 1))
		"gathering":
			what = "gathering takes %d%% less energy" % (6 * (level - 1))
	main.audio.play("chime", null, -6.0, 0.0)
	main.hud.show_message("%s is now level %d: %s." % [name.capitalize(), level, what], 5.0)
