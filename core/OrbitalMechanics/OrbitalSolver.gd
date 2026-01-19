class_name OrbitalSolver
# OrbitalSolver.gd

var model: OrbitalModel
var context_builder: OrbitalContextBuilder = OrbitalContextBuilder.new()

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

func step_all(delta: float, is_ghost: bool) -> Dictionary:
	var snapshots := {}
	var bodies = model.values()
	
	# INITIALIZE
	for body in bodies:
		# 1. Get the solver from THIS class (OrbitalSolver)
		var body_solver = get_solver(body) 
		
		# 2. Pass it into the snapshot
		snapshots[body] = SimulationSnapshot.new(body, body_solver, is_ghost)
	
	# PHASE 1: KICK
	_apply_kick_to_snapshots(snapshots, delta * 0.5, true, is_ghost)
	
	# PHASE 2: CONTEXT PREP (Internalized)
	for body in bodies:
		snapshots[body].prepare_context(snapshots)
	
	# PHASE 3: DRIFT
	for body in bodies:
		_solve_snapshot_orbit(snapshots[body], delta, is_ghost)
	
	# PHASE 4: KICK
	_apply_kick_to_snapshots(snapshots, delta * 0.5, false, is_ghost)
	
	# PHASE 5: COLLAPSE
	_resolve_global_states(snapshots)
	
	# REINTEGRATE
	if not is_ghost:
		_reintegrate_snapshots(snapshots)
			
	return snapshots
	
	
func _apply_kick_to_snapshots(snapshots: Dictionary, dt_factor: float, first_kick: bool, is_ghost: bool):
	for body in snapshots.keys():
		var s: SimulationSnapshot = snapshots[body]
		
		# Get forces from the live binding (forces are typically cleared per-frame)
		var accel = body.get_accumulated_acceleration()
		
		# Mutate snapshot velocity
		s.rel_v += accel * dt_factor
		
		# Apply impulses only on the first kick
		if first_kick and body.pending_impulse != Vector2.ZERO:
			s.rel_v += body.pending_impulse / body.mass
			
		# If this is a real step, we mark the solver dirty because velocity changed
		if not is_ghost and (accel != Vector2.ZERO or body.pending_impulse != Vector2.ZERO):
			s.is_dirty = true

func _solve_snapshot_orbit(s: SimulationSnapshot, dt: float, is_ghost: bool):
	var solver = s.solver
	
	# 1. Sync Mu
	if not solver.set_mu(s.mu):
		s.solver = create_solver(s.body)
		if is_ghost: s.solver = s.solver.duplicate()
		s.solver.set_mu(s.mu)

	# 2. Solver Sync (Perturbations/Dirty state)
	if s.is_dirty:
		s.solver.from_cartesian(s.r_primary, s.v_primary)
		s.is_dirty = false

	# 3. Propagate and Get State
	var state: State2D
	if is_ghost:
		# Predictive: Get state at a future time without advancing internal solver clock
		state = s.solver.to_cartesian(s.solver.t + dt)
	else:
		# Real: Mutate solver state forward in time
		s.solver.propagate(dt) # Returns void
		state = s.solver.to_cartesian() # Get the new state
		
		
	# 4. Apply result to snapshot
	if is_vec2_nan(state.r) or is_vec2_nan(state.v):
		s.rel_r = s.r_primary
		s.rel_v = s.v_primary
	else:
		s.rel_r = state.r
		s.rel_v = state.v

func _resolve_global_states(snapshots: Dictionary):
	# Using the original VisitState approach for safety
	var visit_state := {} # body -> VisitState
	for body in snapshots.keys():
		visit_state[body] = 0 # UNVISITED
		
	for body in snapshots.keys():
		_calculate_recursive(body, snapshots, visit_state)

func _calculate_recursive(body: AbstractBinding, snapshots: Dictionary, visit_map: Dictionary):
	if visit_map[body] == 2: # VISITED
		return
	
	if visit_map[body] == 1: # VISITING
		assert(false, "Cyclic dependency detected in orbital hierarchy!")
	
	visit_map[body] = 1 # VISITING
	
	var s = snapshots[body]
	var parent = body.get_parent_binding()
	
	if parent and parent != body:
		_calculate_recursive(parent, snapshots, visit_map)
		var ps = snapshots[parent]
		s.global_r = ps.global_r + s.rel_r
		s.global_v = ps.global_v + s.rel_v
	else:
		s.global_r = s.rel_r
		s.global_v = s.rel_v
		
	visit_map[body] = 2 # VISITED

func _reintegrate_snapshots(snapshots: Dictionary) -> void:
	for body in snapshots.keys():
		var s: SimulationSnapshot = snapshots[body]
		
		# 1. Apply resolved world coordinates
		body.sim_position = s.global_r
		body.sim_velocity = s.global_v
		
		# 2. Reset transient force accumulators for the next frame
		
		body.constant_forces = Vector2.ZERO
		body.pending_impulse = Vector2.ZERO
		
		# 3. Update the 'last_parent' to track SOI changes
		body.last_parent = body.get_parent_binding()
		
		# 4. Optional: Update the 'live' context if other systems rely on it
		if body.sim_context:
			body.sim_context.mu = s.mu
			body.sim_context.r_primary = s.r_primary
			body.sim_context.v_primary = s.v_primary
		
		body.solver_dirty = s.is_dirty
func is_vec2_nan(v: Vector2) -> bool:
	return is_nan(v.x) or is_nan(v.y)
