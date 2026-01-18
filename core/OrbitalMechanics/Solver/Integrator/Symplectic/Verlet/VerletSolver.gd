# VerletSolver.gd
# Velocity-Verlet orbital propagator (2D Kepler problem)

extends BaseSolver
class_name VerletSolver


# --- Internal state ----------------------------------------------------------

var r: Vector2
var v: Vector2
var a: Vector2


# --- Initialization ----------------------------------------------------------

func from_cartesian(relative_position: Vector2, relative_velocity: Vector2) -> void:
	if mu <= 0.0:
		push_error("mu must be set before from_cartesian()")
		return

	r = relative_position
	v = relative_velocity
	a = _acceleration(r)
	
	compute_params() # for drawer

# --- Propagation -------------------------------------------------------------

func propagate(dt: float) -> void:
	# r_{n+1} = r_n + v_n dt + 1/2 a_n dt^2
	r += v * dt + 0.5 * a * dt * dt

	# a_{n+1}
	var a_new := _acceleration(r)

	# v_{n+1} = v_n + 1/2 (a_n + a_{n+1}) dt
	v += 0.5 * (a + a_new) * dt

	a = a_new
	
	compute_params() # for drawer, since verlet drifts from kepler ever prop


# --- Cartesian output --------------------------------------------------------

func to_cartesian(target_t: float = -1.0) -> State2D:
	return State2D.new(r, v)


# --- Physical invariants -----------------------------------------------------

func energy() -> float:
	# ε = v²/2 − μ / r
	return 0.5 * v.length_squared() - mu / r.length()


func angular_momentum() -> float:
	# |r × v| (2D scalar)
	return abs(r.cross(v))
	
func compute_params() -> void:
	var r_mag = r.length()
	var v_mag_sq = v.length_squared()
	var r_dot_v = r.dot(v)
	
	# Orbit Shape
	var inv_a = (2.0 / r_mag) - (v_mag_sq / mu)
	sma = 1.0 / inv_a
	
	var e_vec = ((v_mag_sq - mu / r_mag) * r - r_dot_v * v) / mu
	ecc = e_vec.length()
	
	# Orbit Orientation (Fixed in space)
	periapsis_angle = e_vec.angle() 
	
	# Orbit Direction (Clockwise vs Counter-Clockwise)
	# In 2D, cross product is a scalar: x1*y2 - y1*x2
	var h = r.x * v.y - r.y * v.x
	orbit_direction = sign(h)

# --- Every Render (After Solver updates r) ---
func compute_ta() -> void:
	# We already have r from the solver. 
	# True Anomaly is just the angle of r relative to the periapsis.
	
	# Method 1: Vector Angle (Cheaper)
	# Since periapsis_angle is fixed, we just compare r's current angle to it.
	true_anomaly = r.angle() - periapsis_angle
	
	# Method 2: Geometric (If you prefer angle_to)
	# var peri_dir = Vector2.from_angle(periapsis_angle)
	# true_anomaly = peri_dir.angle_to(r)

	# Wrap to [0, TAU]
	if true_anomaly < 0:
		true_anomaly += TAU

	var r_mag = r.length()
	var v_mag_sq = v.length_squared()
	var r_dot_v = r.dot(v)
	
	var inv_a = (2.0 / r_mag) - (v_mag_sq / mu)
	sma = 1.0 / inv_a
	
	var e_vec = ((v_mag_sq - mu / r_mag) * r - r_dot_v * v) / mu
	ecc = e_vec.length()
	
	periapsis_angle = e_vec.angle() 
	
	var h = r.cross(v) 
	
	orbit_direction = sign(h)
	
	true_anomaly = e_vec.angle_to(r)
	
	if true_anomaly < 0:
		true_anomaly += TAU
# --- Internal helpers --------------------------------------------------------

func _acceleration(pos: Vector2) -> Vector2:
	var dist_sq := pos.length_squared()
	var dist := sqrt(dist_sq)

	# a = -μ r / r³
	return -mu * pos / (dist_sq * dist)
