class_name ContextBuilder

var tol := 1e-4
var hysteresis := 0.98 

func build(model: OrbitalModel) -> void:
	var bodies = model.values()
	
	for body in model.values():
		# Only update if necessary or if it has no context
		var new_ctx = update_context(body, model, body.sim_context)
		if body.sim_context != new_ctx:
			body.sim_context = new_ctx

func update_context(body: AbstractBinding, model: OrbitalModel, old: OrbitalContext) -> OrbitalContext:
	# 1. Perturbation check (doesn't change hierarchy)
	if body.compute_deviation() > tol:
		body.solver_dirty = true
	
	# 2. Bootstrap if missing
	if old == null:
		var best_p = OrbitalHierarchy.find_best_primary(body, model)
		return _make_context(body, best_p, model) if best_p else _make_root_context(body, model)

	# 3. Transitions (Only if we have a primary)
	if old.primary != null:
		# Downward Check
		for sibling in old.capture_candidates:
			if not is_instance_valid(sibling): continue
			var d = body.sim_position.distance_to(sibling.sim_position)
			var soi = OrbitalHierarchy.compute_soi_radius(sibling, old.primary)
			if d < (soi * hysteresis):
				return _make_context(body, sibling, model)

		# Upward Check
		var d_pri = body.sim_position.distance_to(old.primary.sim_position)
		if d_pri > (old.escape_radius / hysteresis):
			var gp = old.primary.sim_context.primary if old.primary.sim_context else null
			return _make_context(body, gp, model) if gp else _make_root_context(body, model)
	
	# 4. Root-to-Star Transition (For Interstellar objects)
	else:
		for root_sib in old.capture_candidates:
			var d = body.sim_position.distance_to(root_sib.sim_position)
			# Roots check capture against each other's "Star" SOI (Arbitrary or mass-based)
			# For simplicity, we can just dive again if roots are close
			if d < 10000: # Replace with a proper distance check if needed
				var best_p = OrbitalHierarchy.find_best_primary(body, model)
				if best_p: return _make_context(body, best_p, model)

	return old

# --- Factories ---

func _make_context(body: AbstractBinding, parent: AbstractBinding, model: OrbitalModel) -> OrbitalContext:
	# Circuit breaker for cycles
	if parent == null or parent == body or OrbitalHierarchy.is_descendant_of(parent, body):
		return _make_root_context(body, model)

	var ctx = OrbitalContext.new()
	ctx.subject = body
	ctx.primary = parent
	
	# Sibling discovery (The 'Gravity Generators' sharing our parent)
	for other in model.values():
		if other != body and other.produces_gravity:
			if other.sim_context and other.sim_context.primary == parent:
				ctx.capture_candidates.append(other)
	
	# Boundaries
	var gp = parent.sim_context.primary if parent.sim_context else null
	ctx.escape_radius = OrbitalHierarchy.compute_soi_radius(parent, gp) if gp else INF
	
	ctx.mu = parent.get_mu()
	ctx.r_primary = body.sim_position - parent.sim_position
	ctx.v_primary = body.sim_velocity - parent.sim_velocity
	body.solver_dirty = true
	return ctx

func _make_root_context(body: AbstractBinding, model: OrbitalModel) -> OrbitalContext:
	var ctx = OrbitalContext.new()
	ctx.subject = body
	ctx.primary = null
	ctx.escape_radius = INF
	
	for other in model.values():
		if other != body and other.produces_gravity:
			if other.sim_context == null or other.sim_context.primary == null:
				ctx.capture_candidates.append(other)
	return ctx
