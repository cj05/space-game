extends GutTest

const CloseApproachUtil = preload(
	"res://core/OrbitalMechanics/Hierachy/CloseApproachUtil.gd"
)

const UniversalKeplerSolver = preload(
	"res://core/OrbitalMechanics/Solver/Kepler/Universal/UniversalKeplerSolver.gd"
)

func test_solve_time_to_soi_straight_line_flyby() -> void:
	var mu := 1e-6  # NOT zero

	var target_solver: UniversalKeplerSolver = autofree(
		UniversalKeplerSolver.new(mu)
	)
	target_solver.from_cartesian(
		Vector2(1.0, 0.0), # avoid singularity
		Vector2.ZERO
	)

	var ship_solver: UniversalKeplerSolver = autofree(
		UniversalKeplerSolver.new(mu)
	)
	ship_solver.from_cartesian(
		Vector2(101.0, 0.0),
		Vector2(-10.0, 0.0)
	)

	var soi_radius := 50.0
	var t_start := 0.0
	var expected_time := 5.0

	var util := CloseApproachUtil.new()
	autofree(util)

	var t_soi := util.solve_time_to_soi(
		ship_solver,
		target_solver,
		soi_radius,
		t_start
	)

	assert_true(
		abs(t_soi - expected_time) < 1e-3,
		"Incorrect SOI entry time: got=%f expected≈%f"
			% [t_soi, expected_time]
	)

func test_solve_time_to_soi_offset_flyby() -> void:
	var mu := 1e-6

	var target: UniversalKeplerSolver = autofree(UniversalKeplerSolver.new(mu))
	target.from_cartesian(Vector2(1.0, 0.0), Vector2.ZERO)

	var ship: UniversalKeplerSolver = autofree(UniversalKeplerSolver.new(mu))
	ship.from_cartesian(
		Vector2(-99.0, 30.0),
		Vector2(10.0, 0.0)
	)

	var soi := 50.0

	# Solve analytically:
	# (x - 1)^2 + 30^2 = 50^2
	# (x - 1)^2 = 1600
	# x_entry = 1 - 40 = -39
	# Δx = 60 → t = 6
	var expected := 6.0

	var util:CloseApproachUtil = autofree(CloseApproachUtil.new())
	var t := util.solve_time_to_soi(ship, target, soi, 0.0)

	assert_almost_eq(t, expected, 1e-3)

func test_no_soi_intersection() -> void:
	var mu := 1e-6

	var target:UniversalKeplerSolver = autofree(UniversalKeplerSolver.new(mu))
	target.from_cartesian(Vector2(1.0, 0.0), Vector2.ZERO)

	var ship:UniversalKeplerSolver = autofree(UniversalKeplerSolver.new(mu))
	ship.from_cartesian(
		Vector2(-99.0, 60.0),
		Vector2(1.0, 0.0)
	)

	var soi := 50.0

	var util:CloseApproachUtil = autofree(CloseApproachUtil.new())
	var t := util.solve_time_to_soi(ship, target, soi, 0.0)
	
	assert_true(is_nan(t) or t < 0.0, "SOI should never be entered at %f" % [t])
	
	target.propagate(t)
	ship.propagate(t)
	
	var target_state:State2D = target.to_cartesian()
	var ship_state:State2D = ship.to_cartesian()
	
	var distance = ship_state.r.distance_to(target_state.r)
	
	assert_true(distance > 50.0, "SOI distance not fulfilled %f %s %s" % [distance,ship_state.r,target_state.r])
	

func test_realistic_earth_flyby_scaled() -> void:
	# Scaled Earth
	var mu := 1.0
	var soi := 10.0

	var target:UniversalKeplerSolver = autofree(UniversalKeplerSolver.new(mu))
	target.from_cartesian(Vector2(1.0, 0.0), Vector2.ZERO)

	# Ship inbound at ~1.2 * escape-ish speed
	var ship:UniversalKeplerSolver = autofree(UniversalKeplerSolver.new(mu))
	ship.from_cartesian(
		Vector2(31.0, 0.0),  # far outside SOI
		Vector2(-2.0, 0.0)
	)

	# Δr = (31 − 1) − 10 = 20
	# v ≈ 2 → t ≈ 10
	var expected := 10.0

	var util:CloseApproachUtil = autofree(CloseApproachUtil.new())
	var t := util.solve_time_to_soi(ship, target, soi, 0.0)

	assert_true(abs(t - expected) < 0.2)

func test_realistic_lunar_capture_scaled() -> void:
	var mu := 0.1
	var soi := 5.0

	var target :UniversalKeplerSolver= autofree(UniversalKeplerSolver.new(mu))
	target.from_cartesian(Vector2(1.0, 0.0), Vector2.ZERO)

	var ship :UniversalKeplerSolver= autofree(UniversalKeplerSolver.new(mu))
	ship.from_cartesian(
		Vector2(16.0, 0.0),
		Vector2(-1.0, 0.0)
	)

	# Δr = (16 − 1) − 5 = 10
	# v = 1 → t ≈ 10
	var expected := 10.0

	var util :CloseApproachUtil= autofree(CloseApproachUtil.new())
	var t := util.solve_time_to_soi(ship, target, soi, 0.0)

	assert_true(abs(t - expected) < 0.5)

func test_solve_time_to_soi_does_not_mutate_solvers() -> void:
	var mu := 1e-6

	var target :UniversalKeplerSolver= autofree(UniversalKeplerSolver.new(mu))
	target.from_cartesian(Vector2(1.0, 0.0), Vector2.ZERO)

	var ship :UniversalKeplerSolver= autofree(UniversalKeplerSolver.new(mu))
	ship.from_cartesian(
		Vector2(101.0, 0.0),
		Vector2(-10.0, 0.0)
	)

	# --- Snapshot solver state BEFORE ---
	var ship_pchi_before := ship.pchi
	var target_pchi_before := target.pchi

	var ship_state_before := ship.to_cartesian()
	var target_state_before := target.to_cartesian()

	var util :CloseApproachUtil= autofree(CloseApproachUtil.new())

	# --- Act ---
	var t := util.solve_time_to_soi(
		ship,
		target,
		50.0,
		0.0
	)

	# --- Snapshot solver state AFTER ---
	var ship_pchi_after := ship.pchi
	var target_pchi_after := target.pchi

	var ship_state_after := ship.to_cartesian()
	var target_state_after := target.to_cartesian()

	# --- Assertions ---------------------------------------------------------

	assert_eq(
		ship_pchi_after,
		ship_pchi_before,
		"Ship solver pchi was mutated by solve_time_to_soi()"
	)

	assert_eq(
		target_pchi_after,
		target_pchi_before,
		"Target solver pchi was mutated by solve_time_to_soi()"
	)

	assert_true(
		ship_state_after.r.is_equal_approx(ship_state_before.r),
		"Ship state mutated by solve_time_to_soi()"
	)

	assert_true(
		target_state_after.r.is_equal_approx(target_state_before.r),
		"Target state mutated by solve_time_to_soi()"
	)
