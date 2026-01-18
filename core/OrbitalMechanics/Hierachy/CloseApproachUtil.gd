class_name CloseApproachUtil

func solve_time_to_soi(
	ship_solver: UniversalKeplerSolver,
	target_solver: UniversalKeplerSolver,
	soi_radius: float,
	t_start: float
) -> float:
	
	var soi_sq := soi_radius * soi_radius
	
	# --- 1. Closest approach ---
	var t_ca := solve_time_of_closest_approach(
		ship_solver,
		target_solver,
		t_start,
		t_start + 30.0 * 86400.0
	)
	
	# --- 2. Reject if no encounter ---
	var d_min_sq := _get_dist_sq_at(t_ca, ship_solver, target_solver)
	if d_min_sq > soi_sq:
		return INF
	
	# --- 3. Physical initial guess ---
	var s_ca := ship_solver.to_cartesian(t_ca)
	var t_ca_state := target_solver.to_cartesian(t_ca)
	
	var r_rel := s_ca.r - t_ca_state.r
	var v_rel := s_ca.v - t_ca_state.v
	var v_rel_mag:float = max(v_rel.length(), 1e-6)
	
	var t_est:float = t_ca - soi_radius / v_rel_mag
	
	# --- 4. Newton solve on boundary ---
	var current_chi := ship_solver.pchi
	
	for i in range(20):
		current_chi = ship_solver.solve_chi(t_est, current_chi)
		var s_state := ship_solver.get_state_at_chi(current_chi, t_est)
		var t_state := target_solver.to_cartesian(t_est)
		
		var rel_r := s_state.r - t_state.r
		var rel_v := s_state.v - t_state.v
		
		var f := rel_r.length_squared() - soi_sq
		var f_prime := 2.0 * rel_r.dot(rel_v)
		
		if abs(f_prime) < 1e-9:
			break
		
		var dt:float = clamp(f / f_prime, -86400.0, 86400.0)
		t_est -= dt
		
		if abs(dt) < 1e-3:
			break
	
	return t_est

const PHI := 0.6180339887498949

func solve_time_of_closest_approach(
	ship_solver: UniversalKeplerSolver,
	target_solver: UniversalKeplerSolver,
	t_start: float,
	t_end: float
) -> float:
	
	return solve_time_of_closest_approach_brent(
		ship_solver,
		target_solver,
		t_start,
		t_end
	)

func solve_time_of_closest_approach_brent(
	ship_solver,
	target_solver,
	a: float,
	b: float
) -> float:
	
	const EPS := 1e-6
	const GOLD := 0.3819660112501051
	
	var x := a + GOLD * (b - a)
	var w := x
	var v := x
	
	var fx := _get_dist_sq_at(x, ship_solver, target_solver)
	var fw := fx
	var fv := fx
	
	var d := 0.0
	var e := 0.0
	
	var count=0
	for i in range(50):
		count +=1
		var m := 0.5 * (a + b)
		var tol:float = EPS * abs(x) + 1e-9
		
		if abs(x - m) <= 2.0 * tol - 0.5 * (b - a):
			break
		
		var p := 0.0
		var q := 0.0
		var r := 0.0
		
		if abs(e) > tol:
			r = (x - w) * (fx - fv)
			q = (x - v) * (fx - fw)
			p = (x - v) * q - (x - w) * r
			q = 2.0 * (q - r)
			
			if q > 0.0:
				p = -p
			q = abs(q)
			
			if abs(p) < abs(0.5 * q * e) and p > q * (a - x) and p < q * (b - x):
				d = p / q
				e = d
			else:
				e = (b - x) if (x < m) else (a - x)
				d = GOLD * e
		else:
			e = (b - x) if (x < m) else (a - x)
			d = GOLD * e
		
		var u:float = x + (d if abs(d) > tol else sign(d) * tol)
		var fu := _get_dist_sq_at(u, ship_solver, target_solver)
		
		if fu <= fx:
			if u < x:
				b = x
			else:
				a = x
			v = w
			fv = fw
			w = x
			fw = fx
			x = u
			fx = fu
		else:
			if u < x:
				a = u
			else:
				b = u
			if fu <= fw or w == x:
				v = w
				fv = fw
				w = u
				fw = fu
			elif fu <= fv or v == x or v == w:
				v = u
				fv = fu
	print(count)
	return x

func _get_dist_sq_at(time: float, s1: UniversalKeplerSolver, s2: UniversalKeplerSolver) -> float:
	var p1 = s1.to_cartesian(time).r
	var p2 = s2.to_cartesian(time).r
	return p1.distance_squared_to(p2)
