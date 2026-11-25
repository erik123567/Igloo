extends Node
## Plays sound effects and the looping wind and fire ambience.

const STREAMS := {
	"step_0": preload("res://sfx/step_0.wav"),
	"step_1": preload("res://sfx/step_1.wav"),
	"step_2": preload("res://sfx/step_2.wav"),
	"pickup": preload("res://sfx/pickup.wav"),
	"gather": preload("res://sfx/gather.wav"),
	"place_block": preload("res://sfx/place_block.wav"),
	"hit": preload("res://sfx/hit.wav"),
	"swing": preload("res://sfx/swing.wav"),
	"hurt": preload("res://sfx/hurt.wav"),
	"bite": preload("res://sfx/bite.wav"),
	"howl": preload("res://sfx/howl.wav"),
	"squeak": preload("res://sfx/squeak.wav"),
	"eat": preload("res://sfx/eat.wav"),
	"ignite": preload("res://sfx/ignite.wav"),
	"chime": preload("res://sfx/chime.wav"),
	"fire_loop": preload("res://sfx/fire_loop.wav"),
	"wind_loop": preload("res://sfx/wind_loop.wav"),
}
const HEARING_RANGE := 700.0

var main
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _wind: AudioStreamPlayer
var _crackle: AudioStreamPlayer


func _ready() -> void:
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_wind = _make_loop("wind_loop")
	_crackle = _make_loop("fire_loop")


func _make_loop(stream_name: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = STREAMS[stream_name]
	p.volume_db = -60.0
	add_child(p)
	p.finished.connect(p.play)
	p.play()
	return p


## Plays a sound. Pass a world position to make it quieter the further away it is.
func play(sound: String, pos = null, volume_db: float = 0.0, pitch_var: float = 0.08) -> void:
	var vol := volume_db
	if pos != null and main != null and main.player != null:
		var d: float = main.player.position.distance_to(pos)
		if d > HEARING_RANGE:
			return
		vol += linear_to_db(clampf(1.0 - d / HEARING_RANGE, 0.05, 1.0))
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = STREAMS[sound]
	p.volume_db = vol
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()


func _process(_delta: float) -> void:
	if main == null or main.player == null:
		return
	var nf: float = main.get_night_factor()
	var inside: bool = main.get_igloo_at(main.player.position) != null
	var wind_level := (0.22 + 0.4 * nf) * (0.3 if inside else 1.0)
	_wind.volume_db = linear_to_db(wind_level)
	var fire_level := 0.0
	var f = main.get_nearby_fire(main.player.position, 400.0)
	if f != null:
		fire_level = clampf(1.0 - main.player.position.distance_to(f.position) / 400.0, 0.0, 1.0)
	_crackle.volume_db = linear_to_db(maxf(fire_level * 0.9, 0.001))
