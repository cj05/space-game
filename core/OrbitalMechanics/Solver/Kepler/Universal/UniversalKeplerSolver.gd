# UniversalKeplerSolver.gd
# Universal-variable Kepler solver (2D, epoch-based)
# Compatible with AbstractSolver

extends BaseSolver
class_name UniversalKeplerSolver

# --- Epoch state -------------------------------------------------------------

var r_epoch: Vector2
var v_epoch: Vector2

# --- Current evaluated state -------------------------------------------------

var r: Vector2
var v: Vector2

# --- Orbital constants -------------------------------------------------------

var alpha: float        # 1 / a
var t: float = 0.0      # time since epoch

# --- Constants ---------------------------------------------------------------

const MAX_ITERS := 80
const TOL := 1e-16

# --- Initialization ----------------------------------------------------------

func from_cartesian(relative_position: Vector2, relative_velocity: Vector2) -> void:
	r_epoch = relative_position
	v_epoch = relative_velocity

	r = r_epoch
	v = v_epoch

	t = 0.0

	var rmag := r_epoch.length()
	var v2 := v_epoch.length_squared()

	# α = 2/r − v²/μ
	alpha = 2.0 / rmag - v2 / mu
	
	compute_params() # for drawer


# --- Propagation -------------------------------------------------------------

func propagate(dt: float) -> void:
	# Advance time ONLY
	t += dt
	#print(t)


# --- Output ------------------------------------------------------------------

func to_cartesian() -> State2D:
	# Reminder: this SOLVES from epoch, it does NOT integrate

	if t == 0.0:
		return State2D.new(r_epoch, v_epoch)

	var r0mag := r_epoch.length()
	var vr0 := r_epoch.dot(v_epoch) / r0mag
	var sqrt_mu := sqrt(mu)

	# --- Initial guess for χ (robust for all conics) ---
	var chi:float = sqrt_mu * abs(alpha) * t
	if alpha == 0.0:
		chi = sqrt_mu * t / r0mag

	# --- Newton solve ---
	for _i in range(MAX_ITERS):
		var z:float = alpha * chi * chi
		var C:float = stumpff_C(z)
		var S:float = stumpff_S(z)

		var F := (
			r0mag * vr0 / sqrt_mu * chi * chi * C +
			(1.0 - alpha * r0mag) * chi * chi * chi * S +
			r0mag * chi - sqrt_mu * t
		)

		var dF := (
			r0mag * vr0 / sqrt_mu * chi * (1.0 - z * S) +
			(1.0 - alpha * r0mag) * chi * chi * C +
			r0mag
		)

		var delta := F / dF
		chi -= delta

		if abs(delta) < TOL:
			
			break

	# --- Lagrange coefficients ---
	var zf := alpha * chi * chi
	var Cf := stumpff_C(zf)
	var Sf := stumpff_S(zf)

	var f := 1.0 - (chi * chi / r0mag) * Cf
	var g := t - (chi * chi * chi / sqrt_mu) * Sf

	r = f * r_epoch + g * v_epoch
	var rmag := r.length()

	var fdot := (sqrt_mu / (rmag * r0mag)) * (zf * Sf - 1.0) * chi
	var gdot := 1.0 - (chi * chi / rmag) * Cf

	v = fdot * r_epoch + gdot * v_epoch

	return State2D.new(r, v)


# --- Utilities ---------------------------------------------------------------

func energy() -> float:
	return 0.5 * v.length_squared() - mu / r.length()

func angular_momentum() -> float:
	return r.x * v.y - r.y * v.x

# --- One time per orbit change (Thrust/SOI/Collision) ---
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
	if not periapsis_angle:
		compute_params()
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

# --- Stumpff Functions -------------------------------------------------------

static func stumpff_C(z: float) -> float:
	if abs(z) < 1e-5:
		return 0.5 - z / 24.0 + z * z / 720.0

	if z > 0.0:
		var s := sqrt(z)
		return (1.0 - cos(s)) / z
	else:
		var s := sqrt(-z)
		return (cosh(s) - 1.0) / (-z)


static func stumpff_S(z: float) -> float:
	if abs(z) < 1e-5:
		return 1.0 / 6.0 - z / 120.0 + z * z / 5040.0

	if z > 0.0:
		var s := sqrt(z)
		return (s - sin(s)) / (s * s * s)
	else:
		var s := sqrt(-z)
		return (sinh(s) - s) / (s * s * s)
