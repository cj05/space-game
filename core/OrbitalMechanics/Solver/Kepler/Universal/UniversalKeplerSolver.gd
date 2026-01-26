extends BaseSolver
class_name UniversalKeplerSolver

var r_epoch: Vector2
var v_epoch: Vector2

var r: Vector2
var v: Vector2

var alpha: float
var t: float = 0.0
var dt: float = 0.0

var _chi_solver := KeplerChiSolver.new()

var params :UniversalKeplerMath.OrbitParams = UniversalKeplerMath.OrbitParams.new()


# ------------------------------------------------------------
# Initialization
# ------------------------------------------------------------
func from_cartesian(relative_position: Vector2, relative_velocity: Vector2) -> void:
	#var t0 := Time.get_ticks_usec()

	r_epoch = relative_position
	#var t1 := Time.get_ticks_usec()

	v_epoch = relative_velocity
	#var t2 := Time.get_ticks_usec()

	r = r_epoch
	v = v_epoch
	t = 0.0
	#var t3 := Time.get_ticks_usec()

	var rmag := r_epoch.length()
	#var t4 := Time.get_ticks_usec()

	var v2 := v_epoch.length_squared()
	#var t5 := Time.get_ticks_usec()

	alpha = 2.0 / rmag - v2 / mu
	#var t6 := Time.get_ticks_usec()

	compute_params()
	#var t7 := Time.get_ticks_usec()

	_chi_solver.reset(r_epoch, v_epoch, mu, alpha)
	#var t8 := Time.get_ticks_usec()

	#cache_report()
	#var t9 := Time.get_ticks_usec()

	#prints(
	#	"assign r:", t1 - t0,
	#	"assign v:", t2 - t1,
	#	"state:", t3 - t2,
	#	"rmag:", t4 - t3,
	#	"v2:", t5 - t4,
	#	"alpha:", t6 - t5,
	#	"compute:", t7 - t6,
	#	"chi reset:", t8 - t7,
	#	"cache:", t9 - t8,
	#	"TOTAL:", t9 - t0
	#)


# ------------------------------------------------------------
# Propagation
# ------------------------------------------------------------
func propagate(dt: float) -> void:
	t += dt
	self.dt = dt

	if alpha > 0.0:
		var period := UniversalKeplerMath.period(mu, alpha)
		if t > period:
			t = fmod(t, period)
			_chi_solver.pchi = fmod(_chi_solver.pchi, sqrt(alpha) * period)


# ------------------------------------------------------------
# Public query API (unchanged)
# ------------------------------------------------------------
func to_cartesian(target_t: float = INF) -> State2D:
	var is_query := (target_t != INF)
	var solve_t := target_t if is_query else t

	var chi := _chi_solver.solve(solve_t)
	var state := UniversalKeplerMath.state_from_chi(
		r_epoch, v_epoch, mu, alpha, chi, solve_t
	)

	if not is_query:
		r = state.r
		v = state.v
		compute_params()
		compute_ta()

	return state


# ------------------------------------------------------------
# Utilities (public)
# ------------------------------------------------------------
func radius() -> float:
	return r.length()

func energy() -> float:
	return 0.5 * v.length_squared() - mu / r.length()

func angular_momentum() -> float:
	return r.x * v.y - r.y * v.x

func period() -> float:
	return UniversalKeplerMath.period(mu, alpha)


# ------------------------------------------------------------
# Orbit parameter update (delegated)
# ------------------------------------------------------------
func compute_params() -> void:
	#var t0 := Time.get_ticks_usec()

	var t1 := Time.get_ticks_usec()
	
	UniversalKeplerMath.compute_orbit_params(r, v, mu, params)
	#var t2 := Time.get_ticks_usec()

	sma = params.sma
	ecc = params.ecc
	periapsis_angle = params.periapsis_angle
	orbit_direction = params.orbit_direction
	#var t3 := Time.get_ticks_usec()


func compute_ta() -> void:
	true_anomaly = UniversalKeplerMath.compute_true_anomaly(
		r, periapsis_angle
	)

## Solves universal anomaly χ for a given time (read-only query)
func solve_chi(target_t: float) -> float:
	return _chi_solver.solve(target_t)

func radius_at_time(target_t: float) -> float:
	var chi := _chi_solver.solve(target_t)
	var r0mag := r_epoch.length()
	var z := alpha * chi * chi
	var C := KeplerStumpff.C(z)

	# r = a + b * C form
	return r0mag + (r_epoch.dot(v_epoch) / sqrt(mu)) * chi * (1.0 - z * KeplerStumpff.S(z)) \
		+ (1.0 - alpha * r0mag) * chi * chi * C

func state_from_chi(chi: float, target_t: float) -> State2D:
	return UniversalKeplerMath.state_from_chi(
		r_epoch, v_epoch, mu, alpha, chi, target_t
	)

## Closest approach radius (always defined)
func periapsis_radius() -> float:
	return UniversalKeplerMath.periapsis_radius(angular_momentum(),ecc,mu)


## Furthest distance (elliptic only)
func apoapsis_radius() -> float:
	return UniversalKeplerMath.apoapsis_radius(alpha,sma,ecc)


func cache_report():
	print(_chi_solver.cache_report())
	cache_stats_reset()

func cache_stats_reset():
	_chi_solver.cache_stats_reset()
