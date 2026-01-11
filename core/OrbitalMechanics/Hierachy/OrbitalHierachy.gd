class_name OrbitalHierarchy

const MAX_RECURSION_DEPTH = 10

static func compute_soi_radius(child: AbstractBinding, parent: AbstractBinding) -> float:
	if child == parent: return 0.0
	var r := child.sim_position.distance_to(parent.sim_position)
	var soi = r * pow(child.mass / parent.mass, 0.4)
	return soi

static func is_descendant_of(potential_parent: AbstractBinding, subject: AbstractBinding) -> bool:
	var current = potential_parent
	var safety_check = 0
	while current != null and current.sim_context != null and safety_check < MAX_RECURSION_DEPTH:
		var p = current.sim_context.primary
		if p == subject: return true
		current = p
		safety_check += 1
	return false

static func find_best_primary(body: AbstractBinding, model: OrbitalModel) -> AbstractBinding:
	var best_root: AbstractBinding = null
	var best_score := -INF
	
	for candidate in model.values():
		# FIX 1: Mass Gate. A parent must be more massive than the child.
		# This prevents the Sun from orbiting the Earth.
		if not candidate.produces_gravity or candidate == body or candidate.mass <= body.mass: 
			continue
		
		var is_root = candidate.sim_context == null or candidate.sim_context.primary == null
		if not is_root: continue
		
		var score = candidate.mass / body.sim_position.distance_squared_to(candidate.sim_position)
		if score > best_score:
			best_score = score
			best_root = candidate
			
	if best_root == null: 
		return null
		
	return _dive_into_hierarchy(body, best_root, model, 0)
	
static func _dive_into_hierarchy(body: AbstractBinding, parent: AbstractBinding, model: OrbitalModel, depth: int) -> AbstractBinding:
	if depth > MAX_RECURSION_DEPTH: return parent
	
	var best_child: AbstractBinding = null
	
	for other in model.values():
		# FIX 2: Again, mass gate. Don't dive into something smaller than the subject
		# unless it's a special case (like a ship).
		if other == body or other == parent or not other.produces_gravity or other.mass <= body.mass: 
			continue
		
		# Check if 'other' is actually a child of our current 'parent'
		# On bootstrap (null context), we assume it is if it's closer to the parent than we are.
		var is_proper_child = (other.sim_context == null) or (other.sim_context.primary == parent)
		
		if is_proper_child:
			var dist_to_other = body.sim_position.distance_to(other.sim_position)
			var soi = compute_soi_radius(other, parent)
			
			if dist_to_other < soi:
				if best_child == null or other.mass > best_child.mass:
					best_child = other

	if best_child != null:
		return _dive_into_hierarchy(body, best_child, model, depth + 1)
				
	return parent
