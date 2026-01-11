extends RigidBody2D

func _ready():
	print("ready ", global_position, linear_velocity)

func _process(delta):
	print("process ", global_position, linear_velocity)

func _integrate_forces(state:PhysicsDirectBodyState2D):
	print("integrate1 ", global_position, linear_velocity)
	if(custom_integrator):
		_integrate_forces_replica(state)
		print("integrate2 ", global_position, linear_velocity)
	
func _integrate_forces_replica(state:PhysicsDirectBodyState2D):
	var step = get_physics_process_delta_time();
	var lv = state.linear_velocity;
	lv += get_gravity() * step;

	var av = state.angular_velocity;

	var damp = 1.0 - step * linear_damp;

	if (damp < 0):
		damp = 0;

	lv *= damp;

	damp = 1.0 - step * angular_damp;

	if (damp < 0) :
		damp = 0

	av *= damp;
	
	state.linear_velocity = lv;
	state.angular_velocity = av;

func _physics_process(delta):
	print("phys ", global_position, linear_velocity)
	
	
