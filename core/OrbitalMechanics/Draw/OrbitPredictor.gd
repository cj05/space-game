extends Line2D
class_name OrbitPredictor

@export var tracking_node: Node 
@export var max_points := 100
@export var step_size := 0.1
@export var line_width := 2.0
@export var color = Color(0.5, 0.5, 0.7, 1)

@export_range(1, 6) var smooth_stages: int = 4 

func _ready():
	width = line_width
	if not gradient:
		gradient = Gradient.new()
	top_level = true 
	joint_mode = Line2D.LINE_JOINT_ROUND
	begin_cap_mode = Line2D.LINE_CAP_ROUND
	end_cap_mode = Line2D.LINE_CAP_ROUND

func _physics_process(_dt):
	if not tracking_node: return
	var body = tracking_node.get_body()
	if not body: return
	_predict_path(tracking_node)

func _predict_path(state):
	var curve = Curve2D.new()
	var current_anomaly = state.get_true_anomaly()
	var eccentricity = state.get_eccentricity()
	
	# THE FIX: Flip the direction if the line points backward.
	# If your sample() moves backward with a positive orbit_dir, 
	# we multiply by -1.
	var orbit_direction = state.get_orbit_dir()
	if orbit_direction == 0: orbit_direction = 1
	
	# Change this to -1 if the line is still pointing the wrong way
	var direction_multiplier = -1.0 
	
	var is_hyperbolic = eccentricity > 1.0
	var limit_angle = acos(-1.0 / eccentricity) * 0.99 if is_hyperbolic else PI

	var raw_positions = []
	# 1. First point is exactly the ship
	raw_positions.append(state.sample(current_anomaly) - global_position)

	# 2. Prediction loop
	for i in range(1, max_points):
		# We use (+) to go into the future. 
		# If this is wrong for your math, change '+' to '-' below.
		var sample_anomaly = current_anomaly + (i * step_size * orbit_direction * direction_multiplier)
		
		if is_hyperbolic:
			if abs(sample_anomaly) >= limit_angle: break
		else:
			# Wrap the anomaly to keep it in the valid math range (-PI to PI)
			sample_anomaly = fposmod(sample_anomaly + PI, TAU) - PI

		raw_positions.append(state.sample(sample_anomaly) - global_position)

	# 3. Build the Curve
	if raw_positions.size() > 1:
		for i in range(raw_positions.size()):
			var p = raw_positions[i]
			var handle = Vector2.ZERO
			
			# Using a simpler handle calculation to prevent the 'rippling' 
			# and direction confusion at Apoapsis
			if i < raw_positions.size() - 1:
				var next_p = raw_positions[i+1]
				handle = (next_p - p) * 0.33
				# add_point(pos, in_control, out_control)
				# We only need out_control to project forward
				curve.add_point(p, Vector2.ZERO, handle)
			else:
				curve.add_point(p)
		
		# Tessellate to smooth the joints
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
		var alpha = pow(1.0 - t, 2.0) * 0.8 
		
		offsets.append(t)
		colors.append(Color(color.r, color.g, color.b, alpha))

	gradient.offsets = offsets
	gradient.colors = colors
