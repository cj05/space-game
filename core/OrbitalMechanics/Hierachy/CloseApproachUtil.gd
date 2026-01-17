class_name CloseApproachUtil
# This function now lives in a Manager/Utility script.
# It takes the ship's solver specifically to access its internal math.
func solve_time_to_soi(ship_solver: UniversalKeplerSolver, target_solver: UniversalKeplerSolver, soi_radius: float, t_start: float) -> float:
	var t_est := t_start
	
	# We use the ship_solver's current pchi as the first guess.
	# This avoids the 'crude_pchi_guess' logic and keeps the start 'warm'.
	var current_chi := ship_solver.pchi 
	
	for _i in range(10):
		# --- A. Dereferenced Kepler Logic ---
		# We call the solver's internal functions to find the future state
		current_chi = ship_solver.solve_chi(t_est, current_chi)
		var ship_state: State2D = ship_solver.get_state_at_chi(current_chi, t_est)
		
		# --- B. Dereferenced Planet Logic ---
		# We use to_cartesian for the planet (it handles its own pchi internally)
		var target_state: State2D = target_solver.to_cartesian(t_est)
		
		# --- C. Relative Math ---
		var rel_r: Vector2 = ship_state.r - target_state.r
		var rel_v: Vector2 = ship_state.v - target_state.v
		var dist: float = rel_r.length()
		
		# Prevent division by zero if ship is exactly at the planet center
		if dist < 1.0: return t_est 

		# --- D. The Root Function ---
		# Find where distance - soi_radius = 0
		var f := dist - soi_radius
		
		# --- E. The Derivative ---
		# Distance derivative is the dot product of normalized position and velocity
		# (Speed of approach)
		var f_prime := rel_r.dot(rel_v) / dist
		
		# Avoid division by zero if velocity is perpendicular to position
		if abs(f_prime) < 1e-6: break 
		
		var dt := f / f_prime
		t_est -= dt
		
		if abs(dt) < 1e-3: # Converged to 1ms accuracy
			break
			
	return t_est
