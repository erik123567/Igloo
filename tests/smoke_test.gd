extends SceneTree
## Automated play-through used by the web build: crafts a fire and igloo, cooks, eats,
## fights a wolf, hunts a hare, sleeps through the night. Any script error fails the build.

var main
var frame := 0
var test_wolf = null
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
			for w in wolves:
				if w.variant == "wolf" and not w.resident:
					test_wolf = w
			assert(test_wolf != null)
			p.position += Vector2(500, 0)
			test_wolf.position = p.position + Vector2(15, 0)
		55:
			print("health after wolf: ", p.health)
			p.weapon = "bow"
			var w0 = test_wolf
			w0.position = p.position + Vector2(70, 0)
			p.facing = Vector2.RIGHT
			p._attack()
		66:
			var w0 = test_wolf
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
			var bear = null
			for b in get_nodes_in_group("bear"):
				if b.variant == "polar":
					bear = b
			print("bears: ", get_nodes_in_group("bear").size(), " forest wolves: ", get_nodes_in_group("wolf").size())
			var kinds := {}
			for b in get_nodes_in_group("bear"):
				kinds[b.variant] = int(kinds.get(b.variant, 0)) + 1
			var wkinds := {}
			for w in get_nodes_in_group("wolf"):
				wkinds[w.variant] = int(wkinds.get(w.variant, 0)) + 1
			print("bear kinds: ", kinds, " wolf kinds: ", wkinds)
			assert(kinds.get("great", 0) > 0 and wkinds.get("frost", 0) > 0 and wkinds.get("dire", 0) > 0)
			var hunting_before: int = p.skills["hunting"]["xp"] + p.skills["hunting"]["level"] * 1000
			var hits := 0
			while is_instance_valid(bear) and not bear.is_queued_for_deletion() and hits < 60:
				bear.take_hit(p, 2.0)
				hits += 1
			print("bear (", bear.variant if is_instance_valid(bear) else "?", ") down after ", hits, " hits")
			assert(not is_instance_valid(bear) or bear.is_queued_for_deletion())
			assert(p.skills["hunting"]["xp"] + p.skills["hunting"]["level"] * 1000 > hunting_before)
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
			var steel_before: int = p.inventory["steel"]
			for c in get_nodes_in_group("crate"):
				c.interact(p)
			print("steel from crates: ", p.inventory["steel"] - steel_before, " white fur: ", p.inventory["white_fur"])
			assert(p.inventory["steel"] > steel_before)
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
			# progression: skills, armor, polar coat, steel tools
			var lv0: int = p.skill("toughness")
			p.add_xp("toughness", 5000)
			print("toughness ", lv0, " -> ", p.skill("toughness"), " max health ", p.max_health)
			assert(p.skill("toughness") > lv0 and p.max_health > 100.0)
			for st in get_nodes_in_group("structure"):
				if st.kind == "workbench":
					p.position = st.position + Vector2(0, 40)
			assert(main.near_workbench())
			p.gear["coat"] = true
			for k in ["white_fur", "steel", "bone", "iron", "hide", "logs"]:
				p.inventory[k] = 20
			# trophies gate the top gear
			for r in main.get_recipes():
				if r["key"] == "polar_coat":
					print("polar coat without trophy: ", main.missing_for(r))
					assert(main.missing_for(r) != "")
			for k in ["alpha_fang", "great_claw", "king_pelt"]:
				p.inventory[k] = 1
			for key in ["polar_coat", "armor_bone", "armor_iron", "armor_frost", "axe_steel", "spear_steel"]:
				var found := false
				for r in main.get_recipes():
					if r["key"] == key:
						assert(main.missing_for(r) == "")
						main.craft(r)
						found = true
				print("crafted ", key, ": ", found)
				assert(found)
			assert(p.armor == 3 and p.gear["polar_coat"] and p.tools["axe"] == 4 and p.tools["spear"] == 4)
			p.health = p.max_health
			var h0: float = p.health
			p.take_damage(10.0, "a test", false, true)
			print("10 damage with frost armor took ", h0 - p.health)
			assert(absf((h0 - p.health) - 4.5) < 0.6)
			# a dodge roll avoids the hit entirely
			p.dodge()
			h0 = p.health
			p.take_damage(10.0, "a test", false, true)
			assert(p.health == h0)
			main.save_game()
			p.armor = 0
			main.load_game(main.read_save())
			assert(p.armor == 3 and p.skill("toughness") > 1)
		470:
			# bosses: one per zone, with a big health bar; beating one is remembered
			var bosses := get_nodes_in_group("boss")
			print("bosses: ", bosses.map(func(b): return b.display_name))
			assert(bosses.size() == 3)
			print("goal: ", main.current_goal()[0])
			var alpha = null
			for b in bosses:
				if b.variant == "alpha":
					alpha = b
			p.position = alpha.position + Vector2(30, 0)
			p.weapon = "spear"
			var swings := 0
			while is_instance_valid(alpha) and not alpha.is_queued_for_deletion() and swings < 100:
				p._combo = 1
				p._strike((alpha.position - p.position).normalized())
				p.position = alpha.position + Vector2(30, 0)
				swings += 1
			print("alpha down after ", swings, " swings; wolves now: ", get_nodes_in_group("wolf").size())
			assert("alpha" in main.bosses_killed)
			# a click queues a swing that winds up, strikes, then recovers
			p.weapon = "spear"
			p.position = Vector2(3000, 4000)
			p._atk_state = ""
			p._dodge = 0.0   # the perfect dodge above slowed time, so the roll may not be over yet
			p._freeze = 0.0
			p._combo_t = 0.0
			p._attack(Vector2.RIGHT)
			p._update_attack(0.0)
			assert(p._atk_state == "startup" and p._combo == 1)
			p._update_attack(0.1)
			print("swing state after wind-up: ", p._atk_state)
			assert(p._atk_state == "recovery")
			p._attack(Vector2.RIGHT)   # buffered during recovery
			p._update_attack(0.3)
			p._update_attack(0.0)
			assert(p._atk_state == "startup" and p._combo == 2)
		500:
			print("SMOKE TEST OK: day ", main.day, ", health ", p.health, ", weather ", main.weather.label())
			return true
	return false
