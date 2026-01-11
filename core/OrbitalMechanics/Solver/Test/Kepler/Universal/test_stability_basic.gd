# test_basic.gd
# Basic stability test for repeated stepping over large dt

extends GutTest

func test_large_dt_long_term_stability() -> void:
	var mu := 1.0

	# Unit circular orbit
	var r0 := Vector2(1.0, 0.0)
	var v0 := Vector2(0.0, 1.0)

	var solver: UniversalKeplerSolver = autofree(UniversalKeplerSolver.new(mu))
	solver.from_cartesian(r0, v0)

	var energy0 := solver.energy()

	# --- Intentionally large timestep ---
	var dt := 0.1                # VERY large for orbital motion
	var periods := 100            # Many revolutions
	var steps := int(round(periods * TAU / dt))

	var min_r := INF
	var max_r := 0.0

	for i in range(steps):
		solver.propagate(dt)

		var r := solver.to_cartesian().r.length()
		min_r = min(min_r, r)
		max_r = max(max_r, r)

	# --- Assertions ----------------------------------------------------------

	# Orbit should remain bounded
	assert_true(
		min_r > 0.5,
		"Orbit collapsed: min radius = %f" % min_r
	)

	assert_true(
		max_r < 2.0,
		"Orbit exploded: max radius = %f" % max_r
	)

	# Energy error should remain bounded (symplectic behavior)
	var energy_err: float = abs(solver.energy() - energy0)

	assert_true(
		energy_err < 1e-2,
		"Energy drift too large: Δε=%f" % energy_err
	)
	
func test_small_dt_long_term_stability() -> void:
	var mu := 1.0

	# Unit circular orbit
	var r0 := Vector2(1.0, 0.0)
	var v0 := Vector2(0.0, 1.0)

	var solver: UniversalKeplerSolver = autofree(UniversalKeplerSolver.new(mu))
	solver.from_cartesian(r0, v0)

	var energy0 := solver.energy()

	# --- Intentionally large timestep ---
	var dt := 0.001
	var periods := 100            # Many revolutions
	var steps := int(round(periods * TAU / dt))

	var min_r := INF
	var max_r := 0.0

	for i in range(steps):
		solver.propagate(dt)

		var r := solver.to_cartesian().r.length()
		min_r = min(min_r, r)
		max_r = max(max_r, r)

	# --- Assertions ----------------------------------------------------------

	# Orbit should remain bounded
	assert_true(
		min_r > 0.5,
		"Orbit collapsed: min radius = %f" % min_r
	)

	assert_true(
		max_r < 2.0,
		"Orbit exploded: max radius = %f" % max_r
	)

	# Energy error should remain bounded (symplectic behavior)
	var energy_err: float = abs(solver.energy() - energy0)

	assert_true(
		energy_err < 1e-2,
		"Energy drift too large: Δε=%f" % energy_err
	)
	
func test_single_extreme_dt_stability() -> void:
	var mu := 1.0

	# Unit circular orbit
	var r0 := Vector2(1.0, 0.0)
	var v0 := Vector2(0.0, 1.0)

	var solver: UniversalKeplerSolver = autofree(UniversalKeplerSolver.new(mu))
	solver.from_cartesian(r0, v0)

	var energy0 := solver.energy()

	# --- Intentionally large timestep ---
	var dt := 10
	var periods := 100            # Many revolutions
	var steps := int(round(periods * TAU / dt))

	var min_r := INF
	var max_r := 0.0

	for i in range(steps):
		solver.propagate(dt)

		var r := solver.to_cartesian().r.length()
		min_r = min(min_r, r)
		max_r = max(max_r, r)

	# --- Assertions ----------------------------------------------------------

	# Orbit should remain bounded
	assert_true(
		min_r > 0.5,
		"Orbit collapsed: min radius = %f" % min_r
	)

	assert_true(
		max_r < 2.0,
		"Orbit exploded: max radius = %f" % max_r
	)

	# Energy error should remain bounded (symplectic behavior)
	var energy_err: float = abs(solver.energy() - energy0)

	assert_true(
		energy_err < 1e-2,
		"Energy drift too large: Δε=%f" % energy_err
	)
