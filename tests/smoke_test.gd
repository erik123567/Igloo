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
		2:
			assert(paused)  # title screen is up
			main.start_new_game()
			assert(not paused)
		5:
			p.inventory["sticks"] = 10
			p.inventory["flint"] = 3
			p.inventory["stone"] = 1
			p.inventory["snow_block"] = 12
			p.inventory["raw_meat"] = 2
			p.inventory["logs"] = 0
			main.try_craft(2)
		10:
			for ig in get_nodes_in_group("igloo"):
				p.position = ig.position
				for i in 6:
					p.energy = 100.0
					ig.interact(p)
				assert(ig.is_complete())
		15:
			main.try_craft(1)
		17:
			p.inventory["logs"] = 4
			p.inventory["stone"] = 2
			main.try_craft(4)
			assert(main.near_workbench())
			p.inventory["sticks"] = 30
			p.inventory["flint"] = 6
			p.inventory["stone"] = 3
			for key in ["axe", "spear", "arrows", "torch"]:
				for r in main.get_recipes():
					if r["key"] == key:
						main.craft(r)
			assert(p.tools["axe"] == 1 and p.tools["spear"] == 1)
			var tree = get_nodes_in_group("tree")[0]
			for i in 6:
				p.energy = 100.0
				if not tree.chopped:
					tree.interact(p)
			assert(tree.chopped and p.inventory["logs"] >= 2)
			for r in main.get_recipes():
				if r["key"] == "bow":
					main.craft(r)
			assert(p.tools["bow"] == 1)
			# tool tiers and fur gear
			p.inventory["bone"] = 4
			p.inventory["iron"] = 4
			p.inventory["hide"] = 10
			p.inventory["logs"] = 6
			for key in ["axe_bone", "axe_iron", "spear_bone", "spear_iron", "mittens", "boots", "coat"]:
				for r in main.get_recipes():
					if r["key"] == key:
						main.craft(r)
			print("tools: ", p.tools, " gear: ", p.gear, " cold factor ", p.gear_cold_factor())
			assert(p.tools["axe"] == 3 and p.tools["spear"] == 3 and p.gear["coat"])
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
			for r in main.get_recipes():
				if r["key"] == "cabin":
					main.craft(r)
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
		300:
			# fishing on the sea ice
			p.inventory["sticks"] = 10
			p.inventory["bone"] = 2
			for r in main.get_recipes():
				if r["key"] == "rod":
					main.craft(r)
			assert(p.tools["rod"] == 1)
			p.position = Vector2(3000, main.shore_y + 40)
			assert(p.can_fish())
			p._fish_action()
			assert(p.fishing)
			p._fish_wait = 0.01
		305:
			p._fish_action()
			print("fish caught: ", p.inventory["raw_fish"])
			assert(p.inventory["raw_fish"] >= 1)
		310:
			# base upgrades next to a new workbench
			p.position = Vector2(3000, 3900)
			p.inventory["logs"] = 30
			p.inventory["stone"] = 6
			p.inventory["sticks"] = 20
			p.inventory["hide"] = 2
			p.inventory["raw_meat"] = 3
			for key in ["workbench", "chest", "rack", "snare", "fence"]:
				for r in main.get_recipes():
					if r["key"] == key:
						main.craft(r)
						p.position += Vector2(40, 0)
			var kinds := []
			for st in get_nodes_in_group("structure"):
				kinds.append(st.kind)
			print("structures: ", kinds)
			assert(kinds.has("chest") and kinds.has("rack") and kinds.has("snare") and kinds.has("fence"))
			for st in get_nodes_in_group("structure"):
				if st.kind == "rack":
					st.interact(p)
					st.drying = [0.01, 0.01, 0.01, 0.01]
				if st.kind == "chest":
					st.interact(p)
					assert(p.inventory["logs"] == 0 and st.storage["logs"] > 0)
					st.interact(p)
					assert(p.inventory["logs"] > 0)
				if st.kind == "snare":
					st.caught = true
					st.interact(p)
				if st.kind == "fence":
					assert(main.fear_push(st.position) != Vector2.ZERO)
		320:
			for st in get_nodes_in_group("structure"):
				if st.kind == "rack":
					print("jerky ready: ", st.ready_jerky)
					assert(st.ready_jerky >= 3)
					st.interact(p)
			assert(p.inventory["jerky"] >= 3)
			# loot crates up north
			var parts := 0
			for c in get_nodes_in_group("crate"):
				c.interact(p)
			print("radio parts from crates: ", p.inventory["radio_part"])
			assert(p.inventory["radio_part"] == 3)
			# spoilage
			p.inventory["raw_meat"] = 4
			main._spoil_food()
			assert(p.inventory["raw_meat"] == 2)
		450:
			# save, wipe some state, load it back
			main.save_game()
			var data: Dictionary = main.read_save()
			assert(int(data["day"]) == 2)
			p.inventory["logs"] = 0
			main.load_game(data)
			var gone := 0
			for v in data["map"]:
				if int(v) == -2:
					gone += 1
			print("after load: logs ", p.inventory["logs"], " cabin level ", main.get_home().level, " map things used up: ", gone)
			assert(gone > 0)
			assert(p.inventory["logs"] > 0)
		460:
			# build the beacon, switch it on, and get rescued
			p.inventory["iron"] = 4
			p.inventory["logs"] = 10
			p.position = Vector2(3000, 3900)
			for r in main.get_recipes():
				if r["key"] == "beacon":
					main.craft(r)
			var beacon = null
			for st in get_nodes_in_group("structure"):
				if st.kind == "beacon":
					beacon = st
			assert(beacon != null)
			beacon.interact(p)
			assert(main.rescue_day == main.day + 2)
			main.day = main.rescue_day
			main._on_morning()
			assert(main.won and main.game_over)
			print("rescued on day ", main.day)
		500:
			print("SMOKE TEST OK: day ", main.day, ", health ", p.health, ", weather ", main.weather.label())
			return true
	return false
