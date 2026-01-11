# test_reference_numerical.gd
# Numerical regression test against high-accuracy RK4 reference

extends GutTest

const MU := 1.0
const POS_TOL := 2e-5

# ---------------------------------------------------------------------------
# RK4 reference propagator (very small dt)
# ---------------------------------------------------------------------------

func accel(r: Vector2) -> Vector2:
	return -MU * r / pow(r.length(), 3)

func rk4_step(r: Vector2, v: Vector2, dt: float) -> Array:
	var k1r := v
	var k1v := accel(r)

	var k2r := v + 0.5 * dt * k1v
	var k2v := accel(r + 0.5 * dt * k1r)

	var k3r := v + 0.5 * dt * k2v
	var k3v := accel(r + 0.5 * dt * k2r)

	var k4r := v + dt * k3v
	var k4v := accel(r + dt * k3r)

	var r_new := r + dt / 6.0 * (k1r + 2*k2r + 2*k3r + k4r)
	var v_new := v + dt / 6.0 * (k1v + 2*k2v + 2*k3v + k4v)

	return [r_new, v_new]

func propagate_rk4(
	r0: Vector2,
	v0: Vector2,
	t: float,
	sub_dt := 1e-4
) -> Vector2:
	var r := r0
	var v := v0
	var t_acc := 0.0

	while t_acc < t:
		var dt:float = min(sub_dt, t - t_acc)
		var out := rk4_step(r, v, dt)
		r = out[0]
		v = out[1]
		t_acc += dt

	return r

# ---------------------------------------------------------------------------
# Test harness
# ---------------------------------------------------------------------------

func run_numerical_reference_test(
	name: String,
	r0: Vector2,
	v0: Vector2,
	samples: Array
) -> void:
	var solver:UniversalKeplerSolver = autofree(UniversalKeplerSolver.new(MU))
	solver.from_cartesian(r0, v0)

	var t_prev := 0.0

	for t in samples:
		solver.propagate(t - t_prev)
		var r_kepler := solver.to_cartesian().r
		var r_ref := propagate_rk4(r0, v0, t)

		assert_true(
			r_kepler.distance_to(r_ref) < POS_TOL,
			"%s mismatch at t=%f\n kepler=%s\n rk4=%s\n |Δr|=%f"
			% [name, t, r_kepler, r_ref, r_kepler.distance_to(r_ref)]
		)

		t_prev = t

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

func test_circular_numerical() -> void:
	run_numerical_reference_test(
		"Circular",
		Vector2(1.0, 0.0),
		Vector2(0.0, 1.0),
		[0.0, TAU/8.0, TAU/4.0, TAU/2.0, TAU]
	)

func test_elliptic_numerical() -> void:
	run_numerical_reference_test(
		"Elliptic",
		Vector2(0.5, 0.0),
		Vector2(0.0, sqrt(3.0)),
		[0.0, 0.5, 1.0, 2.0, 3.0]
	)

func test_parabolic_numerical() -> void:
	run_numerical_reference_test(
		"Parabolic",
		Vector2(1.0, 0.0),
		Vector2(0.0, sqrt(2.0)),
		[0.0, 0.2, 0.5, 1.0]
	)

func test_hyperbolic_numerical() -> void:
	run_numerical_reference_test(
		"Hyperbolic",
		Vector2(0.5, 0.0),
		Vector2(0.0, 2.0),
		[0.0, 0.2, 0.5, 1.0]
	)
