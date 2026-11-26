extends Node2D
## Igloo MVP: builds the world, runs the day/night clock, crafting, sleep,
## and spawns hares by day and wolves by night.

const PlayerScript = preload("res://scripts/player.gd")
const HudScript = preload("res://scripts/hud.gd")
const ResourceNodeScript = preload("res://scripts/resource_node.gd")
const PineScript = preload("res://scripts/pine_tree.gd")
const FireScript = preload("res://scripts/campfire.gd")
const IglooScript = preload("res://scripts/igloo.gd")
const WolfScript = preload("res://scripts/wolf.gd")
const HareScript = preload("res://scripts/hare.gd")
const GroundScript = preload("res://scripts/ground.gd")
const AudioScript = preload("res://scripts/audio.gd")
const FxScript = preload("res://scripts/fx.gd")
const WeatherScript = preload("res://scripts/weather.gd")
const ArrowScript = preload("res://scripts/arrow.gd")
const CabinScript = preload("res://scripts/cabin.gd")
const BearScript = preload("res://scripts/bear.gd")
const StructureScript = preload("res://scripts/structure.gd")

# ---------- Tuning (change these numbers to balance the game) ----------
const DAY_LENGTH := 360.0      # real seconds for one full day + night
const START_TIME := 0.25       # 0.0 = midnight, 0.25 = 6:00, 0.5 = noon
const DAWN_START := 0.20       # night starts turning to day
const MORNING := 0.28          # full daylight
const DUSK_START := 0.68       # sun starts setting
const NIGHT_START := 0.76      # full night, wolves come out
const WIN_DAYS := 3            # survive this many nights to win
const HARES_PER_DAY := 14
const BEARS := 4                 # polar bears on the tundra
const GREAT_BEARS := 2           # great white bears in the far north
## One boss per wild zone. Beating one gives a trophy that unlocks the next tier of gear.
const BOSSES := [
	{"variant": "alpha", "kind": "wolf", "pos": Vector2(800, 2100), "zone": "Boreal forest", "trophy": "alpha_fang",
		"unlocks": "iron armor"},
	{"variant": "tusk", "kind": "bear", "pos": Vector2(2100, 850), "zone": "Frozen tundra", "trophy": "great_claw",
		"unlocks": "the polar coat and steel tools"},
	{"variant": "king", "kind": "bear", "pos": Vector2(5300, 180), "zone": "Far north", "trophy": "king_pelt",
		"unlocks": "frost king armor"},
]
const TROPHY_FROM := {"alpha_fang": "Greymane, the pack alpha (west forest)", "great_claw": "Old Tusk (tundra, west of the lake)",
	"king_pelt": "The White King (far north-east)"}
## Wolf dens: where each pack lives, and what kind of wolves they are.
const DENS := [
	[Vector2(1500, 2400), "wolf"], [Vector2(4300, 2000), "wolf"], [Vector2(2900, 1900), "wolf"],
	[Vector2(1600, 1150), "dire"], [Vector2(4500, 1050), "dire"],
	[Vector2(1200, 350), "frost"], [Vector2(4100, 300), "frost"],
]
const MAX_WOLVES := 5

# "bench": true means you must stand near a workbench to make it.
const RECIPES := [
	{"key": "campfire", "name": "Campfire", "cost": {"sticks": 3, "flint": 1}, "note": "struck with a stone"},
	{"key": "igloo", "name": "Igloo shelter", "cost": {}, "note": "fill it with 6 snow blocks"},
	{"key": "cabin", "name": "Cabin site", "cost": {}, "note": "your home base, build it up with logs"},
	{"key": "workbench", "name": "Workbench", "cost": {"logs": 4, "stone": 2}, "note": "needed for advanced crafting"},
	{"key": "torch", "name": "Torch", "cost": {"sticks": 3}, "note": "light and a little warmth, T to light"},
	{"key": "axe", "tool": "axe", "tier": 1, "name": "Stone axe", "cost": {"sticks": 2, "stone": 1, "flint": 1}, "note": "chop trees for logs"},
	{"key": "axe_bone", "tool": "axe", "tier": 2, "bench": true, "name": "Bone axe", "cost": {"bone": 2, "logs": 1, "sticks": 1}, "note": "chops twice as fast"},
	{"key": "axe_iron", "tool": "axe", "tier": 3, "bench": true, "name": "Iron axe", "cost": {"iron": 2, "logs": 1}, "note": "chops three times as fast"},
	{"key": "spear", "tool": "spear", "tier": 1, "name": "Stone spear", "cost": {"sticks": 3, "flint": 1}, "note": "2 damage, longer reach"},
	{"key": "spear_bone", "tool": "spear", "tier": 2, "bench": true, "name": "Bone spear", "cost": {"bone": 2, "sticks": 2}, "note": "3 damage"},
	{"key": "spear_iron", "tool": "spear", "tier": 3, "bench": true, "name": "Iron spear", "cost": {"iron": 2, "logs": 1}, "note": "4 damage"},
	{"key": "bow", "tool": "bow", "tier": 1, "bench": true, "name": "Bow", "cost": {"logs": 1, "sticks": 2}, "note": "shoot arrows from afar"},
	{"key": "arrows", "name": "5 arrows", "cost": {"sticks": 2, "flint": 1}, "note": ""},
	{"key": "rod", "tool": "rod", "tier": 1, "name": "Fishing rod", "cost": {"sticks": 3, "bone": 1}, "note": "fish through the ice (lake or sea ice)"},
	{"key": "snare", "name": "Snare", "cost": {"sticks": 3, "hide": 1}, "note": "catches hares overnight"},
	{"key": "fence", "name": "Fence", "cost": {"logs": 2}, "note": "wolves and bears can't get past"},
	{"key": "chest", "bench": true, "name": "Storage chest", "cost": {"logs": 4}, "note": "food stored here doesn't spoil"},
	{"key": "rack", "bench": true, "name": "Drying rack", "cost": {"logs": 2, "sticks": 4}, "note": "turns raw meat and fish into jerky"},
	{"key": "mittens", "gear": "mittens", "bench": true, "name": "Fur mittens", "cost": {"hide": 2}, "note": "10% less cold"},
	{"key": "boots", "gear": "boots", "bench": true, "name": "Fur boots", "cost": {"hide": 3}, "note": "10% less cold, walk a bit faster"},
	{"key": "coat", "gear": "coat", "bench": true, "name": "Fur coat", "cost": {"hide": 5}, "note": "25% less cold"},
	{"key": "polar_coat", "gear": "polar_coat", "needs_gear": "coat", "bench": true, "name": "Polar fur coat", "cost": {"white_fur": 4, "hide": 2}, "trophy": "great_claw", "note": "40% less cold (replaces the fur coat)"},
	{"key": "armor_bone", "armor": 1, "bench": true, "name": "Bone armor", "cost": {"bone": 6, "hide": 2}, "note": "take 20% less damage from animals"},
	{"key": "armor_iron", "armor": 2, "bench": true, "name": "Iron armor", "cost": {"iron": 6, "hide": 2}, "trophy": "alpha_fang", "note": "take 40% less damage from animals"},
	{"key": "armor_frost", "armor": 3, "bench": true, "name": "Frost king armor", "cost": {"steel": 4, "white_fur": 4}, "trophy": "king_pelt", "note": "take 55% less damage. The best there is"},
	{"key": "axe_steel", "tool": "axe", "tier": 4, "bench": true, "name": "Steel axe", "cost": {"steel": 2, "logs": 1}, "trophy": "great_claw", "note": "chops four times as fast"},
	{"key": "spear_steel", "tool": "spear", "tier": 4, "bench": true, "name": "Steel spear", "cost": {"steel": 2, "logs": 1}, "trophy": "great_claw", "note": "5 damage"},
]

# Places worth finding up north. Their crates hold rare loot: steel, white fur, iron.
const SITES := [
	{"name": "shipwreck", "art": "shipwreck", "pos": Vector2(4700, 330), "crates": [
		{"steel": 2, "iron": 3, "arrows": 10}, {"hide": 3, "jerky": 4, "white_fur": 2}]},
	{"name": "trapper's camp", "art": "camp", "pos": Vector2(800, 1050), "crates": [
		{"bone": 6, "hide": 4, "iron": 2}, {"arrows": 10, "torch": 3, "steel": 1}]},
	{"name": "weather station", "art": "station", "pos": Vector2(2900, 200), "crates": [
		{"steel": 3, "iron": 4}, {"jerky": 3, "torch": 2, "white_fur": 2}]},
]

# Zones get colder the further north you go (smaller y = further north).
const ZONES := [
	{"name": "Coast", "from_y": 3200.0, "cold": 1.0, "danger": 1, "wolf": "wolf"},
	{"name": "Boreal forest", "from_y": 1700.0, "cold": 1.15, "danger": 2, "wolf": "wolf"},
	{"name": "Frozen tundra", "from_y": 600.0, "cold": 1.6, "danger": 3, "wolf": "dire"},
	{"name": "Far north", "from_y": -99999.0, "cold": 2.3, "danger": 4, "wolf": "frost"},
]

var world_size := Vector2(6000, 4500)
var shore_y := 4280.0          # ice starts here, open water below
var spawn_point := Vector2(3000, 4050)

var time_of_day := START_TIME
var day := 1
var game_over := false
var endless := false
var won := false
var sleeping := false

var world: Node2D
var fx
var audio
var weather
var cam: Camera2D
var _shake := 0.0
var player
var hud
var canvas_mod: CanvasModulate
var rng := RandomNumberGenerator.new()
var _light_tex: Texture2D
var map_nodes: Array = []        # trees and resources of the hand-made map, in build order (for saving)
var _building := false
var play_time := 0.0
var stats := {"wolves": 0, "bears": 0, "hares": 0}
var rescue_day := 0              # morning the rescue plane arrives (0 = beacon not on yet)
var milestone_shown := false
var bosses_killed := []

const SAVE_PATH := "user://igloo_save.json"
## How the scene should start after a reload: "title", "continue" or "new".
static var start_mode := "title"


func _ready() -> void:
	_setup_input()

	var ground = GroundScript.new()
	ground.world_size = world_size
	ground.shore_y = shore_y
	add_child(ground)

	fx = FxScript.new()
	add_child(fx)

	canvas_mod = CanvasModulate.new()
	add_child(canvas_mod)

	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)

	rng.seed = 20261125  # same hand-made layout every time
	_building = true
	_build_map()
	_building = false
	rng.randomize()

	player = PlayerScript.new()
	player.main = self
	player.position = spawn_point
	world.add_child(player)

	cam = Camera2D.new()
	cam.zoom = Vector2(2, 2)
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(world_size.x)
	cam.limit_bottom = int(world_size.y)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 6.0
	player.add_child(cam)
	cam.make_current()

	audio = AudioScript.new()
	audio.main = self
	add_child(audio)

	weather = WeatherScript.new()
	weather.main = self
	add_child(weather)
	weather.attach_to(player)

	hud = HudScript.new()
	hud.main = self
	hud.player = player
	add_child(hud)

	_spawn_hares()
	_spawn_predators()
	_update_lighting()
	hud.show_message("You wake up alone in the snow. It's getting colder...\nFind sticks, flint and a stone to make a fire.", 8.0)

	var mode := start_mode
	start_mode = "title"
	if mode == "new":
		start_new_game()
	elif mode == "continue" and continue_game():
		pass
	else:
		get_tree().paused = true
		hud.show_title(has_save(), int(read_save().get("day", 1)) if has_save() else 1)


# ---------- Input ----------

func _setup_input() -> void:
	var keys := {
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"sprint": [KEY_SHIFT],
		"interact": [KEY_E],
		"attack": [KEY_SPACE],
		"eat": [KEY_Q],
		"cook": [KEY_C],
		"sleep": [KEY_Z],
		"craft_menu": [KEY_TAB],
		"craft_1": [KEY_1],
		"craft_2": [KEY_2],
		"craft_3": [KEY_3],
		"craft_4": [KEY_4],
		"craft_5": [KEY_5],
		"craft_6": [KEY_6],
		"craft_7": [KEY_7],
		"craft_8": [KEY_8],
		"cycle_weapon": [KEY_F],
		"dodge": [KEY_CTRL],
		"inventory": [KEY_I],
		"torch": [KEY_T],
		"toggle_help": [KEY_H],
		"pause": [KEY_ESCAPE],
		"restart": [KEY_R],
		"continue": [KEY_ENTER, KEY_KP_ENTER],
	}
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	for mb in [["attack_mouse", MOUSE_BUTTON_LEFT], ["dodge", MOUSE_BUTTON_RIGHT]]:
		if not InputMap.has_action(mb[0]):
			InputMap.add_action(mb[0])
		var mev := InputEventMouseButton.new()
		mev.button_index = mb[1]
		if not InputMap.action_has_event(mb[0], mev):
			InputMap.action_add_event(mb[0], mev)


# ---------- Map ----------

func _rand_point(x0: float, y0: float, x1: float, y1: float) -> Vector2:
	return Vector2(rng.randf_range(x0, x1), rng.randf_range(y0, y1))


func _point_near(center: Vector2, min_d: float, max_d: float) -> Vector2:
	var a := rng.randf() * TAU
	var p := center + Vector2(cos(a), sin(a)) * rng.randf_range(min_d, max_d)
	p.x = clampf(p.x, 40, world_size.x - 40)
	p.y = clampf(p.y, 40, shore_y - 40)
	return p


func _away_from_spawn(x0: float, y0: float, x1: float, y1: float, min_d: float) -> Vector2:
	for i in 30:
		var p := _rand_point(x0, y0, x1, y1)
		if p.distance_to(spawn_point) >= min_d:
			return p
	return _rand_point(x0, y0, x1, y1)


func _build_map() -> void:
	var W := world_size.x
	var trees: Array[Vector2] = []
	# Boreal forest: a thick band across the middle of the map
	for i in 430:
		trees.append(_rand_point(40, 1750, W - 40, 3150))
	# Scattered trees on the coast, a few on the tundra, almost none in the far north
	for i in 70:
		trees.append(_away_from_spawn(60, 3200, W - 60, shore_y - 80, 220))
	for i in 30:
		trees.append(_rand_point(60, 650, W - 60, 1650))
	for i in 6:
		trees.append(_rand_point(60, 60, W - 60, 560))
	for t in trees:
		var tree = PineScript.new()
		tree.main = self
		tree.position = t
		tree.size = 2.0 if (t.y < 3150 and rng.randf() < 0.3) else 1.0
		world.add_child(tree)
		map_nodes.append(tree)

	# Sticks: mostly under trees, plenty near where you wake up
	for i in 140:
		var t: Vector2 = trees[rng.randi() % trees.size()]
		spawn_resource("sticks", _point_near(t, 18, 50))
	for i in 30:
		spawn_resource("sticks", _away_from_spawn(80, 3200, W - 80, shore_y - 60, 100))
	for i in 4:
		spawn_resource("sticks", _point_near(spawn_point, 110, 260))

	# Flint outcrops: a couple near the start, more out in the wilds
	spawn_resource("flint_rock", spawn_point + Vector2(320, -150))
	spawn_resource("flint_rock", spawn_point + Vector2(-380, -260))
	for i in 22:
		spawn_resource("flint_rock", _away_from_spawn(120, 300, W - 120, shore_y - 80, 600))

	# Loose stones (you'll need lots for the cabin)
	for i in 70:
		spawn_resource("stone", _rand_point(80, 200, W - 80, shore_y - 40))
	for i in 3:
		spawn_resource("stone", _point_near(spawn_point, 130, 300))

	# Snow drifts for igloo blocks, everywhere
	for i in 120:
		spawn_resource("snow_drift", _away_from_spawn(80, 100, W - 80, shore_y - 60, 120))
	for i in 3:
		spawn_resource("snow_drift", _point_near(spawn_point, 90, 200))

	# Berry bushes on the coast and along the forest edges
	for i in 22:
		spawn_resource("berry_bush", _rand_point(100, 3050, W - 100, shore_y - 80))
	for i in 18:
		spawn_resource("berry_bush", _rand_point(100, 1750, W - 100, 3150))
	spawn_resource("berry_bush", _point_near(spawn_point, 280, 380))
	spawn_resource("berry_bush", _point_near(spawn_point, 300, 420))

	# Iron: rust-streaked rocks out on the tundra and in the far north
	for i in 16:
		spawn_resource("iron_rock", _rand_point(150, 150, W - 150, 1650))

	# Abandoned sites with loot crates
	for site in SITES:
		var deco := Sprite2D.new()
		deco.texture = load("res://art/%s.png" % site["art"])
		deco.centered = false
		deco.offset = Vector2(-deco.texture.get_width() / 2.0, -deco.texture.get_height() + 4.0)
		deco.position = site["pos"]
		world.add_child(deco)
		var i := 0
		for loot in site["crates"]:
			var crate = spawn_resource("crate", site["pos"] + Vector2(-50 + i * 100, 30))
			crate.loot = loot.duplicate()
			i += 1


func zone_at(pos: Vector2) -> Dictionary:
	for z in ZONES:
		if pos.y >= z["from_y"]:
			return z
	return ZONES[ZONES.size() - 1]


func zone_cold(pos: Vector2) -> float:
	return zone_at(pos)["cold"]


func spawn_resource(kind: String, pos: Vector2, amount: int = 1):
	var r = ResourceNodeScript.new()
	r.main = self
	r.kind = kind
	r.amount = amount
	r.position = pos
	world.add_child(r)
	if _building:
		r.map_id = map_nodes.size()
		map_nodes.append(r)
	return r


func spawn_meat(pos: Vector2, amount: int) -> void:
	spawn_loot(pos, {"raw_meat": amount})


## Drops a pile of items (meat, hides, bones) on the ground.
func spawn_loot(pos: Vector2, items: Dictionary) -> void:
	var r = ResourceNodeScript.new()
	r.main = self
	r.kind = "loot"
	r.loot = items
	r.position = pos
	world.add_child(r)


# ---------- Day / night ----------

func _process(delta: float) -> void:
	_shake = maxf(_shake - delta * 30.0, 0.0)
	cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	if game_over or sleeping:
		return
	play_time += delta
	var prev := time_of_day
	time_of_day += delta / DAY_LENGTH
	if time_of_day >= 1.0:
		time_of_day -= 1.0
		day += 1
	if _crossed(prev, time_of_day, DUSK_START):
		hud.show_message("The sun is setting. Get to your fire or igloo.", 5.0)
	if _crossed(prev, time_of_day, NIGHT_START):
		_on_nightfall()
	if _crossed(prev, time_of_day, MORNING):
		_on_morning()
	_update_lighting()


func _crossed(a: float, b: float, mark: float) -> bool:
	if b >= a:
		return a < mark and b >= mark
	return a < mark or b >= mark  # wrapped past midnight


func get_night_factor() -> float:
	var t := time_of_day
	if t >= MORNING and t < DUSK_START:
		return 0.0
	if t >= DUSK_START and t < NIGHT_START:
		return (t - DUSK_START) / (NIGHT_START - DUSK_START)
	if t >= DAWN_START and t < MORNING:
		return 1.0 - (t - DAWN_START) / (MORNING - DAWN_START)
	return 1.0


func is_night() -> bool:
	return get_night_factor() >= 0.5


func phase_name() -> String:
	var t := time_of_day
	if t >= MORNING and t < DUSK_START:
		return "Day"
	if t >= DUSK_START and t < NIGHT_START:
		return "Dusk"
	if t >= DAWN_START and t < MORNING:
		return "Dawn"
	return "Night"


func clock_text() -> String:
	var mins := int(time_of_day * 24.0 * 60.0)
	return "%02d:%02d" % [int(mins / 60.0), mins % 60]


func _update_lighting() -> void:
	var nf := get_night_factor()
	var day_col := Color(1, 1, 1)
	var dusk_col := Color(0.95, 0.72, 0.62)
	var night_col := Color(0.11, 0.13, 0.26)
	var c := day_col.lerp(dusk_col, minf(nf * 2.0, 1.0))
	c = c.lerp(night_col, maxf((nf - 0.5) * 2.0, 0.0))
	canvas_mod.color = c


func _on_nightfall() -> void:
	for h in get_tree().get_nodes_in_group("hare"):
		h.queue_free()
	var count := mini(day + 1, MAX_WOLVES)
	if player.position.y < 3200.0:
		count += 2  # the wilds are more dangerous
	for i in count:
		var w = WolfScript.new()
		w.main = self
		w.variant = zone_at(player.position)["wolf"]
		var a := rng.randf() * TAU
		var p: Vector2 = player.position + Vector2(cos(a), sin(a)) * rng.randf_range(550, 750)
		p.x = clampf(p.x, 30, world_size.x - 30)
		p.y = clampf(p.y, 30, shore_y - 20)
		w.position = p
		world.add_child(w)
	hud.show_message("Night falls. Wolves howl in the distance...", 5.0)
	audio.play("howl", null, -3.0, 0.05)


func _on_morning() -> void:
	for w in get_tree().get_nodes_in_group("wolf"):
		w.leave()
	for n in get_tree().get_nodes_in_group("daily"):
		n.new_day()
	_spawn_hares()
	_spawn_predators()
	if day > WIN_DAYS and not milestone_shown:
		milestone_shown = true
		hud.show_message("You've survived %d nights! The real test lies north: deadlier animals,\nbrutal cold, and old wrecks with steel and rare furs. Gear up and skill up." % WIN_DAYS, 10.0)
	_spoil_food()
	if day > 1:
		save_game()
		if not game_over:
			hud.show_message("Day %d. You made it through the night! (Game saved)" % day, 5.0)
		audio.play("chime", null, -6.0, 0.0)


func _spawn_hares() -> void:
	var have := get_tree().get_nodes_in_group("hare").size()
	for i in maxi(HARES_PER_DAY - have, 0):
		var h = HareScript.new()
		h.main = self
		h.position = _away_from_spawn(150, 700, world_size.x - 150, shore_y - 80, 250)
		world.add_child(h)


## Bears up north and wolf packs at their dens, topped up every morning.
func _spawn_predators() -> void:
	var have := {"polar": 0, "great": 0}
	for b in get_tree().get_nodes_in_group("bear"):
		have[b.variant] += 1
	for i in maxi(BEARS - have["polar"], 0):
		_spawn_bear("polar", rng.randf_range(650, 1600))
	for i in maxi(GREAT_BEARS - have["great"], 0):
		_spawn_bear("great", rng.randf_range(100, 550))
	for bdef in BOSSES:
		if bdef["variant"] in bosses_killed:
			continue
		var alive := false
		for n in get_tree().get_nodes_in_group("boss"):
			if n.variant == bdef["variant"]:
				alive = true
		if not alive:
			var boss = (WolfScript if bdef["kind"] == "wolf" else BearScript).new()
			boss.main = self
			boss.variant = bdef["variant"]
			boss.position = bdef["pos"]
			boss.home = bdef["pos"]
			world.add_child(boss)
	var at_den := {}
	for w in get_tree().get_nodes_in_group("wolf"):
		if w.resident:
			at_den[w.home] = int(at_den.get(w.home, 0)) + 1
	for den in DENS:
		var spot: Vector2 = den[0]
		for i in maxi(3 - int(at_den.get(spot, 0)), 0):
			var w = WolfScript.new()
			w.main = self
			w.resident = true
			w.variant = den[1]
			w.home = spot
			w.position = _away_from_player(spot.x + rng.randf_range(-80, 80), spot.y + rng.randf_range(-80, 80))
			world.add_child(w)


func _spawn_bear(kind: String, y: float) -> void:
	var b = BearScript.new()
	b.main = self
	b.variant = kind
	b.position = _away_from_player(rng.randf_range(100, world_size.x - 100), y)
	b.home = b.position
	world.add_child(b)


func _away_from_player(x: float, y: float) -> Vector2:
	var p := Vector2(x, y)
	if player != null and p.distance_to(player.position) < 500.0:
		p += (p - player.position).normalized() * 500.0
	p.x = clampf(p.x, 40, world_size.x - 40)
	p.y = clampf(p.y, 40, shore_y - 40)
	return p


# ---------- Bosses and guidance ----------

func boss_defeated(variant: String, boss_name: String) -> void:
	if not variant in bosses_killed:
		bosses_killed.append(variant)
	var unlocks := ""
	for b in BOSSES:
		if b["variant"] == variant:
			unlocks = b["unlocks"]
	audio.play("chime", null, 0.0, 0.0, 0.8)
	shake(12.0)
	hud.show_message("%s is dead!\nIts trophy lets you craft %s at a workbench." % [boss_name, unlocks], 8.0)
	save_game()


## What the player should do next, as [text, world position or null].
func current_goal() -> Array:
	var p = player
	var home = get_home()
	if get_tree().get_nodes_in_group("fire").is_empty() and stats.get("fires", 0) == 0:
		return ["Gather sticks, flint and stone (E), then build a campfire (Tab)", null]
	var has_igloo := false
	for ig in get_tree().get_nodes_in_group("igloo"):
		if ig.is_complete():
			has_igloo = true
	if not has_igloo and home == null:
		return ["Build an igloo (6 snow blocks from drifts) to hide from storms", null]
	if p.tools["axe"] == 0:
		return ["Craft a stone axe (Tab) and chop trees for logs", null]
	if home == null:
		return ["Pick a home spot and build your cabin floor (Tab)", null]
	if home.level < 3:
		return ["Haul logs home and finish your cabin's %s" % home.STAGES[home.level]["name"], home.center()]
	if get_tree().get_nodes_in_group("structure").filter(func(st): return st.kind == "workbench").is_empty():
		return ["Build a workbench near home (Tab) for better gear", null]
	if p.tools["spear"] == 0 and p.tools["bow"] == 0:
		return ["Make a spear or a bow and go hunting", null]
	if not p.gear["coat"]:
		return ["Hunt for hides and make fur clothes at the workbench", null]
	if p.armor == 0:
		return ["Collect bones and make bone armor before the bosses", null]
	for b in BOSSES:
		if not b["variant"] in bosses_killed:
			var bname: String = (WolfScript if b["kind"] == "wolf" else BearScript).VARIANTS[b["variant"]]["name"]
			return ["Boss: defeat %s in the %s" % [bname, b["zone"].to_lower()], b["pos"]]
	if p.armor < 3:
		return ["Craft frost king armor from the White King's pelt", null]
	return ["You rule the north. Keep surviving!", null]


func float_text(pos: Vector2, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	l.position = pos + Vector2(-12 + randf_range(-6, 6), -10)
	l.z_index = 90
	add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 26.0, 0.7)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.3)
	tw.tween_callback(l.queue_free)


## A tiny freeze on a solid hit, so blows feel heavy.
func hit_stop() -> void:
	Engine.time_scale = 0.05
	get_tree().create_timer(0.05, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)


## A small health/fuel bar drawn by any world object, centred at pos.
func draw_bar(ci: CanvasItem, pos: Vector2, width: float, frac: float, color: Color) -> void:
	var r := Rect2(pos.x - width / 2.0, pos.y, width, 4)
	ci.draw_rect(r.grow(1.0), Color(0, 0, 0, 0.6))
	ci.draw_rect(Rect2(r.position, Vector2(width * clampf(frac, 0.0, 1.0), 4)), color)


# ---------- Effects ----------

func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


## A little burst of particles (snow, sparks, fur) at a world position.
func puff(pos: Vector2, color: Color, amount: int = 10, speed: float = 50.0) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.z_index = 20
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.6
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2(0, 120)
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = color
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)


func add_footprint(pos: Vector2, is_paw: bool = false) -> void:
	fx.add_print(pos, is_paw)


# ---------- Queries used by player and wolves ----------

func make_light_texture() -> Texture2D:
	if _light_tex:
		return _light_tex
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 256
	t.height = 256
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	_light_tex = t
	return t


func get_fire_heat(pos: Vector2) -> float:
	var best := 0.0
	for f in get_tree().get_nodes_in_group("fire"):
		best = maxf(best, f.heat_at(pos))
	return best


func get_nearby_fire(pos: Vector2, max_dist: float):
	var best = null
	var bd := max_dist
	for f in get_tree().get_nodes_in_group("fire"):
		if f.is_lit():
			var d := pos.distance_to(f.position)
			if d < bd:
				bd = d
				best = f
	return best


## The shelter (finished igloo, or cabin with walls) you're standing in, or null.
func get_shelter_at(pos: Vector2):
	for group in ["igloo", "cabin"]:
		for sh in get_tree().get_nodes_in_group(group):
			if sh.is_shelter_ready() and sh.contains(pos):
				return sh
	return null


func get_igloo_at(pos: Vector2):
	return get_shelter_at(pos)


func get_home():
	var cabins := get_tree().get_nodes_in_group("cabin")
	return cabins[0] if cabins.size() > 0 else null


## True when the player is somewhere wolves won't follow (firelight or a finished igloo).
func is_safe_spot(pos: Vector2) -> bool:
	return fear_push(pos) != Vector2.ZERO


## If pos is inside a place wolves fear, returns the direction out of it.
func fear_push(pos: Vector2) -> Vector2:
	for f in get_tree().get_nodes_in_group("fire"):
		if f.is_lit() and pos.distance_to(f.position) < f.fear_radius():
			return (pos - f.position).normalized()
	for group in ["igloo", "cabin", "structure"]:
		for sh in get_tree().get_nodes_in_group(group):
			if sh.blocks_at(pos):
				var away: Vector2 = pos - sh.center()
				return away.normalized() if away.length() > 0.1 else Vector2.DOWN
	return Vector2.ZERO


# ---------- Crafting ----------

## The recipes worth showing right now (upgrades appear once you own the tier below).
func get_recipes() -> Array:
	var out := []
	for r in RECIPES:
		if r.has("tool"):
			var have: int = int(player.tools[r["tool"]])
			if have != int(r["tier"]) - 1:
				continue
		if r.has("gear") and player.gear[r["gear"]]:
			continue
		if r.has("needs_gear") and not player.gear[r["needs_gear"]]:
			continue
		if r["key"] == "coat" and player.gear["polar_coat"]:
			continue
		if r.has("armor") and player.armor != int(r["armor"]) - 1:
			continue
		if r["key"] == "cabin" and get_home() != null:
			continue
		if r["key"] == "workbench" and near_workbench():
			continue
		out.append(r)
	return out


## Returns "" if the player can craft recipe r, otherwise what's missing.
func missing_for(r: Dictionary) -> String:
	var inv: Dictionary = player.inventory
	var key: String = r["key"]
	var missing := []
	var cost: Dictionary = r["cost"]
	for item in cost:
		if inv[item] < cost[item]:
			missing.append("%d %s" % [cost[item] - inv[item], hud.item_name(item).to_lower()])
	if key == "campfire" and inv["stone"] < 1:
		missing.append("a stone")
	if r.has("trophy") and inv.get(r["trophy"], 0) < 1:
		missing.append("a trophy from %s" % TROPHY_FROM[r["trophy"]])
	if r.get("bench", false) and not near_workbench():
		missing.append("a workbench nearby")
	if missing.is_empty():
		return ""
	return "need " + ", ".join(PackedStringArray(missing))


## Crafts the n-th recipe of the current list (1-based).
func try_craft(which: int) -> void:
	var list := get_recipes()
	if which < 1 or which > list.size():
		return
	craft(list[which - 1])


func craft(r: Dictionary) -> void:
	var miss := missing_for(r)
	if miss != "":
		hud.show_message("%s: %s." % [r["name"], miss])
		return
	var key: String = r["key"]
	var place: Vector2 = player.position + player.facing * 22.0
	place.x = clampf(place.x, 30, world_size.x - 30)
	place.y = clampf(place.y, 30, shore_y + 40)
	if key == "campfire":
		for f in get_tree().get_nodes_in_group("fire"):
			if f.position.distance_to(place) < 40:
				hud.show_message("There's already a fire here.")
				return
	elif key == "cabin":
		if get_home() != null:
			hud.show_message("You already have a cabin. Keep building it up!")
			return
		place = player.position + player.facing * 70.0 + Vector2(0, 40)
		place.x = clampf(place.x, 80, world_size.x - 80)
		place.y = clampf(place.y, 120, shore_y - 10)
	elif key == "igloo":
		place = player.position + player.facing * 50.0
		place.x = clampf(place.x, 50, world_size.x - 50)
		place.y = clampf(place.y, 50, shore_y)
		for ig in get_tree().get_nodes_in_group("igloo"):
			if ig.position.distance_to(place) < 110:
				hud.show_message("Too close to another igloo.")
				return
	var cost: Dictionary = r["cost"]
	for item in cost:
		player.inventory[item] -= cost[item]
	if key in ["workbench", "chest", "rack", "snare", "fence", "beacon"]:
		var st = StructureScript.new()
		st.main = self
		st.kind = key
		st.position = player.position + player.facing * 26.0
		world.add_child(st)
		audio.play("place_block", st.position)
		puff(st.position, Color(0.8, 0.7, 0.55), 8)
		hud.show_toast("Built: %s" % r["name"])
		if key == "beacon":
			hud.show_message("Signal beacon built! Press E on it to start calling for rescue.", 6.0)
		hud.set_craft_open(false)
		return
	match key:
		"campfire":
			var fire = FireScript.new()
			fire.main = self
			fire.position = place
			world.add_child(fire)
			audio.play("ignite", place)
			puff(place, Color(1.0, 0.7, 0.3), 14)
			stats["fires"] = int(stats.get("fires", 0)) + 1
			hud.show_message("You strike flint against stone... the tinder catches!\nFeed the fire with sticks (E) or it will burn out.", 6.0)
		"igloo":
			var igloo = IglooScript.new()
			igloo.main = self
			igloo.position = place
			world.add_child(igloo)
			hud.show_message("Igloo marked. Cut snow blocks from snow drifts,\nthen hold E at the igloo to place them (0/%d)." % igloo.blocks_needed(), 6.0)
		"cabin":
			var cabin = CabinScript.new()
			cabin.main = self
			cabin.position = place
			world.add_child(cabin)
			hud.show_message("Cabin site marked. Haul logs back here and hold E to build:\nfloor (6 logs), walls (10), roof and door (8 logs, 4 stone), then a stove.", 8.0)
		"axe", "axe_bone", "axe_iron":
			player.tools["axe"] = int(r["tier"])
			hud.show_message("%s made. Hold E at a tree to chop it for logs." % r["name"], 5.0)
		"rod":
			player.tools["rod"] = 1
			hud.show_message("Fishing rod made. Stand on ice (the frozen lake up north, or the sea ice by the coast) and press E.", 6.0)
		"spear", "spear_bone", "spear_iron", "bow":
			var tool: String = r["tool"]
			player.tools[tool] = int(r["tier"])
			player.weapon = tool
			hud.show_message("%s made and in hand. F switches weapons." % r["name"], 5.0)
		"armor_bone", "armor_iron", "armor_frost":
			player.armor = int(r["armor"])
			hud.show_message("%s on. Animals hurt you less." % r["name"], 5.0)
		"axe_steel":
			player.tools["axe"] = 4
			hud.show_message("Steel axe made. Trees don't stand a chance.", 5.0)
		"spear_steel":
			player.tools["spear"] = 4
			player.weapon = "spear"
			hud.show_message("Steel spear made and in hand.", 5.0)
		"mittens", "boots", "coat", "polar_coat":
			player.gear[key] = true
			hud.show_message("%s on. You'll feel the cold a little less." % r["name"], 5.0)
		"arrows":
			player.inventory["arrows"] += 5
			hud.show_toast("+5 arrows")
		"torch":
			player.inventory["torch"] += 1
			hud.show_message("Torch made. Press T to light it.", 4.0)
	audio.play("pickup", null, -4.0)
	hud.set_craft_open(false)


func near_workbench() -> bool:
	for st in get_tree().get_nodes_in_group("structure"):
		if st.kind == "workbench" and st.position.distance_to(player.position) < 140.0:
			return true
	return false


## Frozen lake on the tundra, or the sea ice along the coast.
func on_ice(pos: Vector2) -> bool:
	if pos.y > shore_y + 8.0:
		return true
	var d := Vector2((pos.x - 3000.0) / 600.0, (pos.y - 1150.0) / 240.0)
	return d.length() < 0.9


func shoot_arrow(from: Vector2, dir: Vector2) -> void:
	var a = ArrowScript.new()
	a.main = self
	a.shooter = player
	a.dir = dir
	a.position = from
	add_child(a)


## True when standing under a tree's branches (softens hail).
func under_tree(pos: Vector2) -> bool:
	for t in get_tree().get_nodes_in_group("tree"):
		if not t.chopped and pos.distance_to(t.position) < 16.0 * t.size:
			return true
	return false


# ---------- Sleep ----------

func try_sleep() -> void:
	var shelter = get_shelter_at(player.position)
	if shelter == null or not shelter.storm_proof():
		hud.show_message("You can only sleep inside a finished igloo or cabin.")
		return
	if not (time_of_day >= 0.62 or time_of_day < DAWN_START):
		hud.show_message("It's too early to sleep. Use the daylight!")
		return
	sleeping = true
	hud.play_sleep(_finish_sleep)


func _finish_sleep() -> void:
	var shelter = get_shelter_at(player.position)
	var had_fire: bool = get_fire_heat(player.position) > 0.0 or (shelter != null and shelter.heat() > 0.0)
	var t := time_of_day
	var skipped := (MORNING - t) if t < MORNING else (1.0 - t + MORNING)
	if t >= MORNING:
		day += 1
	time_of_day = MORNING
	for f in get_tree().get_nodes_in_group("fire"):
		f.burn(skipped * DAY_LENGTH * 0.5)
	for c in get_tree().get_nodes_in_group("cabin"):
		c.stove_fuel = maxf(c.stove_fuel - skipped * DAY_LENGTH * 0.5, 0.0)
	for w in get_tree().get_nodes_in_group("wolf"):
		w.queue_free()
	if weather.is_storm():
		weather.end_storm(true)
	var sleep_msg: String = player.apply_sleep(had_fire)
	sleeping = false
	_update_lighting()
	if game_over:
		return
	_on_morning()
	if not game_over:
		hud.show_message("Day %d. %s" % [day, sleep_msg], 6.0)


# ---------- End of game ----------

func on_player_died(cause: String) -> void:
	if game_over:
		return
	game_over = true
	hud.show_end(false, "You died from %s." % cause)


## Half of the meat and fish you carry goes bad overnight. Jerky and chest food keep.
func _spoil_food() -> void:
	var lost := 0
	for item in ["raw_meat", "cooked_meat", "raw_fish", "cooked_fish"]:
		var n: int = player.inventory[item]
		var bad := int(n / 2.0)
		player.inventory[item] -= bad
		lost += bad
	if lost > 0:
		hud.show_toast("%d pieces of meat and fish went bad overnight" % lost)


## The nearest abandoned site you haven't searched yet, for the HUD.
func nearest_site_hint() -> String:
	var best := ""
	var bd := INF
	for site in SITES:
		var searched := true
		for c in get_tree().get_nodes_in_group("crate"):
			if c.uses > 0 and c.position.distance_to(site["pos"]) < 200.0:
				searched = false
		if searched:
			continue
		var d: float = player.position.distance_to(site["pos"])
		if d < bd:
			bd = d
			best = "Rumor: a %s, %dm %s" % [site["name"], int(d / 10.0), hud.compass(site["pos"] - player.position)]
	return best


# ---------- Starting, saving and loading ----------

func start_new_game() -> void:
	delete_save()
	hud.hide_title()
	get_tree().paused = false


func continue_game() -> bool:
	var data := read_save()
	if data.is_empty():
		return false
	load_game(data)
	hud.hide_title()
	get_tree().paused = false
	return true


## Reloads the whole scene, then starts it the given way ("new" or "continue").
func restart(mode: String) -> void:
	start_mode = mode
	get_tree().paused = false
	get_tree().reload_current_scene()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)


func read_save() -> Dictionary:
	if not has_save():
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	return data if data is Dictionary else {}


func save_game() -> void:
	var map := []
	for n in map_nodes:
		if not is_instance_valid(n) or n.is_queued_for_deletion():
			map.append(-2)
		elif n.is_in_group("tree"):
			map.append(-2 if n.chopped else n.hp)
		else:
			map.append(n.uses)
	var fires := []
	for f in get_tree().get_nodes_in_group("fire"):
		fires.append([f.position.x, f.position.y, f.fuel])
	var igloos := []
	for ig in get_tree().get_nodes_in_group("igloo"):
		igloos.append([ig.position.x, ig.position.y, ig.blocks])
	var cabin = null
	var home = get_home()
	if home != null:
		cabin = [home.position.x, home.position.y, home.level, home.paid, home.stove_fuel]
	var structures := []
	for st in get_tree().get_nodes_in_group("structure"):
		structures.append({"kind": st.kind, "x": st.position.x, "y": st.position.y, "storage": st.storage,
			"drying": st.drying, "jerky": st.ready_jerky, "caught": st.caught, "on": st.transmitting})
	var loot := []
	for l in get_tree().get_nodes_in_group("loot"):
		if not l.is_queued_for_deletion():
			loot.append([l.position.x, l.position.y, l.loot])
	var data := {
		"version": 1,
		"day": day, "time": time_of_day, "play_time": play_time, "endless": endless, "stats": stats,
		"rescue_day": rescue_day, "milestone": milestone_shown, "bosses": bosses_killed, "structures": structures,
		"player": {
			"x": player.position.x, "y": player.position.y,
			"temp": player.temp, "hunger": player.hunger, "energy": player.energy, "health": player.health,
			"inventory": player.inventory, "tools": player.tools, "gear": player.gear,
			"weapon": player.weapon, "torch_time": player.torch_time,
			"skills": player.skills, "armor": player.armor,
		},
		"map": map, "fires": fires, "igloos": igloos, "cabin": cabin, "loot": loot,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Could not save the game.")
		return
	f.store_string(JSON.stringify(data))
	f.close()


func load_game(data: Dictionary) -> void:
	day = int(data.get("day", 1))
	time_of_day = float(data.get("time", MORNING))
	play_time = float(data.get("play_time", 0.0))
	endless = bool(data.get("endless", false))
	rescue_day = int(data.get("rescue_day", 0))
	milestone_shown = bool(data.get("milestone", false))
	bosses_killed = []
	for b in data.get("bosses", []):
		bosses_killed.append(str(b))
	for n in get_tree().get_nodes_in_group("boss"):
		if n.variant in bosses_killed:
			n.queue_free()
	for sd in data.get("structures", []):
		var st = StructureScript.new()
		st.main = self
		st.kind = str(sd["kind"])
		st.position = Vector2(float(sd["x"]), float(sd["y"]))
		var stor: Dictionary = sd.get("storage", {})
		for k in stor:
			st.storage[k] = int(stor[k])
		for t in sd.get("drying", []):
			st.drying.append(float(t))
		st.ready_jerky = int(sd.get("jerky", 0))
		st.caught = bool(sd.get("caught", false))
		st.transmitting = bool(sd.get("on", false))
		world.add_child(st)
	var saved_stats: Dictionary = data.get("stats", {})
	for k in saved_stats:
		stats[k] = int(saved_stats[k])
	var p: Dictionary = data.get("player", {})
	player.position = Vector2(float(p.get("x", spawn_point.x)), float(p.get("y", spawn_point.y)))
	player.temp = float(p.get("temp", 85.0))
	player.hunger = float(p.get("hunger", 90.0))
	player.energy = float(p.get("energy", 100.0))
	player.health = float(p.get("health", 100.0))
	var inv: Dictionary = p.get("inventory", {})
	for k in inv:
		player.inventory[k] = int(inv[k])
	var tools: Dictionary = p.get("tools", {})
	for k in tools:
		player.tools[k] = int(tools[k])
	var gear: Dictionary = p.get("gear", {})
	for k in gear:
		player.gear[k] = bool(gear[k])
	player.weapon = str(p.get("weapon", "hands"))
	player.armor = int(p.get("armor", 0))
	var sk: Dictionary = p.get("skills", {})
	for k in sk:
		if player.skills.has(k):
			player.skills[k] = {"level": int(sk[k]["level"]), "xp": int(sk[k]["xp"])}
	player.max_health = 100.0 + 10.0 * (player.skill("toughness") - 1)
	player.torch_time = float(p.get("torch_time", 0.0))

	var map: Array = data.get("map", [])
	for i in mini(map.size(), map_nodes.size()):
		var n = map_nodes[i]
		var v := int(map[i])
		if n.is_in_group("tree"):
			if v == -2:
				n.chopped = true
				n.remove_from_group("interactable")
			else:
				n.hp = v
			n.queue_redraw()
		elif v == -2:
			n.queue_free()
		else:
			n.uses = v
			n.queue_redraw()
	for f in data.get("fires", []):
		var fire = FireScript.new()
		fire.main = self
		fire.position = Vector2(float(f[0]), float(f[1]))
		fire.fuel = float(f[2])
		world.add_child(fire)
	for g in data.get("igloos", []):
		var igloo = IglooScript.new()
		igloo.main = self
		igloo.position = Vector2(float(g[0]), float(g[1]))
		world.add_child(igloo)
		igloo.blocks = int(g[2])
		if igloo.is_complete():
			igloo.remove_from_group("interactable")
	var c = data.get("cabin", null)
	if c is Array:
		var cabin = CabinScript.new()
		cabin.main = self
		cabin.position = Vector2(float(c[0]), float(c[1]))
		cabin.level = int(c[2])
		var paid: Dictionary = c[3]
		for k in paid:
			cabin.paid[k] = int(paid[k])
		cabin.stove_fuel = float(c[4])
		world.add_child(cabin)
	for l in data.get("loot", []):
		var items := {}
		var raw: Dictionary = l[2]
		for k in raw:
			items[k] = int(raw[k])
		spawn_loot(Vector2(float(l[0]), float(l[1])), items)
	for h in get_tree().get_nodes_in_group("hare"):
		if h.position.distance_to(player.position) < 300.0:
			h.position.y -= 400.0
	_update_lighting()
	hud.show_message("Welcome back. Day %d." % day, 4.0)
