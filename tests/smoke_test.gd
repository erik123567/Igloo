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
			p.inventory["logs"] = 0
			main.hud.set_craft_open(true)
			main.try_craft(2)
		10:
			for ig in get_nodes_in_group("igloo"):
				p.position = ig.position
				for i in 6:
					p.energy = 100.0
					ig.interact(p)
				assert(ig.is_complete())
		15:
			main.hud.set_craft_open(true)
			main.try_craft(1)
		17:
			p.inventory["sticks"] = 30
			p.inventory["flint"] = 6
			p.inventory["stone"] = 3
			for i in [3, 4, 6, 7]:
				main.try_craft(i)
			assert(p.tools["axe"] and p.tools["spear"])
			var tree = get_nodes_in_group("tree")[0]
			for i in 6:
				p.energy = 100.0
				if not tree.chopped:
					tree.interact(p)
			assert(tree.chopped and p.inventory["logs"] >= 2)
			main.try_craft(5)
			assert(p.tools["bow"])
			p._light_torch()
			p._cycle_weapon()
			print("crafted: ", p.tools, " arrows ", p.inventory["arrows"], " holding ", p.weapon)
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
			p.weapon = "bow"
			var w0 = get_nodes_in_group("wolf")[0]
			p.facing = (w0.position - p.position).normalized()
			p._attack()
		58:
			for i in 3:
				for w in get_nodes_in_group("wolf"):
					w.take_hit(p, 2)
			main.weather.start_storm("hail")
		75:
			var before: float = p.health
			main.weather.hail = 1.0
		76:
			print("health in hail (outside): ", p.health)
			main.weather.start_storm("blizzard")
			main.weather.blizzard = 1.0
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
