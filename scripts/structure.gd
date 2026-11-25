extends Node2D
## Things you build around your base: workbench, storage chest, drying rack, snare, fence
## and the signal beacon.

const TEX := {
	"workbench": preload("res://art/workbench.png"),
	"chest": preload("res://art/chest.png"),
	"rack": preload("res://art/rack.png"),
	"rack_full": preload("res://art/rack_full.png"),
	"snare": preload("res://art/snare.png"),
	"fence": preload("res://art/fence.png"),
	"beacon": preload("res://art/beacon.png"),
	"beacon_lit": preload("res://art/beacon_lit.png"),
	"hare": preload("res://art/hare_0.png"),
}
const DRY_TIME := 90.0          # seconds for raw meat or fish to become jerky
const RACK_SLOTS := 8
const SNARE_CHANCE := 0.6       # chance each morning that a set snare has caught a hare
## Items that go into the chest (tools, arrows and torches stay with you).
const STORABLE := ["sticks", "flint", "stone", "snow_block", "logs", "berries", "raw_meat", "cooked_meat",
	"raw_fish", "cooked_fish", "jerky", "hide", "bone", "iron", "radio_part"]

var main
var kind := "workbench"
var interact_radius := 10.0
var storage := {}               # chest contents
var drying: Array = []          # rack: seconds left for each piece
var ready_jerky := 0
var caught := false             # snare
var transmitting := false       # beacon


func _ready() -> void:
	add_to_group("structure")
	if kind != "fence":
		add_to_group("interactable")
	if kind == "snare":
		add_to_group("daily")
	interact_radius = {"workbench": 14.0, "chest": 10.0, "rack": 12.0, "snare": 6.0, "fence": 8.0, "beacon": 12.0}.get(kind, 10.0)


func new_day() -> void:
	if kind == "snare" and not caught and randf() < SNARE_CHANCE:
		caught = true
		queue_redraw()


## Fences keep animals out.
func blocks_at(pos: Vector2) -> bool:
	return kind == "fence" and pos.distance_to(position + Vector2(0, -4)) < 22.0


func center() -> Vector2:
	return position + Vector2(0, -4)


func _count(d: Dictionary) -> int:
	var n := 0
	for k in d:
		n += int(d[k])
	return n


func _has_storable(player) -> bool:
	for item in STORABLE:
		if player.inventory.get(item, 0) > 0:
			return true
	return false


func _has_raw(player) -> bool:
	return player.inventory["raw_meat"] > 0 or player.inventory["raw_fish"] > 0


func get_prompt(player) -> String:
	match kind:
		"workbench":
			return "Workbench: advanced crafting works near here (Tab)"
		"chest":
			if _has_storable(player):
				return "[E] Store everything in the chest (food keeps fresh in here)"
			if _count(storage) > 0:
				return "[E] Take everything out of the chest (%d things)" % _count(storage)
			return "Empty storage chest"
		"rack":
			if ready_jerky > 0:
				return "[E] Take %d jerky off the rack" % ready_jerky
			if _has_raw(player) and drying.size() < RACK_SLOTS:
				return "[E] Hang raw meat and fish to dry (%d drying)" % drying.size()
			if drying.size() > 0:
				return "Drying rack: %d drying, next ready in %ds" % [drying.size(), int(drying.min())]
			return "Drying rack: hang raw meat or fish here to make jerky that never spoils"
		"snare":
			return "[E] Take the hare from the snare" if caught else "Snare set. Check it in the morning."
		"beacon":
			if transmitting:
				return "Beacon transmitting. Rescue arrives the morning of day %d." % main.rescue_day
			return "[E] Switch on the signal beacon"
	return ""


func can_interact(player) -> bool:
	match kind:
		"chest":
			return _has_storable(player) or _count(storage) > 0
		"rack":
			return ready_jerky > 0 or (_has_raw(player) and drying.size() < RACK_SLOTS)
		"snare":
			return caught
		"beacon":
			return not transmitting
	return false


func interact(player) -> void:
	match kind:
		"chest":
			if _has_storable(player):
				for item in STORABLE:
					var n: int = player.inventory.get(item, 0)
					if n > 0:
						storage[item] = int(storage.get(item, 0)) + n
						player.inventory[item] = 0
				main.hud.show_toast("Stored everything in the chest")
			else:
				for item in storage:
					player.inventory[item] = int(player.inventory.get(item, 0)) + int(storage[item])
				storage = {}
				main.hud.show_toast("Took everything out of the chest")
			main.audio.play("place_block", position, -6.0)
		"rack":
			if ready_jerky > 0:
				player.add_item("jerky", ready_jerky)
				ready_jerky = 0
			else:
				for item in ["raw_meat", "raw_fish"]:
					while player.inventory[item] > 0 and drying.size() < RACK_SLOTS:
						player.inventory[item] -= 1
						drying.append(DRY_TIME)
				main.hud.show_toast("Hung up to dry: %d pieces" % drying.size())
		"snare":
			caught = false
			main.spawn_loot(position + Vector2(10, 4), {"raw_meat": 1, "hide": 1} if randf() < 0.5 else {"raw_meat": 1})
			main.stats["hares"] += 1
			main.audio.play("pickup", position)
		"beacon":
			transmitting = true
			main.rescue_day = main.day + 2
			main.audio.play("chime", null, 0.0, 0.0)
			main.shake(4.0)
			main.hud.show_message("The beacon crackles to life and starts calling for help!\nRescue will come the morning of day %d. Stay alive until then." % main.rescue_day, 8.0)
	queue_redraw()


func _process(delta: float) -> void:
	if kind != "rack" or drying.is_empty() or main.game_over or main.sleeping:
		return
	for i in drying.size():
		drying[i] -= delta
	while not drying.is_empty() and drying.min() <= 0.0:
		drying.erase(drying.min())
		ready_jerky += 1
	queue_redraw()


func _draw() -> void:
	var key := kind
	if kind == "rack" and (drying.size() > 0 or ready_jerky > 0):
		key = "rack_full"
	elif kind == "beacon" and transmitting:
		key = "beacon_lit"
	var tex: Texture2D = TEX[key]
	var sz := tex.get_size()
	draw_set_transform(Vector2(0, 1), 0, Vector2(1, 0.3))
	draw_circle(Vector2.ZERO, sz.x * 0.45, Color(0, 0, 0, 0.14))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	draw_texture(tex, Vector2(-floorf(sz.x / 2.0), 2.0 - sz.y))
	if kind == "snare" and caught:
		draw_texture(TEX["hare"], Vector2(2, -8))
	if kind == "beacon" and transmitting and int(Time.get_ticks_msec() / 500.0) % 2 == 0:
		draw_circle(Vector2(0, -36), 4, Color(1, 0.4, 0.3, 0.8))
