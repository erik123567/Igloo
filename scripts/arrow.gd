extends Node2D
## An arrow shot from the bow. Flies straight and hits the first animal in its path.

var main
var shooter
var dir := Vector2.RIGHT
var speed := 430.0
var life := 0.8
var damage := 10.0
var kind := "arrow"      # "arrow", "spear" (slows) or "net" (roots)
var target = null        # thrown spears and nets home in on their target


func _ready() -> void:
	z_index = 15
	rotation = dir.angle()


func _process(delta: float) -> void:
	if main.game_over or main.sleeping:
		return
	if target != null:
		if not is_instance_valid(target) or target.is_queued_for_deletion():
			queue_free()
			return
		dir = (target.position + Vector2(0, -6) - position).normalized()
		rotation = dir.angle()
		if position.distance_to(target.position + Vector2(0, -6)) < 10.0:
			_hit_target()
			return
		position += dir * speed * delta
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
			n.take_hit(shooter, damage)
			queue_free()
			return


func _hit_target() -> void:
	if kind == "spear":
		target.take_hit(shooter, damage)
		if is_instance_valid(target) and not target.is_queued_for_deletion():
			target.apply_slow(3.0)
	elif kind == "net":
		var t := 3.0 + (1.0 if shooter.subclass == "hunter" else 0.0)
		target.apply_root(t)
		main.float_text(target.position + Vector2(0, -26), "Netted!", Color(0.95, 0.85, 0.5))
		if target.has_method("take_hit") and target.is_in_group("hare"):
			target.take_hit(shooter, 1.0)
	queue_free()


func _draw() -> void:
	if kind == "net":
		draw_arc(Vector2.ZERO, 6, 0, TAU, 12, Color(0.85, 0.75, 0.5), 1.0)
		draw_line(Vector2(-5, -3), Vector2(5, 3), Color(0.85, 0.75, 0.5), 1.0)
		draw_line(Vector2(-5, 3), Vector2(5, -3), Color(0.85, 0.75, 0.5), 1.0)
		return
	if kind == "spear":
		draw_line(Vector2(-14, 0), Vector2(8, 0), Color(0.5, 0.34, 0.18), 2.0)
		draw_colored_polygon(PackedVector2Array([Vector2(8, -3), Vector2(14, 0), Vector2(8, 3)]), Color(0.3, 0.3, 0.35))
		return
	draw_line(Vector2(-8, 0), Vector2(5, 0), Color(0.55, 0.38, 0.2), 1.5)
	draw_colored_polygon(PackedVector2Array([Vector2(5, -2), Vector2(9, 0), Vector2(5, 2)]), Color(0.3, 0.3, 0.35))
	draw_line(Vector2(-8, 0), Vector2(-10, -2), Color(0.95, 0.95, 0.95), 1.0)
	draw_line(Vector2(-8, 0), Vector2(-10, 2), Color(0.95, 0.95, 0.95), 1.0)
