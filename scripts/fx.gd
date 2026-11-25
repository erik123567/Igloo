extends Node2D
## Footprints left in the snow. They slowly fade away.

const LIFETIME := 30.0
const MAX_PRINTS := 400

var _prints: Array = []   # each entry: [position, age, is_paw]


func _ready() -> void:
	z_index = -5


func add_print(pos: Vector2, is_paw: bool) -> void:
	_prints.append([pos, 0.0, is_paw])
	if _prints.size() > MAX_PRINTS:
		_prints.pop_front()


func _process(delta: float) -> void:
	var i := 0
	while i < _prints.size():
		_prints[i][1] += delta
		if _prints[i][1] > LIFETIME:
			_prints.remove_at(i)
		else:
			i += 1
	queue_redraw()


func _draw() -> void:
	for p in _prints:
		var a: float = 0.45 * (1.0 - p[1] / LIFETIME)
		var c := Color(0.62, 0.7, 0.84, a)
		var pos: Vector2 = p[0]
		if p[2]:
			draw_rect(Rect2(pos.x - 1, pos.y - 1, 2, 2), c)
		else:
			draw_rect(Rect2(pos.x - 1.5, pos.y - 1, 3, 2), c)
