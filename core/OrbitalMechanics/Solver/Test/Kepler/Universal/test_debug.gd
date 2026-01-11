# test_debug_dump.gd
extends GutTest

func test_analyze_freefall_jitter() -> void:
	var mu: float = 6000000000000000.0
	var r0 := Vector2(200.0, 0.0)
	var v0 := Vector2(0.0, 1.0) # Aiming for a very close pass
	
	var solver: UniversalKeplerSolver = autofree(UniversalKeplerSolver.new(mu))
	solver.from_cartesian(r0, v0)
	
	var dt := 0.0166 # 60 FPS
	var total_frames := 300 # ~2 seconds of sim time
	
	print("\n" + "=".repeat(80))
	print("%-10s | %-12s | %-12s | %-12s | %-12s" % ["Frame", "Time (t)", "Anomaly(χ)", "Radius(r)", "Pos_X"])
	print("-".repeat(80))
	
	for i in range(total_frames):
		solver.propagate(dt)
		var state = solver.to_cartesian()
		
		# We want to see the values that go INTO the final calculation
		# Note: You might need to make 'chi' a temporary class variable 
		# in UniversalKeplerSolver to print it here.
		print("%-10d | %-12.4f | %-12.4f | %-12.4f | %-12.4f" % [
			i, 
			solver.t, 
			solver.chi if "chi" in solver else 0.0, 
			state.r.length(),
			state.r.x
		])
	print("=".repeat(80) + "\n")
	
	assert_true(true)
