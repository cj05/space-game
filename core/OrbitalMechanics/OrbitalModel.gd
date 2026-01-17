class_name OrbitalModel

var celestial_bodies: Dictionary[Node,AbstractBinding] = {}

# --- Cache variables ---
var _cached_values: Array[AbstractBinding] = []
var _cache_dirty: bool = true

func insert(object: AbstractBinding) -> void:
	celestial_bodies[object.get_body()] = object
	_cache_dirty = true
	
func delete(object: AbstractBinding) -> void:
	if celestial_bodies.erase(object.get_body()):
		_cache_dirty = true

func get_by_node(node: Node) -> AbstractBinding:
	return celestial_bodies.get(node)

func values() -> Array[AbstractBinding]:
	if _cache_dirty:
		_update_cache()
	return _cached_values

func _update_cache() -> void:
	_cached_values = celestial_bodies.values()
	# Sort by mass descending: Parents first, then children
	_cached_values.sort_custom(func(a, b): return a.mass > b.mass)
	_cache_dirty = false
