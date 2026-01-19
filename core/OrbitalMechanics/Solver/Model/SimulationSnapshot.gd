class_name SimulationSnapshot

var body: AbstractBinding
var solver: AbstractSolver

# Math Context
var mu: float = 0.0
var r_primary: Vector2 = Vector2.ZERO
var v_primary: Vector2 = Vector2.ZERO

# Intermediate state (Relative to parent/origin)
var rel_r: Vector2
var rel_v: Vector2

# Final output (World coordinates)
var global_r: Vector2
var global_v: Vector2

var is_dirty: bool

func _init(_body: AbstractBinding, _solver: AbstractSolver, is_ghost: bool):
	self.body = _body
	self.rel_r = _body.sim_position
	self.rel_v = _body.sim_velocity
	
	self.is_dirty = _body.solver_dirty
	
	# We receive the solver from the OrbitalSolver now
	if is_ghost and _solver:
		self.solver = _solver.duplicate()
	else:
		self.solver = _solver

# NEW: Replaces OrbitalContextBuilder logic
func prepare_context(snapshots: Dictionary) -> void:
	var parent = body.get_parent_binding()
	
	if parent:
		self.mu = parent.get_mu()
		# IMPORTANT: Always calculate relative context from the 
		# Global Sim Positions of the bodies at the START of the step.
		self.r_primary = body.sim_position - parent.sim_position
		self.v_primary = body.sim_velocity - parent.sim_velocity # rel_v includes Phase 1 Kick
	else:
		self.mu = 0.0
		self.r_primary = Vector2.ZERO
		self.v_primary = rel_v
