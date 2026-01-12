extends BaseBinding
class_name RigidBodyOrbitBinding

func get_body() -> RigidBody2D:
	return super.get_body() as RigidBody2D

func init() -> void:
	super.init()
	var body = get_body()
	body.custom_integrator = true
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
	self.impulse += impulse

func integrate_impulse(impulse:Vector2):
	sim_velocity += impulse
