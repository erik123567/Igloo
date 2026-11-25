extends Node
## Weather: calm snow most of the time, broken up by surprise storms.
## Blizzards: brutal cold, low visibility, slow walking. Hail: hurts you when you're out in the open.
## A finished igloo protects you from both. Standing under a tree softens the hail.

# ---------- Tuning ----------
const FIRST_STORM_MIN := 140.0      # seconds into the game before the first storm can hit
const FIRST_STORM_MAX := 220.0
const CALM_MIN := 110.0             # calm time between storms
const CALM_MAX := 240.0
const WARNING_TIME := 12.0          # seconds of warning before a storm hits
const BLIZZARD_CHANCE := 0.65       # otherwise it's hail
const BLIZZARD_COLD := 2.5          # extra cold multiplier at full blizzard
const HAIL_DAMAGE := 2.0            # health per second in the open during hail

var main
var state := "snow"                 # "clear", "snow", "blizzard", "hail"
var blizzard := 0.0                 # 0..1, eases in and out
var hail := 0.0
var _time_left := 0.0
var _next_in := 0.0
var _warned := false
var _pending := "blizzard"
var _storm_snow: CPUParticles2D
var _hail_fx: CPUParticles2D


func _ready() -> void:
	_next_in = randf_range(FIRST_STORM_MIN, FIRST_STORM_MAX)


## Called once the player exists, to attach storm particles that follow them.
func attach_to(player: Node2D) -> void:
	_storm_snow = CPUParticles2D.new()
	_storm_snow.amount = 500
	_storm_snow.lifetime = 1.6
	_storm_snow.local_coords = false
	_storm_snow.position = Vector2(-380, 0)
	_storm_snow.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_storm_snow.emission_rect_extents = Vector2(60, 260)
	_storm_snow.direction = Vector2(1, 0.25)
	_storm_snow.spread = 10.0
	_storm_snow.gravity = Vector2(0, 20)
	_storm_snow.initial_velocity_min = 380.0
	_storm_snow.initial_velocity_max = 520.0
	_storm_snow.scale_amount_min = 1.0
	_storm_snow.scale_amount_max = 2.5
	_storm_snow.color = Color(1, 1, 1, 0.9)
	_storm_snow.z_index = 60
	_storm_snow.emitting = false
	player.add_child(_storm_snow)

	_hail_fx = CPUParticles2D.new()
	_hail_fx.amount = 260
	_hail_fx.lifetime = 0.6
	_hail_fx.local_coords = false
	_hail_fx.position = Vector2(0, -260)
	_hail_fx.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_hail_fx.emission_rect_extents = Vector2(380, 30)
	_hail_fx.direction = Vector2(0.1, 1)
	_hail_fx.spread = 4.0
	_hail_fx.gravity = Vector2(0, 300)
	_hail_fx.initial_velocity_min = 500.0
	_hail_fx.initial_velocity_max = 650.0
	_hail_fx.scale_amount_min = 1.5
	_hail_fx.scale_amount_max = 2.5
	_hail_fx.color = Color(0.85, 0.9, 1.0, 1.0)
	_hail_fx.z_index = 60
	_hail_fx.emitting = false
	player.add_child(_hail_fx)


func is_storm() -> bool:
	return state == "blizzard" or state == "hail"


func label() -> String:
	match state:
		"blizzard":
			return "BLIZZARD"
		"hail":
			return "HAIL"
		"snow":
			return "Light snow"
	return "Clear"


func cold_multiplier() -> float:
	return 1.0 + (BLIZZARD_COLD - 1.0) * blizzard


func speed_multiplier() -> float:
	return 1.0 - 0.3 * blizzard


func hail_damage() -> float:
	return HAIL_DAMAGE * hail


func start_storm(kind: String) -> void:
	state = kind
	_time_left = randf_range(45.0, 85.0) if kind == "blizzard" else randf_range(20.0, 35.0)
	if kind == "blizzard":
		main.hud.show_message("BLIZZARD! Get inside an igloo or you'll freeze.", 5.0)
	else:
		main.hud.show_message("HAIL! Get under cover: an igloo, or at least a tree.", 5.0)


func end_storm(quietly: bool = false) -> void:
	state = "snow" if randf() < 0.5 else "clear"
	_next_in = randf_range(CALM_MIN, CALM_MAX)
	_warned = false
	if not quietly:
		main.hud.show_message("The storm passes.", 3.0)


func _process(delta: float) -> void:
	if main == null or main.game_over or main.sleeping:
		return
	if is_storm():
		_time_left -= delta
		if _time_left <= 0.0:
			end_storm()
	else:
		_next_in -= delta
		if _next_in <= WARNING_TIME and not _warned:
			_warned = true
			_pending = "blizzard" if randf() < BLIZZARD_CHANCE else "hail"
			main.audio.play("rumble", null, -2.0, 0.05)
			if _pending == "blizzard":
				main.hud.show_message("The wind is picking up fast... a blizzard is coming!", 6.0)
			else:
				main.hud.show_message("Dark clouds roll in... hail is coming!", 6.0)
		if _next_in <= 0.0:
			start_storm(_pending)
	blizzard = move_toward(blizzard, 1.0 if state == "blizzard" else 0.0, delta * 0.5)
	hail = move_toward(hail, 1.0 if state == "hail" else 0.0, delta * 0.8)
	if _storm_snow:
		_storm_snow.emitting = blizzard > 0.15
		_hail_fx.emitting = hail > 0.15
