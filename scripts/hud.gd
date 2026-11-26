extends CanvasLayer
## On-screen display: stat bars, clock, inventory, prompts, messages, crafting menu,
## help, pause, sleep fade and the win/lose screen.

const ITEM_NAMES := {
	"sticks": "Sticks", "flint": "Flint", "stone": "Stone", "snow_block": "Snow blocks",
	"berries": "Berries", "raw_meat": "Raw meat", "cooked_meat": "Cooked meat",
	"logs": "Logs", "arrows": "Arrows", "torch": "Torches",
	"hide": "Hides", "bone": "Bones", "iron": "Iron",
	"raw_fish": "Raw fish", "cooked_fish": "Cooked fish", "jerky": "Jerky", "radio_part": "Radio parts",
	"white_fur": "White fur", "steel": "Steel",
	"alpha_fang": "Alpha fang (trophy)", "great_claw": "Great claw (trophy)", "king_pelt": "King's pelt (trophy)",
}

const HELP_TEXT := """CONTROLS  (H to hide)
Move: WASD    Sprint: Shift
Gather / use / chop: E (hold)
Attack: left click (aims at mouse)
  or Space (aims for you)
Dodge roll: right click or Ctrl
Switch weapon: F    Torch: T
Crafting: Tab    Inventory: I
Eat: Q    Cook at a fire: C
Sleep in igloo or cabin: Z
Pause: Esc

FIGHTING
- Click in rhythm: the 3rd hit
  of a combo is a big finisher.
- Animals crouch (!) before they
  bite and can't stop once they
  start. Dodge, then punish them
  while they recover.
- Dodge right as a hit lands for
  slow-mo and a critical hit.
- Bears show a red circle before
  they swipe. Get out of it!
- Each zone has a boss. Beat it
  for a trophy that unlocks
  better gear.

Follow the "Next:" line at the
top right if you're unsure."""

var main
var player
var craft_open := false

var _bars := {}
var _clock: Label
var _inv: Label
var _prompt: Label
var _message: Label
var _message_time := 0.0
var _toast: Label
var _toast_time := 0.0
var _status: Label
var _help: PanelContainer
var _skills: Label
var _boss_box: VBoxContainer
var _boss_name: Label
var _boss_bar: ProgressBar
var _inv_panel: PanelContainer
var _inv_label: Label
var _craft: PanelContainer
var _craft_label: Label
var _fade: ColorRect
var _end_box: CenterContainer
var _end_title: Label
var _end_text: Label
var _pause_box: CenterContainer
var _end_buttons: HBoxContainer
var _title_box: CenterContainer
var _title_text: Label
var _title_buttons: HBoxContainer
var craft_index := 0
var _frost: TextureRect
var _hurt_vignette: TextureRect
var _hurt_time := 0.0
var _blizzard: TextureRect
var _gear: Label


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Stat bars, top left
	var stats := PanelContainer.new()
	stats.add_theme_stylebox_override("panel", _panel_style())
	stats.position = Vector2(12, 12)
	root.add_child(stats)
	var vb := VBoxContainer.new()
	stats.add_child(vb)
	_add_bar(vb, "Body temp", Color(0.95, 0.5, 0.2))
	_add_bar(vb, "Hunger", Color(0.85, 0.7, 0.25))
	_add_bar(vb, "Energy", Color(0.35, 0.75, 0.95))
	_add_bar(vb, "Health", Color(0.85, 0.2, 0.25))
	_skills = _label(13, HORIZONTAL_ALIGNMENT_LEFT)
	vb.add_child(_skills)

	_clock = _label(22, HORIZONTAL_ALIGNMENT_RIGHT)
	_wide(_clock, 0.0, 12.0, 50.0)
	_clock.offset_right = -16
	root.add_child(_clock)

	_status = _label(17, HORIZONTAL_ALIGNMENT_RIGHT)
	_wide(_status, 0.0, 44.0, 70.0)
	_status.offset_right = -16
	root.add_child(_status)

	_message = _label(20, HORIZONTAL_ALIGNMENT_CENTER)
	_wide(_message, 0.0, 120.0, 220.0)
	root.add_child(_message)

	_prompt = _label(19, HORIZONTAL_ALIGNMENT_CENTER)
	_wide(_prompt, 1.0, -126.0, -96.0)
	root.add_child(_prompt)

	_toast = _label(17, HORIZONTAL_ALIGNMENT_LEFT)
	_wide(_toast, 1.0, -92.0, -68.0)
	_toast.offset_left = 16
	root.add_child(_toast)

	_gear = _label(17, HORIZONTAL_ALIGNMENT_RIGHT)
	_wide(_gear, 1.0, -38.0, -10.0)
	_gear.offset_right = -16
	root.add_child(_gear)

	_inv = _label(16, HORIZONTAL_ALIGNMENT_LEFT)
	_inv.autowrap_mode = TextServer.AUTOWRAP_WORD
	_wide(_inv, 1.0, -62.0, -10.0)
	_inv.offset_right = -330
	_inv.offset_left = 16
	root.add_child(_inv)

	# Boss health bar, top centre
	_boss_box = VBoxContainer.new()
	_boss_box.anchor_left = 0.5
	_boss_box.anchor_right = 0.5
	_boss_box.offset_left = -220
	_boss_box.offset_right = 220
	_boss_box.offset_top = 70
	_boss_box.visible = false
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_name = _label(18, HORIZONTAL_ALIGNMENT_CENTER)
	_boss_box.add_child(_boss_name)
	_boss_bar = ProgressBar.new()
	_boss_bar.show_percentage = false
	_boss_bar.custom_minimum_size = Vector2(440, 14)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.05, 0.05, 0.8)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color(0.8, 0.12, 0.12)
	_boss_bar.add_theme_stylebox_override("background", bg)
	_boss_bar.add_theme_stylebox_override("fill", fg)
	_boss_box.add_child(_boss_bar)
	root.add_child(_boss_box)

	# Inventory and equipment screen (I)
	var inv_center := CenterContainer.new()
	inv_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	inv_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(inv_center)
	_inv_panel = PanelContainer.new()
	_inv_panel.add_theme_stylebox_override("panel", _panel_style())
	_inv_panel.visible = false
	inv_center.add_child(_inv_panel)
	_inv_label = _label(16, HORIZONTAL_ALIGNMENT_LEFT)
	_inv_label.custom_minimum_size = Vector2(640, 0)
	_inv_panel.add_child(_inv_label)

	# Help panel, right side
	_help = PanelContainer.new()
	_help.add_theme_stylebox_override("panel", _panel_style())
	_help.anchor_left = 1.0
	_help.anchor_right = 1.0
	_help.offset_left = -330
	_help.offset_right = -12
	_help.offset_top = 110
	var help_label := _label(13, HORIZONTAL_ALIGNMENT_LEFT)
	help_label.text = HELP_TEXT
	_help.add_child(help_label)
	root.add_child(_help)

	# Crafting menu, centre
	var craft_center := CenterContainer.new()
	craft_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	craft_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(craft_center)
	_craft = PanelContainer.new()
	_craft.add_theme_stylebox_override("panel", _panel_style())
	_craft_label = _label(18, HORIZONTAL_ALIGNMENT_LEFT)
	_craft.add_child(_craft_label)
	_craft.visible = false
	craft_center.add_child(_craft)

	# Edge vignettes: frost when freezing, red when hurt
	_frost = _vignette(Color(0.7, 0.85, 1.0, 0.85))
	root.add_child(_frost)
	_hurt_vignette = _vignette(Color(0.8, 0.05, 0.05, 0.7))
	root.add_child(_hurt_vignette)
	_blizzard = _vignette(Color(0.93, 0.95, 1.0, 1.0), 0.0, Color(0.93, 0.95, 1.0, 0.45))
	root.add_child(_blizzard)
	root.move_child(_blizzard, 0)

	# Sleep fade
	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)

	# Pause menu, end screen and title screen
	var pause := _make_menu(root)
	_pause_box = pause[0]
	pause[1].text = "PAUSED"
	pause[2].text = "Your game is saved every morning.\nSaving here lets you pick up exactly where you left off."
	_add_button(pause[3], "Resume", func(): _set_paused(false))
	_add_button(pause[3], "Save and quit to title", _save_and_quit)

	var end := _make_menu(root)
	_end_box = end[0]
	_end_title = end[1]
	_end_text = end[2]
	_end_buttons = end[3]

	var title := _make_menu(root, true)
	_title_box = title[0]
	title[1].text = "IGLOO"
	title[1].add_theme_font_size_override("font_size", 72)
	title[1].add_theme_color_override("font_color", Color(0.85, 0.93, 1.0))
	_title_text = title[2]
	_title_buttons = title[3]


## Builds a centred dark panel with a title, a text and a row of buttons.
## Returns [container, title label, text label, button row].
func _make_menu(root: Control, dim_background: bool = false) -> Array:
	var box := CenterContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dim_background:
		var dim := ColorRect.new()
		dim.color = Color(0.02, 0.04, 0.08, 0.55)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(dim)
		box.visibility_changed.connect(func(): dim.visible = box.visible)
	var panel := PanelContainer.new()
	var style := _panel_style()
	style.bg_color = Color(0.03, 0.05, 0.09, 0.9)
	style.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", style)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	var t := _label(44, HORIZONTAL_ALIGNMENT_CENTER)
	var body := _label(19, HORIZONTAL_ALIGNMENT_CENTER)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	vb.add_child(t)
	vb.add_child(body)
	vb.add_child(row)
	panel.add_child(vb)
	box.add_child(panel)
	box.visible = false
	root.add_child(box)
	return [box, t, body, row]


func _add_button(row: HBoxContainer, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = "  " + text + "  "
	b.add_theme_font_size_override("font_size", 20)
	b.custom_minimum_size = Vector2(0, 44)
	b.pressed.connect(action)
	row.add_child(b)
	return b


func _clear_buttons(row: HBoxContainer) -> void:
	for c in row.get_children():
		row.remove_child(c)
		c.queue_free()


func _save_and_quit() -> void:
	main.save_game()
	main.restart("title")


func _set_paused(on: bool) -> void:
	get_tree().paused = on
	_pause_box.visible = on
	if on:
		var first: Button = _pause_box.get_child(0).get_child(0).get_child(2).get_child(0)
		first.grab_focus()


# ---------- Builders ----------

func _vignette(edge: Color, clear_until: float = 0.55, center: Color = Color(0, 0, 0, 0)) -> TextureRect:
	var g := Gradient.new()
	var mid := center if center.a > 0.0 else Color(edge, 0.0)
	g.offsets = PackedFloat32Array([0.0, maxf(clear_until, 0.01), 1.0])
	g.colors = PackedColorArray([mid, mid, edge])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var r := TextureRect.new()
	r.texture = tex
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.modulate.a = 0.0
	return r


func _panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.04, 0.07, 0.12, 0.72)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(10)
	return s


func _flat(c: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(3)
	return s


func _label(font_size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	return l


## Stretches a label across the screen width at a fixed height.
## anchor_y 0 = measured from the top, 1 = measured from the bottom.
func _wide(l: Label, anchor_y: float, top: float, bottom: float) -> void:
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.anchor_top = anchor_y
	l.anchor_bottom = anchor_y
	l.offset_left = 0
	l.offset_right = 0
	l.offset_top = top
	l.offset_bottom = bottom


func _add_bar(parent: Control, title: String, color: Color) -> void:
	var row := HBoxContainer.new()
	var name_label := _label(15, HORIZONTAL_ALIGNMENT_LEFT)
	name_label.text = title
	name_label.custom_minimum_size = Vector2(90, 0)
	row.add_child(name_label)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(170, 16)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	bar.max_value = 100
	bar.add_theme_stylebox_override("fill", _flat(color))
	bar.add_theme_stylebox_override("background", _flat(Color(0, 0, 0, 0.5)))
	row.add_child(bar)
	parent.add_child(row)
	_bars[title] = bar


# ---------- Public ----------

func item_name(item: String) -> String:
	return ITEM_NAMES.get(item, item)


func show_message(text: String, duration: float = 4.0) -> void:
	_message.text = text
	_message_time = duration


func flash_damage() -> void:
	_hurt_time = 0.5


func show_toast(text: String) -> void:
	_toast.text = text
	_toast_time = 2.0


func set_craft_open(open: bool) -> void:
	craft_open = open
	_craft.visible = open
	if open:
		_help.visible = false


func play_sleep(on_dark: Callable) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 1.0)
	tw.tween_callback(on_dark)
	tw.tween_interval(0.8)
	tw.tween_property(_fade, "color:a", 0.0, 1.0)


func show_end(won: bool, text: String) -> void:
	set_craft_open(false)
	_end_title.text = "YOU SURVIVED!" if won else "YOU DIED"
	_end_title.add_theme_color_override("font_color", Color(1, 0.85, 0.4) if won else Color(1, 0.4, 0.4))
	var st: Dictionary = main.stats
	_end_text.text = "%s\n\nSurvived: %s\nWolves killed: %d    Polar bears: %d    Hares caught: %d" % [
		text, main.survived_text(), st["wolves"], st["bears"], st["hares"]]
	_clear_buttons(_end_buttons)
	var first: Button
	if won:
		first = _add_button(_end_buttons, "Keep playing", func(): main.continue_endless())
		_add_button(_end_buttons, "New game", func(): main.restart("new"))
	else:
		if main.has_save():
			first = _add_button(_end_buttons, "Retry from this morning", func(): main.restart("continue"))
			_add_button(_end_buttons, "New game", func(): main.restart("new"))
		else:
			first = _add_button(_end_buttons, "Try again", func(): main.restart("new"))
	_end_box.visible = true
	first.grab_focus()


func hide_end() -> void:
	_end_box.visible = false


func show_title(has_save: bool, saved_day: int) -> void:
	_title_text.text = "Survive the Arctic.\nKeep warm, build shelter, and make it through the nights."
	_clear_buttons(_title_buttons)
	var first: Button
	if has_save:
		first = _add_button(_title_buttons, "Continue (day %d)" % saved_day, func(): main.continue_game())
		_add_button(_title_buttons, "New game", func(): main.start_new_game())
	else:
		first = _add_button(_title_buttons, "Start", func(): main.start_new_game())
	_title_box.visible = true
	first.grab_focus()


func hide_title() -> void:
	_title_box.visible = false


# ---------- Update ----------

func _process(delta: float) -> void:
	if player == null:
		return
	_bars["Body temp"].value = player.temp
	_bars["Hunger"].value = player.hunger
	_bars["Energy"].value = player.energy
	_bars["Health"].value = player.health

	_clock.text = "Day %d   %s   %s   |   %s   |   %s" % [main.day, main.clock_text(), main.phase_name(), main.weather.label(), main.zone_at(player.position)["name"]]
	_clock.text += "  " + "!".repeat(int(main.zone_at(player.position)["danger"]))
	var sk := []
	for k in ["hunting", "toughness", "survival", "gathering"]:
		var lv: int = player.skill(k)
		var pct := 100 if lv >= player.MAX_SKILL else int(100.0 * player.skills[k]["xp"] / player.xp_needed(lv))
		sk.append("%s %d (%d%%)" % [k.capitalize(), lv, pct])
	_skills.text = "Skills  " + "  ".join(PackedStringArray(sk.slice(0, 2))) + "\n        " + "  ".join(PackedStringArray(sk.slice(2)))

	var parts := []
	for key in ITEM_NAMES:
		if player.inventory.get(key, 0) > 0:
			parts.append("%s %d" % [ITEM_NAMES[key], player.inventory[key]])
	_inv.text = "   ".join(PackedStringArray(parts)) if not parts.is_empty() else "Your pack is empty"

	var t = player.target
	var prey = player.prey
	if main.game_over:
		_prompt.text = ""
	elif prey != null and is_instance_valid(prey):
		_prompt.text = "[Space] Hit the %s" % prey.display_name
	elif t != null and is_instance_valid(t):
		_prompt.text = t.get_prompt(player)
	else:
		_prompt.text = player.fishing_prompt()

	_status.text = _status_text()
	var boss = null
	var bd := 650.0
	for b in get_tree().get_nodes_in_group("boss"):
		var d: float = b.position.distance_to(player.position)
		if d < bd and not b.is_queued_for_deletion():
			bd = d
			boss = b
	_boss_box.visible = boss != null
	if boss != null:
		_boss_name.text = boss.display_name
		_boss_bar.max_value = boss.max_hp()
		_boss_bar.value = maxf(boss.hp, 0.0)
	if _inv_panel.visible:
		_inv_label.text = inventory_text()
	var gear := "Holding: %s" % player.weapon.capitalize()
	if player.weapon == "bow":
		gear += " (%d arrows)" % player.inventory["arrows"]
	var tiers := ["", "Stone", "Bone", "Iron", "Steel"]
	if player.weapon == "spear":
		gear = "Holding: %s spear" % tiers[int(player.tools["spear"])]
	if int(player.tools["axe"]) > 0:
		gear += "   %s axe" % tiers[int(player.tools["axe"])]
	var worn := []
	for g in ["mittens", "boots", "coat", "polar_coat"]:
		if player.gear[g] and not (g == "coat" and player.gear["polar_coat"]):
			worn.append(g.replace("_", " "))
	if not worn.is_empty():
		gear += "   Fur %s (-%d%% cold)" % [", ".join(PackedStringArray(worn)), int(round((1.0 - player.gear_cold_factor()) * 100.0))]
	if player.armor > 0:
		gear += "   %s armor" % ["", "Bone", "Iron", "Frost king"][player.armor]
	if player.torch_time > 0.0:
		gear += "   Torch: %ds" % int(player.torch_time)
	_gear.text = gear
	var inside: bool = main.get_igloo_at(player.position) != null
	_blizzard.modulate.a = main.weather.blizzard * (0.25 if inside else 0.95)

	_message_time -= delta
	_message.modulate.a = clampf(_message_time, 0.0, 1.0)
	_toast_time -= delta
	_toast.modulate.a = clampf(_toast_time, 0.0, 1.0)

	if craft_open:
		_craft_label.text = _craft_text()

	_frost.modulate.a = clampf((40.0 - player.temp) / 40.0, 0.0, 1.0)
	_hurt_time = maxf(_hurt_time - delta, 0.0)
	var low_health := clampf((30.0 - player.health) / 30.0, 0.0, 1.0) * (0.35 + 0.15 * sin(Time.get_ticks_msec() / 200.0))
	_hurt_vignette.modulate.a = maxf(_hurt_time * 2.0, low_health)


func _status_text() -> String:
	var lines := []
	if player.warmth_source == "fire":
		lines.append("Warming by the fire")
	elif player.warmth_source != "":
		lines.append("Sheltered in the %s" % player.warmth_source)
	var home = main.get_home()
	if home != null and not home.contains(player.position):
		var to: Vector2 = home.center() - player.position
		lines.append("Home: %dm %s" % [int(to.length() / 10.0), compass(to)])
	var goal: Array = main.current_goal()
	var gl := "Next: %s" % goal[0]
	if goal[1] != null:
		var gto: Vector2 = goal[1] - player.position
		gl += " (%dm %s)" % [int(gto.length() / 10.0), compass(gto)]
	lines.append(gl)
	if main.milestone_shown:
		var hint: String = main.nearest_site_hint()
		if hint != "":
			lines.append(hint)
	var sh = main.get_shelter_at(player.position)
	if main.weather.is_storm() and (sh == null or not sh.storm_proof()):
		lines.append("Storm! Get inside an igloo.")
	if player.temp < 25.0:
		lines.append("You're freezing! Get to a fire.")
	if player.hunger < 15.0:
		lines.append("You're starving. Eat something (Q).")
	if player.energy < 10.0:
		lines.append("Exhausted. Stand still to rest.")
	return "\n".join(PackedStringArray(lines))


func compass(v: Vector2) -> String:
	var names := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]
	var idx := int(round(v.angle() / (TAU / 8.0))) % 8
	if idx < 0:
		idx += 8
	return names[idx]


func _craft_text() -> String:
	var list: Array = main.get_recipes()
	craft_index = clampi(craft_index, 0, maxi(list.size() - 1, 0))
	var lines := ["CRAFTING    W/S or arrows to choose, E or Enter to make, Tab to close", ""]
	var i := 0
	for r in list:
		var cost_parts := []
		for item in r["cost"]:
			cost_parts.append("%d %s" % [r["cost"][item], item_name(item).to_lower()])
		var cost := "free" if cost_parts.is_empty() else ", ".join(PackedStringArray(cost_parts))
		var miss: String = main.missing_for(r)
		var state := "READY" if miss == "" else miss
		var note: String = r["note"]
		var cursor := ">> " if i == craft_index else "     "
		lines.append("%s%s: %s%s   (%s)" % [cursor, r["name"], cost, (" - " + note) if note != "" else "", state])
		i += 1
	return "\n".join(PackedStringArray(lines))


## Called by the player every frame while the crafting menu is open.
func handle_craft_keys() -> void:
	var count: int = main.get_recipes().size()
	if count == 0:
		return
	if Input.is_action_just_pressed("move_down"):
		craft_index = (craft_index + 1) % count
	elif Input.is_action_just_pressed("move_up"):
		craft_index = (craft_index - 1 + count) % count
	elif Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("continue"):
		main.try_craft(craft_index + 1)


func _unhandled_input(event: InputEvent) -> void:
	if main == null or _title_box.visible:
		return
	if event.is_action_pressed("pause") and not main.game_over:
		_set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory") and not main.game_over:
		_inv_panel.visible = not _inv_panel.visible
		if _inv_panel.visible:
			set_craft_open(false)
	elif event.is_action_pressed("toggle_help"):
		_help.visible = not _help.visible
	elif event.is_action_pressed("craft_menu") and not get_tree().paused and not main.game_over:
		set_craft_open(not craft_open)
		get_viewport().set_input_as_handled()


## The full inventory / equipment / skills screen.
func inventory_text() -> String:
	var tiers := ["-", "Stone", "Bone", "Iron", "Steel"]
	var t := "INVENTORY   (I to close)\n\nWEARING & EQUIPPED\n"
	t += "  In hand: %s" % player.weapon.capitalize()
	if player.weapon == "spear":
		t += " (%s, %.1f damage)" % [tiers[int(player.tools["spear"])], (1 + int(player.tools["spear"])) * player.damage_mult()]
	t += "\n  Tools: axe %s, spear %s, bow %s, fishing rod %s\n" % [tiers[int(player.tools["axe"])],
		tiers[int(player.tools["spear"])], "yes" if player.tools["bow"] else "-", "yes" if player.tools["rod"] else "-"]
	var clothes := []
	for g in ["mittens", "boots", "coat", "polar_coat"]:
		if player.gear[g] and not (g == "coat" and player.gear["polar_coat"]):
			clothes.append(g.replace("_", " "))
	t += "  Clothes: %s  (%d%% less cold)\n" % [", ".join(PackedStringArray(clothes)) if not clothes.is_empty() else "none",
		int(round((1.0 - player.gear_cold_factor()) * 100.0))]
	t += "  Armor: %s  (%d%% less damage)\n" % [["none", "bone", "iron", "frost king"][player.armor], [0, 20, 40, 55][player.armor]]
	t += "  Health %d / %d\n\nPACK\n" % [int(player.health), int(player.max_health)]
	var items := []
	for k in player.inventory:
		if player.inventory[k] > 0:
			items.append("%s %d" % [item_name(k), player.inventory[k]])
	if items.is_empty():
		t += "  (empty)\n"
	for i in range(0, items.size(), 4):
		t += "  " + ",   ".join(PackedStringArray(items.slice(i, i + 4))) + "\n"
	t += "\nSKILLS\n"
	for k in ["hunting", "toughness", "survival", "gathering"]:
		var lv: int = player.skill(k)
		var need: int = player.xp_needed(lv)
		t += "  %s  level %d   %s\n" % [k.capitalize(), lv, "MAX" if lv >= player.MAX_SKILL else "%d / %d xp" % [player.skills[k]["xp"], need]]
	t += "\nBOSSES BEATEN: %d / %d" % [main.bosses_killed.size(), main.BOSSES.size()]
	return t


## True when the mouse is busy with a menu, so clicks shouldn't swing.
func mouse_over_ui() -> bool:
	return get_tree().paused or craft_open or _title_box.visible
