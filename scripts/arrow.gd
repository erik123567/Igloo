extends Node2D
## An arrow shot from the bow. Flies straight and hits the first animal in its path.

var main
var shooter
var dir := Vector2.RIGHT
var speed := 430.0
var life := 0.8
var damage := 2


func _ready() -> void:
	z_index = 15
	rotation = dir.angle()


func _process(delta: float) -> void:
	if main.game_over or main.sleeping:
		return
	position += dir * speed * delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	for n in get_tree().get_nodes_in_group("attackable"):
		if n.is_queued_for_deletion():
			continue
		if position.distance_to(n.position + Vector2(0, -5)) < n.hit_radius + 6.0:
			n.take_hit(shooter, damage * shooter.damage_mult())
			queue_free()
			return


func _draw() -> void:
	draw_line(Vector2(-8, 0), Vector2(5, 0), Color(0.55, 0.38, 0.2), 1.5)
	draw_colored_polygon(PackedVector2Array([Vector2(5, -2), Vector2(9, 0), Vector2(5, 2)]), Color(0.3, 0.3, 0.35))
	draw_line(Vector2(-8, 0), Vector2(-10, -2), Color(0.95, 0.95, 0.95), 1.0)
	draw_line(Vector2(-8, 0), Vector2(-10, 2), Color(0.95, 0.95, 0.95), 1.0)
