extends Line2D

@export var tracking_node: AbstractBinding
@export var segments := 128

func _ready():
	if tracking_node == null:
		push_error("SOI Line: tracking_node not set")
		return
	draw_soi()

func _process(_delta):
	# Optional: update if SOI changes dynamically
	draw_soi()

func draw_soi():
	var r := tracking_node.get_soi_radius()
	clear_points()

	for i in range(segments + 1):
		var angle := TAU * i / segments
		add_point(Vector2(cos(angle), sin(angle)) * r)
