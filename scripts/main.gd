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

# ---------- Tuning (change these numbers to balance the game) ----------
const DAY_LENGTH := 360.0      # real seconds for one full day + night
const START_TIME := 0.25       # 0.0 = midnight, 0.25 = 6:00, 0.5 = noon
const DAWN_START := 0.20       # night starts turning to day
const MORNING := 0.28          # full daylight
const DUSK_START := 0.68       # sun starts setting
const NIGHT_START := 0.76      # full night, wolves come out
const WIN_DAYS := 3            # survive this many nights to win
const HARES_PER_DAY := 14
const BEARS := 4
const FOREST_PACKS := [Vector2(1500, 2400), Vector2(4300, 2000), Vector2(2900, 1900)]
const MAX_WOLVES := 5

const RECIPES := [
	{"key": "campfire", "name": "Campfire", "cost": {"sticks": 3, "flint": 1}, "note": "struck with a stone"},
	{"key": "igloo", "name": "Igloo shelter", "cost": {}, "note": "then fill it with 6 snow blocks"},
	{"key": "axe", "name": "Stone axe", "cost": {"sticks": 2, "stone": 1, "flint": 1}, "note": "chop trees for logs"},
	{"key": "spear", "name": "Spear", "cost": {"sticks": 3, "flint": 1}, "note": "hits twice as hard, longer reach"},
	{"key": "bow", "name": "Bow", "cost": {"logs": 1, "sticks": 2}, "note": "shoot arrows from afar"},
	{"key": "arrows", "name": "5 arrows", "cost": {"sticks": 2, "flint": 1}, "note": ""},
	{"key": "torch", "name": "Torch", "cost": {"sticks": 3}, "note": "light and a little warmth, T to light"},
	{"key": "cabin", "name": "Cabin site", "cost": {}, "note": "your home base, build it up with logs"},
]

# Zones get colder the further north you go (smaller y = further north).
const ZONES := [
	{"name": "Coast", "from_y": 3200.0, "cold": 1.0},
	{"name": "Boreal forest", "from_y": 1700.0, "cold": 1.1},
	{"name": "Frozen tundra", "from_y": 600.0, "cold": 1.35},
	{"name": "Far north", "from_y": -99999.0, "cold": 1.7},
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
	_build_map()
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
	return r


func spawn_meat(pos: Vector2, amount: int) -> void:
	spawn_resource("meat", pos, amount)


# ---------- Day / night ----------

func _process(delta: float) -> void:
	_shake = maxf(_shake - delta * 30.0, 0.0)
	cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	if game_over or sleeping:
		return
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
	if day > WIN_DAYS and not endless:
		game_over = true
		won = true
		hud.show_end(true, "You survived %d nights in the Arctic." % WIN_DAYS)
		return
	if day > 1:
		hud.show_message("Day %d. You made it through the night!" % day, 5.0)
		audio.play("chime", null, -6.0, 0.0)


func _spawn_hares() -> void:
	var have := get_tree().get_nodes_in_group("hare").size()
	for i in maxi(HARES_PER_DAY - have, 0):
		var h = HareScript.new()
		h.main = self
		h.position = _away_from_spawn(150, 700, world_size.x - 150, shore_y - 80, 250)
		world.add_child(h)


## Polar bears in the north and wolf packs living in the forest, topped up every morning.
func _spawn_predators() -> void:
	var bears := get_tree().get_nodes_in_group("bear").size()
	for i in maxi(BEARS - bears, 0):
		var b = BearScript.new()
		b.main = self
		b.position = _away_from_player(rng.randf_range(100, world_size.x - 100), rng.randf_range(150, 1500))
		b.home = b.position
		world.add_child(b)
	var residents := 0
	for w in get_tree().get_nodes_in_group("wolf"):
		if w.resident:
			residents += 1
	if residents >= FOREST_PACKS.size() * 2:
		return
	for den in FOREST_PACKS:
		for i in 3:
			var w = WolfScript.new()
			w.main = self
			w.resident = true
			w.home = den
			w.position = _away_from_player(den.x + rng.randf_range(-80, 80), den.y + rng.randf_range(-80, 80))
			world.add_child(w)


func _away_from_player(x: float, y: float) -> Vector2:
	var p := Vector2(x, y)
	if player != null and p.distance_to(player.position) < 500.0:
		p += (p - player.position).normalized() * 500.0
	p.x = clampf(p.x, 40, world_size.x - 40)
	p.y = clampf(p.y, 40, shore_y - 40)
	return p


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
	for group in ["igloo", "cabin"]:
		for sh in get_tree().get_nodes_in_group(group):
			if sh.blocks(pos):
				var away: Vector2 = pos - sh.center()
				return away.normalized() if away.length() > 0.1 else Vector2.DOWN
	return Vector2.ZERO


# ---------- Crafting ----------

func get_recipes() -> Array:
	return RECIPES


## Returns "" if the player can craft recipe r, otherwise what's missing.
func missing_for(r: Dictionary) -> String:
	var inv: Dictionary = player.inventory
	var key: String = r["key"]
	if key in ["axe", "spear", "bow"] and player.tools[key]:
		return "already have one"
	var missing := []
	var cost: Dictionary = r["cost"]
	for item in cost:
		if inv[item] < cost[item]:
			missing.append("%d %s" % [cost[item] - inv[item], hud.item_name(item).to_lower()])
	if key == "campfire" and inv["stone"] < 1:
		missing.append("a stone")
	if missing.is_empty():
		return ""
	return "need " + ", ".join(PackedStringArray(missing))


func try_craft(which: int) -> void:
	if which < 1 or which > RECIPES.size():
		return
	var r: Dictionary = RECIPES[which - 1]
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
	match key:
		"campfire":
			var fire = FireScript.new()
			fire.main = self
			fire.position = place
			world.add_child(fire)
			audio.play("ignite", place)
			puff(place, Color(1.0, 0.7, 0.3), 14)
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
		"axe":
			player.tools["axe"] = true
			hud.show_message("Stone axe made. Hold E at a tree to chop it for logs.", 5.0)
		"spear", "bow":
			player.tools[key] = true
			player.weapon = key
			hud.show_message("%s made and in hand. F switches weapons." % r["name"], 5.0)
		"arrows":
			player.inventory["arrows"] += 5
			hud.show_toast("+5 arrows")
		"torch":
			player.inventory["torch"] += 1
			hud.show_message("Torch made. Press T to light it.", 4.0)
	audio.play("pickup", null, -4.0)
	hud.set_craft_open(false)


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
	var had_fire := get_fire_heat(player.position) > 0.0 or (shelter != null and shelter.heat() > 0.0)
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
	hud.show_end(false, "You died from %s on day %d." % [cause, day])


func continue_endless() -> void:
	endless = true
	game_over = false
	hud.hide_end()
	hud.show_message("Endless mode. How long can you last?", 4.0)
