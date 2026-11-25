extends Node2D
## Your home base: a log cabin you build up in stages by hauling logs and stones back.
## Floor -> walls (cuts the wind) -> roof and door (full shelter, safe from animals and storms)
## -> stove (burns logs to keep the cabin warm all night).

const TEX_FLOOR := preload("res://art/cabin_floor.png")
const TEX_WALLS := preload("res://art/cabin_walls.png")
const TEX_ROOF := preload("res://art/cabin_roof.png")
const TEX_STOVE := preload("res://art/cabin_stove.png")
const TEX_LIT := preload("res://art/cabin_lit.png")

const STAGES := [
	{"name": "floor", "cost": {"logs": 6}},
	{"name": "walls", "cost": {"logs": 10}},
	{"name": "roof and door", "cost": {"logs": 8, "stone": 4}},
	{"name": "stove", "cost": {"stone": 6, "logs": 2}},
]
const LOG_FUEL := 150.0      # seconds of stove heat per log
const MAX_FUEL := 900.0
const STOVE_HEAT := 3.0

var main
var level := 0
var paid := {}
var stove_fuel := 0.0
var interact_radius := 40.0
var _light: PointLight2D
var _smoke: CPUParticles2D


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("cabin")
	_light = PointLight2D.new()
	_light.texture = main.make_light_texture()
	_light.color = Color(1.0, 0.7, 0.4)
	_light.texture_scale = 1.6
	_light.position = Vector2(0, -20)
	_light.energy = 0.0
	add_child(_light)
	_smoke = CPUParticles2D.new()
	_smoke.amount = 10
	_smoke.lifetime = 3.0
	_smoke.position = Vector2(24, -74)
	_smoke.direction = Vector2(0.3, -1)
	_smoke.spread = 10.0
	_smoke.gravity = Vector2(6, -4)
	_smoke.initial_velocity_min = 10.0
	_smoke.initial_velocity_max = 16.0
	_smoke.scale_amount_min = 3.0
	_smoke.scale_amount_max = 6.0
	_smoke.color = Color(0.7, 0.7, 0.75, 0.4)
	_smoke.z_index = 10
	_smoke.emitting = false
	add_child(_smoke)


# ---------- Shelter interface (shared with the igloo) ----------

func shelter_name() -> String:
	return "cabin"


func is_shelter_ready() -> bool:
	return level >= 2


func storm_proof() -> bool:
	return level >= 3


func insulation() -> float:
	return 0.12 if level >= 3 else 0.5


func heat() -> float:
	return STOVE_HEAT if stove_fuel > 0.0 else 0.0


func contains(pos: Vector2) -> bool:
	var d := pos - (position + Vector2(0, -20))
	return absf(d.x) < 44.0 and absf(d.y) < 21.0


## True if animals can't step here (the finished cabin).
func blocks(pos: Vector2) -> bool:
	if level < 3:
		return false
	var d := pos - (position + Vector2(0, -20))
	return absf(d.x) < 66.0 and absf(d.y) < 44.0


func center() -> Vector2:
	return position + Vector2(0, -20)


# ---------- Building ----------

func _remaining(item: String) -> int:
	var cost: Dictionary = STAGES[level]["cost"]
	return int(cost.get(item, 0)) - int(paid.get(item, 0))


func _needs_text() -> String:
	var parts := []
	var cost: Dictionary = STAGES[level]["cost"]
	for item in cost:
		parts.append("%s %d/%d" % [main.hud.item_name(item).to_lower(), int(paid.get(item, 0)), cost[item]])
	return ", ".join(PackedStringArray(parts))


func get_prompt(player) -> String:
	if level < STAGES.size():
		var stage_name: String = STAGES[level]["name"]
		if can_interact(player):
			return "[E] Build the %s (%s)  hold E" % [stage_name, _needs_text()]
		return "Cabin: bring %s to build the %s" % [_needs_text(), stage_name]
	if player.inventory["logs"] > 0:
		return "[E] Add a log to the stove (%ds of heat)" % int(stove_fuel)
	return "Stove: %ds of heat. Bring logs to keep it burning." % int(stove_fuel)


func can_interact(player) -> bool:
	if level >= STAGES.size():
		return player.inventory["logs"] > 0 and stove_fuel < MAX_FUEL - LOG_FUEL
	for item in STAGES[level]["cost"]:
		if _remaining(item) > 0 and player.inventory[item] > 0:
			return true
	return false


func interact(player) -> void:
	if level >= STAGES.size():
		player.inventory["logs"] -= 1
		stove_fuel = minf(stove_fuel + LOG_FUEL, MAX_FUEL)
		main.audio.play("ignite", position, -6.0)
		return
	for item in STAGES[level]["cost"]:
		if _remaining(item) > 0 and player.inventory[item] > 0:
			player.inventory[item] -= 1
			paid[item] = int(paid.get(item, 0)) + 1
			main.audio.play("chop", position, -4.0)
			main.puff(position + Vector2(randf_range(-30, 30), -20), Color(0.8, 0.7, 0.55), 6, 40.0)
			break
	for item in STAGES[level]["cost"]:
		if _remaining(item) > 0:
			return
	var built: String = STAGES[level]["name"]
	level += 1
	paid = {}
	main.audio.play("chime", null, -4.0, 0.0)
	main.shake(3.0)
	match level:
		1:
			main.hud.show_message("Floor down. Next: walls (10 logs). They'll cut the wind.", 5.0)
		2:
			main.hud.show_message("Walls up! It's less windy inside. Next: roof and door (8 logs, 4 stone).", 6.0)
		3:
			main.hud.show_message("The cabin is finished! Safe from storms and animals, and you can sleep here (Z).\nNext: a stove (6 stone, 2 logs) to heat it.", 7.0)
		4:
			stove_fuel = LOG_FUEL
			main.hud.show_message("Stove built and lit! Feed it logs (E) to keep the cabin warm.", 6.0)
	if built == "":
		pass


func _process(delta: float) -> void:
	if main.game_over or main.sleeping:
		return
	if stove_fuel > 0.0:
		stove_fuel = maxf(stove_fuel - delta, 0.0)
	var lit := stove_fuel > 0.0
	_light.energy = (0.4 + 0.6 * main.get_night_factor()) if lit else 0.0
	_smoke.emitting = lit
	var inside: bool = level >= 2 and contains(main.player.position)
	modulate.a = 0.35 if (inside and level >= 2) else 1.0
	queue_redraw()


func _draw() -> void:
	var origin := Vector2(-50, -80)
	match level:
		0:
			var c := Color(0.45, 0.32, 0.2, 0.8)
			for i in 12:
				var x := -46.0 + i * 8.0
				draw_line(Vector2(x, -40), Vector2(x + 4, -40), c, 2.0)
				draw_line(Vector2(x, -1), Vector2(x + 4, -1), c, 2.0)
			for i in 5:
				var y := -40.0 + i * 8.0
				draw_line(Vector2(-46, y), Vector2(-46, y + 4), c, 2.0)
				draw_line(Vector2(45, y), Vector2(45, y + 4), c, 2.0)
		1:
			draw_texture(TEX_FLOOR, origin)
		2:
			draw_texture(TEX_WALLS, origin + Vector2(-1, -1))
		3:
			draw_texture(TEX_ROOF, origin + Vector2(-1, -1))
		_:
			draw_texture(TEX_LIT if stove_fuel > 0.0 else TEX_STOVE, origin + Vector2(-1, -1))
