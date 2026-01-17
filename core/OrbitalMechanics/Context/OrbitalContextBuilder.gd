class_name OrbitalContextBuilder

func build_model(model: OrbitalModel) -> void:
	for body:AbstractBinding in model.values():
		var current_pri = body.get_parent_binding()
		var last_pri = body.last_parent
		
		# Only rebuild if the hierarchy actually changed
		if body.sim_context == null or last_pri != current_pri:
			body.sim_context = _create_context(body, model)
			body.solver_dirty = true
		else:
			_update_relative_state(body, body.sim_context)

func _create_context(body, model) -> OrbitalContext:
	# Prevent cycles

	var ctx = OrbitalContext.new()
	ctx.subject = body
	#body.assign_parent(parent)
	
	var parent = body.get_parent_binding()
	
	if parent:
		ctx.mu = parent.get_mu()
		var gp = parent.get_parent_binding() 
		ctx.escape_radius = OrbitalHierarchy.compute_soi_radius(parent, gp) if gp else INF
	else:
		ctx.escape_radius = INF
		
	_update_relative_state(body, ctx)
	return ctx

func _update_relative_state(body: AbstractBinding, ctx: OrbitalContext) -> void:
	var parent = body.get_parent_binding()
	if parent:
		ctx.r_primary = body.sim_position - parent.sim_position
		ctx.v_primary = body.sim_velocity - parent.sim_velocity
	else:
		ctx.r_primary = body.sim_position
		ctx.v_primary = body.sim_velocity
