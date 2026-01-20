extends BaseBinding
class_name RigidBodyOrbitBinding

func get_body() -> RigidBody2D:
	return super.get_body() as RigidBody2D

func init() -> void:
	super.init()
	var body = get_body()
	body.custom_integrator = true
	body.max_contacts_reported = 8
	pull_from_scene()
	

func apply_displacement(state: PhysicsDirectBodyState2D) -> void:
	var body = get_body()
	# reflect the solver position to the body by modifying position
	state.linear_velocity = (sim_position - state.transform.origin) / state.step
	#print("LV ",state.linear_velocity)
	#print("k ",sim_position," ",body.global_position)
	
func pull_from_scene() -> void:
	sim_position = get_body().global_position
	sim_velocity = get_body().linear_velocity

func compute_deviation() -> float:
	
	var dt = get_physics_process_delta_time()
	var body = get_body()
	
	var next_pos = body.global_position+body.linear_velocity*dt
	var next_vel = (sim_position-body.global_position)/dt

	var dr = sim_position.distance_to(next_pos)
	var dv = body.linear_velocity.distance_to(next_vel)

	# characteristic scales (pick sane defaults)
	var L = 1#reference_radius      # e.g. SOI radius or orbit radius
	var V = 1#reference_speed       # e.g. orbital speed
	#print("k ",dr," ",dv,body.linear_velocity,next_vel)
	#print("k ",dr," ",dv,body.linear_velocity,next_vel)

	return sqrt((dr / L) * (dr / L) + (dv / V) * (dv / V))
	
# --- force hooks -----------------------------------------------------------

func apply_central_impulse_hook(impulse: Vector2):
	self.pending_impulse += impulse

func integrate_impulse(impulse:Vector2):
	sim_velocity += impulse
	solver_dirty = true
	

func get_global_position()->Vector2:
	var body = get_body()
	return body.global_position
	
func get_global_velocity()->Vector2:
	var body = get_body()
	return body.linear_velocity

func apply_immediate_impulse(impulse: Vector2):
	var dt = get_physics_process_delta_time()
	var parent = get_parent_binding()
	
	# 1. Safely get MU
	var mu = 0.0
	var parent_pos = Vector2.ZERO
	var parent_vel = Vector2.ZERO
	
	if parent:
		parent_pos = parent.get_global_position()
		parent_vel = parent.get_global_velocity()
		mu = parent.get_mu() # Pull mu directly from parent
	
	# 2. Sync state from physics engine
	sim_velocity = get_global_velocity()
	sim_position = get_global_position()
	
	# 3. Print with safety check
	#if mu > 0:
		#print("Energy: ", calculate_orbital_energy(sim_position, sim_velocity, parent_pos, parent_vel, mu))
	
	# 4. Trigger the solver re-anchor
	solver_dirty = true

func crude_integrate_forces(state:PhysicsDirectBodyState2D):
	var dt = get_physics_process_delta_time()
	state.apply_central_impulse(pending_impulse + constant_forces *dt)
	pending_impulse = Vector2.ZERO
	constant_forces = Vector2.ZERO

func calculate_orbital_energy(pos: Vector2, vel: Vector2, parent_pos:Vector2, parent_vel:Vector2, mu: float) -> float:
	# 1. Calculate the distance (r) and speed squared (v^2)
	var relative_pos = pos - parent_pos
	var r = relative_pos.length()
	var relative_vel = vel - parent_vel
	var v_squared = relative_vel.length_squared()
	
	# Avoid division by zero if exactly at the center
	if r == 0:
		return 0.0
	
	# 2. Kinetic Energy component (v^2 / 2)
	var kinetic = v_squared / 2.0
	
	# 3. Potential Energy component (-mu / r)
	var potential = -mu / r
	
	return kinetic + potential

func get_soi_radius()->float:
	#print(get_parent_binding(),get_parent().name,self.name)
	if get_parent_binding():
		#print("HH")
		return OrbitalHierarchy.compute_soi_radius(self, get_parent_binding())
	return INF

func period() -> float:
	var parent = get_parent_binding()
	if parent == null:
		return INF
	
	var mu := sim_context.mu
	if mu <= 0.0:
		return INF
	
	# Relative state
	var r_vec := sim_position - parent.get_global_position()
	var v_vec :Vector2 = sim_velocity - parent.get_global_velocity()
	
	var r := r_vec.length()
	if r <= 0.0:
		return INF
	
	var v2 := v_vec.length_squared()
	
	# Specific orbital energy
	var energy := 0.5 * v2 - mu / r
	
	# Unbound orbit (parabolic or hyperbolic)
	if energy >= 0.0:
		return INF
	
	# Semi-major axis
	var a := -mu / (2.0 * energy)
	if a <= 0.0:
		return INF
	
	# Kepler period
	return TAU * sqrt(a * a * a / mu)
