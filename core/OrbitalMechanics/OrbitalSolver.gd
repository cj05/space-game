class_name OrbitalSolver

var model: OrbitalModel

var SolverMap = {
	OrbitalRole.Type.STAR:"Kepler",
	OrbitalRole.Type.PLANET:"Kepler",
	OrbitalRole.Type.MOON:"Kepler",
	OrbitalRole.Type.ASTEROID:"Kepler",
	OrbitalRole.Type.SHIP:"Kepler",
	OrbitalRole.Type.STATION:"Kepler",
	OrbitalRole.Type.DEBRIS:"Verlet",
	OrbitalRole.Type.UNASSIGNED:"Verlet",
	OrbitalRole.Type.TEST_PARTICLE:"Verlet",
}

func get_solver(body: AbstractBinding) -> AbstractSolver:
	if(body.sim_solver == null): 
		create_solver(body)
	return body.sim_solver 
	
func create_solver(body: AbstractBinding) -> AbstractSolver:
	body.sim_solver = get_solver_for_type(body.role)
	return body.sim_solver 

func get_solver_for_type(type: OrbitalRole.Type) -> AbstractSolver:
	return _get_solver(SolverMap[type])

func _get_solver(solver_name: String) -> AbstractSolver:
	match solver_name:
		"Kepler":
			return UniversalKeplerSolver.new()
		_:
			return VerletSolver.new()

func set_model(model_in: OrbitalModel):
	model = model_in 

func step_all(delta: float, is_ghost: bool, snapshots: Dictionary) -> Dictionary:
	var bodies = model.values()
	
	# INITIALIZE
	for body in bodies:
		var body_solver = get_solver(body) 
		snapshots[body] = SimulationSnapshot.new(body, body_solver, is_ghost)
	
	# PHASE 1: KICK
	_apply_kick_to_snapshots(snapshots, delta * 0.5, true, is_ghost)
	
	# PHASE 2: CONTEXT PREP
	for body in bodies:
		snapshots[body].prepare_context(snapshots)
	
	# PHASE 3: DRIFT
	for body in bodies:
		_solve_snapshot_orbit(snapshots[body], body, delta, is_ghost)
	
	# PHASE 4: KICK
	_apply_kick_to_snapshots(snapshots, delta * 0.5, false, is_ghost)
	
	# PHASE 5: COLLAPSE
	_resolve_global_states(snapshots)
	
	# REINTEGRATE (Only if real)
	if not is_ghost:
		_reintegrate_snapshots(snapshots)
			
	return snapshots

func _apply_kick_to_snapshots(snapshots: Dictionary, dt_factor: float, first_kick: bool, is_ghost: bool):
	for body in snapshots.keys():
		var s: SimulationSnapshot = snapshots[body]
		var accel = body.get_accumulated_acceleration()
		
		# Impulse logic
		var impulse = Vector2.ZERO
		if first_kick and body.pending_impulse != Vector2.ZERO:
			impulse = body.pending_impulse / body.mass
			body.pending_impulse = Vector2.ZERO
		
		# Change velocity
		s.rel_v += (accel * dt_factor) + impulse
		
		# Dirtiness check
		if accel != Vector2.ZERO or impulse != Vector2.ZERO:
			s.is_dirty = true
			#print(accel,impulse)

func _now_us() -> int:
	return Time.get_ticks_usec()

func _solve_snapshot_orbit(s: SimulationSnapshot, body:AbstractBinding, dt: float, is_ghost: bool):
	var t0 := _now_us()

	var solver = s.solver
	var start_rel_r = s.rel_r
	var start_rel_v = s.rel_v

	var t_init := _now_us()

	# ------------------------------------------------
	# 1. Sync Mu
	# ------------------------------------------------
	if not solver.set_mu(s.mu):
		var t_recreate_start := _now_us()
		solver = create_solver(body)
		s.solver = solver
		if not solver.set_mu(s.mu):
			s.rel_r += s.rel_v * dt
			print("MU fallback time:", _now_us() - t_recreate_start, "us")
			return
		print("Solver recreate time:", _now_us() - t_recreate_start, "us")

	var t_mu := _now_us()

	# ------------------------------------------------
	# 2. Solver Sync (Dirty)
	# ------------------------------------------------
	if s.is_dirty:
		#var t_dirty_start := _now_us()
		solver.from_cartesian(s.rel_r, s.rel_v)
		s.is_dirty = false
		#print("Dirty sync time:", _now_us() - t_dirty_start, "us")

	var t_dirty := _now_us()

	# ------------------------------------------------
	# 3. Propagation / Cartesian
	# ------------------------------------------------
	var state: State2D
	var t_prop_start := _now_us()

	if is_ghost:
		state = solver.to_cartesian(solver.t + dt)
	else:
		solver.propagate(dt)
		state = solver.to_cartesian()

	var t_prop := _now_us()

	# ------------------------------------------------
	# 4. Apply + NaN safety
	# ------------------------------------------------
	var t_apply_start := _now_us()

	if is_vec2_nan(state.r) or is_vec2_nan(state.v):
		s.rel_r += s.rel_v * dt
	else:
		s.rel_r = state.r
		s.rel_v = state.v

	var t_apply := _now_us()

	# ------------------------------------------------
	# TOTAL
	# ------------------------------------------------
	var t_end := _now_us()

	prints(
		"Total:", t_end - t0, "us |",
		"init:", t_init - t0,
		"mu:", t_mu - t_init,
		"dirty:", t_dirty - t_mu,
		"prop+cart:", t_prop - t_dirty,
		"apply:", t_apply - t_prop
	)

func _resolve_global_states(snapshots: Dictionary):
	var visit_state := {} 
	for body in snapshots.keys():
		visit_state[body] = 0
		
	for body in snapshots.keys():
		_calculate_recursive(body, snapshots, visit_state)

func _calculate_recursive(body: AbstractBinding, snapshots: Dictionary, visit_map: Dictionary):
	if visit_map[body] == 2: return
	if visit_map[body] == 1: assert(false, "Cyclic dependency!")
	
	visit_map[body] = 1 
	var s = snapshots[body]
	var parent = body.get_parent_binding()
	
	if parent and snapshots.has(parent):
		_calculate_recursive(parent, snapshots, visit_map)
		var ps = snapshots[parent]
		s.global_r = ps.global_r + s.rel_r
		s.global_v = ps.global_v + s.rel_v
	else:
		# Root bodies use their relative as global
		s.global_r = s.rel_r
		s.global_v = s.rel_v
		
	visit_map[body] = 2

func _reintegrate_snapshots(snapshots: Dictionary) -> void:
	for body:AbstractBinding in snapshots.keys():
		var s: SimulationSnapshot = snapshots[body]
		
		# USE RELATIVE, NOT GLOBAL
		body.sim_position = s.global_r
		body.sim_velocity = s.global_v
		
		body.solver_dirty = s.is_dirty
		
		# Ensure the solver knows exactly what its primary was doing
		if body.sim_context:
			body.sim_context.mu = s.mu
			body.sim_context.r_primary = s.r_primary
			body.sim_context.v_primary = s.v_primary
			
	
func is_vec2_nan(v: Vector2) -> bool:
	return is_nan(v.x) or is_nan(v.y)

func reset_forces():
	var bodies = model.values()
	for body in bodies:
		body.constant_forces = Vector2.ZERO
