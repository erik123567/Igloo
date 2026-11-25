extends Node2D
## An igloo: mark a spot, then place snow blocks one at a time until the dome is finished.
## A finished igloo keeps out most of the cold and all of the wolves, and lets you sleep.

const BLOCKS_NEEDED := 10
const RADIUS := 34.0

var main
var blocks := 0
var interact_radius := 20.0
var _pop := 0.0


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("igloo")


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
	if is_complete():
		remove_from_group("interactable")
		main.hud.show_message("Igloo finished! Inside, you're out of the wind and safe from wolves.\nLight a fire inside, then sleep (Z) when night comes.", 7.0)


func _process(delta: float) -> void:
	_pop = maxf(_pop - delta, 0.0)
	var inside: bool = is_complete() and contains(main.player.position)
	modulate.a = 0.45 if inside else 1.0
	queue_redraw()


func _draw() -> void:
	var snow := Color(0.95, 0.97, 1.0)
	var edge := Color(0.62, 0.74, 0.9)
	if is_complete():
		draw_set_transform(Vector2(0, -4), 0, Vector2(1, 0.8))
		draw_circle(Vector2.ZERO, RADIUS + 8.0, Color(0, 0, 0, 0.12))
		draw_circle(Vector2(0, -4), RADIUS + 4.0, snow)
		for r in [14.0, 26.0, 36.0]:
			draw_arc(Vector2(0, -4), r, PI, TAU, 24, edge, 1.2)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		for i in 5:
			var x := -24.0 + i * 12.0
			draw_line(Vector2(x, -20), Vector2(x + 4, -6), edge, 1.0)
		draw_rect(Rect2(-9, 14, 18, 14), snow)
		draw_circle(Vector2(0, 22), 7.5, Color(0.2, 0.24, 0.35))
		draw_rect(Rect2(-7.5, 22, 15, 6), Color(0.2, 0.24, 0.35))
		return
	# foundation ring
	draw_set_transform(Vector2(0, -4), 0, Vector2(1, 0.8))
	for i in 24:
		var a := TAU * i / 24.0
		draw_arc(Vector2.ZERO, RADIUS, a, a + TAU / 48.0, 3, edge, 1.5)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# placed blocks, leaving a gap at the bottom for the door
	var start := PI * 0.5 + 0.55
	var span := TAU - 1.1
	for i in blocks:
		var a := start + span * (i + 0.5) / BLOCKS_NEEDED
		var p := Vector2(cos(a) * RADIUS, sin(a) * RADIUS * 0.8 - 4.0)
		var grow := 1.0 + (_pop * 1.2 if i == blocks - 1 else 0.0)
		draw_set_transform(p, a, Vector2(grow, grow))
		draw_rect(Rect2(-5, -9, 10, 18), snow)
		draw_rect(Rect2(-5, -9, 10, 18), edge, false, 1.0)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
