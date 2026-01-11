# test_reference_samples.gd
# Regression test against known (t, r) samples

extends GutTest


# --- Reference trajectory ----------------------------------------------------
# Circular orbit, r = 1, v = 1, mu = 1
# r(t) = (cos t, sin t)

const REF_SAMPLES := [
	{ "t": 0.0,          "r": Vector2( 1.0,  0.0) },
	{ "t": TAU / 8.0,    "r": Vector2( sqrt(0.5),  sqrt(0.5)) },
	{ "t": TAU / 4.0,    "r": Vector2( 0.0,  1.0) },
	{ "t": TAU / 2.0,    "r": Vector2(-1.0,  0.0) },
	{ "t": 3.0 * TAU / 4.0, "r": Vector2( 0.0, -1.0) },
	{ "t": TAU,          "r": Vector2( 1.0,  0.0) },
]

const POS_TOL := 1e-6
const RAD_TOL := 1e-6


# --- Test --------------------------------------------------------------------

func test_against_reference_samples() -> void:
	var mu := 1.0
	var r0 := Vector2(1.0, 0.0)
	var v0 := Vector2(0.0, 1.0)

	var solver: UniversalKeplerSolver = autofree(UniversalKeplerSolver.new(mu))
	solver.from_cartesian(r0, v0)

	var t_prev := 0.0

	for sample in REF_SAMPLES:
		var t: float = sample["t"]
		var r_expected: Vector2 = sample["r"]

		solver.propagate(t - t_prev)
		

		var r_actual := solver.to_cartesian().r
		
		t_prev = t
		# --- Assertions ------------------------------------------------------

		assert_true(
			r_actual.distance_to(r_expected) < POS_TOL,
			"Position mismatch at t=%f\n got=%s\n exp=%s\n |Δr|=%f"
			% [t, r_actual, r_expected, r_actual.distance_to(r_expected)]
		)
