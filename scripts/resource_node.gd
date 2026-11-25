extends Node2D
## Anything you can gather with E: sticks, stones, flint rocks, snow drifts, berry bushes, meat.

const TEX := {
	"sticks": preload("res://art/sticks.png"),
	"stone": preload("res://art/stone.png"),
	"flint_rock": preload("res://art/flint_rock.png"),
	"flint_rock_empty": preload("res://art/flint_rock_empty.png"),
	"snow_drift": preload("res://art/snow_drift.png"),
	"berry_bush": preload("res://art/bush_berries.png"),
	"berry_bush_empty": preload("res://art/bush_empty.png"),
	"meat": preload("res://art/meat.png"),
}

var main
var kind := "sticks"
var amount := 1           # used by meat drops
var uses := 1             # -1 means it never runs out
var max_uses := 1
var interact_radius := 6.0
var _look := 0            # small random variation in how it's drawn


func _ready() -> void:
	add_to_group("interactable")
	_look = int(absf(position.x * 7.0 + position.y * 13.0)) % 1000
	match kind:
		"flint_rock":
			uses = 4
			interact_radius = 18.0
		"snow_drift":
			uses = -1
			interact_radius = 14.0
		"berry_bush":
			uses = 3
			max_uses = 3
			interact_radius = 12.0
			add_to_group("daily")
		"stone":
			interact_radius = 5.0


func get_prompt(_player) -> String:
	match kind:
		"sticks":
			return "[E] Pick up sticks"
		"stone":
			return "[E] Pick up stone"
		"flint_rock":
			return "[E] Chip flint from the rock" if uses > 0 else "This rock is picked clean"
		"snow_drift":
			return "[E] Cut a snow block (hold E)"
		"berry_bush":
			return "[E] Pick berries (%d left)" % uses if uses > 0 else "No berries left today"
		"meat":
			return "[E] Take raw meat"
	return ""


func can_interact(_player) -> bool:
	return uses != 0


func interact(player) -> void:
	match kind:
		"sticks":
			if player.spend_energy(1.0):
				player.add_item("sticks", 2)
				queue_free()
		"stone":
			if player.spend_energy(1.0):
				player.add_item("stone", 1)
				queue_free()
		"flint_rock":
			if player.spend_energy(3.0):
				uses -= 1
				main.audio.play("gather", position)
				main.puff(position + Vector2(0, -8), Color(0.55, 0.55, 0.6), 6, 50.0)
				player.add_item("flint", 1)
				if randf() < 0.3:
					player.add_item("stone", 1)
		"snow_drift":
			if player.spend_energy(2.0):
				main.audio.play("gather", position, -2.0)
				main.puff(position + Vector2(0, -4), Color(1, 1, 1), 10, 55.0)
				player.add_item("snow_block", 1)
		"berry_bush":
			if player.spend_energy(0.5):
				uses -= 1
				player.add_item("berries", 1)
		"meat":
			player.add_item("raw_meat", amount)
			queue_free()
	queue_redraw()


func new_day() -> void:
	if kind == "berry_bush":
		uses = max_uses
		queue_redraw()


# ---------- Drawing ----------

func _draw() -> void:
	var key := kind
	if kind == "flint_rock" and uses == 0:
		key = "flint_rock_empty"
	elif kind == "berry_bush" and uses == 0:
		key = "berry_bush_empty"
	var tex: Texture2D = TEX[key]
	var sz := tex.get_size()
	var bottom := 3.0 if kind in ["sticks", "stone", "meat"] else 5.0
	draw_set_transform(Vector2(0, bottom - 2.0), 0, Vector2(1, 0.3))
	draw_circle(Vector2.ZERO, sz.x * 0.45, Color(0, 0, 0, 0.12))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	draw_texture(tex, Vector2(-floorf(sz.x / 2.0), bottom - sz.y))
