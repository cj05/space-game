extends GutTest

const CloseApproachUtil = preload(
	"res://core/OrbitalMechanics/Hierachy/CloseApproachUtil.gd"
)

const UniversalKeplerSolver = preload(
	"res://core/OrbitalMechanics/Solver/Kepler/Universal/UniversalKeplerSolver.gd"
)

func test_solve_time_to_soi_straight_line_flyby() -> void:
	# --- Setup ---------------------------------------------------------------

	var mu := 0.0
	# mu = 0 → inertial straight-line motion (no gravity)
	# This makes the expected SOI time analytically solvable.

	# Target (planet) at origin, stationary
	var target_solver: UniversalKeplerSolver = autofree(
		UniversalKeplerSolver.new(mu)
	)
	target_solver.from_cartesian(
		Vector2.ZERO,
		Vector2.ZERO
	)

	# Ship starts at x = 100, moving directly toward target at 10 m/s
	var ship_solver: UniversalKeplerSolver = autofree(
		UniversalKeplerSolver.new(mu)
	)
	ship_solver.from_cartesian(
		Vector2(100.0, 0.0),
		Vector2(-10.0, 0.0)
	)

	var soi_radius := 50.0
	var t_start := 0.0

	# Expected time:
	# distance_to_soi = 100 - 50 = 50
	# speed = 10
	# t = 5
	var expected_time := 5.0

	var util := CloseApproachUtil.new()
	autofree(util)

	# --- Act -----------------------------------------------------------------

	var t_soi := util.solve_time_to_soi(
		ship_solver,
		target_solver,
		soi_radius,
		t_start
	)

	# --- Assert --------------------------------------------------------------

	assert_true(
		abs(t_soi - expected_time) < 1e-3,
		"Incorrect SOI entry time: got=%f expected≈%f"
			% [t_soi, expected_time]
	)
