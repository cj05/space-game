extends AbstractBinding
class_name BaseBinding
## Abstract binding for bodies that move via kinematic rules.
## Still no solver logic.

func get_body() -> PhysicsBody2D:
	return super.get_body() as PhysicsBody2D

func apply_displacement(state) -> void:
	assert(false, "apply_displacement must be implemented by subclass")


func pull_from_scene() -> void:
	assert(false, "pull_from_scene must be implemented by subclass")
