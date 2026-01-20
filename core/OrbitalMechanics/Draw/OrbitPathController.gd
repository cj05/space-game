extends Node2D
class_name OrbitPathController

@export var max_points = 200
@export var line_width = 2.0
@export_group("Colors")
@export var elliptic_color = Color.AQUA
@export var hyperbola_future_color = Color(1.0, 0.4, 0.4) # Warm Red/Orange
@export var past_trail_color = Color(1, 1, 0.5,0.5) # Faded Gray
@export var trail_alpha = 0.2
@export_range(1, 6) var smooth_stages = 4

var segments = []


# ------------------------------------------------------------
# Lifecycle
# ------------------------------------------------------------

func _ready():
	top_level = true
	_clear_segments()


func _physics_process(_dt):
	var state = get_parent()
	if not state:
		return
	if not state is AbstractBinding:
		return

	_draw_orbit(state)


# ------------------------------------------------------------
# Segment management
# ------------------------------------------------------------

func _clear_segments():
	for s in segments:
		s.queue_free()
	segments.clear()


func _new_segment():
	var line = Line2D.new()
	line.width = line_width or 1
	line.top_level = true
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.gradient = Gradient.new()
	add_child(line)
	segments.append(line)
	return line


# ------------------------------------------------------------
# Orbit drawing
# ------------------------------------------------------------

func _draw_orbit(state):
	_clear_segments()

	var solver = state.sim_solver
	if not solver:
		return

	if solver.alpha > 0.0:
		_draw_elliptic(state, solver)
	else:
		_draw_hyperbolic(state, solver)


# ------------------------------------------------------------
# Elliptic (single closed segment)
# ------------------------------------------------------------

func _draw_elliptic(state, solver):
	var line = _new_segment()
	var pts = []
	var nu0 = solver.get_true_anomaly()
	
	# --- 1. Determine SOI Limits ---
	var soi_r = state.get_parent_soi()
	var e = solver.ecc
	var a = solver.sma
	var p_parameter = a * (1.0 - e * e)
	
	var nu_min = -PI
	var nu_max = PI
	
	# If apoapsis exceeds SOI, calculate the exit/entry angles
	var apoapsis = a * (1.0 + e)
	if apoapsis > soi_r:
		var cos_nu_soi = ((p_parameter / soi_r) - 1.0) / e
		# Ensure we stay within acos range [-1, 1]
		var safe_cos = clamp(cos_nu_soi, -1.0, 1.0)
		var nu_soi = acos(safe_cos)
		
		nu_min = -nu_soi
		nu_max = nu_soi

	# --- 2. Sampling ---
	# We sample from nu_min to nu_max to respect the SOI boundaries
	var dnu = (nu_max - nu_min) / max_points

	for i in range(max_points + 1):
		var nu = nu_min + float(i) * dnu
		var p = state.sample_ta(nu)
		pts.append(p - global_position)

	# If the orbit is a closed loop (doesn't hit SOI), 
	# we want the line to connect perfectly at the end.
	if apoapsis <= soi_r:
		pts.append(pts[0])

	_apply_points(line, pts, elliptic_color)


# ------------------------------------------------------------
# Hyperbolic / Parabolic (two disjoint branches)
# ------------------------------------------------------------
# Add this at the top with other variables
var debug_timer = 0.0

func _draw_hyperbolic(state, solver):
	var e = solver.ecc
	if e <= 1.0:
		return

	# --- 1. Calculate the Mathematical Asymptote (Infinity) ---
	var nu_inf = acos(-1.0 / e)
	var eps = 0.01 # Safety buffer to prevent coordinate explosion
	var nu_limit = nu_inf - eps
	
	# --- 2. Calculate the SOI Cap ---
	var soi_r = state.get_parent_soi()
	var a = solver.sma
	var p_parameter = abs(a) * (e * e - 1.0)
	
	# Check if the SOI radius is reached before the asymptote
	var cos_nu_soi = ((p_parameter / soi_r) - 1.0) / e
	if abs(cos_nu_soi) < 1.0:
		# Use whichever is smaller: the SOI angle or the safety limit
		nu_limit = min(nu_limit, acos(cos_nu_soi))

	var nu_min = -nu_limit
	var nu_max =  nu_limit

	# --- 3. Current true anomaly (standardized to -PI, PI) ---
	var nu0 = solver.get_true_anomaly()
	while nu0 > PI:  nu0 -= TAU
	while nu0 < -PI: nu0 += TAU
	nu0 = clamp(nu0, nu_min, nu_max)

	# --- 4. Sampling ---
	var past_line   = _new_segment()
	var future_line = _new_segment()
	var all_pts = []
	var nu_samples = []
	var dnu = (nu_max - nu_min) / float(max_points)

	for i in range(max_points + 1):
		var nu = nu_min + float(i) * dnu
		var p = state.sample_ta(nu)
		
		# Hard safety check for coordinate explosion
		if not is_finite(p.x) or p.length() > 2_000_000:
			continue

		all_pts.append(p - global_position)
		nu_samples.append(nu)

	if all_pts.size() < 2:
		return

	# --- 5. Topological Split ---
	var split_idx = -1
	for i in range(nu_samples.size()):
		if nu_samples[i] >= nu0:
			split_idx = i
			break

	var past_pts = []
	var future_pts = []
	if split_idx == -1:
		past_pts = all_pts
	else:
		past_pts   = all_pts.slice(0, split_idx + 1)
		future_pts = all_pts.slice(split_idx, all_pts.size())

	# Ensure both lines meet exactly at the ship's position
	var ship_pos = state.sample_ta(nu0) - global_position
	if past_pts.size() > 0: past_pts[past_pts.size() - 1] = ship_pos
	if future_pts.size() > 0: future_pts[0] = ship_pos
		
	# --- 6. Directional Handling (CCW vs CW) ---
	var is_ccw = state.get_angular_momentum() > 0
	if not is_ccw:
		# Swap and reverse so gradients always fade AWAY from the ship
		var temp = past_pts
		past_pts = future_pts
		future_pts = temp
		future_pts.reverse()
		past_pts.reverse()
	
	_apply_points(past_line, past_pts, past_trail_color)
	_apply_points(future_line, future_pts, hyperbola_future_color)
# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

func _clamp_hyperbolic_nu(nu, nu_lim):
	if nu >  nu_lim:
		return  nu_lim
	if nu < -nu_lim:
		return -nu_lim
	return nu


func _adaptive_nu_step(r):
	return clamp(40.0 / max(r, 1.0), 0.002, 0.05)


func _apply_points(line: Line2D, pts: Array, base_color: Color):
	if pts.size() < 2: return

	var curve = Curve2D.new()
	for i in range(pts.size()):
		var p = pts[i]
		if i < pts.size() - 1:
			var h = (pts[i + 1] - p) * 0.33
			curve.add_point(p, Vector2.ZERO, h)
		else:
			curve.add_point(p)

	line.points = curve.tessellate_even_length(smooth_stages, 4.0)
	_update_gradient(line, line.points.size(), base_color)

func _update_gradient(line: Line2D, n: int, base_color: Color):
	if n < 2: return

	var offsets = PackedFloat32Array()
	var colors = PackedColorArray()

	for i in range(n):
		var t = float(i) / float(n - 1)
		# Future lines fade out as they get further away
		# Past lines fade in (or out) depending on preference
		var alpha = (1.0 - t) * (base_color.a - trail_alpha) + trail_alpha
		
		offsets.append(t)
		colors.append(Color(base_color.r, base_color.g, base_color.b, alpha))

	line.gradient.offsets = offsets
	line.gradient.colors = colors
	
func radial_velocity(solver):
	return solver.r.dot(solver.v)
