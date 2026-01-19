class_name OrbitalContextBuilder

# Purely populates snapshots without touching AbstractBinding sim_context
func build_snapshot_context(model: OrbitalModel, snapshots: Dictionary) -> void:
	for body in model.values():
		var s: SimulationSnapshot = snapshots[body]
		var parent = body.get_parent_binding()
		
		# 1. Update Mu and Solver Parameters
		if parent:
			s.mu = parent.get_mu()
			# If you still use escape_radius logic:
			var gp = parent.get_parent_binding()
			# Note: s.escape_radius would need to be added to SimulationSnapshot class
			s.escape_radius = OrbitalHierarchy.compute_soi_radius(parent, gp) if gp else INF
		else:
			s.mu = 0.0 
			s.escape_radius = INF
			
		# 2. Update Primary Context (Relative r and v)
		# We calculate this from the snapshot's current relative state 
		# (which has been modified by Phase 1 Kick)
		_fill_relative_context(s, snapshots)

func _fill_relative_context(s: SimulationSnapshot, snapshots: Dictionary) -> void:
	var parent = s.body.get_parent_binding()
	
	if parent and snapshots.has(parent):
		var ps: SimulationSnapshot = snapshots[parent]
		# The solver expects r_primary to be the vector FROM parent TO body
		s.r_primary = s.rel_r - ps.rel_r
		s.v_primary = s.rel_v - ps.rel_v
	else:
		# Root bodies (Stars) are relative to origin
		s.r_primary = s.rel_r
		s.v_primary = s.rel_v
