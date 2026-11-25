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

var main

var temp := 85.0      # body temperature, 0 = freezing
var hunger := 90.0    # 100 = full, 0 = starving
var energy := 100.0
var health := 100.0

var inventory := {
	"sticks": 0, "flint": 0, "stone": 0, "snow_block": 0,
	"berries": 0, "raw_meat": 0, "cooked_meat": 0,
}

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
	_light.energy = 0.55 * main.get_night_factor()
	queue_redraw()


func _move(delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	is_moving = dir.length() > 0.1
	is_sprinting = is_moving and Input.is_action_pressed("sprint") and energy > 1.0
	var speed := SPRINT_SPEED if is_sprinting else WALK_SPEED
	if temp < 25.0:
		speed *= COLD_SLOW
	if energy < 10.0 and not is_sprinting:
		speed *= 0.85
	if is_moving:
		facing = dir.normalized()
		position += dir * speed * delta
		position.x = clampf(position.x, 16.0, main.world_size.x - 16.0)
		position.y = clampf(position.y, 16.0, main.shore_y + 60.0)
		_walk += delta * speed * 0.08


func _update_stats(delta: float) -> void:
	var nf: float = main.get_night_factor()
	var rate := -lerpf(TEMP_DRAIN_DAY, TEMP_DRAIN_NIGHT, nf)
	warmth_source = ""
	if main.get_igloo_at(position) != null:
		rate *= IGLOO_INSULATION
		warmth_source = "igloo"
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
	if temp > 45.0 and hunger > 40.0 and health < 100.0:
		health = minf(health + HEAL_RATE * delta, 100.0)


func _find_target() -> void:
	target = null
	var best := INF
	for n in get_tree().get_nodes_in_group("interactable"):
		if not is_instance_valid(n) or n.is_queued_for_deletion():
			continue
		var d: float = position.distance_to(n.position) - n.interact_radius
		if d < INTERACT_RANGE and d < best:
			best = d
			target = n


func _handle_actions() -> void:
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
	if main.hud.craft_open:
		if Input.is_action_just_pressed("craft_1"):
			main.try_craft(1)
		elif Input.is_action_just_pressed("craft_2"):
			main.try_craft(2)


func _use_target() -> void:
	_action_cd = 0.35
	if target.can_interact(self):
		target.interact(self)
	else:
		say(target.get_prompt(self))


func _attack() -> void:
	_attack_cd = 0.45
	_swing = 0.18
	energy = maxf(energy - 3.0, 0.0)
	var best = _nearest_attackable(ATTACK_RANGE)
	if best != null:
		facing = (best.position - position).normalized()
		best.take_hit(self)


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
	elif inventory["berries"] > 0:
		inventory["berries"] -= 1
		hunger = minf(hunger + 7.0, 100.0)
		say("You eat a handful of berries.")
	elif inventory["raw_meat"] > 0:
		inventory["raw_meat"] -= 1
		hunger = minf(hunger + 15.0, 100.0)
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


# ---------- Called by other scripts ----------

func add_item(item: String, n: int) -> void:
	inventory[item] += n
	main.hud.show_toast("+%d %s" % [n, main.hud.item_name(item)])


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


# ---------- Drawing (placeholder art) ----------

func _draw() -> void:
	draw_set_transform(Vector2(0, 11), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 11, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if dead:
		draw_circle(Vector2(0, 4), 10, Color(0.5, 0.25, 0.2))
		return
	var bob := sin(_walk) * 1.8 if is_moving else 0.0
	var parka := Color(0.85, 0.3, 0.2)
	if _hurt > 0.0:
		parka = Color(1, 0.7, 0.7)
	# boots
	draw_circle(Vector2(-4, 9 + bob), 3.5, Color(0.25, 0.18, 0.12))
	draw_circle(Vector2(4, 9 - bob), 3.5, Color(0.25, 0.18, 0.12))
	# parka
	draw_circle(Vector2(0, 2), 9, parka)
	# mittens
	draw_circle(Vector2(-9, 3 - bob * 0.5), 3, Color(0.3, 0.3, 0.55))
	draw_circle(Vector2(9, 3 + bob * 0.5), 3, Color(0.3, 0.3, 0.55))
	# fur hood and face
	draw_circle(Vector2(0, -8), 7.5, Color(0.55, 0.4, 0.28))
	if facing.y > -0.5:
		draw_circle(Vector2(0, -8) + facing * 2.5, 4.5, Color(0.95, 0.8, 0.65))
	# attack swing
	if _swing > 0.0:
		var a := facing.angle()
		draw_arc(facing * 12.0, 13, a - 1.0, a + 1.0, 10, Color(1, 1, 1, 0.9), 2.5)
