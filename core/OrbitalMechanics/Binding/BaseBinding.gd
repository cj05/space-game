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

func integrate_uncatched_impulse():
	pull_from_scene()
	
func collision_handle(state:PhysicsDirectBodyState2D) -> bool:
	
	if(respond_collision):
		var contact_count := state.get_contact_count()
		#print(contact_count)
		for i in range(contact_count):
			var collider := state.get_contact_collider_object(i)
			var position := state.get_contact_local_position(i)
			var normal := state.get_contact_local_normal(i)
			var impulse := state.get_contact_impulse(i)

			if collider:
				#print("Contact no",i)
				#print("Collided with:", collider.name)
				#print("Normal:", normal)
				#print("Impulse:", impulse)
				
				apply_immediate_impulse(impulse)
				
		if(contact_count > 0):
			return true
	return false
