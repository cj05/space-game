class_name OrbitalSolver

# --- pre-initialization ----------------------------------------------------
var context_builder := ContextBuilder.new()
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
		body.sim_solver = get_solver_for_type(body.role)
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

func step_all(delta:float):
	## For future reference, unimpl
	## 0 - Precompute N body logic here
	
	## 1 - Build Context for Orbits
	context_builder.build(model)
	
	## 2 - Compute Orbits
	for candidate in model.values():
		solve_orbit(candidate,delta)
	
	## 3 - Collapse it back to reality
	propagate_orbit(model)
	



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
		print(state.r,state.v,r_pos,r_vel,context.primary)
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
	var parent = candidate.sim_context.primary
	if(parent and parent != candidate):
		out = out.add(calculate_state(model,parent))
	if out:
		candidate.sim_position = out.r
		candidate.sim_velocity = out.v
		candidate.visit_state = AbstractBinding.VisitState.VISITED
		return out
	
	candidate.visit_state = AbstractBinding.VisitState.VISITED
	return State2D.new(Vector2.ZERO,Vector2.ZERO)
	
