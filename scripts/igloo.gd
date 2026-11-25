extends Node2D
## An igloo: mark a spot, then place snow blocks one at a time until the dome is finished.
## A finished igloo keeps out most of the cold and all of the wolves, and lets you sleep.

const BLOCKS_NEEDED := 6
const RADIUS := 34.0

const TEX_DONE := preload("res://art/igloo.png")
const TEX_BLOCK := preload("res://art/snow_block.png")

var main
var blocks := 0
var interact_radius := 20.0
var _pop := 0.0


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("igloo")


func shelter_name() -> String:
	return "igloo"


func is_shelter_ready() -> bool:
	return is_complete()


func storm_proof() -> bool:
	return is_complete()


func insulation() -> float:
	return 0.3


func heat() -> float:
	return 0.0


func blocks(pos: Vector2) -> bool:
	return is_complete() and pos.distance_to(position) < RADIUS + 22.0


func center() -> Vector2:
	return position


func radius() -> float:
	return RADIUS


func blocks_needed() -> int:
	return BLOCKS_NEEDED


func is_complete() -> bool:
	return blocks >= BLOCKS_NEEDED


func contains(pos: Vector2) -> bool:
	return pos.distance_to(position) < RADIUS + 6.0


func get_prompt(player) -> String:
	if player.inventory["snow_block"] > 0:
		return "[E] Place snow block (%d/%d)  hold E to keep going" % [blocks, BLOCKS_NEEDED]
	return "Need snow blocks: cut them from snow drifts (%d/%d)" % [blocks, BLOCKS_NEEDED]


func can_interact(player) -> bool:
	return not is_complete() and player.inventory["snow_block"] > 0


func interact(player) -> void:
	if not player.spend_energy(2.0):
		return
	player.inventory["snow_block"] -= 1
	blocks += 1
	_pop = 0.25
	main.audio.play("place_block", position)
	main.puff(position + Vector2(0, -6), Color(1, 1, 1), 8, 50.0)
	if is_complete():
		main.audio.play("chime", null, -4.0, 0.0)
		remove_from_group("interactable")
		main.hud.show_message("Igloo finished! Inside, you're out of the wind and safe from wolves.\nLight a fire inside, then sleep (Z) when night comes.", 7.0)


func _process(delta: float) -> void:
	_pop = maxf(_pop - delta, 0.0)
	var inside: bool = is_complete() and contains(main.player.position)
	modulate.a = 0.45 if inside else 1.0
	queue_redraw()


func _draw() -> void:
	if is_complete():
		draw_set_transform(Vector2(0, 4), 0, Vector2(1, 0.3))
		draw_circle(Vector2.ZERO, RADIUS + 8.0, Color(0, 0, 0, 0.14))
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		draw_texture(TEX_DONE, Vector2(-41, -54))
		return
	# foundation ring
	var edge := Color(0.55, 0.66, 0.84, 0.8)
	draw_set_transform(Vector2(0, -4), 0, Vector2(1, 0.55))
	for i in 24:
		var a := TAU * i / 24.0
		draw_arc(Vector2.ZERO, RADIUS, a, a + TAU / 48.0, 3, edge, 2.0)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# placed blocks around the ring, back ones first, with a gap at the front for the door
	var start := PI * 0.5 + 0.55
	var span := TAU - 1.1
	var order := []
	for i in blocks:
		var a := start + span * (i + 0.5) / BLOCKS_NEEDED
		order.append([sin(a), a, i])
	order.sort_custom(func(x, y): return x[0] < y[0])
	for entry in order:
		var a: float = entry[1]
		var i: int = entry[2]
		var p := Vector2(cos(a) * RADIUS, sin(a) * RADIUS * 0.55 - 4.0)
		var grow := 1.0 + (_pop * 1.2 if i == blocks - 1 else 0.0)
		draw_set_transform(p, 0, Vector2(grow, grow))
		draw_texture(TEX_BLOCK, Vector2(-6, -14))
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
