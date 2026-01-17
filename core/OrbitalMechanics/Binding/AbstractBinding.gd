extends Node
class_name AbstractBinding
## Adapter between a scene node and the orbital simulation.
## No control logic. No integration logic.
## Pure contract + registration.

# --- configuration ---------------------------------------------------------

@export var role: OrbitalRole.Type = OrbitalRole.Type.UNASSIGNED

@export var produces_gravity: bool = false
@export var receives_gravity: bool = true
@export var respond_collision: bool = true

## Specifies the parent it will be orbiting around
## Leave null if you want it to dynamically calculate it
## Specifying this will make the object always behave with 
## only respect to the specified parent
@export var fixed_primary_node: Node = null

# --- physical parameters ---------------------------------------------------

@export var mass: float = 0.0
@export var radius: float = 0.0

# --- Solver ---------------------------------------------------------------
var sim_solver: AbstractSolver = null

# --- authoritative simulation state ---------------------------------------

var sim_position: Vector2 = Vector2.ZERO
var sim_velocity: Vector2 = Vector2.ZERO

var sim_context: OrbitalContext

var solver_dirty := true

# --- temporary cache state ------------------------------------------------
var last_parent: AbstractBinding

var temp_rel_state2D: State2D

enum VisitState { UNVISITED, VISITING, VISITED }
var visit_state := VisitState.UNVISITED

# Cached reference to owning spatial node
func get_body() -> Node:
	return self as Node
	
# --- cached force appliers -------------------------------------------------
var constant_forces: Vector2 = Vector2.ZERO
var pending_impulse: Vector2 = Vector2.ZERO

# --- lifecycle -------------------------------------------------------------

func _ready() -> void:
	assert(get_body() != null, "AbstractBinding must be a child of Node")
	init()

func _enter_tree():
	_register()

func _exit_tree() -> void:
	_unregister()
	
func _integrate_forces(state:PhysicsDirectBodyState2D) -> void:
	
	
	if not collision_handle(state):
		apply_displacement(state)
	#print(state.linear_velocity)
	

func collision_handle(state:PhysicsDirectBodyState2D) -> bool:
	return false

# --- registration ----------------------------------------------------------

func _register() -> void:
	assert(OrbitalMechanics.registry != null)
	OrbitalMechanics.registry.register_body(self)
	print("regisrter")

func _unregister() -> void:
	assert(OrbitalMechanics.registry != null)
	OrbitalMechanics.registry.unregister_body(self)
	print("unregisrter :(")

# --- state sync ------------------------------------------------------------

func init() -> void:
	## One-time sync at spawn
	pass

func apply_displacement(state) -> void:
	pass
	
func pull_from_scene() -> void:
	pass

# --- solver hooks ----------------------------------------------------------

func get_acceleration(context) -> Vector2:
	## Optional external forces (thrust, drag, etc.)
	return Vector2.ZERO

func compute_deviation() -> float:
	## Computes the positional deviation of the output compared to what solver predicted last time
	return 0
	
func get_mu() -> float:
	#print(mass * Orbital_Constants.G)
	return mass * Orbital_Constants.G

# --- drawer hooks ----------------------------------------------------------

func sample(true_anomaly:float) -> Vector2: #
	if not sim_solver: 
		return Vector2.ZERO
	var offset = Vector2.ZERO
	var parent = get_parent_binding()
	if parent:
		offset += parent.get_body().global_position
	return sim_solver.sample_point_at(true_anomaly) + offset
	
func get_true_anomaly()->float:
	if sim_solver:
		sim_solver.compute_ta()
		return sim_solver.get_true_anomaly()
	return 0
	
func get_orbit_dir()->float:
	if sim_solver:
		return sim_solver.get_orbit_dir()
	return 0
	
func get_eccentricity()->float:
	if sim_solver:
		return sim_solver.get_eccentricity()
	return 0
func integrate_impulse(impulse:Vector2):
	pass
func integrate_uncatched_impulse():
	pass
func apply_central_impulse_hook(impulse: Vector2):
	pass
func apply_immediate_impulse(impulse: Vector2):
	pass
func get_global_position()->Vector2:
	return Vector2.ZERO
func get_soi_radius()->float:
	return 0
func add_force(f: Vector2):
	constant_forces += f
func get_accumulated_acceleration() -> Vector2:
	return constant_forces / mass if mass > 0 else Vector2.ZERO
func get_parent_binding()->AbstractBinding:
	return get_parent() as AbstractBinding
	
func assign_parent(parent:AbstractBinding):
	print(parent)
	reparent(parent)
	
func _on_initial_bind(parent: AbstractBinding) -> void:
	# Hard bind, no exit logic
	assign_parent(parent)
	
func _on_exit_soi(old_parent: AbstractBinding) -> void:
	if old_parent:
		sim_position += old_parent.sim_position
		sim_velocity += old_parent.sim_velocity

	sim_solver = null
	sim_context = null
	last_parent = old_parent

func _on_enter_soi(new_parent: AbstractBinding) -> void:
	if new_parent:
		sim_position -= new_parent.sim_position
		sim_velocity -= new_parent.sim_velocity
