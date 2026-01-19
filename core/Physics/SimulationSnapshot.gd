class_name SimulationSnapshot
extends RefCounted

var body: AbstractBinding
var solver: AbstractSolver

# Math Context
var mu: float = 0.0
var r_primary: Vector2 = Vector2.ZERO
var v_primary: Vector2 = Vector2.ZERO

# Intermediate state
var rel_r: Vector2
var rel_v: Vector2

# Final output
var global_r: Vector2
var global_v: Vector2

var is_dirty: bool = false
var body_start_sim_pos: Vector2 # Added this to fix the "Invalid Access" error

func _init(_body: AbstractBinding, _solver: AbstractSolver, is_ghost: bool):
	self.body = _body
	self.rel_r = _body.sim_position
	self.rel_v = _body.sim_velocity
	self.is_dirty = _body.solver_dirty
	
	# Capture this immediately for the debug comparison
	self.body_start_sim_pos = _body.sim_position
	
	if is_ghost and _solver:
		# Use duplicate if it exists, otherwise manual clone or reference
		if _solver.has_method("duplicate"):
			self.solver = _solver.duplicate()
		elif _solver.has_method("clone"):
			self.solver = _solver.clone()
		else:
			self.solver = _solver
	else:
		self.solver = _solver

func prepare_context(snapshots: Dictionary) -> void:
	var parent = body.get_parent_binding()
	
	if parent:
		self.mu = parent.get_mu()
		#print(mu," ",solver.mu)
		# Relative context calculation
		# We use the LIVE body positions to ensure the relative anchor is clean
		self.rel_r = body.sim_position - parent.sim_position
		# v_primary uses the snapshot's rel_v because it was modified by Phase 1 Kick
		self.rel_v = self.rel_v - parent.sim_velocity
	else:
		self.mu = 0.0
		self.r_primary = Vector2.ZERO
		self.v_primary = self.rel_v
