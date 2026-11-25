extends SceneTree
## Automated play-through used by the web build: crafts a fire and igloo, cooks, eats,
## fights a wolf, hunts a hare, sleeps through the night. Any script error fails the build.

var main
var frame := 0


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frame += 1
	var p = main.player
	match frame:
		5:
			p.inventory["sticks"] = 10
			p.inventory["flint"] = 3
			p.inventory["stone"] = 1
			p.inventory["snow_block"] = 12
			p.inventory["raw_meat"] = 2
			main.hud.set_craft_open(true)
			main.try_craft(2)
		10:
			for ig in get_nodes_in_group("igloo"):
				p.position = ig.position
				for i in 10:
					p.energy = 100.0
					ig.interact(p)
				assert(ig.is_complete())
		15:
			main.hud.set_craft_open(true)
			main.try_craft(1)
		20:
			p._cook()
			p._eat()
			p._eat()
			p._attack()
			for f in get_nodes_in_group("fire"):
				f.interact(p)
		25:
			main.time_of_day = 0.7599
		40:
			var wolves := get_nodes_in_group("wolf")
			print("wolves at night: ", wolves.size())
			assert(wolves.size() > 0)
			p.position += Vector2(500, 0)
			wolves[0].position = p.position + Vector2(15, 0)
		55:
			print("health after wolf: ", p.health)
			for i in 3:
				for w in get_nodes_in_group("wolf"):
					w.take_hit(p)
		60:
			for h in get_nodes_in_group("hare"):
				h.take_hit(p)
				break
		70:
			for w in get_nodes_in_group("wolf"):
				w.position = p.position + Vector2(200, 0)
		80:
			for ig in get_nodes_in_group("igloo"):
				p.position = ig.position
		90:
			main.try_sleep()
		400:
			print("SMOKE TEST OK: day ", main.day, ", health ", p.health)
			return true
	return false
