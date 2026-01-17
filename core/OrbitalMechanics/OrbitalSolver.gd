class_name OrbitalSolver

# --- pre-initialization ----------------------------------------------------
var context_builder := OrbitalContextBuilder.new()
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
		#print("H")
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
	
# --- lifecycle ----------------------------------------------------

# OrbitalSolver.gd

func _apply_kick(dt_factor: float, apply_impulses: bool):
	for body in model.values():
		var accel = body.get_accumulated_acceleration()
		
		# Apply partial force kick
		body.sim_velocity += accel * dt_factor
		
		# Apply full impulses only during the first kick phase
		if apply_impulses and body.pending_impulse != Vector2.ZERO:
			body.sim_velocity += body.pending_impulse / body.mass
			body.pending_impulse = Vector2.ZERO
			body.solver_dirty = true
		
		# If the velocity changed, the Keplerian orbit is now invalid
		if accel != Vector2.ZERO:
			body.solver_dirty = true

func step_all(delta: float):
	# PHASE 1: KICK (Half force, Full impulse)
	
	_apply_kick(delta * 0.5, true)
	
	# PHASE 2: DRIFT
	context_builder.build_model(model)
	for candidate in model.values():
		#print("hi ",model.values())
		solve_orbit(candidate, delta)
	
	# PHASE 3: KICK (Final half force)
	_apply_kick(delta * 0.5, false)
	
	# PHASE 4: COLLAPSE
	propagate_orbit(model)
	
	# Reset constant forces AFTER the final kick is processed
	for body in model.values():
		body.constant_forces = Vector2.ZERO
	

# Inside AbstractBinding.gd or a PhysicsHandler
const TOLERANCE := 1e-4

func process_impulse(body: AbstractBinding):
	# Handle external perturbations
	if body.compute_deviation() > TOLERANCE:
		body.solver_dirty = true
		body.integrate_uncatched_impulse()
	
	# Handle discrete impulses (Explosions, Engines)
	if body.pending_impulse.length() > 0:
		body.solver_dirty = true
		body.integrate_impulse(body.pending_impulse) 
		body.pending_impulse = Vector2.ZERO

func solve_orbit(body: AbstractBinding, dt: float):
	var solver = get_solver(body)
	var mu = body.sim_context.mu
	if(not solver.set_mu(mu)):
		print("Recreating MU")
		solver = create_solver(body)
		if(not solver.set_mu(mu)):
			print("Error: Mu calculation failed")
	
	var context = body.sim_context
	
	var r_pos = context.r_primary
	var r_vel = context.v_primary
	#print(r_pos,r_vel)
	
	if(r_pos == Vector2.ZERO and r_vel == Vector2.ZERO):
		body.temp_rel_state2D = State2D.new(Vector2.ZERO,Vector2.ZERO)
		return
	
	if body.solver_dirty:
		print("solver dirt", r_pos, r_vel)
		solver.from_cartesian(r_pos, r_vel)
		body.solver_dirty = false
	
	solver.propagate(dt)
	var state:State2D = solver.to_cartesian()
	body.temp_rel_state2D = state
	if is_vec2_nan(state.r) or is_vec2_nan(state.v):
		print("bad",state.r,state.v,r_pos,r_vel,body.get_parent_binding())
	#print(state.r,state.v)


func is_vec2_nan(v: Vector2) -> bool:
	return is_nan(v.x) or is_nan(v.y)

func propagate_orbit(model: OrbitalModel):
	# DAG traversal
	# O(n)
	# reset visit state
	for candidate in model.values():
		candidate.visit_state = AbstractBinding.VisitState.UNVISITED
	
	for candidate in model.values():
		calculate_state(model,candidate)

func calculate_state(model: OrbitalModel, candidate: AbstractBinding) -> State2D:
	if(candidate.visit_state == AbstractBinding.VisitState.VISITED):
		return State2D.new(candidate.sim_position,candidate.sim_velocity)
	
	if(candidate.visit_state == AbstractBinding.VisitState.VISITING):
		#this is NOT a DAG
		assert(false,"There are cycles in the Hierachy, please fix")
	
	candidate.visit_state = AbstractBinding.VisitState.VISITING
	# start visiting
	# recursively call
	var out = candidate.temp_rel_state2D
	#print(out.r,out.v," ",candidate)
	var parent = candidate.get_parent_binding()
	if(parent and parent != candidate):
		out = out.add(calculate_state(model,parent))
	if out:
		candidate.sim_position = out.r
		candidate.sim_velocity = out.v
		candidate.visit_state = AbstractBinding.VisitState.VISITED
		return out
	
	candidate.visit_state = AbstractBinding.VisitState.VISITED
	return State2D.new(Vector2.ZERO,Vector2.ZERO)
	
