# orbit_state.gd
class_name OrbitState
extends Resource

var position: Vector3
var velocity: Vector3
var mu: float
var epoch: float

# Metadata for the drawer (e.g., is the orbit closed or hyperbolic?)
var is_escaped: bool = false
