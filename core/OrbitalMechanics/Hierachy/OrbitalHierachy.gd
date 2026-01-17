class_name OrbitalHierarchy

const MAX_RECURSION_DEPTH = 10

## Laplace SOI formula: r_soi = a * (m/M)^(2/5)
static func compute_soi_radius(child: AbstractBinding, parent: AbstractBinding) -> float:
	
	if child == parent or not parent: return INF
	var distance := child.get_global_position().distance_to(parent.get_global_position())
	return distance * pow(child.mass / parent.mass, 0.4)

## Prevents infinite loops and circular orbits (A orbits B orbits A)
static func is_descendant_of(potential_parent: AbstractBinding, subject: AbstractBinding) -> bool:
	var current = potential_parent
	for i in MAX_RECURSION_DEPTH:
		if not current or not current.sim_context: break
		var p = current.get_parent_binding()
		if p == subject: return true
		current = p
	return false

## Entry point for finding the most influential gravity source
static func find_best_primary(body: AbstractBinding, model: OrbitalModel) -> AbstractBinding:
	var root_parent = _find_dominant_root(body, model)
	if not root_parent: 
		return null
		
	return _dive_into_hierarchy(body, root_parent, model, 0)

## Finds the root-level object (e.g. Star) with the highest gravitational pull
static func _find_dominant_root(body: AbstractBinding, model: OrbitalModel) -> AbstractBinding:
	var best_root: AbstractBinding = null
	var best_score := -INF
	
	for candidate in model.values():
		if not candidate.produces_gravity or candidate == body: continue
		if candidate.mass <= body.mass: continue
		
		# Only check root objects (bodies with no primary)
		var is_root = body.get_parent_binding() == null
		if not is_root: continue
		
		# Newton's law simplified for scoring (M/r^2)
		var score = candidate.mass / body.sim_position.distance_squared_to(candidate.sim_position)
		if score > best_score:
			best_score = score
			best_root = candidate
			
	return best_root

## Recursively steps down the tree (Star -> Planet -> Moon)
static func _dive_into_hierarchy(body: AbstractBinding, parent: AbstractBinding, model: OrbitalModel, depth: int) -> AbstractBinding:
	if depth >= MAX_RECURSION_DEPTH: return parent
	
	var best_child: AbstractBinding = null
	
	for other in model.values():
		# Filter candidates: must be gravity producers, larger than subject, and children of current parent
		if other == body or other == parent or not other.produces_gravity: continue
		if other.mass <= body.mass: continue
		
		var is_child_of_parent = other.get_parent_binding() == parent
		if not is_child_of_parent: continue
		print("found",other,"for",body)
		
		# Check if the subject is within this candidate's Sphere of Influence
		var dist_to_other = body.get_global_position().distance_to(other.get_global_position())
		var soi = compute_soi_radius(other, parent)
		print(dist_to_other , soi)
		if dist_to_other < soi:
			# If multiple children overlap, pick the most massive one (dominant influence)
			if not best_child or other.mass > best_child.mass:
				print("found_better",other,"for",body)
				best_child = other

	if best_child:
		return _dive_into_hierarchy(body, best_child, model, depth + 1)
				
	return parent

## Helper to find all bodies sharing the same parent
static func find_siblings(body: AbstractBinding, parent: AbstractBinding, model: OrbitalModel) -> Array:
	var siblings = []
	for other in model.values():
		if other == body or not other.produces_gravity: continue
		var other_pri = other.get_parent_binding()
		if other_pri == parent:
			siblings.append(other)
	return siblings
