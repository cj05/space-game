extends Line2D
class_name LineTracer

@export var tracking_node: Node2D

@export var max_points := 200
@export var sample_distance := 5.0   # meters / units
@export var line_width := 2.0

@export var fade_strength := 10.0  # higher = sharper fade
@export var color = Color(0.5,0.5,0.7,1)


var _last_sample_pos: Vector2
var _points := PackedVector2Array()

func _ready():
	width = line_width
	if(not gradient):
		gradient = Gradient.new()
	clear_points()

func _physics_process(_dt):
	var parent := tracking_node
	if parent == null:
		return

	var pos := parent.global_position

	if _points.is_empty():
		_add_point(pos)
		_last_sample_pos = pos
		return

	if pos.distance_to(_last_sample_pos) >= sample_distance:
		_add_point(pos)
		_last_sample_pos = pos

func _add_point(world_pos: Vector2):
	_points.append(world_pos)

	if _points.size() > max_points:
		_points.remove_at(0)

	_rebuild_line()

var _gradient: Gradient


func _rebuild_line():
	clear_points()

	for p in _points:
		add_point(p - global_position)

	_update_gradient()

func _update_gradient():
	var gradient_data := {}

	var n := _points.size()
	if n < 2:
		gradient_data[0.0] = color
		return

	for i in range(n):
		var t := float(max_points-n+i) / float(max_points)  # 0 = oldest, 1 = newest
		#print(t)
		# inverse-log fade
		var alpha := log(1.0 + fade_strength * t) / log(1.0 + fade_strength)
		
		color.a = alpha
		gradient_data[t] = color
	#print(gradient_data)

	gradient.offsets = gradient_data.keys()
	gradient.colors = gradient_data.values()
