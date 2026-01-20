# SolverBase.gd
# Abstract base class for orbital propagation solvers.
# Provides shared structure: calculate(), propagate(), and utilities.
extends Resource
class_name AbstractSolver

var mu_locked := false

func _init(mu_value: float = 0.0):
	if mu_value > 0.0:
		set_mu(mu_value)
		
func set_mu(mu_value: float) :
	if(mu_value == mu):
		return true
	if mu_locked:
		return false
	if mu_value > 0.0:
		mu = mu_value
		mu_locked = true
	return true
		

# --- Physical parameter ------------------------------------------------------

var mu: float

# --- Public API --------------------------------------------------------------

func from_cartesian(relative_position: Vector2, relative_velocity: Vector2) -> void:
	"""Calculate solver-specific variables
	Override in subclass.
	"""
	push_error("from_cartesian() not implemented in subclass")

func propagate(dt: float) -> void:
	"""Propagate position & velocity forward by dt.
	Override in subclass.
	"""
	push_error("propagate() not implemented in subclass")

func to_cartesian(target_t: float = -1.0) -> State2D:
	"""Compute Cartesian Parameters [r,v]
	Override in subclass.
	"""
	push_error("to_cartesian() not implemented in subclass")
	return State2D.new(Vector2.ZERO,Vector2.ZERO)

# --- Read-only Utilities --------------------------------------------------------

func energy() -> float:
	# Specific orbital energy ε
	push_error("energy() not implemented in subclass")
	return 0.0
	
func period() -> float:
	return INF

func angular_momentum() -> float:
	# |r × v| (2D)
	push_error("angular_momentum() not implemented in subclass")
	return 0.0

func compute_params() -> void:
	pass

func compute_ta() -> void:
	pass
	
func get_true_anomaly() -> float:
	return 0
	
func get_orbit_dir()->float:
	return 1.0

func get_eccentricity()->float:
	return 0

func sample_point_at(true_anomaly:float) -> Vector2:
	return Vector2.ZERO

func time_to_radius(target_r: float) -> float:
	return 0

# Subclasses must implement all of the functions
