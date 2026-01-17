# test_periapsis_stability.gd
extends GutTest

func test_close_approach_convergence() -> void:
	var mu: float = 6000000000000000.0
	var r0 := Vector2(200.0, 0.0)
	var v0 := Vector2(0.0, 1.0) # Very low speed = very close approach
	
	var solver: UniversalKeplerSolver = autofree(UniversalKeplerSolver.new(mu))
	solver.from_cartesian(r0, v0)

	# We want to test a time very close to periapsis
	# In high-eccentricity, even a 0.001s difference can be huge
	var epoch_time: float = 0.5 
	
	# Check for "Chatter": small variations in time should yield small variations in pos
	solver.propagate(epoch_time)
	var p1 = solver.to_cartesian().r
	
	solver.propagate(0.000001) # A tiny micro-tick
	var p2 = solver.to_cartesian().r
	
	var displacement = p1.distance_to(p2)
	
	# If the solver is jittering, it will "snap" to a distant point or (0,0)
	assert_lt(displacement, 5.0, "Jitter detected at periapsis! Solver snapped %f units in a micro-tick." % displacement)
	assert_gt(displacement, 0.0, "Solver frozen at periapsis.")
