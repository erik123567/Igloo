extends Node2D
## A campfire: warms a radius, lights the dark, scares wolves, cooks meat. Burns out unless fed.

# ---------- Tuning ----------
const START_FUEL := 60.0     # seconds of burn when first lit
const STICK_FUEL := 30.0     # seconds added per stick
const MAX_FUEL := 180.0
const HEAT_RADIUS := 150.0
const FEAR_RADIUS := 160.0   # wolves won't come closer than this while it burns

const TEX_BASE := preload("res://art/fire_base.png")
const TEX_ASH := preload("res://art/fire_ash.png")
const TEX_FLAME := [preload("res://art/flame_0.png"), preload("res://art/flame_1.png"), preload("res://art/flame_2.png")]

var main
var fuel := START_FUEL
var interact_radius := 12.0
var _light: PointLight2D
var _flicker := 0.0
var _sparks: CPUParticles2D
var _smoke: CPUParticles2D


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("fire")
	_light = PointLight2D.new()
	_light.texture = main.make_light_texture()
	_light.color = Color(1.0, 0.68, 0.38)
	add_child(_light)
	_sparks = CPUParticles2D.new()
	_sparks.amount = 10
	_sparks.lifetime = 1.0
	_sparks.position = Vector2(0, -8)
	_sparks.direction = Vector2(0, -1)
	_sparks.spread = 25.0
	_sparks.gravity = Vector2(0, -20)
	_sparks.initial_velocity_min = 20.0
	_sparks.initial_velocity_max = 45.0
	_sparks.color = Color(1.0, 0.7, 0.25)
	_sparks.z_index = 10
	add_child(_sparks)
	_smoke = CPUParticles2D.new()
	_smoke.amount = 8
	_smoke.lifetime = 2.5
	_smoke.position = Vector2(0, -18)
	_smoke.direction = Vector2(0.2, -1)
	_smoke.spread = 12.0
	_smoke.gravity = Vector2(4, -6)
	_smoke.initial_velocity_min = 10.0
	_smoke.initial_velocity_max = 18.0
	_smoke.scale_amount_min = 3.0
	_smoke.scale_amount_max = 5.0
	_smoke.color = Color(0.6, 0.62, 0.68, 0.35)
	_smoke.z_index = 10
	add_child(_smoke)


func fear_radius() -> float:
	return FEAR_RADIUS


func is_lit() -> bool:
	return fuel > 0.0


func _strength() -> float:
	return minf(fuel / 60.0, 1.0)


func heat_at(pos: Vector2) -> float:
	if not is_lit():
		return 0.0
	var r := HEAT_RADIUS * (0.6 + 0.4 * _strength())
	var d := pos.distance_to(position)
	if d >= r:
		return 0.0
	return 1.0 - d / r


func burn(seconds: float) -> void:
	fuel = maxf(fuel - seconds, 0.0)


func _process(delta: float) -> void:
	if main.game_over or main.sleeping:
		return
	if fuel > 0.0:
		fuel = maxf(fuel - delta, 0.0)
		if fuel <= 0.0 and main.player.position.distance_to(position) < 400.0:
			main.hud.show_message("Your fire has burned out.", 3.0)
	_flicker += delta * 9.0
	_light.visible = is_lit()
	_sparks.emitting = is_lit()
	_smoke.emitting = is_lit()
	var nf: float = main.get_night_factor()
	_light.energy = (0.9 + 0.4 * _strength() + sin(_flicker) * 0.08 + sin(_flicker * 2.3) * 0.05) * (0.25 + 0.75 * nf)
	_light.texture_scale = 1.6 + 1.0 * _strength()
	queue_redraw()


func get_prompt(_player) -> String:
	if is_lit():
		return "[E] Add a stick (fire: %ds)    [C] Cook meat" % int(fuel)
	return "[E] Relight the fire (1 stick + 1 flint, needs a stone)"


func can_interact(_player) -> bool:
	return true


func interact(player) -> void:
	var inv: Dictionary = player.inventory
	if inv["sticks"] <= 0:
		player.say("You need sticks to feed the fire.")
		return
	if is_lit():
		if fuel >= MAX_FUEL - 5.0:
			player.say("The fire is already roaring.")
			return
		inv["sticks"] -= 1
		fuel = minf(fuel + STICK_FUEL, MAX_FUEL)
		main.puff(position + Vector2(0, -6), Color(1.0, 0.75, 0.3), 8, 60.0)
		main.hud.show_toast("Fire: %ds" % int(fuel))
	else:
		if inv["flint"] < 1 or inv["stone"] < 1:
			player.say("Relighting needs 1 stick, 1 flint and a stone to strike it.")
			return
		inv["sticks"] -= 1
		inv["flint"] -= 1
		fuel = STICK_FUEL * 1.5
		main.audio.play("ignite", position)
		player.say("The fire crackles back to life.")


func _draw() -> void:
	if not is_lit():
		draw_texture(TEX_ASH, Vector2(-14, -10))
		return
	draw_texture(TEX_BASE, Vector2(-14, -10))
	var s := 0.55 + 0.45 * _strength()
	var flame: Texture2D = TEX_FLAME[int(_flicker * 0.9) % 3]
	draw_texture_rect(flame, Rect2(-7.0 * s, -4.0 - 20.0 * s, 14.0 * s, 20.0 * s), false)
