extends Node2D
## A campfire: warms a radius, lights the dark, scares wolves, cooks meat. Burns out unless fed.

# ---------- Tuning ----------
const START_FUEL := 60.0     # seconds of burn when first lit
const STICK_FUEL := 30.0     # seconds added per stick
const MAX_FUEL := 180.0
const HEAT_RADIUS := 150.0
const FEAR_RADIUS := 160.0   # wolves won't come closer than this while it burns

var main
var fuel := START_FUEL
var interact_radius := 12.0
var _light: PointLight2D
var _flicker := 0.0


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("fire")
	_light = PointLight2D.new()
	_light.texture = main.make_light_texture()
	_light.color = Color(1.0, 0.68, 0.38)
	add_child(_light)


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
		main.hud.show_toast("Fire: %ds" % int(fuel))
	else:
		if inv["flint"] < 1 or inv["stone"] < 1:
			player.say("Relighting needs 1 stick, 1 flint and a stone to strike it.")
			return
		inv["sticks"] -= 1
		inv["flint"] -= 1
		fuel = STICK_FUEL * 1.5
		player.say("The fire crackles back to life.")


func _draw() -> void:
	for i in 7:
		var a := TAU * i / 7.0
		draw_circle(Vector2(cos(a) * 11.0, sin(a) * 6.0 + 2.0), 3.0, Color(0.45, 0.45, 0.48))
	draw_line(Vector2(-8, 4), Vector2(8, -1), Color(0.4, 0.25, 0.12), 3.5)
	draw_line(Vector2(-8, -1), Vector2(8, 4), Color(0.35, 0.22, 0.1), 3.5)
	if is_lit():
		var s := 0.6 + 0.4 * _strength()
		var f := sin(_flicker) * 1.5
		draw_colored_polygon(PackedVector2Array([Vector2(-7 * s, 2), Vector2(f, -20 * s), Vector2(7 * s, 2)]), Color(1, 0.45, 0.1))
		draw_colored_polygon(PackedVector2Array([Vector2(-4 * s, 2), Vector2(-f * 0.7, -12 * s), Vector2(4 * s, 2)]), Color(1, 0.88, 0.35))
	else:
		draw_circle(Vector2(0, 1), 5, Color(0.3, 0.3, 0.32))
