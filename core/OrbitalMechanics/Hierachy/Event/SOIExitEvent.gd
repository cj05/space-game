## SOIExitEvent.gd
class_name SOIExitEvent
extends Node

const EXIT_BUFFER = 1.005 # 0.5% buffer to prevent "jitter" transitions

func register():
	Scheduler.detect_event.connect(_on_detect_event)

func _on_detect_event(d0: float, d1: float, _last_snapshots: Dictionary, events: Array):
	events.append({
		"sample_t": d1,
		"t": d0,
		"fn": probe_for_exit,
		"ghost": true,
		"body": null
	})

func probe_for_exit(state: SimulationState):
	var snaps = state.snapshots
	for body in snaps.keys():
		if body.role <= OrbitalRole.Type.MOON: continue 
		
		var parent = body.get_parent_binding()
		if not parent or not snaps.has(parent): continue
		
		# --- ADD THIS GUARD ---
		# If the parent is the STAR (Root), don't allow "Exit" 
		# unless you actually have an Interstellar system.
		if parent.role == OrbitalRole.Type.STAR: continue
		# ----------------------
		
		var s_body = snaps[body]
		var s_parent = snaps[parent]
		
		# Calculate distance using GLOBAL positions to avoid relative math errors
		var dist_end = s_body.global_r.distance_to(s_parent.global_r)
		
		# 1.01 Hysteresis factor
		if dist_end > (parent.get_soi_radius() * 1.01):
			# Verify we are actually MOVING AWAY (RV Dot product)
			# This prevents infinite loops if we are stuck on the boundary
			var rel_v = s_body.global_v - s_parent.global_v
			var rel_p = s_body.global_r - s_parent.global_r
			if rel_v.dot(rel_p) > 0: 
				_refine_exit_and_inject(body, parent, 0.0, Scheduler.current_frame_dt, 0)
				
func _refine_exit_and_inject(body, parent, t_low, t_high, depth):
	if depth >= 8: # Reduced depth for performance/stability
		_final_exit_inject(body, parent, t_high)
		return

	var t_mid = (t_low + t_high) / 2.0
	Scheduler.schedule_task(ScheduledTask.new(
		Scheduler.sim_time + t_mid, Scheduler.sim_time, Scheduler.next_order(),
		func(state):
			var snaps = state.snapshots
			var d = (snaps[body].global_r - snaps[parent].global_r).length()
			if d > parent.get_soi_radius():
				_refine_exit_and_inject(body, parent, t_low, t_mid, depth + 1)
			else:
				_refine_exit_and_inject(body, parent, t_mid, t_high, depth + 1),
		true, body
	))

func _final_exit_inject(body, parent, t_offset):
	var t_hit = Scheduler.sim_time + t_offset
	var grand_parent = parent.get_parent_binding() 
	
	Scheduler.schedule_task(ScheduledTask.new(
		t_hit, t_hit, Scheduler.next_order(),
		func(state):
			# 1. Check if we already handled this (Safety)
			if body.get_parent_binding() != parent:
				return Scheduler.EventResult.CONTINUE

			print("[EXIT] %s leaving %s SOI" % [body.name, parent.name])
			
			# 2. DO THE REAL TRANSITION
			body.perform_soi_transition(grand_parent)
			
			# 3. CRITICAL: Update the Snapshot in the current state
			# If we don't do this, the next detector probe sees the old data!
			if state.snapshots.has(body):
				var s = state.snapshots[body]
				# Sync snapshot to the body's new relative reality
				s.rel_r = body.sim_position 
				s.rel_v = body.sim_velocity
				s.mu = grand_parent.get_mu() if grand_parent else 0.0
				s.is_dirty = true # Force solver rebuild
				
				# Update global cache so distance checks pass correctly
				s.global_r = body.get_global_position() 
				s.global_v = body.get_global_velocity()

			return Scheduler.EventResult.CONTINUE,
		false, body
	))
