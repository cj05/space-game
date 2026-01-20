extends Line2D

@export var tracking_node: Node
@export var max_points := 100
@export var step_size := 1
@export var line_width := 2.0
@export var line_color := Color.AQUA

@export_range(1, 6) var smooth_stages: int = 4 
@onready var soi_label := Label.new()



func _ready():
	width = line_width
	if not gradient:
		gradient = Gradient.new()
	top_level = true 
	joint_mode = Line2D.LINE_JOINT_ROUND
	begin_cap_mode = Line2D.LINE_CAP_ROUND
	end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(soi_label)
	soi_label.visible = false
	soi_label.top_level = true
	soi_label.z_index = 100

func _physics_process(_dt):
	if not tracking_node: return
	var body = tracking_node.get_body()
	if not body: return
	_predict_path(tracking_node)

func _predict_path(state:AbstractBinding):
	var curve := Curve2D.new()
	var raw_positions := []

	var solver := state.sim_solver
	if not solver:
		clear_points()
		return

	# --- TA setup ---
	var nu0 := solver.get_true_anomaly()
	var soi_pos = Vector2.ZERO
	# --- SOI TIME LABEL ---
	var t_soi :float = state.get_time_at_soi()
	if t_soi != INF:
		var soi_state := state.sample_t_world(t_soi)
		if soi_state:
			soi_pos = soi_state.r
			soi_label.visible = true
			soi_label.global_position = soi_state.r
			soi_label.text = ("~%.2f" % (t_soi - solver.t)) + " s"
		else:
			soi_label.visible = false
	else:
		soi_label.visible = false

	var dnu := TAU / float(max_points)

	# SOI cutoff (radius-based, geometry only)
	var soi_r :float = state.get_parent_soi()

	# First point (current position)
	var p0 := state.sample_ta(nu0) - global_position
	raw_positions.append(p0)

	for i in range(1, max_points):
		var nu := nu0 + float(i) * dnu

		var p := state.sample_ta(nu)
		print(p)
		if not is_finite(p.x) or not is_finite(p.y):
			print("Finite")
			break

		# --- SOI stop (pure radius check) ---
		if soi_r != INF:
			var local_r := solver.sample_point_at(nu).length()
			if local_r >= soi_r:
				raw_positions.append(soi_pos - global_position)
				print("SOI")
				break

		raw_positions.append(p - global_position)

	# --- Build Curve ---
	if raw_positions.size() > 1:
		for i in range(raw_positions.size()):
			var pt :Vector2 = raw_positions[i]
			if i < raw_positions.size() - 1:
				var handle :Vector2 = (raw_positions[i + 1] - pt) * 0.33
				curve.add_point(pt, Vector2.ZERO, handle)
			else:
				curve.add_point(pt)

		points = curve.tessellate_even_length(smooth_stages, 4.0)
	else:
		clear_points()

	_update_gradient(points.size())



func _update_gradient(n: int):
	if n < 2: return
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()

	for i in range(n):
		# Adjust 't' by the phase so the gradient doesn't "jitter"
		var t := float(i) / float(n - 1)
		
		# Apply quadratic fade
		var x = 0.4
		var alpha = pow(1.0 - t, 2.0) * (1-x) + x
		
		offsets.append(t)
		colors.append(Color(line_color.r, line_color.g, line_color.b, alpha))

	gradient.offsets = offsets
	gradient.colors = colors
