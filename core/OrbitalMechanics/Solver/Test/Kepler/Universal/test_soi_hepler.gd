extends GutTest

# --- Setup Helpers -----------------------------------------------------------

func create_test_solver(mu: float, r0: Vector2, v0: Vector2) -> UniversalKeplerSolver:
	var solver = UniversalKeplerSolver.new()
	solver.mu = mu
	solver.from_cartesian(r0, v0)
	return solver

# --- Component Tests ---------------------------------------------------------

## Tests the math involved in finding the Universal Variable (chi)
func test_solve_chi_logic() -> void:
	var mu := 1.0
	var r0 := Vector2(1.0, 0.0)
	var v0 := Vector2(0.0, 1.0) # Circular orbit
	var solver = create_test_solver(mu, r0, v0)
	
	# After 1/4 of a period (T = TAU), chi should be predictable.
	# For a circular unit orbit, chi at t=PI/2 is roughly 1.57
	var target_t := PI / 2.0
	var chi = solver.solve_chi(target_t)
	
	assert_gt(chi, 0.0, "Chi should be positive for forward time")
	
	# Verify chi by plugging it into the state generator
	var state = solver.state_from_chi(chi, target_t)
	
	# At 1/4 orbit, pos should be approx (0, 1)
	assert_almost_eq(state.r.x, 0.0, 1e-5, "Position X error at solved chi")
	assert_almost_eq(state.r.y, 1.0, 1e-5, "Position Y error at solved chi")

## Tests the conversion from chi to Cartesian vectors
func test_get_state_at_chi_mapping() -> void:
	var mu := 1.0
	var r0 := Vector2(1.0, 0.0)
	var v0 := Vector2(0.0, 1.2) # Eccentric
	var solver = create_test_solver(mu, r0, v0)
	
	# Manually solve chi for a specific time
	var t_val := 1.0
	var chi = solver.solve_chi(t_val)
	
	# Generate state
	var state = solver.state_from_chi(chi, t_val)
	
	# Test that the energy of the generated state matches the energy of the epoch
	# This proves the f and g functions are maintaining orbital consistency
	var energy_epoch = 0.5 * v0.length_squared() - mu / r0.length()
	var energy_generated = 0.5 * state.v.length_squared() - mu / state.r.length()
	
	assert_almost_eq(energy_generated, energy_epoch, 1e-7, "State generation at chi violated energy conservation")

## Tests the raw geometry functions (Periapsis/Apoapsis)
func test_apsis_calculations() -> void:
	var mu := 1.0
	var r0 := Vector2(1.0, 0.0)
	var v0 := Vector2(0.0, 1.2)
	var solver = create_test_solver(mu, r0, v0)
	
	# a = 1 / (2/1 - 1.44/1) = 1.7857
	# e = 0.44
	var expected_peri := 1.0
	var expected_apo := 2.5714 # a * (1 + e)
	
	assert_almost_eq(solver.periapsis_radius(), expected_peri, 1e-4)
	assert_almost_eq(solver.apoapsis_radius(), expected_apo, 1e-4)

## Tests the specific root-finding math used for the Radius Solver
func test_time_to_radius_internal_math() -> void:
	var mu := 1.0
	var r0 := Vector2(1.0, 0.0)
	var v0 := Vector2(0.0, 1.2)
	var solver = create_test_solver(mu, r0, v0)
	
	# Choose a radius we know is reachable (between 1.0 and 2.57)
	var target_r := 1.8
	var dt = solver.time_to_radius(target_r)
	
	# Manually verify: use the wrapper to see if we are at target_r at that dt
	var result_state = solver.to_cartesian(dt)
	assert_almost_eq(result_state.r.length(), target_r, 1e-5, "Radius root finder failed" + str(dt))

## Verifies that 'pchi' updates correctly when using the public wrapper
func test_pchi_warm_start_persistence() -> void:
	var mu := 1.0
	var r0 := Vector2(1.0, 0.0)
	var v0 := Vector2(0.0, 1.0)
	var solver = create_test_solver(mu, r0, v0)
	
	# Initial pchi is 0
	assert_eq(solver._chi_solver.pchi, 0.0)
	
	# Calling to_cartesian with target_t < 0 should update pchi
	solver.propagate(1.0)
	var _state = solver.to_cartesian(-1.0)
	
	assert_ne(solver._chi_solver.pchi, 0.0, "pchi should have been updated after propagation")
	
	# Calling with a specific time (prediction) should NOT update the main pchi
	var old_pchi = solver._chi_solver.pchi
	var _pred = solver.to_cartesian(50.0)
	
	assert_eq(solver._chi_solver.pchi, old_pchi, "pchi should not be modified by prediction calls")
