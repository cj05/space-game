class_name OrbitalModel

var celestial_bodies: Dictionary[Node,AbstractBinding]
# thats it hehe
func insert(object: AbstractBinding) -> void:
	celestial_bodies[object.get_body()] = object
	
func delete(object: AbstractBinding) -> void:
	celestial_bodies.erase(object.get_body())

func get_by_node(node: Node) -> AbstractBinding:
	return celestial_bodies[node]

func values() -> Array[AbstractBinding]:
	return celestial_bodies.values()
