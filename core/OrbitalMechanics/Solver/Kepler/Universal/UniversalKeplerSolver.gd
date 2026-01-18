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
var dt: float  = 0.0
var pchi:float = 0.0    # for better newt. guess
var last_t:float = 0.0

# --- Constants ---------------------------------------------------------------

const MAX_ITERS := 80
const TOL := 1e-13

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
	self.last_t = t
	t += dt
	self.dt = dt
	
	
	# Redundancy: If the orbit is elliptical (alpha > 0), wrap time by the period
	if alpha > 0.0:
		var period = TAU / (pow(alpha, 1.5) * sqrt(mu))
		if t > period:
			t = fmod(t, period)
			# Resetting chi slightly helps prevent pchi from carrying 
			# error across the modulo jump
			pchi = fmod(pchi, sqrt(alpha) * period)


# --- Output ------------------------------------------------------------------

# --- Refactored Kepler Logic -------------------------------------------------

# 1. Finds the universal variable chi for a specific time t
func solve_chi(target_t: float, chi_guess: float = -1.0) -> float:
	var r0mag := r_epoch.length()
	var vr0 := r_epoch.dot(v_epoch) / r0mag
	var sqrt_mu := sqrt(mu)
	
	# Use provided guess or calculate a fallback
	var chi: float = chi_guess
	if chi < 0:
		chi = crude_pchi_guess(sqrt_mu,r0mag,target_t)
	var cnt = 0
	for _i in range(MAX_ITERS):
		cnt+=1
		var z := alpha * chi * chi
		var C := stumpff_C(z)
		var S := stumpff_S(z)

		# f(chi) = r0*vr0/sqrt(mu) * chi^2 * C + (1 - alpha*r0) * chi^3 * S + r0*chi - sqrt(mu)*t
		var F := (r0mag * vr0 / sqrt_mu) * chi * chi * C + \
				 (1.0 - alpha * r0mag) * chi * chi * chi * S + \
				 r0mag * chi - sqrt_mu * target_t

		# df/dchi = r (the current radius)
		var dF := (r0mag * vr0 / sqrt_mu) * chi * (1.0 - z * S) + \
				  (1.0 - alpha * r0mag) * chi * chi * C + r0mag

		var delta := F / dF
		chi -= delta
		if abs(delta) < TOL: break
	return chi

# 2. Converts a solved chi back into r and v vectors
func get_state_at_chi(chi: float, target_t: float) -> State2D:
	var r0mag := r_epoch.length()
	var sqrt_mu := sqrt(mu)
	var zf := alpha * chi * chi
	var Cf := stumpff_C(zf)
	var Sf := stumpff_S(zf)

	var f := 1.0 - (chi * chi / r0mag) * Cf
	var g := target_t - (chi * chi * chi / sqrt_mu) * Sf
	
	var res_r = f * r_epoch + g * v_epoch
	var rmag := res_r.length()

	var fdot := (sqrt_mu / (rmag * r0mag)) * (zf * Sf - 1.0) * chi
	var gdot := 1.0 - (chi * chi / rmag) * Cf
	var res_v = fdot * r_epoch + gdot * v_epoch

	return State2D.new(res_r, res_v)

func crude_pchi_guess(sqrt_mu:float,r0mag:float,target_t:float):
	var chi = sqrt_mu * abs(alpha) * target_t
	if alpha == 0.0:
		chi = sqrt_mu * target_t / r0mag 
	return chi

# 3. Public wrapper (can be called with any future time)
func to_cartesian(target_t: float = -1.0) -> State2D:
	var solve_t = t if target_t < 0 else target_t
	# Use pchi as a "warm start" if we are solving for a time near our current one
	var guess = pchi if abs(solve_t - last_t) < 1.0 else -1
	
	var chi = solve_chi(solve_t, guess)
	
	# If this is our current evaluation, update the persistent pchi
	if target_t < 0: pchi = chi 
	
	return get_state_at_chi(chi, solve_t)

# --- Utilities ---------------------------------------------------------------
func radius() -> float:
	return r.length()

func apoapsis_radius() -> float:
	if alpha <= 0.0:
		return INF # hyperbolic / parabolic
	return sma * (1.0 + ecc)

func periapsis_radius() -> float:
	var h = angular_momentum()
	return (h * h) / ((1+ecc) * mu)

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

func period() -> float:
	# Only defined for bound (elliptical) orbits
	if alpha <= 0.0:
		return INF

	# alpha = 1 / a
	# T = 2π * sqrt(a^3 / μ)
	#   = 2π / (sqrt(mu) * alpha^(3/2))
	return TAU / (sqrt(mu) * pow(alpha, 1.5))


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
		
		
#Exit Time calc
func time_to_radius(target_r: float) -> float:
	# 1. Physical Bounds Check
	if alpha > 0.0:
		if target_r < periapsis_radius() - 1e-4 or target_r > apoapsis_radius() + 1e-4:
			return INF

	var r0mag := r_epoch.length()
	var vr0_sqrt_mu := r_epoch.dot(v_epoch) / sqrt(mu)
	
	# 2. Starting Guess
	# If starting at periapsis (chi=0), we nudge it slightly positive 
	# to search "forward" in time.
	var chi: float = pchi
	if abs(chi) < 1e-7: chi = 0.1 
	var conv_count = 0
	for _i in range(MAX_ITERS):
		conv_count+=1
		var z = alpha * chi * chi
		var c = stumpff_C(z)
		var s = stumpff_S(z)

		# Current radius at this chi
		var r_val = (chi * chi * c) + (vr0_sqrt_mu * chi * (1.0 - z * s)) + (r0mag * (1.0 - z * c))
		
		# Derivative dr/dchi
		var dr_dchi = (chi * (1.0 - z * s)) \
		   + (vr0_sqrt_mu * (1.0 - z * c)) \
		   + (r0mag * alpha * chi * s)

		# --- THE FIX: Damping / Clamping ---
		# Prevent division by zero and massive jumps that skip the first solution
		if abs(dr_dchi) < 1e-9: dr_dchi = 1e-9 * sign(dr_dchi)
		
		var delta = (r_val - target_r) / dr_dchi
		
		# Limit the change to 1.0 per iteration to prevent "teleporting"
		delta = clamp(delta, -1.0, 1.0)
		
		chi -= delta
		
		if alpha > 0.0:
			var chi_apo := PI / sqrt(alpha)
			chi = clamp(chi, 0.0, chi_apo)

		if abs(delta) < TOL:
			break
	
	if is_nan(chi): return INF

	# 3. Final Conversion to Time
	var z_final = alpha * chi * chi
	return ((1.0 - alpha * r0mag) * chi * chi * chi * stumpff_S(z_final) + \
		vr0_sqrt_mu * chi * chi * stumpff_C(z_final) + \
		r0mag * chi) / sqrt(mu)
			
			
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
