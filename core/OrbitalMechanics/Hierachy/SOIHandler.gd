class_name SOIHandler

const HYSTERESIS := 0.98

## Evaluates the current context and returns the 'intended' primary
static func evaluate_primary(body: AbstractBinding, model: OrbitalModel) -> AbstractBinding:
	var ctx = body.sim_context
	if ctx == null: 
		return OrbitalHierarchy.find_best_primary(body, model)

	# 1. CHECK DOWNWARD: Can we be captured by a sibling?
	for sibling in ctx.capture_candidates:
		if _is_captured_by(body, sibling, ctx.primary):
			return sibling

	# 2. CHECK UPWARD: Have we escaped our current primary?
	if ctx.primary and _has_escaped(body, ctx):
		return _get_grandparent(ctx.primary)

	# 3. CHECK ROOT: If interstellar, look for any new capture
	if ctx.primary == null:
		var best_p = OrbitalHierarchy.find_best_primary(body, model)
		if best_p: return best_p

	return ctx.primary

static func _is_captured_by(body, sibling, current_pri) -> bool:
	if not is_instance_valid(sibling): return false
	var d = body.sim_position.distance_to(sibling.sim_position)
	var soi = OrbitalHierarchy.compute_soi_radius(sibling, current_pri)
	return d < (soi * HYSTERESIS)

static func _has_escaped(body, ctx) -> bool:
	var d_pri = body.sim_position.distance_to(ctx.primary.sim_position)
	return d_pri > (ctx.escape_radius / HYSTERESIS)

static func _get_grandparent(primary) -> AbstractBinding:
	if primary.sim_context and primary.sim_context.primary:
		return primary.sim_context.primary
	return null
