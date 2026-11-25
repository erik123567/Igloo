extends SceneTree
## Automated play-through used by the web build: crafts a fire and igloo, cooks, eats,
## fights a wolf, hunts a hare, sleeps through the night. Any script error fails the build.

var main
var frame := 0
var hail_start := 0.0
var temp_start := 0.0


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
			w0.position = p.position + Vector2(70, 0)
			p.facing = Vector2.RIGHT
			p._attack()
		66:
			var w0 = get_nodes_in_group("wolf")[0]
			print("wolf hp after arrow: ", w0.hp)
			assert(w0.hp < 3)
			for i in 3:
				for w in get_nodes_in_group("wolf"):
					w.take_hit(p, 2)
			main.weather.start_storm("hail")
			main.weather.hail = 1.0
			hail_start = p.health
		120:
			print("health after 1s of hail outside: ", hail_start, " -> ", p.health)
			assert(p.health < hail_start)
			main.weather.start_storm("blizzard")
			main.weather.blizzard = 1.0
			temp_start = p.temp
		180:
			print("body temp after 1s of blizzard: ", temp_start, " -> ", p.temp)
			for ig in get_nodes_in_group("igloo"):
				p.position = ig.position
			p.health = 100.0
		185:
			# build the whole cabin and sleep in it instead
			p.inventory["logs"] = 40
			p.inventory["stone"] = 20
			main.hud.set_craft_open(true)
			main.try_craft(8)
			var cabin = main.get_home()
			assert(cabin != null)
			for i in 40:
				if cabin.can_interact(p):
					cabin.interact(p)
			print("cabin level: ", cabin.level, " stove: ", cabin.stove_fuel)
			assert(cabin.level == 4)
			p.position = cabin.center()
			assert(main.get_shelter_at(p.position) == cabin)
			# a polar bear next to us outside should hurt
		190:
			var bear = get_nodes_in_group("bear")[0]
			print("bears: ", get_nodes_in_group("bear").size(), " forest wolves: ", get_nodes_in_group("wolf").size())
			for i in 5:
				bear.take_hit(p, 2)
			assert(not is_instance_valid(bear) or bear.is_queued_for_deletion())
		200:
			main.try_sleep()
		500:
			assert(main.day == 2)
			print("SMOKE TEST OK: day ", main.day, ", health ", p.health, ", weather ", main.weather.label())
			return true
	return false
