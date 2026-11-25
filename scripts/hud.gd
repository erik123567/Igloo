extends CanvasLayer
## On-screen display: stat bars, clock, inventory, prompts, messages, crafting menu,
## help, pause, sleep fade and the win/lose screen.

const ITEM_NAMES := {
	"sticks": "Sticks", "flint": "Flint", "stone": "Stone", "snow_block": "Snow blocks",
	"berries": "Berries", "raw_meat": "Raw meat", "cooked_meat": "Cooked meat",
}

const HELP_TEXT := """CONTROLS  (H to hide)
Move: WASD or arrow keys
Sprint: Shift (uses energy)
Gather / use: E (hold to repeat)
Crafting menu: Tab
Eat: Q
Cook meat at a fire: C
Attack / hunt: Space
Sleep in a finished igloo: Z
Pause: Esc

SURVIVE 3 NIGHTS
1. Pick up sticks, flint and a stone.
2. Tab, then 1: build a campfire.
3. Tab, then 2: mark an igloo.
4. Cut snow blocks from drifts and
   place them on the igloo (E).
5. Light a fire inside, then sleep (Z)."""

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
var _craft: PanelContainer
var _craft_label: Label
var _fade: ColorRect
var _end_box: CenterContainer
var _end_title: Label
var _end_text: Label
var _pause_box: CenterContainer


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
	_wide(_prompt, 1.0, -96.0, -66.0)
	root.add_child(_prompt)

	_toast = _label(17, HORIZONTAL_ALIGNMENT_LEFT)
	_wide(_toast, 1.0, -68.0, -44.0)
	_toast.offset_left = 16
	root.add_child(_toast)

	_inv = _label(17, HORIZONTAL_ALIGNMENT_LEFT)
	_wide(_inv, 1.0, -38.0, -10.0)
	_inv.offset_left = 16
	root.add_child(_inv)

	# Help panel, right side
	_help = PanelContainer.new()
	_help.add_theme_stylebox_override("panel", _panel_style())
	_help.anchor_left = 1.0
	_help.anchor_right = 1.0
	_help.offset_left = -330
	_help.offset_right = -12
	_help.offset_top = 130
	var help_label := _label(15, HORIZONTAL_ALIGNMENT_LEFT)
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

	# Sleep fade
	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)

	# Pause
	_pause_box = CenterContainer.new()
	_pause_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pause_label := _label(40, HORIZONTAL_ALIGNMENT_CENTER)
	pause_label.text = "PAUSED\n(Esc to resume)"
	_pause_box.add_child(pause_label)
	_pause_box.visible = false
	root.add_child(_pause_box)

	# Win / lose screen
	_end_box = CenterContainer.new()
	_end_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var end_panel := PanelContainer.new()
	var end_style := _panel_style()
	end_style.bg_color = Color(0.03, 0.05, 0.09, 0.88)
	end_style.set_content_margin_all(28)
	end_panel.add_theme_stylebox_override("panel", end_style)
	var end_vb := VBoxContainer.new()
	_end_title = _label(44, HORIZONTAL_ALIGNMENT_CENTER)
	_end_text = _label(20, HORIZONTAL_ALIGNMENT_CENTER)
	end_vb.add_child(_end_title)
	end_vb.add_child(_end_text)
	end_panel.add_child(end_vb)
	_end_box.add_child(end_panel)
	_end_box.visible = false
	root.add_child(_end_box)


# ---------- Builders ----------

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


func show_toast(text: String) -> void:
	_toast.text = text
	_toast_time = 2.0


func set_craft_open(open: bool) -> void:
	craft_open = open
	_craft.visible = open


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
	if won:
		_end_text.text = text + "\n\nEnter: keep playing      R: start over"
	else:
		_end_text.text = text + "\n\nPress R to try again"
	_end_box.visible = true


func hide_end() -> void:
	_end_box.visible = false


# ---------- Update ----------

func _process(delta: float) -> void:
	if player == null:
		return
	_bars["Body temp"].value = player.temp
	_bars["Hunger"].value = player.hunger
	_bars["Energy"].value = player.energy
	_bars["Health"].value = player.health

	_clock.text = "Day %d   %s   %s" % [main.day, main.clock_text(), main.phase_name()]

	var parts := []
	for key in ["sticks", "flint", "stone", "snow_block", "berries", "raw_meat", "cooked_meat"]:
		parts.append("%s %d" % [ITEM_NAMES[key], player.inventory[key]])
	_inv.text = "   ".join(PackedStringArray(parts))

	var t = player.target
	_prompt.text = t.get_prompt(player) if (t != null and is_instance_valid(t) and not main.game_over) else ""

	_status.text = _status_text()

	_message_time -= delta
	_message.modulate.a = clampf(_message_time, 0.0, 1.0)
	_toast_time -= delta
	_toast.modulate.a = clampf(_toast_time, 0.0, 1.0)

	if craft_open:
		_craft_label.text = _craft_text()


func _status_text() -> String:
	var lines := []
	if player.warmth_source == "fire":
		lines.append("Warming by the fire")
	elif player.warmth_source == "igloo":
		lines.append("Sheltered in the igloo")
	if player.temp < 25.0:
		lines.append("You're freezing! Get to a fire.")
	if player.hunger < 15.0:
		lines.append("You're starving. Eat something (Q).")
	if player.energy < 10.0:
		lines.append("Exhausted. Stand still to rest.")
	return "\n".join(PackedStringArray(lines))


func _craft_text() -> String:
	var inv: Dictionary = player.inventory
	var fire_missing := []
	if inv["sticks"] < 3:
		fire_missing.append("%d sticks" % (3 - inv["sticks"]))
	if inv["flint"] < 1:
		fire_missing.append("1 flint")
	if inv["stone"] < 1:
		fire_missing.append("a stone")
	var fire_state := "READY" if fire_missing.is_empty() else "need " + ", ".join(PackedStringArray(fire_missing))
	return "CRAFTING   (Tab to close)\n\n[1]  Campfire: 3 sticks + 1 flint, struck with a stone   (%s)\n[2]  Igloo foundation: free. Fill it with 10 snow blocks." % fire_state


func _unhandled_input(event: InputEvent) -> void:
	if main == null:
		return
	if event.is_action_pressed("pause") and not main.game_over:
		get_tree().paused = not get_tree().paused
		_pause_box.visible = get_tree().paused
	elif event.is_action_pressed("toggle_help"):
		_help.visible = not _help.visible
	elif event.is_action_pressed("craft_menu") and not get_tree().paused and not main.game_over:
		set_craft_open(not craft_open)
		get_viewport().set_input_as_handled()
	elif main.game_over:
		if event.is_action_pressed("restart"):
			get_tree().paused = false
			get_tree().reload_current_scene()
		elif event.is_action_pressed("continue") and main.won:
			main.continue_endless()
