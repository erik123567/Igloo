extends Node2D
## A snowy pine tree. Chop it with an axe for logs. Standing under one softens hail.

const TEX := preload("res://art/pine.png")
const TEX_STUMP := preload("res://art/stump.png")

var main
var size := 1.0
var hp := 3
var chopped := false
var interact_radius := 8.0
var _wobble := 0.0


func _ready() -> void:
	hp = 5 if size > 1.5 else 3
	add_to_group("tree")
	add_to_group("interactable")


func get_prompt(player) -> String:
	if chopped or int(player.tools["axe"]) == 0:
		return ""
	return "[E] Chop the tree (hold E)"


func can_interact(player) -> bool:
	return not chopped and int(player.tools["axe"]) > 0


func interact(player) -> void:
	if not player.spend_energy(4.0):
		return
	hp -= int(player.tools["axe"])
	_wobble = 0.3
	main.audio.play("chop", position)
	main.puff(position + Vector2(0, -30 * size), Color(1, 1, 1), 12, 40.0)
	if hp <= 0:
		chopped = true
		remove_from_group("interactable")
		player.add_item("logs", 3 if size > 1.5 else 2)
		player.add_item("sticks", 1)
	queue_redraw()


func _process(delta: float) -> void:
	if _wobble > 0.0:
		_wobble = maxf(_wobble - delta, 0.0)
		queue_redraw()


func _draw() -> void:
	if chopped:
		draw_texture(TEX_STUMP, Vector2(-8, -8))
		return
	draw_set_transform(Vector2(0, 2), 0, Vector2(1, 0.3))
	draw_circle(Vector2.ZERO, 14.0 * size, Color(0, 0, 0, 0.18))
	var sway := sin(_wobble * 40.0) * _wobble * 0.15
	draw_set_transform(Vector2.ZERO, sway, Vector2(size, size))
	draw_texture(TEX, Vector2(-16, -44))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
