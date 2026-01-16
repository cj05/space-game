class_name OrbitalContextBuilder

func build_model(model: OrbitalModel) -> void:
	for body in model.values():
		var current_pri = body.sim_context.primary if body.sim_context else null
		var target_pri = SOIHandler.evaluate_primary(body, model)
		
		# Only rebuild if the hierarchy actually changed
		if body.sim_context == null or target_pri != current_pri:
			body.sim_context = _create_context(body, target_pri, model)
			body.solver_dirty = true
		else:
			_update_relative_state(body, body.sim_context)

func _create_context(body, parent, model) -> OrbitalContext:
	# Prevent cycles
	if parent == body or (parent and OrbitalHierarchy.is_descendant_of(parent, body)):
		parent = null

	var ctx = OrbitalContext.new()
	ctx.subject = body
	ctx.primary = parent
	ctx.capture_candidates = OrbitalHierarchy.find_siblings(body, parent, model)
	
	if parent:
		ctx.mu = parent.get_mu()
		var gp = parent.sim_context.primary if parent.sim_context else null
		ctx.escape_radius = OrbitalHierarchy.compute_soi_radius(parent, gp) if gp else INF
	else:
		ctx.escape_radius = INF
		
	_update_relative_state(body, ctx)
	return ctx

func _update_relative_state(body: AbstractBinding, ctx: OrbitalContext) -> void:
	if ctx.primary:
		ctx.r_primary = body.sim_position - ctx.primary.sim_position
		ctx.v_primary = body.sim_velocity - ctx.primary.sim_velocity
